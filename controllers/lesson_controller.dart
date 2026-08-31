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
