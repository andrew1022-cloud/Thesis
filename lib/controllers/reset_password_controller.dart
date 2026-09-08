import 'package:flutter/material.dart';

/// Holds state and logic for the "Reset Password" screen.
/// Kept separate from AuthController since it's a distinct flow.
class ResetPasswordController extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();

  bool isSending = false;
  String? errorMessage;
  bool linkSent = false;

  Future<void> sendResetLink() async {
    final email = emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      errorMessage = 'Please enter a valid email address.';
      notifyListeners();
      return;
    }

    errorMessage = null;
    isSending = true;
    notifyListeners();

    // TODO: replace with a real API call (e.g. via an AuthService)
    await Future.delayed(const Duration(seconds: 1));
    debugPrint('Sending reset link to "$email"');

    isSending = false;
    linkSent = true;
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}
