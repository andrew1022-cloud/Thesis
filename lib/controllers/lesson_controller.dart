import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/lesson_pdf_service.dart';
import '../services/local_db_service.dart';
import '../services/offline_pdf_store.dart';
import '../services/points_service.dart';

/// Holds all state for the Lesson screen. The UI only reads from this
/// controller — it does not touch LocalDbService directly.
class LessonController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final String uid;
  final String subjectId;
  final String lessonId;

  LessonController({
    required this.uid,
    required this.subjectId,
    required this.lessonId,
  });

  bool _disposed = false;

  bool isLoading = true;
  Map<String, dynamic>? lesson;
  bool isCompleted = false;
  bool hasQuiz = false;

  // ---- PDF state ----
  /// The reassembled PDF, once downloaded from Firestore.
  Uint8List? pdfBytes;
  bool isPdfLoading = false;

  /// True when the lesson has a PDF but it couldn't be loaded
  /// (offline and never opened before, Firestore error, ...).
  bool pdfLoadFailed = false;

  int _pdfChunkCount = 0;
  int _pdfVersion = 0;

  /// Whether an admin published a PDF for this lesson.
  bool get hasPdf => _pdfChunkCount > 0 && _pdfVersion > 0;

  Future<void> loadLesson() async {
    isLoading = true;
    notifyListeners();

    // Always refresh this subject's lessons from Firestore first, so a
    // freshly (re)published PDF's version/chunk count is picked up
    // instead of a stale cached row. Also sync this lesson's quiz
    // questions.
    try {
      await _db.syncLessonsForSubject(subjectId);
      await _db.syncQuizForLesson(subjectId, lessonId);
    } catch (e) {
      // Offline, or Firestore unreachable — fall back to whatever is
      // already cached locally rather than blocking the screen.
      debugPrint('LessonController: failed to sync lesson data: $e');
    }

    final results = await Future.wait([
      _db.getLessonById(lessonId),
      _db.getCompletedLessonIdsForSubject(uid, subjectId),
      _db.getQuizQuestions(lessonId),
    ]);

    lesson = results[0] as Map<String, dynamic>?;
    final completedIds = results[1] as Set<String>;
    isCompleted = completedIds.contains(lessonId);
    hasQuiz = (results[2] as List<Map<String, dynamic>>).isNotEmpty;

    await _readPdfFields();

    // Opening the lesson is what powers "Continue by Subject" on Home.
    await _db.recordLessonOpened(
      uid: uid,
      subjectId: subjectId,
      lessonId: lessonId,
    );

    isLoading = false;
    notifyListeners();

    // The PDF can be several MB, so it loads after the screen is
    // already showing (title, buttons) rather than behind a spinner.
    await loadPdf();
  }

  /// Reads which PDF (if any) the admin published for this lesson.
  ///
  /// Firestore is asked first. If that fails (e.g. offline and this
  /// lesson was never opened online), fall back to the PDF the user
  /// saved through Offline Content, so downloaded lessons always show
  /// their PDF with no connection.
  Future<void> _readPdfFields() async {
    _pdfVersion = 0;
    _pdfChunkCount = 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('subjects')
          .doc(subjectId)
          .collection('lessons')
          .doc(lessonId)
          .get();
      final data = snap.data();
      _pdfVersion = (data?['pdfVersion'] as num?)?.toInt() ?? 0;
      _pdfChunkCount = (data?['pdfChunkCount'] as num?)?.toInt() ?? 0;
      debugPrint('Lesson PDF fields (Firestore): lessonId=$lessonId '
          'version=${data?['pdfVersion']} chunks=${data?['pdfChunkCount']}');
      return;
    } catch (e) {
      debugPrint('LessonController: could not read PDF fields: $e');
    }

    try {
      final saved = await OfflinePdfStore.instance.getSavedPdf(lessonId);
      if (saved != null) {
        _pdfVersion = saved.version;
        _pdfChunkCount = saved.chunks;
        debugPrint('Lesson PDF fields (offline store): lessonId=$lessonId '
            'version=${saved.version} chunks=${saved.chunks}');
      }
    } catch (e) {
      debugPrint('LessonController: offline PDF lookup failed: $e');
    }
  }

  /// Loads the lesson's PDF (offline download first, then Firestore).
  /// Also used by the "Try again" button when the first attempt fails.
  Future<void> loadPdf() async {
    if (!hasPdf) {
      pdfBytes = null;
      pdfLoadFailed = false;
      isPdfLoading = false;
      notifyListeners();
      return;
    }

    isPdfLoading = true;
    pdfLoadFailed = false;
    notifyListeners();

    Uint8List? bytes;
    try {
      bytes = await LessonPdfService.instance.loadPdf(
        subjectId: subjectId,
        lessonId: lessonId,
        version: _pdfVersion,
        chunkCount: _pdfChunkCount,
      );
    } catch (e) {
      debugPrint('LessonController: failed to load PDF: $e');
    }

    pdfBytes = bytes;
    pdfLoadFailed = bytes == null;
    isPdfLoading = false;
    notifyListeners();
  }

  Future<void> markComplete() async {
    if (isCompleted) return;
    await _db.markLessonCompleted(
      uid: uid,
      subjectId: subjectId,
      lessonId: lessonId,
    );
    isCompleted = true;
    PointsService.instance.award(uid, PointsService.lessonCompletePoints);
    notifyListeners();
  }

  // The screen can be popped while a PDF is still downloading; don't
  // notify a disposed controller when that download finishes.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
