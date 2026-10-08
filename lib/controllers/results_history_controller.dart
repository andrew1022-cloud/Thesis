import 'package:flutter/material.dart';

import '../services/local_db_service.dart';
import '../services/results_history_db.dart';
import 'quiz_controller.dart' show QuizController;

enum HistoryFilter { all, competency, subject }

/// One past quiz attempt, ready for the UI.
class AttemptItem {
  final int id;
  final String quizType; // 'competency' | 'subject'
  final String title; // lesson title (competency) or subject name (subject)
  final String subjectName;
  final String? subjectCode;
  final int score;
  final int totalItems;
  final DateTime dateTaken;

  AttemptItem({
    required this.id,
    required this.quizType,
    required this.title,
    required this.subjectName,
    required this.subjectCode,
    required this.score,
    required this.totalItems,
    required this.dateTaken,
  });

  int get percent =>
      totalItems <= 0 ? 0 : ((score / totalItems) * 100).round();
  bool get passed => percent >= QuizController.passingPercent;
  bool get isSubjectQuiz => quizType == 'subject';

  factory AttemptItem.fromRow(Map<String, dynamic> r) {
    final type = (r['quizType'] as String?) ?? 'competency';
    final subjectName = (r['subjectName'] as String?)?.isNotEmpty == true
        ? r['subjectName'] as String
        : 'Unknown subject';
    final lessonTitle = r['lessonTitle'] as String?;
    return AttemptItem(
      id: r['id'] as int,
      quizType: type,
      title: type == 'subject'
          ? subjectName
          : ((lessonTitle?.isNotEmpty == true) ? lessonTitle! : subjectName),
      subjectName: subjectName,
      subjectCode: r['subjectCode'] as String?,
      score: (r['score'] as int?) ?? 0,
      totalItems: (r['totalItems'] as int?) ?? 0,
      dateTaken: DateTime.tryParse((r['dateTaken'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

/// Holds all state for the Results History screen.
class ResultsHistoryController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final String uid;

  ResultsHistoryController({required this.uid});

  bool isLoading = true;
  HistoryFilter filter = HistoryFilter.all;
  List<AttemptItem> _all = [];

  List<AttemptItem> get attempts {
    switch (filter) {
      case HistoryFilter.competency:
        return _all.where((a) => !a.isSubjectQuiz).toList();
      case HistoryFilter.subject:
        return _all.where((a) => a.isSubjectQuiz).toList();
      case HistoryFilter.all:
        return _all;
    }
  }

  int get totalAttempts => attempts.length;
  int get bestPercent => attempts.isEmpty
      ? 0
      : attempts.map((a) => a.percent).reduce((a, b) => a > b ? a : b);
  int get averagePercent => attempts.isEmpty
      ? 0
      : (attempts.map((a) => a.percent).reduce((a, b) => a + b) /
              attempts.length)
          .round();

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final rows = await _db.getQuizAttemptHistory(uid);
    _all = rows.map(AttemptItem.fromRow).toList();
    isLoading = false;
    notifyListeners();
  }

  /// Pull-to-refresh: push anything unsynced, pull attempts from
  /// Firestore (covers a fresh install / new device), then reload.
  Future<void> refresh() async {
    try {
      await _db.pushPendingSyncs(uid);
      await _db.syncUserDataFromFirestore(uid);
    } catch (e) {
      debugPrint('ResultsHistoryController: sync failed: $e');
    }
    await load();
  }

  void setFilter(HistoryFilter f) {
    if (filter == f) return;
    filter = f;
    notifyListeners();
  }
}
