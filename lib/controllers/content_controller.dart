// Matches these pubspec.yaml versions:
//   file_picker: ^11.0.3           (static FilePicker.pickFiles(), no .platform)
//   csv: ^8.0.0                    (global `csv` singleton, csv.decode())
//   docx_to_text: ^1.0.1           (pull text out of an uploaded .docx)
//   syncfusion_flutter_pdf: ^33.2.13  (pull text out of an uploaded .pdf)
//
// Legacy binary .doc files are accepted (extension-wise) but aren't
// safely parseable client-side, so their lesson content stays blank
// until edited directly — everything else about publishing still works.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Which sub-tab of the Contents screen is active.
enum ContentTab { lessons, assessment }

/// One entry in the Category dropdown.
class ContentCategory {
  final String code;
  final String label;
  const ContentCategory(this.code, this.label);
}

/// Fixed category list — mirrors the `code` values already used on
/// subject docs ('GE' / 'PE' / 'SP') elsewhere in the app.
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

  static const Map<String, String> categoryLabels = {
    'GE': 'General Education',
    'PE': 'Professional Education',
    'SP': 'Specialization',
  };

  ContentTab activeTab = ContentTab.lessons;

  bool isLoading = true;
  bool isPublishing = false;
  String? formError;
  String? successMessage;

  // ---- form state ----
  String? selectedCategoryCode;
  String? selectedSubjectId;
  String? selectedCompetencyLessonId; // null = brand-new competency
  final TextEditingController competencyController = TextEditingController();

  PlatformFile? pickedFile;
  String? _extractedText;

  // ---- data ----
  List<Map<String, dynamic>> _allSubjects = [];

  List<Map<String, dynamic>> get subjectsForSelectedCategory =>
      selectedCategoryCode == null
          ? []
          : _allSubjects
              .where((s) => (s['code'] as String?) == selectedCategoryCode)
              .toList();

  List<Map<String, dynamic>> _lessonsForSelectedSubject = [];
  List<Map<String, dynamic>> get lessonsForSelectedSubject =>
      _lessonsForSelectedSubject;

  List<ExistingContentItem> existingLessons = [];
  List<ExistingContentItem> existingAssessments = [];

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    final subjectsSnap =
        await _firestore.collection('subjects').orderBy('order').get();
    _allSubjects =
        subjectsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

    await _loadExistingContent();

    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadExistingContent() async {
    final lessons = <ExistingContentItem>[];
    final assessments = <ExistingContentItem>[];

    for (final subject in _allSubjects) {
      final subjectId = subject['id'] as String;
      final code = (subject['code'] as String?) ?? '';
      final categoryLabel = categoryLabels[code] ?? code;

      final lessonsSnap = await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('lessons')
          .orderBy('order')
          .get();

      for (final lessonDoc in lessonsSnap.docs) {
        final data = lessonDoc.data();
        final content = (data['content'] as String?) ?? '';

        lessons.add(ExistingContentItem(
          subjectId: subjectId,
          lessonId: lessonDoc.id,
          competencyTitle: (data['title'] as String?) ?? '',
          subjectName: (subject['name'] as String?) ?? '',
          categoryLabel: categoryLabel,
          estimatedMinutes: _estimateReadMinutes(content),
        ));

        final quizSnap = await _firestore
            .collection('subjects')
            .doc(subjectId)
            .collection('lessons')
            .doc(lessonDoc.id)
            .collection('quiz')
            .get();

        if (quizSnap.docs.isNotEmpty) {
          assessments.add(ExistingContentItem(
            subjectId: subjectId,
            lessonId: lessonDoc.id,
            competencyTitle: (data['title'] as String?) ?? '',
            subjectName: (subject['name'] as String?) ?? '',
            categoryLabel: categoryLabel,
            questionCount: quizSnap.docs.length,
          ));
        }
      }
    }

    // Most-recently-added first, matching the mockup's list ordering.
    existingLessons = lessons.reversed.toList();
    existingAssessments = assessments.reversed.toList();
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
    competencyController.clear();
    pickedFile = null;
    _extractedText = null;
    _lessonsForSelectedSubject = [];
    formError = null;
    successMessage = null;
  }

  void selectCategory(String code) {
    selectedCategoryCode = code;
    selectedSubjectId = null;
    selectedCompetencyLessonId = null;
    competencyController.clear();
    _lessonsForSelectedSubject = [];
    notifyListeners();
  }

  Future<void> selectSubject(String subjectId) async {
    selectedSubjectId = subjectId;
    selectedCompetencyLessonId = null;
    competencyController.clear();
    notifyListeners();

    final snap = await _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('lessons')
        .orderBy('order')
        .get();
    _lessonsForSelectedSubject =
        snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    notifyListeners();
  }

  /// [lessonId] null means "brand-new competency" — clears the text
  /// field for typing. Otherwise prefills it with that lesson's
  /// current title so the admin can also rename it here.
  void selectCompetency(String? lessonId) {
    selectedCompetencyLessonId = lessonId;
    if (lessonId == null) {
      competencyController.clear();
    } else {
      final lesson = _lessonsForSelectedSubject.firstWhere(
        (l) => l['id'] == lessonId,
        orElse: () => const {},
      );
      competencyController.text = (lesson['title'] as String?) ?? '';
    }
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
    if (competencyController.text.trim().isEmpty) {
      formError = 'Please enter a competency.';
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
        await _ensureLessonDoc(isLessonTab: true);
      } else {
        await _publishAssessment();
      }

      successMessage =
          activeTab == ContentTab.lessons ? 'Lesson published.' : 'Assessment published.';

      await _loadExistingContent();
      selectedCompetencyLessonId = null;
      competencyController.clear();
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

  /// Creates a new lesson doc for a brand-new competency, or updates
  /// the title (and, for the Lessons tab, the content) of an existing
  /// one. Returns the lesson id either way.
  Future<String> _ensureLessonDoc({required bool isLessonTab}) async {
    final subjectRef =
        _firestore.collection('subjects').doc(selectedSubjectId);
    final title = competencyController.text.trim();

    if (selectedCompetencyLessonId != null) {
      final data = <String, dynamic>{
        'title': title,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isLessonTab) data['content'] = (_extractedText ?? '').trim();

      await subjectRef
          .collection('lessons')
          .doc(selectedCompetencyLessonId)
          .set(data, SetOptions(merge: true));
      return selectedCompetencyLessonId!;
    }

    // New competency → new lesson doc, appended after existing ones so
    // it shows up right away in the user-facing Subject Detail screen.
    final nextOrder = _lessonsForSelectedSubject.length;
    final doc = await subjectRef.collection('lessons').add({
      'title': title,
      'content': isLessonTab ? (_extractedText ?? '').trim() : '',
      'order': nextOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> _publishAssessment() async {
    final lessonId = await _ensureLessonDoc(isLessonTab: false);
    final rows = await _parseCsv(pickedFile!);
    if (rows.isEmpty) {
      throw Exception('CSV had no valid question rows.');
    }

    final quizCollection = _firestore
        .collection('subjects')
        .doc(selectedSubjectId)
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

    final header = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
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
        'explanation':
            (explCol == -1 || row.length <= explCol) ? '' : row[explCol].toString().trim(),
      });
    }
    return result;
  }

  @override
  void dispose() {
    competencyController.dispose();
    super.dispose();
  }
}
