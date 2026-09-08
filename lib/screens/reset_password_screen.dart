import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/reset_password_controller.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/home_widgets.dart' show labelColorFor, primaryTextColor;

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final ResetPasswordController _controller = ResetPasswordController();

  static const Color maroon = Color(0xFF6E1B24);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: maroon,
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
                  color: maroon,
                  height: MediaQuery.of(context).padding.top,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Row(
                            children: [
                              Icon(Icons.chevron_left,
                                  color: labelColorFor(context), size: 20),
                              Text(
                                'Back to Log-in',
                                style: TextStyle(
                                  color: labelColorFor(context),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Envelope icon in a circle
                        Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: maroon, width: 3),
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              color: maroon,
                              size: 44,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Reset Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: primaryTextColor(context),
                            fontFamily: 'Georgia',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Enter the email linked to your account and "
                          "we'll send you a link to reset your password.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: labelColorFor(context),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),

                        FieldLabel('Email Address:', color: labelColorFor(context)),
                        const SizedBox(height: 6),
                        StyledTextField(
                          controller: _controller.emailController,
                          hintText: 'juandelacruz@gmail.com',
                        ),

                        if (_controller.errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _controller.errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],

                        if (_controller.linkSent) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'A reset link has been sent to your email.',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _controller.isSending
                                ? null
                                : _controller.sendResetLink,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: maroon,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 2,
                            ),
                            child: _controller.isSending
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Send Reset Link',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
