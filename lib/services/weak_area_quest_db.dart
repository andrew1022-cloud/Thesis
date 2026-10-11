import 'local_db_service.dart';

/// Weak-Area Quests
/// ----------------
/// A quest points the student at one of their weakest competencies and
/// pays a small bonus for improving it.
///
/// Rules:
///  - A competency is "weak" once it has at least one competency-quiz
///    attempt and its average score is below [kWeakAreaThresholdPercent].
///  - The [kMaxWeakAreaQuests] weakest competencies each get a quest.
///  - Quest: score [kWeakAreaTargetPercent]% or higher on that
///    competency's quiz.
///  - Reward: [kWeakAreaQuestPoints] points, once per competency per
///    week (Mon–Sun). It is deliberately small next to a first attempt
///    (10 points for a competency quiz) so quests never replace the
///    normal way of earning points.
///
/// Nothing extra is stored: whether a quest is already done this week
/// is worked out from the quiz attempts themselves.
const int kWeakAreaThresholdPercent = 75;
const int kWeakAreaTargetPercent = 80;
const int kWeakAreaQuestPoints = 5;
const int kMaxWeakAreaQuests = 3;

class WeakAreaQuest {
  final String subjectId;
  final String lessonId;
  final String lessonTitle;
  final String subjectName;
  final String? subjectCode;

  /// Average of all attempts on this competency, 0–100.
  final int avgPercent;

  /// True once a qualifying attempt has been made this week.
  final bool completedThisWeek;

  const WeakAreaQuest({
    required this.subjectId,
    required this.lessonId,
    required this.lessonTitle,
    required this.subjectName,
    required this.subjectCode,
    required this.avgPercent,
    required this.completedThisWeek,
  });
}

extension WeakAreaQuestDb on LocalDbService {
  /// Monday 00:00 (local) of the current week, as an ISO-8601 prefix
  /// that compares correctly against `dateTaken` strings.
  String _questWeekStart() => LocalDbService.weekKeyFor(DateTime.now());

  /// The active quests, weakest first. Empty if the user has no weak
  /// competencies (or no competency attempts yet).
  Future<List<WeakAreaQuest>> getWeakAreaQuests(String uid) async {
    final db = await database;
    final weekStart = _questWeekStart();

    final rows = await db.rawQuery('''
      SELECT
        l.id AS lessonId,
        l.subjectId AS subjectId,
        l.title AS lessonTitle,
        s.name AS subjectName,
        s.code AS subjectCode,
        AVG(
          CASE WHEN a.totalItems > 0
            THEN (a.score * 100.0 / a.totalItems)
            ELSE 0
          END
        ) AS avgScore,
        MAX(
          CASE WHEN a.dateTaken >= ? AND a.totalItems > 0
            THEN (a.score * 100.0 / a.totalItems)
            ELSE -1
          END
        ) AS bestThisWeek
      FROM ${LocalDbService.tableQuizAttempts} a
      INNER JOIN ${LocalDbService.tableLessons} l ON l.id = a.lessonId
      INNER JOIN ${LocalDbService.tableSubjects} s ON s.id = l.subjectId
      WHERE a.userId = ? AND a.quizType = 'competency'
      GROUP BY l.id
      HAVING avgScore < ?
      ORDER BY avgScore ASC
      LIMIT ?
    ''', [weekStart, uid, kWeakAreaThresholdPercent, kMaxWeakAreaQuests]);

    return [
      for (final r in rows)
        WeakAreaQuest(
          subjectId: r['subjectId'] as String,
          lessonId: r['lessonId'] as String,
          lessonTitle: r['lessonTitle'] as String,
          subjectName: r['subjectName'] as String,
          subjectCode: r['subjectCode'] as String?,
          avgPercent: (r['avgScore'] as num).round(),
          completedThisWeek:
              (r['bestThisWeek'] as num) >= kWeakAreaTargetPercent,
        ),
    ];
  }

  /// Bonus points a just-finished competency attempt earns from a quest
  /// (0 if there is no open quest for it). Call BEFORE inserting the
  /// attempt, so this week's earlier attempts are the only ones seen.
  Future<int> weakAreaQuestBonus({
    required String uid,
    required String lessonId,
    required int score,
    required int total,
  }) async {
    if (total <= 0 || (score * 100 / total) < kWeakAreaTargetPercent) {
      return 0;
    }
    final quests = await getWeakAreaQuests(uid);
    for (final q in quests) {
      if (q.lessonId == lessonId) {
        return q.completedThisWeek ? 0 : kWeakAreaQuestPoints;
      }
    }
    return 0;
  }
}
