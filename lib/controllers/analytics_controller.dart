import 'package:flutter/material.dart';

import '../services/local_db_service.dart';

/// One row in the Strongest/Weakest Competency lists.
class CompetencyStat {
  final String lessonTitle;
  final String categoryLabel;
  final String? subjectCode;
  final double avgScorePercent;

  CompetencyStat({
    required this.lessonTitle,
    required this.categoryLabel,
    required this.subjectCode,
    required this.avgScorePercent,
  });
}

/// One row on the leaderboard.
class LeaderboardEntry {
  final int rank;
  final String name;
  final int points;
  final bool isCurrentUser;
  final int? totalPoints; // lifetime points; falls back to [points]

  LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.points,
    this.isCurrentUser = false,
    this.uid,
    this.totalPoints,
  });

  final String? uid;

  /// Points used to work out the level (always lifetime points).
  int get levelPoints => totalPoints ?? points;
}

/// Holds all state for the Analytics screen. The UI only reads from
/// this controller — it does not compute any stats itself.
class AnalyticsController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final String uid;

  AnalyticsController({required this.uid});

  static const Map<String, String> categoryTitles = {
    'GE': 'General Education',
    'PE': 'Professional Education',
    'SP': 'Specialization',
  };

  bool isLoading = true;

  int overallProgressPercent = 0;
  int generalEducationProgressPercent = 0;
  int professionalEducationProgressPercent = 0;
  int specializationProgressPercent = 0;

  List<CompetencyStat> strongestCompetencies = [];
  List<CompetencyStat> weakestCompetencies = [];

  List<LeaderboardEntry> leaderboardTop = [];
  LeaderboardEntry? currentUserEntry;

  bool _disposed = false;

  /// True when the online leaderboard/rank could not be loaded
  /// (offline, Firestore quota exceeded, etc.). The UI can use this
  /// to show a "couldn't load" hint; local stats still display.
  bool leaderboardUnavailable = false;

  /// Runs a Firestore-backed load and returns [fallback] on any error,
  /// so one failing request can never freeze the whole screen.
  Future<T> _safe<T>(String name, Future<T> Function() load, T fallback) async {
    try {
      return await load().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('AnalyticsController: $name failed: $e');
      return fallback;
    }
  }

  Future<void> loadAnalytics() async {
    isLoading = true;
    notifyListeners();

    try {
      // Local (SQLite) stats — fast and always available.
      final local = await Future.wait([
        _db.getOverallProgressPercent(uid),
        _db.getCategoryProgressPercent(uid, 'GE'),
        _db.getCategoryProgressPercent(uid, 'PE'),
        _db.getCategoryProgressPercent(uid, 'SP'),
        _db.getCompetencyRankings(uid),
      ]);

      overallProgressPercent = local[0] as int;
      generalEducationProgressPercent = local[1] as int;
      professionalEducationProgressPercent = local[2] as int;
      specializationProgressPercent = local[3] as int;

      final rankings = local[4] as List<Map<String, dynamic>>;
      final stats = rankings.map((r) {
        final code = r['subjectCode'] as String?;
        return CompetencyStat(
          lessonTitle: r['lessonTitle'] as String,
          categoryLabel: categoryTitles[code] ?? (r['subjectName'] as String),
          subjectCode: code,
          avgScorePercent: (r['avgScore'] as num).toDouble(),
        );
      }).toList();

      strongestCompetencies = stats.take(5).toList();
      weakestCompetencies = stats.reversed.take(5).toList();
    } catch (e) {
      debugPrint('AnalyticsController: local stats failed: $e');
    }

    // Show the local numbers right away; the online part follows.
    isLoading = false;
    notifyListeners();

    // Online (Firestore) leaderboard + rank. Each one fails on its own.
    final online = await Future.wait([
      _safe<List<Map<String, dynamic>>?>(
          'leaderboard', () => _db.getLeaderboardTop(limit: 5), null),
      _safe<Map<String, dynamic>?>(
          'rank', () => _db.getUserPointsAndRank(uid), null),
    ]);

    final top = online[0] as List<Map<String, dynamic>>?;
    final me = online[1] as Map<String, dynamic>?;

    leaderboardUnavailable = top == null && me == null;

    if (top != null) {
      leaderboardTop = top
          .map((r) => LeaderboardEntry(
                rank: r['rank'] as int,
                name: r['username'] as String,
                points: r['points'] as int,
                uid: r['uid'] as String?,
              ))
          .toList();
    }

    if (me != null) {
      currentUserEntry = LeaderboardEntry(
        rank: me['rank'] as int,
        name: (me['username'] as String?) ?? 'User',
        points: me['points'] as int,
        isCurrentUser: true,
        uid: uid,
      );
    }

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

  Future<void> refresh() => loadAnalytics();
}
