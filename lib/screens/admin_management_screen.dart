import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/admin_management_controller.dart';
import '../widgets/add_admin_dialog.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/home_widgets.dart';
import 'admin_screen.dart';
import 'content_screen.dart';

/// The "Admins" tab: shows every account with admin access, and lets
/// the signed-in admin add new ones via the "+" FAB.
class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  late final AdminManagementController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AdminManagementController();
    _controller.loadAdmins();
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
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
        break;
      case 1:
        // Already on Admins.
        break;
      default:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ContentScreen()),
        );
        break;
    }
  }

  void _openAddAdminDialog() {
    showDialog(
      context: context,
      builder: (_) => AddAdminDialog(controller: _controller),
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
        floatingActionButton: FloatingActionButton(
          onPressed: _openAddAdminDialog,
          backgroundColor: kMaroon,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: AdminBottomNavBar(
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
                'Admin',
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Admins:',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 16),

          if (_controller.admins.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No admins yet. Tap "+" to add one.',
                  style: TextStyle(color: secondaryTextColor(context)),
                ),
              ),
            )
          else
            ..._controller.admins.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AdminListItem(
                  name: a.username,
                  email: a.email,
                  role: a.role,
                  addedLabel: a.addedLabel,
                  lastActiveLabel: a.lastActiveLabel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
