import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/local_db_fast.dart';
import '../services/local_db_service.dart';
import '../services/notification_service.dart';

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

  Future<void> loadDashboard() async {
    isLoading = true;
    notifyListeners();

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
      _db.getDayStreak(uid),
      _db.getCompletedLessonCount(uid),
      _db.getAverageScorePercent(uid),
      _db.getContinueBySubjectFast(uid),
      _db.getLastOpenedLessonOverall(uid),
    ]);

    overallProgressPercent = results[0] as int;
    dayStreak = results[1] as int;
    lessonsDone = results[2] as int;
    averageScorePercent = results[3] as int;
    continueBySubject = results[4] as List<Map<String, dynamic>>;
    lastOpenedLesson = results[5] as Map<String, dynamic>?;
  }

  Future<void> _runBackgroundWork() async {
    try {
      // Log today's visit (local insert + Firestore write), then
      // refresh just the streak number.
      await _db.recordAppOpenedToday(uid);
      dayStreak = await _db.getDayStreak(uid);
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
