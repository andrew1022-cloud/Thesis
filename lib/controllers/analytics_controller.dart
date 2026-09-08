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

  LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.points,
    this.isCurrentUser = false,
  });
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

  Future<void> loadAnalytics() async {
    isLoading = true;
    notifyListeners();

    final results = await Future.wait([
      _db.getOverallProgressPercent(uid),
      _db.getCategoryProgressPercent(uid, 'GE'),
      _db.getCategoryProgressPercent(uid, 'PE'),
      _db.getCategoryProgressPercent(uid, 'SP'),
      _db.getCompetencyRankings(uid),
      _db.getLeaderboardTop(limit: 5),
      _db.getUserPointsAndRank(uid),
    ]);

    overallProgressPercent = results[0] as int;
    generalEducationProgressPercent = results[1] as int;
    professionalEducationProgressPercent = results[2] as int;
    specializationProgressPercent = results[3] as int;

    final rankings = results[4] as List<Map<String, dynamic>>;
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

    final top = results[5] as List<Map<String, dynamic>>;
    leaderboardTop = top
        .map((r) => LeaderboardEntry(
              rank: r['rank'] as int,
              name: r['username'] as String,
              points: r['points'] as int,
            ))
        .toList();

    final me = results[6] as Map<String, dynamic>;
    currentUserEntry = LeaderboardEntry(
      rank: me['rank'] as int,
      name: 'User',
      points: me['points'] as int,
      isCurrentUser: true,
    );

    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadAnalytics();
}
