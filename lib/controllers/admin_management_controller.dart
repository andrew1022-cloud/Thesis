import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One row in the "All Admins" list.
class AdminListEntry {
  final String uid;
  final String username;
  final String email;
  final String role;
  final String addedLabel;
  final String lastActiveLabel;

  AdminListEntry({
    required this.uid,
    required this.username,
    required this.email,
    required this.role,
    required this.addedLabel,
    required this.lastActiveLabel,
  });
}

/// Holds all state for the Admins tab: the roster of existing admins,
/// and the "Add Admin" flow.
class AdminManagementController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> availableRoles = [
    'Admin',
    'Supervisor',
    'Content Manager',
  ];

  bool isLoading = true;
  List<AdminListEntry> admins = [];

  bool isSaving = false;
  String? formError;

  Future<void> loadAdmins() async {
    isLoading = true;
    notifyListeners();

    try {
      final adminDocs = await _firestore
          .collection('admins')
          .orderBy('grantedAt', descending: true)
          .get();

      final entries = <AdminListEntry>[];
      for (final doc in adminDocs.docs) {
        final uid = doc.id;
        final data = doc.data();

        final userDoc = await _firestore.collection('users').doc(uid).get();
        final userData = userDoc.data() ?? {};

        final username = (userData['username'] as String?)?.isNotEmpty == true
            ? userData['username'] as String
            : 'Unknown';
        final email = (userData['email'] as String?) ?? '';
        final role = (data['role'] as String?)?.isNotEmpty == true
            ? data['role'] as String
            : 'Admin';

        final grantedAt = data['grantedAt'] as Timestamp?;
        final addedLabel =
            grantedAt != null ? DateFormat('MM/dd/yyyy').format(grantedAt.toDate()) : '—';

        final lastActiveLabel = await _fetchLastActiveLabel(uid);

        entries.add(AdminListEntry(
          uid: uid,
          username: username,
          email: email,
          role: role,
          addedLabel: addedLabel,
          lastActiveLabel: lastActiveLabel,
        ));
      }

      admins = entries;
    } catch (e) {
      debugPrint('AdminManagementController: failed to load admins: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<String> _fetchLastActiveLabel(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('appUsage')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return 'No activity yet';

      final data = snap.docs.first.data();
      final openedAtRaw = data['openedAt'] as String?;
      final openedAt =
          openedAtRaw != null ? DateTime.tryParse(openedAtRaw) : null;
      if (openedAt == null) return snap.docs.first.id;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final openedDay = DateTime(openedAt.year, openedAt.month, openedAt.day);
      final dayDiff = today.difference(openedDay).inDays;

      if (dayDiff == 0) return 'Today';
      if (dayDiff == 1) return 'Yesterday';
      return DateFormat('MMM d').format(openedAt);
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Creates a brand-new account and grants it admin access.
  ///
  /// Firebase Auth's client SDK signs in as whatever user it just
  /// created, which would otherwise boot the current admin out of
  /// their own session. To avoid that, this spins up a short-lived
  /// secondary [FirebaseApp] just for the createUser call, then tears
  /// it down — the primary app (and the signed-in admin) is
  /// untouched throughout.
  ///
  /// Returns null on success, or an error message to show in the
  /// dialog on failure.
  Future<String?> addAdmin({
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    if (username.trim().isEmpty) return 'Please enter a username.';
    if (email.trim().isEmpty || !email.contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    isSaving = true;
    formError = null;
    notifyListeners();

    FirebaseApp? secondaryApp;
    try {
      // Duplicate-username check up front (Firebase Auth already
      // enforces unique emails on its own).
      final existingUsername = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();
      if (existingUsername.docs.isNotEmpty) {
        return 'That username is already taken.';
      }

      secondaryApp = await Firebase.initializeApp(
        name: 'AddAdmin_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(username.trim());
      await secondaryAuth.signOut();

      await _firestore.collection('users').doc(uid).set({
        'username': username.trim(),
        'email': email.trim(),
        'points': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('admins').doc(uid).set({
        'role': role,
        'grantedAt': FieldValue.serverTimestamp(),
      });

      await loadAdmins();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      debugPrint('AdminManagementController: failed to add admin: $e');
      return 'Something went wrong. Please try again.';
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
      isSaving = false;
      notifyListeners();
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return e.message ?? 'Failed to create the admin account.';
    }
  }

  Future<void> refresh() => loadAdmins();
}
