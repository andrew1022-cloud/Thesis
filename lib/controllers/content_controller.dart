// Matches these pubspec.yaml versions:
//   file_picker: ^11.0.3           (static FilePicker.pickFiles(), no .platform)
//   csv: ^8.0.0                    (global `csv` singleton, csv.decode())
//   docx_to_text: ^1.0.1           (pull text out of an uploaded .docx)
//   syncfusion_flutter_pdf: ^33.2.13  (pull text out of an uploaded .pdf)
//   syncfusion_flutter_pdfviewer: ^33.2.13  (actually *render* a picked
//     PDF for the admin preview dialog, and the published PDF on the
//     Lesson screen — see PdfViewerScreen)
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

import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../data/curriculum_data.dart';

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
  final FirebaseStorage _storage = FirebaseStorage.instance;

  ContentTab activeTab = ContentTab.lessons;

  bool isLoading = true;
  bool isPublishing = false;
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
  /// publish or upload it first.
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
          if (data != null && content.trim().isNotEmpty) {
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
        _extractedText = docxToText(bytes);
      } else if (ext == 'pdf') {
        final document = PdfDocument(inputBytes: bytes);
        _extractedText = PdfTextExtractor(document).extractText();
        document.dispose();
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

    isPublishing = true;
    notifyListeners();

    try {
      if (activeTab == ContentTab.lessons) {
        await _publishLesson();
      } else {
        await _publishAssessment();
      }

      successMessage = activeTab == ContentTab.lessons
          ? 'Lesson published.'
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
      formError = 'Something went wrong while publishing. Please try again.';
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

  /// If the picked file is a PDF, uploads its original bytes to
  /// Firebase Storage (under `lesson_pdfs/{subjectId}/{lessonId}.pdf`,
  /// overwriting any previous upload for this competency) and returns
  /// its public download URL — this is what `PdfViewerScreen` renders
  /// on the student-facing Lesson screen, as opposed to the plain
  /// extracted text. Returns null for non-PDF uploads (e.g. .docx) or
  /// if the upload fails, in which case the lesson simply has no
  /// `pdfUrl` and only the extracted text is shown.
  Future<String?> _uploadPdfIfNeeded(String subjectId, String lessonId) async {
    final file = pickedFile;
    if (file == null || file.bytes == null) return null;
    final ext = (file.extension ?? '').toLowerCase();
    if (ext != 'pdf') return null;

    try {
      final ref = _storage
          .ref()
          .child('lesson_pdfs')
          .child(subjectId)
          .child('$lessonId.pdf');
      await ref.putData(
        file.bytes!,
        SettableMetadata(contentType: 'application/pdf'),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('ContentController: PDF upload failed: $e');
      return null;
    }
  }

  Future<void> _publishLesson() async {
    final subjectId = selectedSubjectId!;
    final lessonId = selectedCompetencyLessonId!;
    final competencyIndex = _competencyIndexFor(lessonId);
    final competency = competenciesForSelectedSubject[competencyIndex].value;

    await _ensureSubjectDoc(subjectId);

    // Upload the original PDF (if that's what was picked) so students
    // can view the real, paginated document — not just its extracted
    // text. A non-PDF upload (e.g. Word) explicitly clears any PDF
    // left over from a previous publish of this same competency.
    final pdfUrl = await _uploadPdfIfNeeded(subjectId, lessonId);

    await _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('lessons')
        .doc(lessonId)
        .set({
      'title': competency.title,
      'content': (_extractedText ?? '').trim(),
      'pdfUrl': pdfUrl ?? '',
      'order': competencyIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _publishAssessment() async {
    final subjectId = selectedSubjectId!;
    final lessonId = selectedCompetencyLessonId!;
    final competencyIndex = _competencyIndexFor(lessonId);
    final competency = competenciesForSelectedSubject[competencyIndex].value;

    await _ensureSubjectDoc(subjectId);

    // Merge only title/order here — don't touch 'content'/'pdfUrl' so
    // a lesson that already has published content keeps it when only
    // its quiz is being (re)published.
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
  /// explanation (explanation is optional).
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

    if ([qCol, aCol, bCol, cCol, dCol, correctCol].any((i) => i == -1)) {
      throw Exception(
          'CSV must have columns: questionText, optionA, optionB, optionC, '
          'optionD, correctOption, explanation (optional).');
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
      });
    }
    return result;
  }
}
