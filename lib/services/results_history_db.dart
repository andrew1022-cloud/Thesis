import 'local_db_service.dart';

/// Adds the Results History query to [LocalDbService] without having
/// to edit that (large) file — just import this file where needed.
extension ResultsHistoryDb on LocalDbService {
  /// Every quiz attempt for [uid], newest first, with subject/lesson
  /// names for display. LEFT JOINs so attempts still appear even if
  /// the subject/lesson isn't cached locally.
  Future<List<Map<String, dynamic>>> getQuizAttemptHistory(String uid) async {
    final db = await database;
    return db.rawQuery('''
      SELECT a.id, a.quizType, a.score, a.totalItems, a.dateTaken,
             a.subjectId, a.lessonId,
             s.name AS subjectName, s.code AS subjectCode,
             l.title AS lessonTitle
      FROM ${LocalDbService.tableQuizAttempts} a
      LEFT JOIN ${LocalDbService.tableSubjects} s ON s.id = a.subjectId
      LEFT JOIN ${LocalDbService.tableLessons} l ON l.id = a.lessonId
      WHERE a.userId = ?
      ORDER BY a.dateTaken DESC
    ''', [uid]);
  }
}
