import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../services/local_db_fast.dart';
import '../services/local_db_service.dart';
import '../services/notification_service.dart';
import '../services/streak_freeze_db.dart';
import '../services/weak_area_quest_db.dart';

/// Holds all state for the Home dashboard. The UI only reads from
/// this controller — it does not compute any stats itself.
///
/// Loading order (this is what makes Home fast):
///  1. Read everything from the local SQLite cache and show it.
///  2. Only AFTER the screen is visible, do the slow stuff in the
///     background: log today's visit, sync from Firestore, schedule
///     reminders. When they finish, the numbers quietly refresh.
class HomeController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final String uid;

  HomeController({required this.uid});

  bool _disposed = false;

  bool isLoading = true;

  int overallProgressPercent = 0;
  int dayStreak = 0;
  int lessonsDone = 0;
  int averageScorePercent = 0;

  /// Each entry: {subject, lastLessonId, lastLessonTitle, progressPercent}
  List<Map<String, dynamic>> continueBySubject = [];

  /// The single most recently opened lesson across all subjects, or
  /// null if the user hasn't opened anything yet.
  Map<String, dynamic>? lastOpenedLesson;

  /// Weak-area quests for the user's weakest competencies (empty when
  /// they have none).
  List<WeakAreaQuest> weakAreaQuests = [];

  Future<void> loadDashboard() async {
    isLoading = true;
    notifyListeners();

    // Starts the online/offline detector (safe to call repeatedly).
    // Powers the "You're offline" banner and the Offline Content screen.
    ConnectivityService.instance.start();

    // 1) Local reads only — no network, no waiting on Firestore.
    await _loadStats();

    isLoading = false;
    notifyListeners();

    // 2) Everything slow runs after the first paint.
    _runBackgroundWork();
  }

  Future<void> _loadStats() async {
    final results = await Future.wait([
      _db.getOverallProgressPercent(uid),
      _db.getDayStreakWithFreeze(uid),
      _db.getCompletedLessonCount(uid),
      _db.getAverageScorePercent(uid),
      _db.getContinueBySubjectFast(uid),
    ]);

    overallProgressPercent = results[0] as int;
    dayStreak = results[1] as int;
    lessonsDone = results[2] as int;
    averageScorePercent = results[3] as int;
    final allSubjects = results[4] as List<Map<String, dynamic>>;
    continueBySubject = _topThreePerCategory(allSubjects);
    lastOpenedLesson = _lastOpenedUnfinished(allSubjects);

    // Best-effort: quests must never break the rest of the dashboard.
    try {
      weakAreaQuests = await _db.getWeakAreaQuests(uid);
    } catch (e) {
      debugPrint('HomeController: weak-area quests failed: $e');
      weakAreaQuests = [];
    }
  }

  /// Categories shown on Home, in order, with how many subjects each.
  static const List<String> _homeCategories = ['GE', 'PE', 'SP'];
  static const int _subjectsPerCategory = 3;

  /// Keeps only 3 subjects for each of General Education, Professional
  /// Education and Specialization. Subjects the user opened most
  /// recently come first; the rest follow in curriculum order.
  List<Map<String, dynamic>> _topThreePerCategory(
      List<Map<String, dynamic>> all) {
    final out = <Map<String, dynamic>>[];
    for (final code in _homeCategories) {
      final inCategory = all
          .where((e) => (e['subject'] as Map)['code'] == code)
          .toList();
      final indexed = {
        for (var i = 0; i < inCategory.length; i++) inCategory[i]: i,
      };
      inCategory.sort((a, b) {
        // lastOpenedAt is an ISO-8601 string, so text order = time order.
        final ao = (a['lastOpenedAt'] as String?) ?? '';
        final bo = (b['lastOpenedAt'] as String?) ?? '';
        if (ao != bo) return bo.compareTo(ao); // newest first
        return indexed[a]!.compareTo(indexed[b]!);
      });
      out.addAll(inCategory.take(_subjectsPerCategory));
    }
    return out;
  }

  /// The subject the user opened most recently that they have NOT
  /// finished yet (progress < 100%). Null if there isn't one.
  Map<String, dynamic>? _lastOpenedUnfinished(
      List<Map<String, dynamic>> all) {
    Map<String, dynamic>? best;
    var bestOpened = '';
    for (final e in all) {
      if (e['lastLessonId'] == null) continue;
      if ((e['progressPercent'] as int) >= 100) continue;
      final opened = (e['lastOpenedAt'] as String?) ?? '';
      if (best == null || opened.compareTo(bestOpened) > 0) {
        best = e;
        bestOpened = opened;
      }
    }
    if (best == null) return null;
    return {
      'subjectId': (best['subject'] as Map)['id'],
      'subjectName': (best['subject'] as Map)['name'],
      'lessonId': best['lastLessonId'],
      'lessonTitle': best['lastLessonTitle'],
      'progressPercent': best['progressPercent'],
    };
  }

  Future<void> _runBackgroundWork() async {
    try {
      // Log today's visit (local insert + Firestore write), then
      // refresh just the streak number.
      await _db.recordAppOpenedToday(uid);
      dayStreak = await _db.getDayStreakWithFreeze(uid);
      notifyListeners();

      unawaited(_db.pushPendingSyncs(uid));

      // Download new admin-published content (throttled to once per
      // 10 minutes), then refresh the numbers from the updated cache.
      await _db.syncAllFast();
      await _loadStats();
      notifyListeners();
    } catch (e) {
      debugPrint('HomeController: background work failed: $e');
    }

    // Reminders render several images, so wait a bit and keep them
    // out of the way of the first frames.
    await Future.delayed(const Duration(seconds: 4));
    if (_disposed) return;
    unawaited(_refreshInactivityReminders());
  }

  Future<void> _refreshInactivityReminders() async {
    try {
      // Respect the Settings → Study Reminders switch.
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if ((doc.data()?['remindersEnabled'] as bool?) == false) return;
      } catch (_) {
        // Offline — fall through and schedule anyway.
      }

      await NotificationService.instance.requestPermission();
      await NotificationService.instance.scheduleInactivityReminders();
    } catch (e) {
      debugPrint('HomeController: failed to schedule reminders: $e');
    }
  }

  /// Pull-to-refresh: force a real sync, then reload.
  Future<void> refresh() async {
    try {
      await _db.syncAllFast(force: true);
    } catch (e) {
      debugPrint('HomeController: refresh sync failed: $e');
    }
    await _loadStats();
    notifyListeners();
  }

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

// Small helper so we can fire-and-forget without a lint warning.
void unawaited(Future<void> future) {
  future.catchError((Object e) {
    debugPrint('unawaited task failed: $e');
  });
}
