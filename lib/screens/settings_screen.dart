import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/settings_controller.dart';
import '../services/notification_service.dart';
import '../widgets/home_widgets.dart';
import '../widgets/settings_widgets.dart';
import 'account_settings_screen.dart';
import 'help_center_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = SettingsController(uid: uid);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleReminders(bool value) async {
    final error = await _controller.setRemindersEnabled(value);
    if (error != null) {
      _snack(error);
    } else {
      _snack(value ? 'Study reminders on.' : 'Study reminders off.');
    }
  }

  Future<void> _syncNow() async {
    final error = await _controller.syncNow();
    _snack(error ?? 'Everything is up to date.');
  }

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Clear local cache?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: primaryTextColor(context),
          ),
        ),
        content: Text(
          'Downloaded lessons and quizzes on this device are removed and '
          're-downloaded. Your progress is synced first, so nothing is lost.',
          style: TextStyle(color: primaryTextColor(context), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: secondaryTextColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear',
                style: TextStyle(color: kMaroon, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await _controller.clearLocalCache();
    _snack(error ?? 'Local cache cleared and refreshed.');
  }

  Future<void> _testNotification() async {
    try {
      await NotificationService.instance.scheduleTestNotification();
      _snack('Test notification sent — check your tray 🔔');
    } catch (e) {
      _snack('Notification test failed: $e');
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'RevEduc',
      applicationVersion: '1.0.0',
      applicationLegalese: 'TUPC Department of Industrial Education',
      children: const [
        SizedBox(height: 12),
        Text(
          'A LET reviewer covering General Education, Professional '
          'Education, and Specialization.',
        ),
      ],
    );
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
                const SubScreenHeader(
                  title: 'Settings',
                  icon: Icons.settings_rounded,
                ),
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

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSection(
            title: 'Account',
            children: [
              SettingsTile(
                icon: Icons.person_outline_rounded,
                label: 'Account Settings',
                subtitle: 'Username and password',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const AccountSettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSection(
            title: 'Preferences',
            children: [
              SettingsSwitchTile(
                icon: Icons.dark_mode_outlined,
                label: 'Dark Mode',
                subtitle: 'Resets to light when the app restarts',
                value: _controller.isDarkMode,
                onChanged: (_) => _controller.toggleDarkMode(),
              ),
              SettingsSwitchTile(
                icon: Icons.notifications_none_rounded,
                label: 'Study Reminders',
                subtitle: "Nudges when you haven't reviewed in a while",
                value: _controller.remindersEnabled,
                onChanged: _toggleReminders,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSection(
            title: 'Data',
            children: [
              SettingsTile(
                icon: Icons.sync_rounded,
                label: 'Sync Now',
                subtitle: 'Upload your progress and download new content',
                onTap: _controller.isSyncing ? null : _syncNow,
                trailing: _controller.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: kMaroon),
                      )
                    : null,
              ),
              SettingsTile(
                icon: Icons.delete_sweep_outlined,
                label: 'Clear Local Cache',
                subtitle: 'Free up space and re-download content',
                onTap: _controller.isSyncing ? null : _confirmClearCache,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSection(
            title: 'Support',
            children: [
              SettingsTile(
                icon: Icons.help_outline_rounded,
                label: 'Help Center',
                subtitle: 'FAQs and contact',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                ),
              ),
              SettingsTile(
                icon: Icons.info_outline_rounded,
                label: 'About RevEduc',
                subtitle: 'Version 1.0.0',
                onTap: _showAbout,
              ),
              if (kDebugMode)
                SettingsTile(
                  icon: Icons.notifications_active_rounded,
                  label: 'Test Notification',
                  subtitle: 'Debug builds only',
                  onTap: _testNotification,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
