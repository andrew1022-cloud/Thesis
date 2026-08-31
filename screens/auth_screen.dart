import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/auth_controller.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/home_widgets.dart' show labelColorFor, primaryTextColor;
import 'admin_screen.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthController _controller = AuthController();

  static const Color maroon = Color(0xFF6E1B24);
  static const Color gold = Color(0xFFC9A24B);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final success = await _controller.login();
    if (!success || !mounted) return;

    // Admin accounts (flagged via the `admins/{uid}` Firestore doc)
    // land on the Admin dashboard instead of the regular Home screen.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _controller.isAdminLogin
            ? const AdminScreen()
            : const HomeScreen(),
      ),
    );
  }

  Future<void> _handleSignup() async {
    final success = await _controller.signup();
    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cream = Theme.of(context).scaffoldBackgroundColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: maroon,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: cream,
        // ListenableBuilder rebuilds only this subtree whenever the
        // controller calls notifyListeners() — no setState() needed here.
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Logo(maroon: maroon, gold: gold, cream: cream),
                        const SizedBox(height: 14),
                        Text(
                          'RevEduc',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: primaryTextColor(context),
                            fontFamily: 'Georgia',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'TUPC Department of Industrial Education',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: labelColorFor(context),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Log-in / Sign-up toggle
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: Theme.of(context).dividerColor),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: ToggleButton(
                                  label: 'Log-in',
                                  selected: _controller.isLogin,
                                  color: maroon,
                                  onTap: _controller.showLogin,
                                ),
                              ),
                              Expanded(
                                child: ToggleButton(
                                  label: 'Sign-up',
                                  selected: !_controller.isLogin,
                                  color: maroon,
                                  onTap: _controller.showSignup,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _controller.isLogin
                              ? _buildLoginForm()
                              : _buildSignupForm(),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: primaryTextColor(context)
                                        .withOpacity(0.4))),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor(context)
                                      .withOpacity(0.7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(
                                    color: primaryTextColor(context)
                                        .withOpacity(0.4))),
                          ],
                        ),
                        const SizedBox(height: 18),

                        Center(
                          child: SizedBox(
                            width: 160,
                            height: 46,
                            child: OutlinedButton(
                              onPressed: _controller.continueWithGoogle,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Theme.of(context).cardColor,
                                side: BorderSide(
                                    color: Theme.of(context).dividerColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Google',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: primaryTextColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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

  // ---------------- LOG-IN FORM (UI only) ----------------
  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel('Username / Email Address:', color: labelColorFor(context)),
        const SizedBox(height: 6),
        StyledTextField(
          controller: _controller.loginUsernameController,
          hintText: 'Juan Dela Cruz / juandelacruz@gmail.com',
        ),
        const SizedBox(height: 16),
        FieldLabel('Password:', color: labelColorFor(context)),
        const SizedBox(height: 6),
        StyledTextField(
          controller: _controller.loginPasswordController,
          hintText: '••••••••',
          obscureText: _controller.obscureLoginPassword,
          suffix: ShowHideButton(
            obscured: _controller.obscureLoginPassword,
            color: labelColorFor(context),
            onTap: _controller.toggleLoginPasswordVisibility,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _controller.rememberMe,
                    activeColor: maroon,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: _controller.toggleRememberMe,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Remember Me',
                    style: TextStyle(
                        fontSize: 13, color: primaryTextColor(context))),
              ],
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ResetPasswordScreen(),
                  ),
                );
              },
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 13,
                  color: maroon,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (_controller.isLogin && _controller.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _controller.errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _controller.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: maroon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 2,
            ),
            child: _controller.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Log-in',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  // ---------------- SIGN-UP FORM (UI only) ----------------
  Widget _buildSignupForm() {
    return Column(
      key: const ValueKey('signup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel('Username:', color: labelColorFor(context)),
        const SizedBox(height: 6),
        StyledTextField(
          controller: _controller.signupUsernameController,
          hintText: 'Juan Dela Cruz',
        ),
        const SizedBox(height: 16),
        FieldLabel('Email Address:', color: labelColorFor(context)),
        const SizedBox(height: 6),
        StyledTextField(
          controller: _controller.signupEmailController,
          hintText: 'juandelacruz@gmail.com',
        ),
        const SizedBox(height: 16),
        FieldLabel('Password:', color: labelColorFor(context)),
        const SizedBox(height: 6),
        StyledTextField(
          controller: _controller.signupPasswordController,
          hintText: '••••••••',
          obscureText: _controller.obscureSignupPassword,
          suffix: ShowHideButton(
            obscured: _controller.obscureSignupPassword,
            color: labelColorFor(context),
            onTap: _controller.toggleSignupPasswordVisibility,
          ),
        ),
        const SizedBox(height: 16),
        FieldLabel('Confirm Password:', color: labelColorFor(context)),
        const SizedBox(height: 6),
        StyledTextField(
          controller: _controller.signupConfirmPasswordController,
          hintText: '••••••••',
          obscureText: _controller.obscureConfirmPassword,
          suffix: ShowHideButton(
            obscured: _controller.obscureConfirmPassword,
            color: labelColorFor(context),
            onTap: _controller.toggleConfirmPasswordVisibility,
          ),
        ),
        if (!_controller.isLogin && _controller.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _controller.errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _controller.isLoading ? null : _handleSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: maroon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 2,
            ),
            child: _controller.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Sign-up',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}
