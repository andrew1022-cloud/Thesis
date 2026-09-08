import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/quiz_controller.dart';
import '../widgets/home_widgets.dart';
import '../widgets/quiz_widgets.dart';

/// Takes a quiz — either one lesson's competency quiz (pass [lessonId])
/// or a whole subject's quiz (leave [lessonId] null, used by "Take a
/// Subject Quiz"). Pops with `true` if taking it changed a lesson's
/// completion status, so the screen behind it knows to refresh.
class QuizScreen extends StatefulWidget {
  final String subjectId;
  final String? lessonId;
  final String title;

  const QuizScreen({
    super.key,
    required this.subjectId,
    this.lessonId,
    required this.title,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final QuizController _controller;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = QuizController(
      uid: uid,
      subjectId: widget.subjectId,
      lessonId: widget.lessonId,
    );
    _controller.loadQuiz();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    if (!_controller.isSubmitted &&
        _controller.selectedAnswers.isNotEmpty &&
        _controller.questions.isNotEmpty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('Leave quiz?',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor(context))),
          content: Text('Your progress on this attempt will be lost.',
              style: TextStyle(color: primaryTextColor(context))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Stay',
                  style: TextStyle(color: secondaryTextColor(context))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave',
                  style:
                      TextStyle(color: kMaroon, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return leave ?? false;
    }
    return true;
  }

  Future<void> _submit() async {
    final lessonChanged = await _controller.submitQuiz();
    // Result is shown inline; lessonChanged is reported when the user
    // taps "Done" below via Navigator.pop(context, lessonChanged).
    _pendingResult = lessonChanged;
  }

  bool _pendingResult = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: kMaroon,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Column(
                children: [
                  Container(
                    color: kMaroon,
                    height: MediaQuery.of(context).padding.top,
                  ),
                  _buildHeader(),
                  Expanded(
                    child: _controller.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: kMaroon))
                        : _controller.questions.isEmpty
                            ? _buildEmptyState()
                            : (_controller.isSubmitted
                                ? _buildResults()
                                : _buildQuiz()),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: kMaroon,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (await _handleBack() && mounted) Navigator.of(context).pop();
            },
            child: const Icon(Icons.chevron_left,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quiz',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No quiz questions are available for this yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondaryTextColor(context)),
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    final question = _controller.questions[_controller.currentIndex];
    final selected = _controller.selectedAnswers[question.id];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuizProgressLabel(
            currentIndex: _controller.currentIndex,
            total: _controller.questions.length,
          ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: primaryTextColor(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          QuizOptionTile(
            letter: 'A',
            text: question.optionA,
            isSelected: selected == 'A',
            isSubmitted: false,
            isCorrectAnswer: false,
            onTap: () => _controller.selectAnswer('A'),
          ),
          QuizOptionTile(
            letter: 'B',
            text: question.optionB,
            isSelected: selected == 'B',
            isSubmitted: false,
            isCorrectAnswer: false,
            onTap: () => _controller.selectAnswer('B'),
          ),
          QuizOptionTile(
            letter: 'C',
            text: question.optionC,
            isSelected: selected == 'C',
            isSubmitted: false,
            isCorrectAnswer: false,
            onTap: () => _controller.selectAnswer('C'),
          ),
          QuizOptionTile(
            letter: 'D',
            text: question.optionD,
            isSelected: selected == 'D',
            isSubmitted: false,
            isCorrectAnswer: false,
            onTap: () => _controller.selectAnswer('D'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_controller.canGoPrevious)
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _controller.previousQuestion,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kMaroon),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text('Back',
                          style: TextStyle(
                              color: kMaroon, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              if (_controller.canGoPrevious) const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: !_controller.hasAnsweredCurrent
                        ? null
                        : (_controller.isLastQuestion
                            ? (_controller.allAnswered ? _submitAndShow : null)
                            : _controller.nextQuestion),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMaroon,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      _controller.isLastQuestion ? 'Submit Quiz' : 'Next',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitAndShow() async {
    await _submit();
  }

  Widget _buildResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuizResultSummaryCard(
            score: _controller.score,
            total: _controller.questions.length,
            passed: _controller.passed,
          ),
          if (!_controller.isSubjectQuiz) ...[
            const SizedBox(height: 10),
            Text(
              _controller.passed
                  ? 'This lesson is now marked complete.'
                  : 'Score ${QuizController.passingPercent}% or higher to '
                      'mark this lesson complete. You can retake the quiz '
                      'any time.',
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor(context),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Review',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 12),
          ..._controller.questions.map((q) => _buildReviewQuestion(q)),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_pendingResult),
              style: ElevatedButton.styleFrom(
                backgroundColor: kMaroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 2,
              ),
              child: const Text('Done',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await _controller.loadQuiz();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kMaroon),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text('Retake Quiz',
                  style: TextStyle(
                      color: kMaroon, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReviewQuestion(QuizQuestionData q) {
    final selected = _controller.selectedAnswers[q.id];
    final options = {
      'A': q.optionA,
      'B': q.optionB,
      'C': q.optionC,
      'D': q.optionD,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.questionText,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: primaryTextColor(context),
            ),
          ),
          const SizedBox(height: 10),
          for (final entry in options.entries)
            QuizOptionTile(
              letter: entry.key,
              text: entry.value,
              isSelected: selected == entry.key,
              isSubmitted: true,
              isCorrectAnswer: q.correctOption == entry.key,
            ),
          if (q.explanation != null && q.explanation!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              q.explanation!,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: secondaryTextColor(context),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
