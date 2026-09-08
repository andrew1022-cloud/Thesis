import 'package:flutter/material.dart';

import '../services/local_db_service.dart';

/// A single quiz question plus its options, in a form the UI can
/// render without touching raw Firestore/SQLite field names.
class QuizQuestionData {
  final String id;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption; // 'A' | 'B' | 'C' | 'D'
  final String? explanation;

  QuizQuestionData({
    required this.id,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    this.explanation,
  });

  factory QuizQuestionData.fromRow(Map<String, dynamic> row) {
    return QuizQuestionData(
      id: row['id'] as String,
      questionText: row['questionText'] as String,
      optionA: row['optionA'] as String,
      optionB: row['optionB'] as String,
      optionC: row['optionC'] as String,
      optionD: row['optionD'] as String,
      correctOption: (row['correctOption'] as String).toUpperCase(),
      explanation: row['explanation'] as String?,
    );
  }
}

/// Holds all state for the Quiz screen. Works for two cases:
/// - [lessonId] set  → that lesson's "competency" quiz.
/// - [lessonId] null → every question across the whole subject
///   ("Take a Subject Quiz").
class QuizController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final String uid;
  final String subjectId;
  final String? lessonId;

  QuizController({
    required this.uid,
    required this.subjectId,
    this.lessonId,
  });

  /// Percentage of correct answers needed to mark a lesson complete
  /// via its competency quiz. Only applies when [lessonId] is set.
  static const int passingPercent = 70;

  bool isLoading = true;
  List<QuizQuestionData> questions = [];

  int currentIndex = 0;
  final Map<String, String> selectedAnswers = {}; // questionId -> letter

  bool isSubmitted = false;
  bool isSubmitting = false;
  int score = 0;

  bool get isSubjectQuiz => lessonId == null;
  bool get canGoNext => currentIndex < questions.length - 1;
  bool get canGoPrevious => currentIndex > 0;
  bool get isLastQuestion => currentIndex == questions.length - 1;
  bool get hasAnsweredCurrent =>
      questions.isNotEmpty && selectedAnswers.containsKey(questions[currentIndex].id);
  bool get allAnswered =>
      questions.isNotEmpty && questions.every((q) => selectedAnswers.containsKey(q.id));
  bool get passed =>
      questions.isEmpty ? false : (score / questions.length * 100) >= passingPercent;

  Future<void> loadQuiz() async {
    isLoading = true;
    notifyListeners();

    final rows = lessonId != null
        ? await _db.getQuizQuestions(lessonId!)
        : await _db.getQuizQuestionsForSubject(subjectId);

    questions = rows.map(QuizQuestionData.fromRow).toList();
    currentIndex = 0;
    selectedAnswers.clear();
    isSubmitted = false;
    score = 0;

    isLoading = false;
    notifyListeners();
  }

  void selectAnswer(String letter) {
    if (isSubmitted || questions.isEmpty) return;
    selectedAnswers[questions[currentIndex].id] = letter;
    notifyListeners();
  }

  void nextQuestion() {
    if (!canGoNext) return;
    currentIndex++;
    notifyListeners();
  }

  void previousQuestion() {
    if (!canGoPrevious) return;
    currentIndex--;
    notifyListeners();
  }

  /// Grades the quiz, saves the attempt, and — for a single-lesson
  /// competency quiz that passes — marks that lesson complete.
  /// Returns true if the lesson's completion status changed, so the
  /// caller can signal screens behind it to refresh.
  Future<bool> submitQuiz() async {
    if (questions.isEmpty || isSubmitting) return false;

    isSubmitting = true;
    notifyListeners();

    score = questions
        .where((q) => selectedAnswers[q.id] == q.correctOption)
        .length;

    await _db.insertQuizAttempt(
      uid: uid,
      subjectId: subjectId,
      lessonId: lessonId,
      quizType: isSubjectQuiz ? 'subject' : 'competency',
      score: score,
      totalItems: questions.length,
    );

    var lessonNewlyCompleted = false;
    if (lessonId != null && passed) {
      await _db.markLessonCompleted(
        uid: uid,
        subjectId: subjectId,
        lessonId: lessonId!,
      );
      lessonNewlyCompleted = true;
    }

    isSubmitting = false;
    isSubmitted = true;
    notifyListeners();
    return lessonNewlyCompleted;
  }
}
