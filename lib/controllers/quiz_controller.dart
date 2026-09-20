import 'package:flutter/material.dart';

import '../data/assessment_config.dart';
import '../data/curriculum_data.dart';
import '../services/local_db_service.dart';
import '../services/quiz_builder.dart';

/// Which assessment is being taken.
enum QuizMode {
  /// 5 questions from one competency (lesson). Passing marks it complete.
  competency,

  /// 15 questions across every competency of one topic (subject).
  topic,

  /// 150 questions across one category (GE / PE / SP), weighted by
  /// [kExamBlueprint].
  subjectExam,

  /// 450 questions across all three categories.
  mockExam,
}

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

/// Holds all state for the Quiz screen. Required fields per [mode]:
/// - competency  → [subjectId] + [lessonId]
/// - topic       → [subjectId]
/// - subjectExam → [categoryCode] ('GE' | 'PE' | 'SP')
/// - mockExam    → nothing extra
///
/// Every call to [loadQuiz] (including "Retake") draws a fresh random
/// set of questions.
class QuizController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;

  final QuizMode mode;
  final String uid;
  final String? subjectId;
  final String? lessonId;
  final String? categoryCode;

  QuizController({
    required this.mode,
    required this.uid,
    this.subjectId,
    this.lessonId,
    this.categoryCode,
  })  : assert(mode != QuizMode.competency ||
            (subjectId != null && lessonId != null)),
        assert(mode != QuizMode.topic || subjectId != null),
        assert(mode != QuizMode.subjectExam || categoryCode != null);

  /// Percentage of correct answers needed to mark a lesson complete
  /// via its competency quiz. Only applies to [QuizMode.competency].
  static const int passingPercent = 70;

  bool isLoading = true;
  List<QuizQuestionData> questions = [];

  int currentIndex = 0;
  final Map<String, String> selectedAnswers = {}; // questionId -> letter

  bool isSubmitted = false;
  bool isSubmitting = false;
  int score = 0;

  // Only try to pull a missing question bank from Firestore once per
  // screen visit, so "Retake" on a genuinely small bank doesn't hit
  // the network every time.
  bool _triedSync = false;

  bool get isCompetencyQuiz => mode == QuizMode.competency;

  /// How many questions this assessment is supposed to have.
  int get requestedCount => switch (mode) {
        QuizMode.competency => kCompetencyQuizCount,
        QuizMode.topic => kTopicQuizCount,
        QuizMode.subjectExam => kSubjectExamCount,
        QuizMode.mockExam => kMockExamCount,
      };

  /// True when the question bank is too small to fill the quiz.
  bool get isShort =>
      questions.isNotEmpty && questions.length < requestedCount;

  String get quizType => switch (mode) {
        QuizMode.competency => 'competency',
        QuizMode.topic => 'topic',
        QuizMode.subjectExam => 'subject_exam',
        QuizMode.mockExam => 'mock_exam',
      };

  bool get canGoNext => currentIndex < questions.length - 1;
  bool get canGoPrevious => currentIndex > 0;
  bool get isLastQuestion => currentIndex == questions.length - 1;
  bool get hasAnsweredCurrent =>
      questions.isNotEmpty &&
      selectedAnswers.containsKey(questions[currentIndex].id);
  bool get allAnswered =>
      questions.isNotEmpty &&
      questions.every((q) => selectedAnswers.containsKey(q.id));
  bool get passed => questions.isEmpty
      ? false
      : (score / questions.length * 100) >= passingPercent;

  Future<void> loadQuiz() async {
    isLoading = true;
    notifyListeners();

    var rows = await _buildQuestionSet();

    // Fresh install / new device: the bank may simply not be synced
    // yet. Try once, then rebuild.
    if (rows.length < requestedCount && !_triedSync) {
      _triedSync = true;
      try {
        await _syncQuestionBank();
      } catch (e) {
        debugPrint('QuizController: sync failed: $e');
      }
      rows = await _buildQuestionSet();
    }

    questions = rows.map(QuizQuestionData.fromRow).toList();
    currentIndex = 0;
    selectedAnswers.clear();
    isSubmitted = false;
    score = 0;

    isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // Question selection
  // ---------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _buildQuestionSet() async {
    switch (mode) {
      case QuizMode.competency:
        final pool = await _db.getQuizQuestions(lessonId!);
        return QuizBuilder.pickByDifficulty(pool, kCompetencyQuizCount);

      case QuizMode.topic:
        // Spread the 15 questions evenly over the topic's competencies.
        final rows = await _db.getQuizQuestionsForSubject(subjectId!);
        final byLesson = <String, List<Map<String, dynamic>>>{};
        for (final row in rows) {
          byLesson.putIfAbsent(row['lessonId'] as String, () => []).add(row);
        }
        return QuizBuilder.buildWeighted(
          kTopicQuizCount,
          [for (final qs in byLesson.values) WeightedPool(1, qs)],
        );

      case QuizMode.subjectExam:
        return _buildCategoryExam(categoryCode!, kSubjectExamCount);

      case QuizMode.mockExam:
        // Categories stay in order (GE → PE → SP); questions are
        // shuffled within each one.
        final all = <Map<String, dynamic>>[];
        for (final entry in kMockExamCategoryCounts.entries) {
          all.addAll(await _buildCategoryExam(entry.key, entry.value));
        }
        return all;
    }
  }

  /// Builds one category's exam from [kExamBlueprint]. Subjects that
  /// share a blueprint line split its percentage evenly.
  Future<List<Map<String, dynamic>>> _buildCategoryExam(
      String code, int total) async {
    final blueprint = kExamBlueprint[code] ?? const <ExamGroup>[];

    final subjectIds = <String>{
      for (final group in blueprint)
        for (final index in group.subjectIndices)
          curriculumSubjectId(code, index),
    };
    final bySubject = await _db.getQuizQuestionsGroupedBySubject(subjectIds);

    final slots = <WeightedPool>[];
    for (final group in blueprint) {
      final weightEach = group.percent / group.subjectIndices.length;
      for (final index in group.subjectIndices) {
        slots.add(WeightedPool(
          weightEach,
          bySubject[curriculumSubjectId(code, index)] ?? const [],
        ));
      }
    }
    return QuizBuilder.buildWeighted(total, slots);
  }

  Future<void> _syncQuestionBank() async {
    switch (mode) {
      case QuizMode.competency:
        await _db.syncQuizForLesson(subjectId!, lessonId!);
      case QuizMode.topic:
        final lessons = await _db.syncLessonsForSubject(subjectId!);
        for (final lesson in lessons) {
          await _db.syncQuizForLesson(subjectId!, lesson['id'] as String);
        }
      case QuizMode.subjectExam:
      case QuizMode.mockExam:
        await _db.syncAll();
    }
  }

  // ---------------------------------------------------------------
  // Answering
  // ---------------------------------------------------------------

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

  /// Grades the quiz, saves the attempt, and — for a competency quiz
  /// that passes — marks that lesson complete. Returns true if the
  /// lesson's completion status changed, so the caller can signal
  /// screens behind it to refresh.
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
      quizType: quizType,
      score: score,
      totalItems: questions.length,
    );

    var lessonNewlyCompleted = false;
    if (isCompetencyQuiz && passed) {
      await _db.markLessonCompleted(
        uid: uid,
        subjectId: subjectId!,
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
