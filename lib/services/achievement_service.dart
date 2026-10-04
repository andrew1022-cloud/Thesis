import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'local_db_service.dart';
import 'notification_service.dart';

/// AchievementService
/// ------------------
/// Awards a "Topic Mastery" badge once a user has:
///   1. Completed every competency (lesson) under a subject/topic, AND
///   2. Scored at least [topicMasteryPassingPercent] on that topic's
///      15-question Topic Quiz (see QuizController, QuizMode.topic).
///
/// A badge is written to `users/{uid}/badges/{badgeId}` — the exact
/// collection ProfileController already reads for the "User Ledger"
/// card — so it shows up there automatically with no Profile changes
/// needed. `assetPath` is left null for now: this is a placeholder
/// award, so the badge renders with profile_widgets.dart's default
/// icon/circle until a real badge graphic is designed and swapped in.
///
/// Idempotent: the badge doc id is deterministic per subject
/// (`topic_mastery_{subjectId}`), so re-passing the same topic quiz
/// later doesn't award a duplicate badge or re-fire the notification.
class AchievementService {
  AchievementService._internal();
  static final AchievementService instance = AchievementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDbService _localDb = LocalDbService.instance;

  /// Minimum Topic Quiz score (percent) required, on top of full
  /// competency completion, to earn the Topic Mastery badge.
  static const double topicMasteryPassingPercent = 75;

  /// Reserved notification-id range for achievement notifications —
  /// kept well outside NotificationService's inactivity-reminder and
  /// test-notification ranges so ids never collide.
  static const int _notificationIdBase = 8000;

  String _badgeIdFor(String subjectId) => 'topic_mastery_$subjectId';

  int _notificationIdFor(String badgeId) =>
      _notificationIdBase + (badgeId.hashCode.abs() % 1000);

  /// Checks whether the user just qualified for [subjectId]'s Topic
  /// Mastery badge, and if so, awards it (Firestore) and fires a
  /// celebratory local notification. Safe to call after every topic
  /// quiz submission — does nothing if the score is below the
  /// threshold, not every competency is complete yet, or the badge
  /// was already earned.
  Future<void> checkAndAwardTopicMastery({
    required String uid,
    required String subjectId,
    required double scorePercent,
  }) async {
    if (scorePercent < topicMasteryPassingPercent) return;

    try {
      final totalCount = await _localDb.getLessonCountForSubject(subjectId);
      if (totalCount == 0) return; // nothing published for this subject yet

      final completedCount =
          await _localDb.getCompletedLessonCountForSubject(uid, subjectId);
      if (completedCount < totalCount) return; // not all competencies done

      final badgeId = _badgeIdFor(subjectId);
      final badgeRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('badges')
          .doc(badgeId);

      final existing = await badgeRef.get();
      if (existing.exists) return; // already earned — no duplicate award

      final subject = await _localDb.getSubjectById(subjectId);
      final subjectName = (subject?['name'] as String?) ?? 'Topic';

      await badgeRef.set({
        'label': '$subjectName Mastery',
        // Placeholder for now — swap in a real badge graphic later.
        // Left null so the UI falls back to its default badge icon.
        'assetPath': null,
        'type': 'topic_mastery',
        'subjectId': subjectId,
        'scorePercent': scorePercent,
        'earnedAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.instance.showAchievementNotification(
        title: 'Achievement unlocked! 🏆',
        body: 'You mastered $subjectName — every competency completed '
            'with a passing Topic Quiz score.',
        notificationId: _notificationIdFor(badgeId),
      );
    } catch (e) {
      debugPrint('AchievementService: topic mastery check failed: $e');
    }
  }
}
