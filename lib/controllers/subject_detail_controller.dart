import 'package:flutter/material.dart';

import '../data/curriculum_data.dart';
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

  /// Finds this [subjectId]'s entry in the fixed curriculum, if it
  /// matches one of the deterministic curriculum ids. Used as a
  /// fallback when Firestore/the local cache doesn't have this
  /// subject yet — e.g. the Subjects screen now lists every fixed
  /// curriculum subject even before anything has been published for
  /// it, so tapping one of those needs a sensible screen instead of
  /// "Subject not found".
  ({CurriculumCategory category, CurriculumSubject subject})?
      _lookupCurriculumSubject() {
    for (final category in kFixedCurriculum) {
      for (var i = 0; i < category.subjects.length; i++) {
        if (curriculumSubjectId(category.code, i) == subjectId) {
          return (category: category, subject: category.subjects[i]);
        }
      }
    }
    return null;
  }

  Future<void> loadSubjectDetail() async {
    isLoading = true;
    notifyListeners();

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

    // Nothing has been published/synced for this subject yet — fall
    // back to curriculum data so the header shows the real subject
    // name instead of "Subject not found".
    if (subject == null) {
      final match = _lookupCurriculumSubject();
      if (match != null) {
        subject = {
          'id': subjectId,
          'name': match.subject.name,
          'code': match.category.code,
          'colorHex': '',
        };
      }
    }

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
