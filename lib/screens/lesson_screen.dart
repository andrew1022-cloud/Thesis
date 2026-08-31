import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/lesson_controller.dart';
import '../widgets/home_widgets.dart';
import '../widgets/subject_widgets.dart';
import 'quiz_screen.dart';

/// Shown when a lesson row is tapped from the Subject Detail screen.
/// Displays the lesson's content, lets the user mark it complete, and
/// links into that lesson's competency quiz if one exists.
class LessonScreen extends StatefulWidget {
  final String subjectId;
  final String lessonId;

  const LessonScreen({
    super.key,
    required this.subjectId,
    required this.lessonId,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late final LessonController _controller;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = LessonController(
      uid: uid,
      subjectId: widget.subjectId,
      lessonId: widget.lessonId,
    );
    _controller.loadLesson();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openQuiz() async {
    // Returning true tells the Subject Detail screen behind this one
    // to refresh, since completing the quiz may have marked the
    // lesson complete.
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          subjectId: widget.subjectId,
          lessonId: widget.lessonId,
          title: (_controller.lesson?['title'] as String?) ?? 'Quiz',
        ),
      ),
    );
    if (result == true) {
      await _controller.loadLesson();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                      : _buildBody(),
                ),
              ],
            );
          },
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
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.chevron_left,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 6),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.menu_book_rounded, color: kGold, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RevEduc',
                style: TextStyle(
                  color: kGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Lesson',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final lesson = _controller.lesson;

    if (lesson == null) {
      return Center(
        child: Text(
          'Lesson not found.',
          style: TextStyle(color: secondaryTextColor(context)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson['title'] as String,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                _controller.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 16,
                color: _controller.isCompleted
                    ? Colors.green
                    : secondaryTextColor(context),
              ),
              const SizedBox(width: 6),
              Text(
                _controller.isCompleted ? 'Completed' : 'Not completed yet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _controller.isCompleted
                      ? Colors.green
                      : secondaryTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              (lesson['content'] as String?)?.isNotEmpty == true
                  ? lesson['content'] as String
                  : 'No content added for this lesson yet.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: primaryTextColor(context),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _controller.isCompleted ? null : _controller.markComplete,
              icon: Icon(_controller.isCompleted
                  ? Icons.check
                  : Icons.check_circle_outline),
              label: Text(
                _controller.isCompleted ? 'Marked as Complete' : 'Mark as Complete',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _controller.isCompleted ? Colors.grey.shade400 : kMaroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),

          const ActionDivider(),
          ExamActionButton(
            label: _controller.hasQuiz
                ? 'Take Competency Quiz'
                : 'No Quiz Available Yet',
            onPressed: _controller.hasQuiz ? _openQuiz : null,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
