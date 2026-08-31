import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/home_controller.dart';
import '../widgets/home_widgets.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'subject_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = HomeController(uid: uid);
    _controller.loadDashboard();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNavTap(int index) {
    switch (index) {
      case 0:
        // Already on Home.
        break;
      case 1:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SubjectScreen()),
        );
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
                      ? const Center(child: CircularProgressIndicator(color: kMaroon))
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
          currentIndex: 0,
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
                'Home',
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back',
            style: TextStyle(
              color: labelColorFor(context),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Good Day!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 18),

          // ---- Overall Progress card ----
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: kMaroon,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                ProgressRing(percent: _controller.overallProgressPercent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'You have completed ${_controller.overallProgressPercent}% '
                        'of overall progress',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ---- Stat tiles ----
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${_controller.dayStreak}',
                  label: 'Day Streak',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '${_controller.lessonsDone}',
                  label: 'Lessons Done',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '${_controller.averageScorePercent}%',
                  label: 'Average Score',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---- Continue by Subject ----
          Text(
            'Continue by Subject',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: primaryTextColor(context),
            ),
          ),
          const SizedBox(height: 12),
          ..._buildSubjectCards(),

          const SizedBox(height: 20),

          // ---- Do you wish to continue? ----
          if (_controller.lastOpenedLesson != null)
            ContinuePromptCard(
              subjectLabel:
                  '${_controller.lastOpenedLesson!['subjectName']} - '
                  '${_controller.lastOpenedLesson!['lessonTitle']}',
              progressPercent:
                  _controller.lastOpenedLesson!['progressPercent'] as int,
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<Widget> _buildSubjectCards() {
    if (_controller.continueBySubject.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No subjects synced yet.',
            style: TextStyle(color: secondaryTextColor(context)),
          ),
        ),
      ];
    }

    return _controller.continueBySubject.map((entry) {
      final subject = entry['subject'] as Map<String, dynamic>;
      final code = (subject['code'] as String?)?.isNotEmpty == true
          ? subject['code'] as String
          : (subject['name'] as String).substring(0, 2).toUpperCase();
      final color =
          subjectColorFor(subject['code'] as String?, subject['colorHex'] as String?);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SubjectContinueCard(
          code: code,
          name: subject['name'] as String,
          lessonTitle: entry['lastLessonTitle'] as String?,
          progressPercent: entry['progressPercent'] as int,
          color: color,
        ),
      );
    }).toList();
  }
}
