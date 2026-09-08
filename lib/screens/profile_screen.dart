import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/profile_controller.dart';
import '../services/local_db_service.dart';
import '../services/notification_service.dart';
import '../services/seed_service.dart';
import '../widgets/home_widgets.dart';
import '../widgets/profile_widgets.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'subject_screen.dart';
import 'notes_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController _controller = ProfileController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.attachContext(context);
    });
    _controller.loadProfile();
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
        );
        break;
      case 3:
        // Already on Profile.
        break;
    }
  }

  // ── Dev-only: seed / clear temporary test lesson & quiz ────────────────
  Future<void> _seedTestData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SeedService.instance.seedTestData();
      await LocalDbService.instance.syncAll();
      await _controller.loadProfile();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Test lesson & quiz seeded ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Seeding failed: $e')),
        );
      }
    }
  }

  Future<void> _clearTestData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SeedService.instance.clearTestData();
      await LocalDbService.instance.syncAll();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Test data cleared 🧹')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Clear failed: $e')),
        );
      }
    }
  }

  // ── Dev-only: verify the inactivity-reminder notification pipeline ─────
  // Fires immediately on tap, so you can confirm permissions, the
  // notification channel, and the branded styling without waiting
  // days for a real "you've been away" reminder to trigger.
  Future<void> _testNotification() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await NotificationService.instance.scheduleTestNotification();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Test notification sent — check your tray 🔔')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Notification test failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _controller.attachContext(context);

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
                          child: CircularProgressIndicator(color: kMaroon),
                        )
                      : _buildBody(),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: HomeBottomNavBar(
          currentIndex: 3,
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
                'Profile',
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. User info row (avatar + username + email) ──────────────────
          UserInfoRow(
            username: _controller.username,
            email: _controller.email,
          ),
          const SizedBox(height: 20),

          // ── 2. User Ledger card (points + badges) ─────────────────────────
          UserLedgerCard(
            points: _controller.points,
            badges: _controller.badges,
          ),
          const SizedBox(height: 28),

          // ── 3. Menu buttons ───────────────────────────────────────────────
          ProfileMenuButton(
            icon: Icons.calendar_today_rounded,
            label: 'Calendar',
            onTap: _controller.goToCalendar,
          ),
          const SizedBox(height: 16),
          ProfileMenuButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            onTap: _controller.goToSettings,
          ),
          const SizedBox(height: 16),
          ProfileMenuButton(
            icon: Icons.help_outline_rounded,
            label: 'Help',
            onTap: _controller.goToHelp,
          ),
          const SizedBox(height: 16),
          ProfileMenuButton(
            icon: Icons.dark_mode_outlined,
            label: 'Dark Mode',
            onTap: _controller.toggleDarkMode,
            trailing: IgnorePointer(
              child: Switch(
                value: _controller.isDarkMode,
                activeColor: kMaroon,
                onChanged: (_) {},
              ),
            ),
          ),

          const SizedBox(height: 16),
          ProfileMenuButton(
            icon: Icons.edit_note_rounded,
            label: 'My Notes',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotesScreen()),
              );
            },
          ),
          // ── 4. Dev-only: seed / clear temporary test data, notif test ──────
          // Hidden automatically in release builds via kDebugMode.
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            Text(
              'Developer Tools',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor(context),
              ),
            ),
            const SizedBox(height: 12),
            ProfileMenuButton(
              icon: Icons.bug_report_rounded,
              label: 'Seed Test Lesson/Quiz',
              onTap: _seedTestData,
            ),
            const SizedBox(height: 16),
            ProfileMenuButton(
              icon: Icons.delete_sweep_rounded,
              label: 'Clear Test Data',
              onTap: _clearTestData,
            ),
            const SizedBox(height: 16),
            ProfileMenuButton(
              icon: Icons.notifications_active_rounded,
              label: 'Test Notification',
              onTap: _testNotification,
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
