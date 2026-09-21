import 'dart:async';
import 'dart:math';

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

/// Randomly re-assigns which option letter (A/B/C/D) each answer text
/// sits under, so — for example — a choice stored as "optionC" in the
/// CSV bank might display as "A" this time and "D" next time. Works on
/// the raw row (before [QuizQuestionData.fromRow]) so it applies no
/// matter which mode/pool the question came from.
///
/// Shuffles indices rather than the option texts themselves, so
/// duplicate option text doesn't break which one is marked correct.
QuestionRow _shuffleOptionPositions(QuestionRow row, Random rng) {
  const letters = ['A', 'B', 'C', 'D'];
  final originalTexts = [
    row['optionA'],
    row['optionB'],
    row['optionC'],
    row['optionD'],
  ];

  final correctLetter = (row['correctOption'] as String).toUpperCase();
  final correctIndex = letters.indexOf(correctLetter);
  // Malformed/unrecognized correctOption — leave the row untouched
  // rather than risk losing track of the right answer.
  if (correctIndex == -1) return row;

  final newOrder = List<int>.generate(letters.length, (i) => i)..shuffle(rng);

  final shuffledRow = Map<String, dynamic>.from(row);
  for (var i = 0; i < letters.length; i++) {
    shuffledRow['option${letters[i]}'] = originalTexts[newOrder[i]];
  }
  shuffledRow['correctOption'] = letters[newOrder.indexOf(correctIndex)];
  return shuffledRow;
}

/// Holds all state for the Quiz screen. Required fields per [mode]:
/// - competency  → [subjectId] + [lessonId]
/// - topic       → [subjectId]
/// - subjectExam → [categoryCode] ('GE' | 'PE' | 'SP')
/// - mockExam    → nothing extra
///
/// Every call to [loadQuiz] (including "Retake") draws a fresh random
/// set of questions, in a fresh random order, with each question's
/// answer choices shuffled into fresh random positions.
///
/// Every question also carries its own [secondsPerQuestion]-second
/// countdown (see [secondsRemaining]). When time runs out on a
/// question, the quiz auto-advances to the next one — or auto-submits
/// if it was the last one — regardless of whether the question had
/// been answered yet.
class QuizController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final Random _rng = Random();

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

  /// How long the user has to answer each question before it
  /// auto-advances (or auto-submits, on the last question). Applies
  /// uniformly to every assessment type (competency, topic, subject
  /// exam, mock exam).
  static const int secondsPerQuestion = 60;

  bool isLoading = true;
  List<QuizQuestionData> questions = [];

  int currentIndex = 0;
  final Map<String, String> selectedAnswers = {}; // questionId -> letter

  bool isSubmitted = false;
  bool isSubmitting = false;
  int score = 0;

  Timer? _questionTimer;
  int secondsRemaining = secondsPerQuestion;

  bool _disposed = false;

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

    // Randomize which letter (A/B/C/D) each option displays under,
    // per question, per attempt — independent of the question order
    // itself (which QuizBuilder already randomizes).
    questions = rows
        .map((r) => QuizQuestionData.fromRow(_shuffleOptionPositions(r, _rng)))
        .toList();
    currentIndex = 0;
    selectedAnswers.clear();
    isSubmitted = false;
    score = 0;

    isLoading = false;
    if (questions.isNotEmpty) {
      _startQuestionTimer();
    } else {
      _cancelTimer();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // Per-question timer
  // ---------------------------------------------------------------

  void _cancelTimer() {
    _questionTimer?.cancel();
    _questionTimer = null;
  }

  /// Resets the countdown for the current question and starts ticking
  /// it down, one second at a time.
  void _startQuestionTimer() {
    _cancelTimer();
    if (questions.isEmpty || isSubmitted) return;

    secondsRemaining = secondsPerQuestion;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining <= 1) {
        timer.cancel();
        _questionTimer = null;
        secondsRemaining = 0;
        notifyListeners();
        _handleTimeUp();
      } else {
        secondsRemaining--;
        notifyListeners();
      }
    });
  }

  /// Time's up on the current question: move on automatically (left
  /// unanswered if the user hadn't picked yet), or submit the quiz if
  /// this was the last question.
  void _handleTimeUp() {
    if (isSubmitted) return;
    if (isLastQuestion) {
      submitQuiz();
    } else {
      currentIndex++;
      _startQuestionTimer();
      notifyListeners();
    }
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
    _startQuestionTimer();
    notifyListeners();
  }

  void previousQuestion() {
    if (!canGoPrevious) return;
    currentIndex--;
    _startQuestionTimer();
    notifyListeners();
  }

  /// Grades the quiz, saves the attempt, and — for a competency quiz
  /// that passes — marks that lesson complete. Returns true if the
  /// lesson's completion status changed, so the caller can signal
  /// screens behind it to refresh.
  Future<bool> submitQuiz() async {
    if (questions.isEmpty || isSubmitting) return false;

    _cancelTimer();
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

  // The screen can be popped while a timer tick is still pending;
  // don't notify (or keep ticking) a disposed controller.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimer();
    super.dispose();
  }
}
