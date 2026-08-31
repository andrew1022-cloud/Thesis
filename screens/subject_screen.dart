import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/subject_controller.dart';
import '../widgets/home_widgets.dart';
import '../widgets/subject_widgets.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'subject_detail_screen.dart';

class SubjectScreen extends StatefulWidget {
  const SubjectScreen({super.key});

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  late final SubjectController _controller;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = SubjectController(uid: uid);
    _controller.loadSubjects();
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
        // Already on Subjects.
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
            child: const Icon(Icons.menu_book_rounded, color: kGold, size: 20),
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
    if (_controller.groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No subjects synced yet.',
                style: TextStyle(color: secondaryTextColor(context)),
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _controller.groups.length; i++) ...[
            _buildGroup(_controller.groups[i],
                isLast: i == _controller.groups.length - 1),
            if (i != _controller.groups.length - 1) const SizedBox(height: 28),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGroup(SubjectGroup group, {required bool isLast}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubjectSectionTitle(group.title),
        for (final item in group.subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SubjectCompetencyRow(
              code: (item.subject['code'] as String?)?.isNotEmpty == true
                  ? item.subject['code'] as String
                  : (item.subject['name'] as String)
                      .substring(0, 2)
                      .toUpperCase(),
              name: item.subject['name'] as String,
              completedCount: item.completedCount,
              totalCount: item.totalCount,
              progressPercent: item.progressPercent,
              color: subjectColorFor(
                item.subject['code'] as String?,
                item.subject['colorHex'] as String?,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubjectDetailScreen(
                      subjectId: item.subject['id'] as String,
                    ),
                  ),
                );
              },
            ),
          ),
        const ActionDivider(),
        ExamActionButton(
          label: 'Take a Subject Exam',
          onPressed: () => _controller.takeSubjectExam(group.code),
        ),
        if (isLast) ...[
          const ActionDivider(),
          ExamActionButton(
            label: 'Take a Mock Exam',
            onPressed: _controller.takeMockExam,
          ),
        ],
      ],
    );
  }
}
