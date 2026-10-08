import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Holds all state and logic for the Account Settings screen:
/// viewing the profile, changing the username, changing the password.
class AccountController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _disposed = false;

  bool isLoading = true;
  bool isSavingUsername = false;
  bool isSavingPassword = false;

  String username = '';
  String email = '';

  /// Password changes only apply to accounts created with email +
  /// password. Google sign-in accounts have no password to change.
  bool get canChangePassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    final user = _auth.currentUser;
    email = user?.email ?? '';

    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        final data = doc.data();
        username = (data?['username'] as String?) ?? user.displayName ?? '';
        email = (data?['email'] as String?) ?? email;
      } catch (e) {
        debugPrint('AccountController: failed to load account: $e');
        username = user.displayName ?? '';
      }
    }

    isLoading = false;
    notifyListeners();
  }

  /// Returns null on success, or an error message.
  Future<String?> updateUsername(String input) async {
    final user = _auth.currentUser;
    if (user == null) return 'You are not signed in.';

    final newName = input.trim();
    if (newName.isEmpty) return 'Please enter a username.';
    if (newName == username) return null;

    isSavingUsername = true;
    notifyListeners();

    try {
      final existing = await _firestore
          .collection('users')
          .where('username', isEqualTo: newName)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty && existing.docs.first.id != user.uid) {
        return 'That username is already taken.';
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'username': newName}, SetOptions(merge: true));
      await user.updateDisplayName(newName);

      username = newName;
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'network-request-failed' || e.code == 'unavailable') {
        return 'No internet connection. Please check your network.';
      }
      return e.message ?? 'Could not update your username.';
    } catch (e) {
      debugPrint('AccountController: username update failed: $e');
      return 'Something went wrong. Please try again.';
    } finally {
      isSavingUsername = false;
      notifyListeners();
    }
  }

  /// Re-authenticates with the current password, then sets the new
  /// one. Returns null on success, or an error message.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return 'You are not signed in.';

    if (currentPassword.isEmpty) return 'Please enter your current password.';
    if (newPassword.length < 6) {
      return 'New password must be at least 6 characters.';
    }
    if (newPassword != confirmPassword) return 'New passwords do not match.';
    if (newPassword == currentPassword) {
      return 'New password must be different from the current one.';
    }

    isSavingPassword = true;
    notifyListeners();

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Current password is incorrect.';
        case 'weak-password':
          return 'New password is too weak.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'requires-recent-login':
          return 'Please log out and log in again, then retry.';
        case 'network-request-failed':
          return 'No internet connection. Please check your network.';
        default:
          return e.message ?? 'Could not change your password.';
      }
    } catch (e) {
      debugPrint('AccountController: password change failed: $e');
      return 'Something went wrong. Please try again.';
    } finally {
      isSavingPassword = false;
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
    super.dispose();
  }
}
