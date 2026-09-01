import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/subject_detail_controller.dart';
import '../widgets/home_widgets.dart';
import '../widgets/subject_widgets.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'lesson_screen.dart';
import 'profile_screen.dart';
import 'quiz_screen.dart';
import 'notes_screen.dart';


/// Shown when a subject is tapped from the Subjects screen. Displays
/// that subject's lessons ("competencies") with completion status,
/// overall progress, and a CTA to take that subject's quiz.
class SubjectDetailScreen extends StatefulWidget {
  final String subjectId;

  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  late final SubjectDetailController _controller;

  static const Map<String, String> _categoryTitles = {
    'GE': 'General Education',
    'PE': 'Professional Education',
    'SP': 'Specialization',
  };

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller =
        SubjectDetailController(uid: uid, subjectId: widget.subjectId);
    _controller.loadSubjectDetail();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        break;
      case 1:
        Navigator.of(context).pop();
        break;
      case 2:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
        );
        break;
      default:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
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
                      : RefreshIndicator(
                          color: kMaroon,
                          onRefresh: _controller.refresh,
                          child: _buildBody(),
                        ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: HomeBottomNavBar(
          currentIndex: 1,
          onTap: _handleNavTap,
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
                'Subject',
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
    final subject = _controller.subject;

    if (subject == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Subject not found.',
                style: TextStyle(color: secondaryTextColor(context)),
              ),
            ),
          ),
        ],
      );
    }

    final code = (subject['code'] as String?)?.isNotEmpty == true
        ? subject['code'] as String
        : (subject['name'] as String).substring(0, 2).toUpperCase();
    final color = subjectColorFor(
        subject['code'] as String?, subject['colorHex'] as String?);
    final categoryLabel = _categoryTitles[subject['code']] ?? 'Subject';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left,
                    color: labelColorFor(context), size: 20),
                Text(
                  'Back to Subjects',
                  style: TextStyle(
                    color: labelColorFor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SubjectDetailHeaderCard(
            code: code,
            categoryLabel: categoryLabel,
            subjectName: subject['name'] as String,
            completedCount: _controller.completedCount,
            totalCount: _controller.totalCount,
            progressPercent: _controller.progressPercent,
            color: color,
          ),
          const SizedBox(height: 20),

          if (_controller.lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No lessons synced for this subject yet.',
                style: TextStyle(color: secondaryTextColor(context)),
              ),
            )
          else
            ..._controller.lessons.map(
              (lesson) => LessonProgressRow(
                title: lesson.title,
                isCompleted: lesson.isCompleted,
                estimatedMinutes: lesson.estimatedMinutes,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LessonScreen(
                        subjectId: widget.subjectId,
                        lessonId: lesson.id,
                      ),
                    ),
                  );
                  await _controller.refresh();
                },
              ),
            ),

          const ActionDivider(),
          ExamActionButton(
            label: 'Take a Subject Quiz',
            onPressed: _controller.lessons.isEmpty
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          subjectId: widget.subjectId,
                          title: subject['name'] as String,
                        ),
                      ),
                    );
                    await _controller.refresh();
                  },
          ),
          const SizedBox(height: 20),

          const SizedBox(height: 12),
          ExamActionButton(
            label: 'My Notes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotesScreen(
                    subjectId: widget.subjectId,
                    subjectName: subject['name'] as String,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
