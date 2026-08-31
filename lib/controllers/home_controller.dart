import 'package:flutter/material.dart';

import '../services/local_db_service.dart';
import '../services/notification_service.dart';

/// Holds all state for the Home dashboard. The UI only reads from
/// this controller — it does not compute any stats itself.
class HomeController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final String uid;

  HomeController({required this.uid});

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

    // Log today's visit for the streak, then try to flush anything
    // that failed to sync earlier while we're at it.
    await _db.recordAppOpenedToday(uid);
    unawaited(_db.pushPendingSyncs(uid));

    // Opening the app resets the "you've been away" reminder ladder —
    // request permission (no-op if already granted/denied) and
    // reschedule the next set of inactivity nudges counting from
    // today. If the user doesn't open the app again before one of
    // them fires, that's the point.
    unawaited(_refreshInactivityReminders());

    final results = await Future.wait([
      _db.getOverallProgressPercent(uid),
      _db.getDayStreak(uid),
      _db.getCompletedLessonCount(uid),
      _db.getAverageScorePercent(uid),
      _db.getContinueBySubject(uid),
      _db.getLastOpenedLessonOverall(uid),
    ]);

    overallProgressPercent = results[0] as int;
    dayStreak = results[1] as int;
    lessonsDone = results[2] as int;
    averageScorePercent = results[3] as int;
    continueBySubject = results[4] as List<Map<String, dynamic>>;
    lastOpenedLesson = results[5] as Map<String, dynamic>?;

    isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshInactivityReminders() async {
    try {
      await NotificationService.instance.requestPermission();
      await NotificationService.instance.scheduleInactivityReminders();
    } catch (e) {
      debugPrint('HomeController: failed to schedule reminders: $e');
    }
  }

  Future<void> refresh() => loadDashboard();
}

// Small helper so we can fire-and-forget without a lint warning.
void unawaited(Future<void> future) {}
