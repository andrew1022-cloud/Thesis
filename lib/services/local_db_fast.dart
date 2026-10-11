import 'dart:async';

import 'package:flutter/foundation.dart';

import 'local_db_service.dart';

/// Faster read/sync helpers for [LocalDbService], added as an extension so
/// the big local_db_service.dart file doesn't need to change.
///
/// The old code ran dozens of tiny SQLite queries one after another (and
/// even a Firestore call per empty subject) every time Home / Subjects
/// opened. These replace that with a handful of grouped queries.

DateTime? _lastFullSync;
Future<void>? _syncInFlight;

/// Don't re-download everything from Firestore more often than this
/// (pull-to-refresh and "Sync Now" can pass force: true).
const Duration _minSyncGap = Duration(minutes: 10);

extension LocalDbFast on LocalDbService {
  // ---------------------------------------------------------------
  // GROUPED READS
  // ---------------------------------------------------------------

  /// subjectId -> number of lessons, in ONE query.
  Future<Map<String, int>> getLessonCountsBySubject() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT subjectId, COUNT(*) AS c FROM ${LocalDbService.tableLessons} '
      'GROUP BY subjectId',
    );
    return {for (final r in rows) r['subjectId'] as String: (r['c'] as int)};
  }

  /// subjectId -> number of completed lessons for [uid], in ONE query.
  Future<Map<String, int>> getCompletedCountsBySubject(String uid) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT subjectId, COUNT(*) AS c '
      'FROM ${LocalDbService.tableLessonProgress} '
      'WHERE userId = ? AND isCompleted = 1 GROUP BY subjectId',
      [uid],
    );
    return {for (final r in rows) r['subjectId'] as String: (r['c'] as int)};
  }

  /// subjectId -> subject row, in ONE query.
  Future<Map<String, Map<String, dynamic>>> getSubjectsById() async {
    final subjects = await getSubjects();
    return {for (final s in subjects) s['id'] as String: s};
  }

  /// Same output as getContinueBySubject(), but with 4 queries total
  /// instead of ~4 per subject.
  Future<List<Map<String, dynamic>>> getContinueBySubjectFast(
      String uid) async {
    final db = await database;
    final subjects = await getSubjects();
    final lessonCounts = await getLessonCountsBySubject();
    final completedCounts = await getCompletedCountsBySubject(uid);

    // Most recently opened lesson per subject (rows come newest first,
    // so the first one we see for a subject is the one we want).
    final opened = await db.rawQuery('''
      SELECT p.subjectId AS subjectId, l.id AS lessonId,
             l.title AS lessonTitle, p.lastOpenedAt AS lastOpenedAt
      FROM ${LocalDbService.tableLessonProgress} p
      INNER JOIN ${LocalDbService.tableLessons} l ON l.id = p.lessonId
      WHERE p.userId = ?
      ORDER BY p.lastOpenedAt DESC
    ''', [uid]);
    final lastBySubject = <String, Map<String, Object?>>{};
    for (final r in opened) {
      lastBySubject.putIfAbsent(r['subjectId'] as String, () => r);
    }

    return [
      for (final subject in subjects)
        () {
          final id = subject['id'] as String;
          final total = lessonCounts[id] ?? 0;
          final done = completedCounts[id] ?? 0;
          final last = lastBySubject[id];
          return <String, dynamic>{
            'subject': subject,
            'lastLessonId': last?['lessonId'],
            'lastLessonTitle': last?['lessonTitle'],
            'lastOpenedAt': last?['lastOpenedAt'],
            'progressPercent': total == 0 ? 0 : ((done / total) * 100).round(),
          };
        }(),
    ];
  }

  // ---------------------------------------------------------------
  // FASTER SYNC
  // ---------------------------------------------------------------

  /// Drop-in replacement for syncAll():
  ///  - fetches lessons / quizzes several at a time instead of one by one
  ///  - skips the work if a sync finished in the last 10 minutes
  ///  - never runs two syncs at once
  Future<void> syncAllFast({bool force = false}) {
    final inFlight = _syncInFlight;
    if (inFlight != null) return inFlight;

    final last = _lastFullSync;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _minSyncGap) {
      return Future.value();
    }

    final future = _runSync().whenComplete(() => _syncInFlight = null);
    _syncInFlight = future;
    return future;
  }

  Future<void> _runSync() async {
    const concurrency = 6;

    final subjects = await syncSubjects();

    // Lessons: several subjects at once.
    final pairs = <(String, String)>[]; // (subjectId, lessonId)
    for (var i = 0; i < subjects.length; i += concurrency) {
      final chunk = subjects.skip(i).take(concurrency).toList();
      final results = await Future.wait([
        for (final s in chunk) syncLessonsForSubject(s['id'] as String),
      ]);
      for (var j = 0; j < chunk.length; j++) {
        for (final lesson in results[j]) {
          pairs.add((chunk[j]['id'] as String, lesson['id'] as String));
        }
      }
    }

    // Quizzes: several lessons at once.
    for (var i = 0; i < pairs.length; i += concurrency) {
      final chunk = pairs.skip(i).take(concurrency);
      await Future.wait([
        for (final p in chunk) syncQuizForLesson(p.$1, p.$2),
      ]);
    }

    _lastFullSync = DateTime.now();
    debugPrint('LocalDbFast: synced ${subjects.length} subjects, '
        '${pairs.length} lessons.');
  }
}
