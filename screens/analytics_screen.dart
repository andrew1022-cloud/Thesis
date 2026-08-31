import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/analytics_controller.dart';
import '../widgets/analytics_widgets.dart';
import '../widgets/home_widgets.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'subject_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final AnalyticsController _controller;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = AnalyticsController(uid: uid);
    _controller.loadAnalytics();
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SubjectScreen()),
        );
        break;
      case 2:
        // Already on Analytics.
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
          currentIndex: 2,
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
                'Analytics',
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
          _buildProgressCard(),
          const SizedBox(height: 24),
          _buildCompetencySection(
            title: 'Strongest Competency',
            stats: _controller.strongestCompetencies,
          ),
          const SizedBox(height: 20),
          _buildCompetencySection(
            title: 'Weakest Competency',
            stats: _controller.weakestCompetencies,
          ),
          const SizedBox(height: 24),
          Text(
            'Leaderboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 12),
          _buildLeaderboard(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kMaroon,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
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
                      'You have completed '
                      '${_controller.overallProgressPercent}% of overall '
                      'progress',
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
          const SizedBox(height: 18),
          Divider(color: Colors.white.withOpacity(0.25), height: 1),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: LabeledMiniProgressRing(
                  percent: _controller.generalEducationProgressPercent,
                  label: 'General Education\nProgress',
                ),
              ),
              Expanded(
                child: LabeledMiniProgressRing(
                  percent: _controller.professionalEducationProgressPercent,
                  label: 'Professional\nEducation Progress',
                ),
              ),
              Expanded(
                child: LabeledMiniProgressRing(
                  percent: _controller.specializationProgressPercent,
                  label: 'Specialization\nProgress',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompetencySection({
    required String title,
    required List<CompetencyStat> stats,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: primaryTextColor(context),
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 10),
        if (stats.isEmpty)
          Text(
            'Take some quizzes to see this here.',
            style: TextStyle(color: secondaryTextColor(context), fontSize: 13),
          )
        else
          ...stats.map((s) => CompetencyBulletRow(
                lessonTitle: s.lessonTitle,
                categoryLabel: s.categoryLabel,
                color: subjectColorFor(s.subjectCode, null),
              )),
      ],
    );
  }

  Widget _buildLeaderboard() {
    final entries = _controller.leaderboardTop;
    final me = _controller.currentUserEntry;

    if (entries.isEmpty && me == null) {
      return Text(
        'No leaderboard data yet.',
        style: TextStyle(color: secondaryTextColor(context), fontSize: 13),
      );
    }

    // Don't show the current user's own row twice if they're already
    // sitting inside the top list under their own name.
    final meAlreadyShown =
        me != null && entries.any((e) => e.rank == me.rank && e.points == me.points);

    return LeaderboardCard(
      topRows: entries
          .map((e) =>
              LeaderboardRow(rank: e.rank, name: e.name, points: e.points))
          .toList(),
      currentUserRow: (me == null || meAlreadyShown)
          ? null
          : LeaderboardRow(
              rank: me.rank,
              name: me.name,
              points: me.points,
              highlighted: true,
            ),
    );
  }
}
