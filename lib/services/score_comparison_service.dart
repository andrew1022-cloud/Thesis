import 'local_db_service.dart';

/// Result of comparing one just-finished attempt against the user's
/// earlier attempts of the same quiz.
class ScoreComparison {
  final int currentPercent;
  final int? previousPercent; // most recent earlier attempt
  final int? averagePercent; // average of all earlier attempts
  final int? bestPercent; // best earlier attempt
  final int previousCount;

  /// Oldest → newest, last item is the current attempt.
  final List<int> recentPercents;

  const ScoreComparison({
    required this.currentPercent,
    required this.previousPercent,
    required this.averagePercent,
    required this.bestPercent,
    required this.previousCount,
    required this.recentPercents,
  });

  bool get isFirstAttempt => previousCount == 0;
  int? get deltaVsPrevious =>
      previousPercent == null ? null : currentPercent - previousPercent!;
  int? get deltaVsAverage =>
      averagePercent == null ? null : currentPercent - averagePercent!;
  bool get isNewBest => bestPercent != null && currentPercent > bestPercent!;

  /// [previous] = earlier attempts, NEWEST first (rows from the DB).
  factory ScoreComparison.from({
    required int score,
    required int total,
    required List<Map<String, dynamic>> previous,
  }) {
    int pct(int s, int t) => t <= 0 ? 0 : ((s / t) * 100).round();

    final current = pct(score, total);
    final prevPercents = [
      for (final r in previous)
        pct((r['score'] as int?) ?? 0, (r['totalItems'] as int?) ?? 0),
    ];

    if (prevPercents.isEmpty) {
      return ScoreComparison(
        currentPercent: current,
        previousPercent: null,
        averagePercent: null,
        bestPercent: null,
        previousCount: 0,
        recentPercents: [current],
      );
    }

    final avg =
        (prevPercents.reduce((a, b) => a + b) / prevPercents.length).round();
    final best = prevPercents.reduce((a, b) => a > b ? a : b);
    final lastFive = prevPercents.take(5).toList().reversed.toList();

    return ScoreComparison(
      currentPercent: current,
      previousPercent: prevPercents.first,
      averagePercent: avg,
      bestPercent: best,
      previousCount: prevPercents.length,
      recentPercents: [...lastFive, current],
    );
  }
}

extension ScoreComparisonDb on LocalDbService {
  /// Earlier attempts of the same quiz, newest first. Call this
  /// BEFORE inserting the current attempt so it isn't included.
  Future<List<Map<String, dynamic>>> getPreviousAttemptsForComparison({
    required String uid,
    required String quizType,
    String? subjectId,
    String? lessonId,
    int limit = 20,
  }) async {
    final db = await database;
    final where = <String>['userId = ?', 'quizType = ?'];
    final args = <Object?>[uid, quizType];
    if (subjectId != null) {
      where.add('subjectId = ?');
      args.add(subjectId);
    }
    if (lessonId != null) {
      where.add('lessonId = ?');
      args.add(lessonId);
    }
    return db.query(
      LocalDbService.tableQuizAttempts,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'dateTaken DESC',
      limit: limit,
    );
  }
}
