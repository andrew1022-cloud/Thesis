import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart' show themeNotifier;
import '../screens/calendar_screen.dart';

/// A single badge earned by the user.
class UserBadge {
  final String id;
  final String label;
  /// Either an asset path (e.g. 'assets/badges/profed.png') or null
  /// to fall back to a default icon.
  final String? assetPath;

  const UserBadge({required this.id, required this.label, this.assetPath});
}

/// Holds state and logic for the Profile screen.
class ProfileController extends ChangeNotifier {
  BuildContext? _context;

  void attachContext(BuildContext context) => _context = context;

  ProfileController() {
    themeNotifier.addListener(_onThemeChanged);
  }

  // ── User ledger state ──────────────────────────────────────────────────────
  bool isLoading = true;
  String username = '';
  String email = '';
  int points = 0;
  List<UserBadge> badges = [];

  Future<void> loadProfile() async {
    isLoading = true;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final email_ = FirebaseAuth.instance.currentUser?.email ?? '';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        username = (data['username'] as String?) ?? '';
        email = (data['email'] as String?) ?? email_;
        points = (data['points'] as int?) ?? 0;
      } else {
        email = email_;
      }

      // Badges sub-collection: users/{uid}/badges  (optional)
      // Each doc: { label: String, assetPath: String? }
      final badgeSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('badges')
          .get();

      badges = badgeSnap.docs.map((d) {
        final data = d.data();
        return UserBadge(
          id: d.id,
          label: (data['label'] as String?) ?? d.id,
          assetPath: data['assetPath'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('ProfileController: failed to load profile: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Theme ──────────────────────────────────────────────────────────────────
  bool get isDarkMode => themeNotifier.value == ThemeMode.dark;

  void _onThemeChanged() => notifyListeners();

  void toggleDarkMode() {
    themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // ── Menu actions ───────────────────────────────────────────────────────────
  void goToAccount() {
    debugPrint('Account tapped');
  }

  void goToCalendar() {
    if (_context == null) return;
    Navigator.of(_context!).push(
      MaterialPageRoute(builder: (_) => const CalendarScreen()),
    );
  }

  void goToSettings() {
    debugPrint('Settings tapped');
  }

  void goToHelp() {
    debugPrint('Help tapped');
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }
}
