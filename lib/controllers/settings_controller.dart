import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart' show themeNotifier;
import '../services/local_db_service.dart';
import '../services/notification_service.dart';

/// Holds all state for the Settings screen.
///
/// The reminders preference is stored on the user's Firestore doc
/// (`users/{uid}.remindersEnabled`, default true) so it follows the
/// account across devices. HomeController reads the same field before
/// scheduling the inactivity ladder.
class SettingsController extends ChangeNotifier {
  final String uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDbService _localDb = LocalDbService.instance;

  SettingsController({required this.uid}) {
    themeNotifier.addListener(_onThemeChanged);
  }

  bool _disposed = false;

  bool isLoading = true;
  bool remindersEnabled = true;
  bool isSyncing = false;

  bool get isDarkMode => themeNotifier.value == ThemeMode.dark;

  void _onThemeChanged() => notifyListeners();

  void toggleDarkMode() {
    themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    if (uid.isNotEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        remindersEnabled = (doc.data()?['remindersEnabled'] as bool?) ?? true;
      } catch (e) {
        debugPrint('SettingsController: failed to load settings: $e');
      }
    }

    isLoading = false;
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  Future<String?> setRemindersEnabled(bool value) async {
    final previous = remindersEnabled;
    remindersEnabled = value;
    notifyListeners();

    try {
      if (uid.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(uid)
            .set({'remindersEnabled': value}, SetOptions(merge: true));
      }
      if (value) {
        await NotificationService.instance.requestPermission();
        await NotificationService.instance.scheduleInactivityReminders();
      } else {
        await NotificationService.instance.cancelInactivityReminders();
      }
      return null;
    } catch (e) {
      debugPrint('SettingsController: failed to update reminders: $e');
      remindersEnabled = previous;
      notifyListeners();
      return "Couldn't update reminders. Check your connection and try again.";
    }
  }

  /// Pushes unsynced progress, then pulls reviewer content and the
  /// user's own data. Returns an error message, or null on success.
  Future<String?> syncNow() async {
    if (isSyncing) return null;
    isSyncing = true;
    notifyListeners();

    try {
      await _localDb.pushPendingSyncs(uid);
      await _localDb.syncAll();
      await _localDb.syncUserDataFromFirestore(uid);
      return null;
    } catch (e) {
      debugPrint('SettingsController: sync failed: $e');
      return "Sync failed. Check your connection and try again.";
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  /// Wipes the local SQLite cache and re-downloads everything.
  /// Unsynced progress is pushed first so nothing is lost.
  Future<String?> clearLocalCache() async {
    if (isSyncing) return null;
    isSyncing = true;
    notifyListeners();

    try {
      await _localDb.pushPendingSyncs(uid);
      await _localDb.clearAllData();
      await _localDb.syncAll();
      await _localDb.syncUserDataFromFirestore(uid);
      return null;
    } catch (e) {
      debugPrint('SettingsController: clear cache failed: $e');
      return "Cache cleared, but re-downloading failed. Pull to refresh "
          'when you are back online.';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }
}
