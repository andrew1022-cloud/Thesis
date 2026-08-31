import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Holds all state and business logic for the Log-in / Sign-up screen.
/// The UI (AuthScreen) only reads from this controller and calls its
/// methods — it does not manage any state itself.
class AuthController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Which form is currently shown
  bool isLogin = true;

  // Shared loading/error state for whichever form is active.
  bool isLoading = false;
  String? errorMessage;

  /// Set right after a successful [login] call. If true, the account
  /// that just signed in has an admin doc (see `admins/{uid}` in
  /// Firestore) and AuthScreen should route to the Admin dashboard
  /// instead of the regular Home screen.
  bool isAdminLogin = false;

  // ---- Log-in fields ----
  final TextEditingController loginUsernameController =
      TextEditingController();
  final TextEditingController loginPasswordController =
      TextEditingController();
  bool obscureLoginPassword = true;
  bool rememberMe = false;

  // ---- Sign-up fields ----
  final TextEditingController signupUsernameController =
      TextEditingController();
  final TextEditingController signupEmailController = TextEditingController();
  final TextEditingController signupPasswordController =
      TextEditingController();
  final TextEditingController signupConfirmPasswordController =
      TextEditingController();
  bool obscureSignupPassword = true;
  bool obscureConfirmPassword = true;

  // ---- Tab toggle ----
  void showLogin() {
    isLogin = true;
    errorMessage = null;
    notifyListeners();
  }

  void showSignup() {
    isLogin = false;
    errorMessage = null;
    notifyListeners();
  }

  // ---- Log-in actions ----
  void toggleLoginPasswordVisibility() {
    obscureLoginPassword = !obscureLoginPassword;
    notifyListeners();
  }

  void toggleRememberMe(bool? value) {
    rememberMe = value ?? false;
    notifyListeners();
  }

  /// Accepts either an email address or a username in the same field
  /// (matching the "Juan Dela Cruz / juandelacruz@gmail.com" hint).
  /// Firebase Auth only signs in by email, so a plain username is
  /// resolved to its email via the users/{uid} Firestore profile
  /// created at sign-up.
  Future<String?> _resolveEmail(String input) async {
    if (input.contains('@')) return input;

    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: input)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first.data()['email'] as String?;
  }

  /// True if `uid` has a doc under the top-level `admins` collection.
  /// Grant admin access by creating `admins/{uid}` (any contents, or
  /// empty) in Firestore — no separate credentials needed, it's the
  /// same login, just an elevated account.
  Future<bool> _checkIsAdmin(String uid) async {
    try {
      final doc = await _firestore.collection('admins').doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('AuthController: admin check failed: $e');
      return false;
    }
  }

  /// Returns true on success. On failure, [errorMessage] is set and
  /// listeners are notified so the UI can display it. On success,
  /// [isAdminLogin] is also set so the UI knows where to navigate.
  Future<bool> login() async {
    final input = loginUsernameController.text.trim();
    final password = loginPasswordController.text;

    if (input.isEmpty || password.isEmpty) {
      errorMessage = 'Please enter your username/email and password.';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final email = await _resolveEmail(input);
      if (email == null) {
        errorMessage = 'No account found for that username or email.';
        isLoading = false;
        notifyListeners();
        return false;
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      isAdminLogin = await _checkIsAdmin(credential.user!.uid);

      isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = _mapAuthError(e);
      isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'Something went wrong. Please try again.';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ---- Sign-up actions ----
  void toggleSignupPasswordVisibility() {
    obscureSignupPassword = !obscureSignupPassword;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword = !obscureConfirmPassword;
    notifyListeners();
  }

  /// Returns an error message if validation fails, or null if OK.
  String? validateSignup() {
    if (signupUsernameController.text.trim().isEmpty) {
      return 'Please enter a username.';
    }
    if (signupEmailController.text.trim().isEmpty) {
      return 'Please enter an email address.';
    }
    if (signupPasswordController.text.isEmpty) {
      return 'Please enter a password.';
    }
    if (signupPasswordController.text.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (signupPasswordController.text != signupConfirmPasswordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  /// Returns true on success. On failure, [errorMessage] is set and
  /// listeners are notified so the UI can display it.
  Future<bool> signup() async {
    final error = validateSignup();
    if (error != null) {
      errorMessage = error;
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final username = signupUsernameController.text.trim();
    final email = signupEmailController.text.trim();
    final password = signupPasswordController.text;

    try {
      // Reject duplicate usernames up front (Firebase Auth already
      // enforces unique emails, but not usernames).
      final existing = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        errorMessage = 'That username is already taken.';
        isLoading = false;
        notifyListeners();
        return false;
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(username);

      await _firestore.collection('users').doc(uid).set({
        'username': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'points': 0,
      });

      // Sign-up never grants admin access — that has to be set up
      // separately by creating an `admins/{uid}` doc.
      isAdminLogin = false;

      isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = _mapAuthError(e);
      isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'Something went wrong. Please try again.';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> continueWithGoogle() async {
    // TODO: hook up Google sign-in
    debugPrint('Continue with Google tapped');
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect username/email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  @override
  void dispose() {
    loginUsernameController.dispose();
    loginPasswordController.dispose();
    signupUsernameController.dispose();
    signupEmailController.dispose();
    signupPasswordController.dispose();
    signupConfirmPasswordController.dispose();
    super.dispose();
  }
}
