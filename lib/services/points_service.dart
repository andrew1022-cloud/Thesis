import 'dart:async';

import 'package:flutter/foundation.dart';

import 'local_db_service.dart';

/// PointsService
/// -------------
/// Single place that defines how points are earned, so the rules live
/// in one spot and the Profile "User Ledger" and the Analytics
/// leaderboard (both read `users/{uid}.points`) finally move.
///
/// Rules:
///  - Completing a lesson for the first time: [lessonCompletePoints].
///  - Every quiz pays out in proportion to the score, scaled by how
///    big the assessment is (see [quizBasePoints]), plus
///    [perfectScoreBonus] for a perfect score.
///  - Only the first attempt of a quiz earns points; retakes earn none,
///    so repeating a quiz can't be farmed.
///  - Topic Mastery badge: [topicMasteryBonus] (awarded by
///    AchievementService).
class PointsService {
  PointsService._internal();
  static final PointsService instance = PointsService._internal();

  static const int lessonCompletePoints = 10;
  static const int perfectScoreBonus = 5;
  static const int topicMasteryBonus = 50;

  /// Points for a 100% score, before the perfect-score bonus.
  static int quizBasePoints(String quizType) => switch (quizType) {
        'competency' => 10,
        'topic' => 25,
        'subject_exam' => 60,
        'mock_exam' => 100,
        _ => 10,
      };

  /// Points a single attempt is worth on its own.
  static int pointsForAttempt({
    required String quizType,
    required int score,
    required int total,
  }) {
    if (total <= 0 || score <= 0) return 0;
    final base = (quizBasePoints(quizType) * score / total).round();
    final bonus = score >= total ? perfectScoreBonus : 0;
    return base + bonus;
  }

  /// Points to actually award for this attempt: only the FIRST attempt
  /// of a given quiz earns points; any retake earns none.
  /// [previous] = earlier attempt rows from the database.
  static int quizPointsToAward({
    required String quizType,
    required int score,
    required int total,
    required List<Map<String, dynamic>> previous,
  }) {
    if (previous.isNotEmpty) return 0;
    return pointsForAttempt(quizType: quizType, score: score, total: total);
  }

  /// Adds [delta] to the user's points. Deliberately not awaited by
  /// callers: Firestore queues the increment while offline and syncs
  /// it later, so the UI must never wait on the network for this.
  void award(String uid, int delta) {
    if (uid.isEmpty || delta <= 0) return;
    unawaited(
      LocalDbService.instance.incrementUserPoints(uid, delta).catchError((e) {
        debugPrint('PointsService: failed to award $delta points: $e');
      }),
    );
  }
}
