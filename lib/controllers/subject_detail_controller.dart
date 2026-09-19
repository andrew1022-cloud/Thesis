import 'package:flutter/material.dart';

import '../services/local_db_service.dart';

/// One lesson row's display data for the Subject Detail screen.
class LessonDetailItem {
  final String id;
  final String title;
  final bool isCompleted;
  final int estimatedMinutes;

  LessonDetailItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.estimatedMinutes,
  });
}

/// Holds all state for the Subject Detail screen (shown when a
/// subject is tapped from the Subjects list). The UI only reads from
/// this controller — it does not compute completion or read-time
/// estimates itself.
class SubjectDetailController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final String uid;
  final String subjectId;

  SubjectDetailController({required this.uid, required this.subjectId});

  bool isLoading = true;

  Map<String, dynamic>? subject;
  List<LessonDetailItem> lessons = [];
  int progressPercent = 0;

  int get completedCount => lessons.where((l) => l.isCompleted).length;
  int get totalCount => lessons.length;

  Future<void> loadSubjectDetail() async {
    isLoading = true;
    notifyListeners();

    // The local cache may not have this subject's lessons synced yet
    // — LocalDbService.syncAll() (kicked off in the background from
    // Home) walks subjects/lessons/quiz sequentially, so this screen
    // can be opened before that sync reaches this particular subject,
    // showing a stale "0/0 Done" with no lessons listed. Sync this
    // subject's lessons on demand whenever the local cache is empty,
    // rather than relying on a manual pull-to-refresh to fix it.
    var rawLessons = await _db.getLessons(subjectId);
    if (rawLessons.isEmpty) {
      await _db.syncLessonsForSubject(subjectId);
      rawLessons = await _db.getLessons(subjectId);
    }

    final results = await Future.wait([
      _db.getSubjectById(subjectId),
      _db.getCompletedLessonIdsForSubject(uid, subjectId),
      _db.getSubjectProgressPercent(uid, subjectId),
    ]);

    subject = results[0] as Map<String, dynamic>?;
    final completedIds = results[1] as Set<String>;
    progressPercent = results[2] as int;

    lessons = rawLessons.map((l) {
      final id = l['id'] as String;
      final content = (l['content'] as String?) ?? '';
      return LessonDetailItem(
        id: id,
        title: l['title'] as String,
        isCompleted: completedIds.contains(id),
        estimatedMinutes: _estimateReadMinutes(content),
      );
    }).toList();

    isLoading = false;
    notifyListeners();
  }

  /// Rough "x mins read" estimate at ~200 words per minute. Content
  /// doesn't carry its own read-time field, so this is derived from
  /// word count and always rounds up to at least 1 minute.
  int _estimateReadMinutes(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return 1;
    final wordCount = trimmed.split(RegExp(r'\s+')).length;
    return (wordCount / 200).ceil().clamp(1, 999);
  }

  /// Call when a lesson row is tapped — records it as opened so it
  /// shows up in "Continue by Subject" on Home. Doesn't navigate
  /// anywhere yet since there's no LessonScreen built out.
  Future<void> openLesson(String lessonId) async {
    if (subject == null) return;
    await _db.recordLessonOpened(
      uid: uid,
      subjectId: subjectId,
      lessonId: lessonId,
    );
  }

  /// Pull-to-refresh: sync this subject's lessons and quiz questions
  /// from Firestore first, then reload from the updated local cache.
  Future<void> refresh() async {
    await _db.syncLessonsForSubject(subjectId);
    final lessons = await _db.getLessons(subjectId);
    for (final lesson in lessons) {
      await _db.syncQuizForLesson(subjectId, lesson['id'] as String);
    }
    await loadSubjectDetail();
  }
}
