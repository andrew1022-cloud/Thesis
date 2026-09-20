// Matches these pubspec.yaml versions:
//   file_picker: 10.3.10           (FilePicker.platform.pickFiles())
//   csv: ^8.0.0                    (global `csv` singleton, csv.decode())
//   docx_to_text: ^1.0.1           (pull text out of an uploaded .docx)
//   syncfusion_flutter_pdf: ^33.2.13  (pull text out of an uploaded .pdf)
//   syncfusion_flutter_pdfviewer: ^33.2.13  (actually *render* a picked
//     PDF for the admin preview dialog, and the published PDF on the
//     Lesson screen)
//
// PDFs are stored in Firestore only (no Firebase Storage, which needs
// the paid Blaze plan): see LessonPdfService, which splits the PDF
// into chunk docs under subjects/{id}/lessons/{id}/pdfChunks.
//
// Legacy binary .doc files are accepted (extension-wise) but aren't
// safely parseable client-side, so their lesson content stays blank
// until edited directly — everything else about publishing still works.
//
// Category → Subject → Competency are driven entirely by the fixed
// curriculum in `data/curriculum_data.dart` (kFixedCurriculum), not by
// whatever happens to already be sitting in Firestore. Picking a
// category only ever offers that category's subjects; picking a
// subject only ever offers that subject's competencies. subjectId /
// lessonId are derived deterministically (see curriculumSubjectId /
// curriculumLessonId) so publishing always writes to the same doc a
// given competency would use, whether or not "Seed Fixed Curriculum"
// has been run first.
//
// Assessment CSV columns: questionText, optionA, optionB, optionC,
// optionD, correctOption, explanation (optional), difficulty
// (optional: Easy / Moderate / Difficult — a column named "tag" works
// too). Untagged questions count as Moderate.

import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../data/assessment_config.dart';
import '../data/curriculum_data.dart';
import '../services/lesson_pdf_service.dart';

/// Which sub-tab of the Contents screen is active.
enum ContentTab { lessons, assessment }

/// One entry in the Category dropdown.
class ContentCategory {
  final String code;
  final String label;
  const ContentCategory(this.code, this.label);
}

/// Fixed category list — mirrors kFixedCurriculum's own categories.
const List<ContentCategory> kContentCategories = [
  ContentCategory('GE', 'General Education'),
  ContentCategory('PE', 'Professional Education'),
  ContentCategory('SP', 'Specialization'),
];

/// One row in "Existing Lessons" / "Existing Assessment".
class ExistingContentItem {
  final String subjectId;
  final String lessonId;
  final String competencyTitle;
  final String subjectName;
  final String categoryLabel;
  final int estimatedMinutes; // lessons only
  final int questionCount; // assessment only

  ExistingContentItem({
    required this.subjectId,
    required this.lessonId,
    required this.competencyTitle,
    required this.subjectName,
    required this.categoryLabel,
    this.estimatedMinutes = 0,
    this.questionCount = 0,
  });
}

/// Holds all state for the Contents tab: the Lessons/Assessment form
/// (category → subject → competency → file), and the two "Existing"
/// lists below it. The UI only reads from this controller.
class ContentController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ContentTab activeTab = ContentTab.lessons;

  bool isLoading = true;
  bool isPublishing = false;
  bool isDeleting = false;
  String? formError;
  String? successMessage;

  /// Set when the initial load of "Existing Lessons/Assessment" fails
  /// (e.g. a Firestore permission-denied on the collectionGroup
  /// queries below, or a missing composite index). Shown in the UI
  /// with a Retry action instead of leaving the screen stuck on its
  /// loading spinner forever.
  String? loadError;

  // ---- form state ----
  String? selectedCategoryCode;
  String? selectedSubjectId;
  String? selectedCompetencyLessonId;

  PlatformFile? pickedFile;
  String? _extractedText;

  // ---- data ----
  List<ExistingContentItem> existingLessons = [];
  List<ExistingContentItem> existingAssessments = [];

  // =================================================================
  // CURRICULUM-DRIVEN DROPDOWN DATA
  // =================================================================

  CurriculumCategory? _categoryByCode(String code) {
    for (final c in kFixedCurriculum) {
      if (c.code == code) return c;
    }
    return null;
  }

  CurriculumCategory? get _selectedCategory => selectedCategoryCode == null
      ? null
      : _categoryByCode(selectedCategoryCode!);

  /// (subjectId, subject) pairs for the selected category only — e.g.
  /// picking "General Education" only ever offers GenEd subjects.
  List<MapEntry<String, CurriculumSubject>> get subjectsForSelectedCategory {
    final category = _selectedCategory;
    if (category == null) return [];
    return [
      for (var i = 0; i < category.subjects.length; i++)
        MapEntry(curriculumSubjectId(category.code, i), category.subjects[i]),
    ];
  }

  CurriculumSubject? get _selectedSubject {
    if (selectedSubjectId == null) return null;
    for (final entry in subjectsForSelectedCategory) {
      if (entry.key == selectedSubjectId) return entry.value;
    }
    return null;
  }

  /// (lessonId, competency) pairs for the selected subject only — e.g.
  /// picking "Purposive Communication in English" only ever offers
  /// that subject's own competencies.
  List<MapEntry<String, CurriculumCompetency>>
      get competenciesForSelectedSubject {
    final subject = _selectedSubject;
    if (subject == null || selectedSubjectId == null) return [];
    return [
      for (var i = 0; i < subject.competencies.length; i++)
        MapEntry(
          curriculumLessonId(selectedSubjectId!, i),
          subject.competencies[i],
        ),
    ];
  }

  int _competencyIndexFor(String lessonId) =>
      competenciesForSelectedSubject.indexWhere((e) => e.key == lessonId);

  // =================================================================
  // PDF PREVIEW (admin-side, before publishing)
  // =================================================================

  /// True when the currently picked file is a PDF whose bytes are
  /// available in memory — i.e. it can be rendered directly with
  /// `SfPdfViewer.memory` in a preview dialog, without needing to
  /// publish it first.
  bool get canPreviewPickedPdf =>
      activeTab == ContentTab.lessons &&
      pickedFile != null &&
      (pickedFile!.extension ?? '').toLowerCase() == 'pdf' &&
      pickedFile!.bytes != null;

  /// Bytes of the currently picked PDF, for the admin preview dialog.
  /// Null whenever [canPreviewPickedPdf] is false.
  Uint8List? get pickedPdfBytes =>
      canPreviewPickedPdf ? pickedFile!.bytes : null;

  Future<void> init() async {
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      await _loadExistingContent();
    } catch (e) {
      debugPrint('ContentController: failed to load existing content: $e');
      loadError = _describeLoadError(e);
      existingLessons = [];
      existingAssessments = [];
    }

    isLoading = false;
    notifyListeners();
  }

  /// Retry hook for a "Retry" button in the UI after [loadError].
  Future<void> retryInit() => init();

  String _describeLoadError(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return "Couldn't load existing content: permission denied. "
          'Firestore rules need to explicitly allow collection-group '
          'reads on "lessons" and "quiz" '
          '(e.g. match /{path=**}/lessons/{id} and '
          'match /{path=**}/quiz/{id}), not just the nested path — a '
          'rule scoped only to subjects/{id}/lessons/{id} does not '
          'cover a collectionGroup() query.';
    }
    if (e is FirebaseException && e.code == 'failed-precondition') {
      return "Couldn't load existing content: Firestore needs a "
          'composite index for this query. Check the debug console for '
          'a link to create it, or open the Firestore console > '
          'Indexes.';
    }
    return "Couldn't load existing content. Please try again.";
  }

  /// Scans every lesson/quiz doc that belongs to the fixed curriculum
  /// (matched by the same deterministic ids `publish()` writes to) and
  /// lists only the ones that actually have something published.
  Future<void> _loadExistingContent() async {
    final lessonsSnap = await _firestore.collectionGroup('lessons').get();
    final lessonDataById = <String, Map<String, dynamic>>{
      for (final doc in lessonsSnap.docs) doc.id: doc.data(),
    };

    final quizSnap = await _firestore.collectionGroup('quiz').get();
    final quizCountByLesson = <String, int>{};
    for (final doc in quizSnap.docs) {
      final lessonId = doc.reference.parent.parent?.id;
      if (lessonId == null) continue;
      quizCountByLesson[lessonId] = (quizCountByLesson[lessonId] ?? 0) + 1;
    }

    final lessons = <ExistingContentItem>[];
    final assessments = <ExistingContentItem>[];

    for (final category in kFixedCurriculum) {
      for (var s = 0; s < category.subjects.length; s++) {
        final subject = category.subjects[s];
        final subjectId = curriculumSubjectId(category.code, s);

        for (var c = 0; c < subject.competencies.length; c++) {
          final competency = subject.competencies[c];
          final lessonId = curriculumLessonId(subjectId, c);

          final data = lessonDataById[lessonId];
          final content = (data?['content'] as String?) ?? '';
          final hasPdf = ((data?['pdfChunkCount'] as num?)?.toInt() ?? 0) > 0;
          if (data != null && (content.trim().isNotEmpty || hasPdf)) {
            lessons.add(ExistingContentItem(
              subjectId: subjectId,
              lessonId: lessonId,
              competencyTitle: competency.title,
              subjectName: subject.name,
              categoryLabel: category.label,
              estimatedMinutes: _estimateReadMinutes(content),
            ));
          }

          final quizCount = quizCountByLesson[lessonId] ?? 0;
          if (quizCount > 0) {
            assessments.add(ExistingContentItem(
              subjectId: subjectId,
              lessonId: lessonId,
              competencyTitle: competency.title,
              subjectName: subject.name,
              categoryLabel: category.label,
              questionCount: quizCount,
            ));
          }
        }
      }
    }

    existingLessons = lessons;
    existingAssessments = assessments;
  }

  int _estimateReadMinutes(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return 1;
    final wordCount = trimmed.split(RegExp(r'\s+')).length;
    return (wordCount / 200).ceil().clamp(1, 999);
  }

  // ---- tab / selection ----

  void switchTab(ContentTab tab) {
    if (activeTab == tab) return;
    activeTab = tab;
    _resetForm();
    notifyListeners();
  }

  void _resetForm() {
    selectedCategoryCode = null;
    selectedSubjectId = null;
    selectedCompetencyLessonId = null;
    pickedFile = null;
    _extractedText = null;
    formError = null;
    successMessage = null;
  }

  void selectCategory(String code) {
    selectedCategoryCode = code;
    selectedSubjectId = null;
    selectedCompetencyLessonId = null;
    pickedFile = null;
    _extractedText = null;
    notifyListeners();
  }

  void selectSubject(String subjectId) {
    selectedSubjectId = subjectId;
    selectedCompetencyLessonId = null;
    pickedFile = null;
    _extractedText = null;
    notifyListeners();
  }

  void selectCompetency(String lessonId) {
    selectedCompetencyLessonId = lessonId;
    notifyListeners();
  }

  // ---- file picking ----

  Future<void> pickFile() async {
    formError = null;
    final allowed = activeTab == ContentTab.lessons
        ? ['pdf', 'doc', 'docx']
        : ['csv'];

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowed,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final ext = (file.extension ?? '').toLowerCase();
    if (!allowed.contains(ext)) {
      formError = activeTab == ContentTab.lessons
          ? 'Please choose a .pdf or Word (.doc/.docx) file.'
          : 'Please choose a .csv file.';
      notifyListeners();
      return;
    }

    pickedFile = file;
    _extractedText = null;
    notifyListeners();

    if (activeTab == ContentTab.lessons) {
      await _extractLessonText(file);
    }
  }

  Future<void> _extractLessonText(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) return;
    final ext = (file.extension ?? '').toLowerCase();

    try {
      if (ext == 'docx') {
        _extractedText = _dropRepeatedPageFurniture(
          _reflowByBlankLines(docxToText(bytes)),
        );
      } else if (ext == 'pdf') {
        final document = PdfDocument(inputBytes: bytes);
        final raw = _extractTextByLinePosition(document);
        document.dispose();
        _extractedText = _dropRepeatedPageFurniture(raw);
      } else {
        // Legacy .doc — leave content blank rather than risk garbled text.
        _extractedText = '';
      }
    } catch (e) {
      debugPrint('ContentController: text extraction failed: $e');
      _extractedText = '';
    }
    notifyListeners();
  }

  /// Rebuilds readable paragraphs from a PDF using each line's actual
  /// position on the page, rather than trusting the newlines
  /// `PdfTextExtractor.extractText()` embeds in its output.
  ///
  /// Those embedded newlines turned out to be unreliable for some
  /// PDFs: a single visual line (e.g. a title using an em dash, or
  /// any run of differently-styled text) can get split into several
  /// separate "lines" in the extracted string, and genuine paragraph
  /// breaks aren't consistently marked by a blank line either — both
  /// of which made the student-facing lesson screen render as
  /// fragmented text instead of normal prose.
  ///
  /// Using `extractTextLines()` instead gives each line's bounding
  /// box, so line breaks can be reconstructed from real page geometry
  /// per page: a small vertical gap to the next line (including
  /// near-zero — fragments of the same visual line) is treated as a
  /// continuation and joined with a space; a gap noticeably larger
  /// than a normal line height is treated as an actual paragraph
  /// break.
  String _extractTextByLinePosition(PdfDocument document) {
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();

    for (var pageIndex = 0; pageIndex < document.pages.count; pageIndex++) {
      List<TextLine> lines;
      try {
        lines = extractor.extractTextLines(
          startPageIndex: pageIndex,
          endPageIndex: pageIndex,
        );
      } catch (e) {
        debugPrint(
            'ContentController: extractTextLines failed on page $pageIndex: $e');
        continue;
      }

      double? previousBottom;
      double typicalLineHeight = 12;

      for (final line in lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;

        final top = line.bounds.top;
        final bottom = line.bounds.bottom;
        if (line.bounds.height > 0) typicalLineHeight = line.bounds.height;

        if (previousBottom == null) {
          buffer.write(text);
        } else {
          final gap = top - previousBottom;
          final isNewParagraph = gap > typicalLineHeight * 0.6;
          buffer
            ..write(isNewParagraph ? '\n\n' : ' ')
            ..write(text);
        }
        previousBottom = bottom;
      }
      buffer.write('\n\n'); // always start the next page fresh
    }

    return buffer.toString();
  }

  /// Simpler paragraph reflow used for DOCX text (which, unlike the
  /// PDF path above, comes from `docx_to_text` parsing real `<w:p>`
  /// paragraph elements, so blank lines reliably mark real paragraph
  /// breaks). A blank line (2+ consecutive newlines) is kept as a
  /// paragraph break; any other newline is a soft wrap joined with a
  /// space. Only a genuine bullet glyph or numbered-list marker keeps
  /// its own line — a bare "-" is deliberately NOT treated as a
  /// bullet, since it's far more often a stray fragment (an em dash,
  /// a mid-title hyphen) than an actual list item.
  String _reflowByBlankLines(String raw) {
    if (raw.trim().isEmpty) return '';

    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawParagraphs = normalized.split(RegExp(r'\n{2,}'));
    final paragraphs = <String>[];

    for (final rawParagraph in rawParagraphs) {
      final lines = rawParagraph
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      final buffer = StringBuffer(lines.first);
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i];
        final isBullet = RegExp(r'^(●|•|\d+[.)])\s').hasMatch(line);
        buffer.write(isBullet ? '\n$line' : ' $line');
      }
      paragraphs.add(buffer.toString());
    }

    return paragraphs.join('\n\n');
  }

  /// Drops page furniture: lone "Page N" markers, and any short
  /// paragraph (a running header/footer) that repeats across most of
  /// the document. The length cap keeps this from ever discarding a
  /// genuine multi-sentence paragraph that just happens to repeat.
  String _dropRepeatedPageFurniture(String text) {
    final paragraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) return '';

    final counts = <String, int>{};
    for (final p in paragraphs) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final pageNumberPattern = RegExp(r'^Page\s+\d+$', caseSensitive: false);

    final cleaned = paragraphs.where((p) {
      if (pageNumberPattern.hasMatch(p)) return false;
      if (p.length <= 100 && (counts[p] ?? 0) >= 3) return false;
      return true;
    }).toList();

    return cleaned.join('\n\n');
  }

  void clearFile() {
    pickedFile = null;
    _extractedText = null;
    notifyListeners();
  }

  // ---- publish ----

  Future<bool> publish() async {
    formError = null;
    successMessage = null;

    if (selectedCategoryCode == null) {
      formError = 'Please select a category.';
      notifyListeners();
      return false;
    }
    if (selectedSubjectId == null) {
      formError = 'Please select a subject.';
      notifyListeners();
      return false;
    }
    if (selectedCompetencyLessonId == null) {
      formError = 'Please select a competency.';
      notifyListeners();
      return false;
    }
    if (pickedFile == null) {
      formError = activeTab == ContentTab.lessons
          ? 'Please upload a .pdf or Word file.'
          : 'Please upload a .csv file.';
      notifyListeners();
      return false;
    }

    // A PDF is stored in Firestore in chunks, so cap its size to stay
    // inside the free plan's storage / daily-write limits.
    final pickedBytes = pickedFile!.bytes?.length ?? 0;
    if (activeTab == ContentTab.lessons &&
        (pickedFile!.extension ?? '').toLowerCase() == 'pdf' &&
        pickedBytes > LessonPdfService.maxPdfBytes) {
      formError =
          'This PDF is ${(pickedBytes / 1048576).toStringAsFixed(1)} MB. '
          'The limit is ${LessonPdfService.maxPdfBytes ~/ 1048576} MB — '
          'please compress it and try again.';
      notifyListeners();
      return false;
    }

    isPublishing = true;
    notifyListeners();

    try {
      var pdfChunks = 0;
      if (activeTab == ContentTab.lessons) {
        pdfChunks = await _publishLesson();
      } else {
        await _publishAssessment();
      }

      successMessage = activeTab == ContentTab.lessons
          ? (pdfChunks > 0
              ? 'Lesson published with PDF ($pdfChunks parts).'
              : 'Lesson published as text only — no PDF was saved.')
          : 'Assessment published.';

      try {
        await _loadExistingContent();
        loadError = null;
      } catch (e) {
        // Publishing itself succeeded — don't block on the list
        // refresh failing, just surface it quietly.
        debugPrint('ContentController: post-publish reload failed: $e');
      }
      selectedCompetencyLessonId = null;
      pickedFile = null;
      _extractedText = null;

      isPublishing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ContentController: publish failed: $e');
      formError = 'Something went wrong while publishing: $e';
      isPublishing = false;
      notifyListeners();
      return false;
    }
  }

  /// Upserts the subject doc's own metadata (name/code/order) so the
  /// subject shows up in the user-facing Subjects screen even if
  /// "Seed Fixed Curriculum" was never run — publishing one
  /// competency's content is enough on its own.
  Future<void> _ensureSubjectDoc(String subjectId) async {
    final category = _selectedCategory!;
    final subject = _selectedSubject!;
    await _firestore.collection('subjects').doc(subjectId).set({
      'name': subject.name,
      'description': '',
      'code': category.code,
      'colorHex': '',
      'order': curriculumGlobalSubjectOrder(subjectId),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// If the picked file is a PDF, saves its original bytes into
  /// Firestore as chunk docs (see LessonPdfService) and returns the
  /// new version + chunk count. Returns null for non-PDF uploads
  /// (e.g. .docx). Any failure is thrown, not swallowed, so the admin
  /// sees it instead of silently publishing a text-only lesson.
  Future<({int version, int chunkCount})?> _savePdfIfNeeded(
    String subjectId,
    String lessonId,
  ) async {
    final file = pickedFile;
    if (file == null) return null;
    if ((file.extension ?? '').toLowerCase() != 'pdf') return null;
    if (file.bytes == null) {
      throw Exception('The file picker did not load the PDF bytes.');
    }

    return LessonPdfService.instance.savePdf(
      subjectId: subjectId,
      lessonId: lessonId,
      bytes: file.bytes!,
    );
  }

  /// Returns how many PDF chunks were saved (0 = no PDF, text only).
  Future<int> _publishLesson() async {
    final subjectId = selectedSubjectId!;
    final lessonId = selectedCompetencyLessonId!;
    final competencyIndex = _competencyIndexFor(lessonId);
    final competency = competenciesForSelectedSubject[competencyIndex].value;

    await _ensureSubjectDoc(subjectId);

    // 1) Write the new PDF chunks first, so the previous PDF (if any)
    //    stays viewable until the lesson doc points at the new one.
    final pdf = await _savePdfIfNeeded(subjectId, lessonId);

    // 2) Point the lesson at the new PDF. A non-PDF upload (e.g. Word)
    //    writes version/count 0, which clears any earlier PDF.
    await _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('lessons')
        .doc(lessonId)
        .set({
      'title': competency.title,
      'content': (_extractedText ?? '').trim(),
      'pdfVersion': pdf?.version ?? 0,
      'pdfChunkCount': pdf?.chunkCount ?? 0,
      'order': competencyIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3) Remove chunks left over from any previous upload.
    try {
      await LessonPdfService.instance.deleteStaleChunks(
        subjectId: subjectId,
        lessonId: lessonId,
        keepVersion: pdf?.version,
      );
    } catch (e) {
      debugPrint('ContentController: stale chunk cleanup failed: $e');
    }

    return pdf?.chunkCount ?? 0;
  }

  // =================================================================
  // DELETE
  // =================================================================

  /// Deletes a published module: clears its text and PDF and removes
  /// the PDF chunks. The competency's lesson doc itself is kept (with
  /// an empty body) so it still appears under its subject, its quiz is
  /// untouched, and students' progress records stay valid.
  ///
  /// Returns null on success, or an error message.
  Future<String?> deleteLesson(ExistingContentItem item) async {
    if (isDeleting) return 'Please wait for the current delete to finish.';
    isDeleting = true;
    notifyListeners();

    try {
      // Clear the lesson first so students stop seeing it right away.
      await _firestore
          .collection('subjects')
          .doc(item.subjectId)
          .collection('lessons')
          .doc(item.lessonId)
          .set({
        'content': '',
        'pdfVersion': 0,
        'pdfChunkCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Then remove the PDF chunks. If this fails the lesson is already
      // cleared; leftover chunks are cleaned up on the next publish.
      try {
        await LessonPdfService.instance.deleteStaleChunks(
          subjectId: item.subjectId,
          lessonId: item.lessonId,
          keepVersion: null,
        );
      } catch (e) {
        debugPrint('ContentController: chunk cleanup after delete failed: $e');
      }

      await _refreshExistingAfterDelete();
      return null;
    } catch (e) {
      debugPrint('ContentController: delete lesson failed: $e');
      return "Couldn't delete the module: $e";
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }

  /// Deletes every quiz question of a published assessment. The
  /// lesson/competency itself is not touched.
  ///
  /// Returns null on success, or an error message.
  Future<String?> deleteAssessment(ExistingContentItem item) async {
    if (isDeleting) return 'Please wait for the current delete to finish.';
    isDeleting = true;
    notifyListeners();

    try {
      final snap = await _firestore
          .collection('subjects')
          .doc(item.subjectId)
          .collection('lessons')
          .doc(item.lessonId)
          .collection('quiz')
          .get();

      // Firestore batches are limited to 500 operations.
      const batchSize = 400;
      for (var i = 0; i < snap.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        for (final doc in snap.docs.skip(i).take(batchSize)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      await _refreshExistingAfterDelete();
      return null;
    } catch (e) {
      debugPrint('ContentController: delete assessment failed: $e');
      return "Couldn't delete the assessment: $e";
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }

  Future<void> _refreshExistingAfterDelete() async {
    try {
      await _loadExistingContent();
      loadError = null;
    } catch (e) {
      // The delete itself succeeded — don't report it as a failure.
      debugPrint('ContentController: post-delete reload failed: $e');
    }
  }

  Future<void> _publishAssessment() async {
    final subjectId = selectedSubjectId!;
    final lessonId = selectedCompetencyLessonId!;
    final competencyIndex = _competencyIndexFor(lessonId);
    final competency = competenciesForSelectedSubject[competencyIndex].value;

    await _ensureSubjectDoc(subjectId);

    // Merge only title/order here — don't touch 'content' or the PDF
    // fields so a lesson that already has published content keeps it
    // when only its quiz is being (re)published.
    await _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('lessons')
        .doc(lessonId)
        .set({
      'title': competency.title,
      'order': competencyIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final rows = await _parseCsv(pickedFile!);
    if (rows.isEmpty) {
      throw Exception('CSV had no valid question rows.');
    }

    final quizCollection = _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('lessons')
        .doc(lessonId)
        .collection('quiz');

    // Replace this competency's question bank rather than appending
    // duplicates on re-upload.
    final existing = await quizCollection.get();
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (var i = 0; i < rows.length; i++) {
      batch.set(quizCollection.doc(), {
        ...rows[i],
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Expected header row (case-insensitive):
  /// questionText, optionA, optionB, optionC, optionD, correctOption,
  /// explanation (optional), difficulty (optional — Easy / Moderate /
  /// Difficult; a column named "tag" is accepted too).
  Future<List<Map<String, dynamic>>> _parseCsv(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) return [];

    final text = utf8.decode(bytes, allowMalformed: true);
    final rows = csv.decode(text); // `csv` is the package's default Csv() instance
    if (rows.length < 2) return [];

    final header =
        rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
    int col(String name) => header.indexOf(name.toLowerCase());

    final qCol = col('questionText');
    final aCol = col('optionA');
    final bCol = col('optionB');
    final cCol = col('optionC');
    final dCol = col('optionD');
    final correctCol = col('correctOption');
    final explCol = col('explanation');
    final diffCol = col('difficulty') != -1 ? col('difficulty') : col('tag');

    if ([qCol, aCol, bCol, cCol, dCol, correctCol].any((i) => i == -1)) {
      throw Exception(
          'CSV must have columns: questionText, optionA, optionB, optionC, '
          'optionD, correctOption, explanation (optional), '
          'difficulty (optional).');
    }

    final result = <Map<String, dynamic>>[];
    for (final row in rows.skip(1)) {
      if (row.length <= qCol || row[qCol].toString().trim().isEmpty) continue;
      result.add({
        'questionText': row[qCol].toString().trim(),
        'optionA': row[aCol].toString().trim(),
        'optionB': row[bCol].toString().trim(),
        'optionC': row[cCol].toString().trim(),
        'optionD': row[dCol].toString().trim(),
        'correctOption': row[correctCol].toString().trim().toUpperCase(),
        'explanation': (explCol == -1 || row.length <= explCol)
            ? ''
            : row[explCol].toString().trim(),
        // Stored as 'easy' | 'moderate' | 'difficult'. Blank or
        // unrecognized values count as moderate.
        'difficulty': parseDifficulty(
          (diffCol == -1 || row.length <= diffCol)
              ? null
              : row[diffCol].toString(),
        ).name,
      });
    }
    return result;
  }
}
