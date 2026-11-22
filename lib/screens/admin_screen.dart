import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/admin_controller.dart';
import '../services/session_service.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/home_widgets.dart';
import 'admin_management_screen.dart';
import 'auth_screen.dart';
import 'content_screen.dart';

/// Landing page shown after a user with admin access logs in.
/// Shows registered/prepared/completed stats plus a browsable list
/// of every registered user's per-category progress.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminController _controller;

  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _controller = AdminController();
    _controller.loadAdminData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNavTap(int index) {
    switch (index) {
      case 0:
        // Already on Users.
        break;
      case 1:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminManagementScreen()),
        );
        break;
      default:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ContentScreen()),
        );
        break;
    }
  }

  Future<void> _handleLogout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      // Same full teardown as the student log-out: remember-me flags,
      // Google + Firebase sign-out, reminders, connectivity listener.
      await SessionService.instance.logout();
    } catch (e) {
      debugPrint('AdminScreen: logout failed: $e');
      if (!mounted) return;
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't log out. Please try again.")),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _handleExport() async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await _controller.exportUsers();
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
        bottomNavigationBar: AdminBottomNavBar(
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
          const Expanded(
            child: Column(
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
                  'Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _loggingOut
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white70),
                  ),
                )
              : IconButton(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                  tooltip: 'Log out',
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
          // ---- Stat cards ----
          Row(
            children: [
              Expanded(
                child: AdminStatCard(
                  value: '${_controller.registeredUserCount}',
                  label: 'Registered\nUsers',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminStatCard(
                  value: '${_controller.averagePreparednessPercent}%',
                  label: 'Average\nPreparedness',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminStatCard(
                  value: '${_controller.completedUserCount}',
                  label: 'Completed\nUsers',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---- All Users header + Export ----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Users:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor(context),
                  fontFamily: 'Georgia',
                ),
              ),
              TextButton(
                onPressed: _controller.isExporting ? null : _handleExport,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: _controller.isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kMaroon),
                      )
                    : const Text(
                        'Export',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F6FEB),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_controller.users.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No registered users yet.',
                  style: TextStyle(color: secondaryTextColor(context)),
                ),
              ),
            )
          else
            ..._controller.users.map(
              (u) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AdminUserCard(
                  name: u.name,
                  email: u.email,
                  genEdPercent: u.genEdPercent,
                  profEdPercent: u.profEdPercent,
                  specializationPercent: u.specializationPercent,
                  overallPercent: u.overallPercent,
                  lastActiveLabel: u.lastActiveLabel,
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
