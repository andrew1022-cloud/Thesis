import 'package:flutter/material.dart';

import '../services/local_db_service.dart';

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

  bool isLoading = true;
  Map<String, dynamic>? lesson;
  bool isCompleted = false;
  bool hasQuiz = false;

  Future<void> loadLesson() async {
    isLoading = true;
    notifyListeners();

    // Always refresh this subject's lessons from Firestore first —
    // relying on whatever's already cached locally is what silently
    // hides a lesson's `pdfUrl`. If an admin published (or
    // re-published, e.g. attaching a PDF for the first time) after
    // this device last synced, the local SQLite row can still be the
    // old text-only version, so the screen falls back to the plain
    // extracted text even though a real PDF now exists. Since this
    // is a single lesson doc read, the sync is cheap and keeps the
    // "original PDF" view actually current.
    try {
      await _db.syncLessonsForSubject(subjectId);
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

    // Opening the lesson is what powers "Continue by Subject" on Home.
    await _db.recordLessonOpened(
      uid: uid,
      subjectId: subjectId,
      lessonId: lessonId,
    );

    isLoading = false;
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
    notifyListeners();
  }
}
