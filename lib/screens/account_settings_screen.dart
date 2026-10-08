import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/account_controller.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/profile_widgets.dart' show UserInfoRow;
import '../widgets/settings_widgets.dart';

/// Lets the signed-in user change their username and password.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final AccountController _controller = AccountController();

  final _usernameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _usernameError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _controller.load().then((_) {
      if (mounted) _usernameController.text = _controller.username;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveUsername() async {
    FocusScope.of(context).unfocus();
    setState(() => _usernameError = null);

    final error = await _controller.updateUsername(_usernameController.text);
    if (!mounted) return;

    if (error != null) {
      setState(() => _usernameError = error);
    } else {
      _snack('Username updated.');
    }
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    setState(() => _passwordError = null);

    final error = await _controller.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    if (!mounted) return;

    if (error != null) {
      setState(() => _passwordError = error);
    } else {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _snack('Password changed.');
    }
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
                const SubScreenHeader(
                  title: 'Account Settings',
                  icon: Icons.person_outline_rounded,
                ),
                Expanded(
                  child: _controller.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: kMaroon))
                      : _buildBody(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserInfoRow(
            username: _controller.username,
            email: _controller.email,
          ),
          const SizedBox(height: 24),
          _buildUsernameCard(),
          const SizedBox(height: 20),
          _buildPasswordCard(),
        ],
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required bool busy,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kMaroon,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 2,
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _error(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  Widget _buildUsernameCard() {
    return _card(
      title: 'Username',
      children: [
        FieldLabel('Username:', color: labelColorFor(context)),
        const SizedBox(height: 6),
        StyledTextField(
          controller: _usernameController,
          hintText: 'Juan Dela Cruz',
        ),
        _error(_usernameError),
        const SizedBox(height: 16),
        _primaryButton(
          label: 'Save Username',
          busy: _controller.isSavingUsername,
          onPressed: _saveUsername,
        ),
      ],
    );
  }

  Widget _buildPasswordCard() {
    if (!_controller.canChangePassword) {
      return _card(
        title: 'Password',
        children: [
          Text(
            'You signed in with Google, so your password is managed by '
            'your Google account.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: secondaryTextColor(context),
            ),
          ),
        ],
      );
    }

    return _card(
      title: 'Change Password',
      children: [
        FieldLabel('Current Password:', color: labelColorFor(context)),
        const SizedBox(height: 6),
        StyledTextField(
          controller: _currentPasswordController,
          hintText: '••••••••',
          obscureText: _obscureCurrent,
          suffix: ShowHideButton(
            obscured: _obscureCurrent,
            color: labelColorFor(context),
            onTap: () => setState(() => _obscureCurrent = !_obscureCurrent),
          ),
        ),
        const SizedBox(height: 14),
        FieldLabel('New Password:', color: labelColorFor(context)),
        const SizedBox(height: 6),
        StyledTextField(
          controller: _newPasswordController,
          hintText: '••••••••',
          obscureText: _obscureNew,
          suffix: ShowHideButton(
            obscured: _obscureNew,
            color: labelColorFor(context),
            onTap: () => setState(() => _obscureNew = !_obscureNew),
          ),
        ),
        const SizedBox(height: 14),
        FieldLabel('Confirm New Password:', color: labelColorFor(context)),
        const SizedBox(height: 6),
        StyledTextField(
          controller: _confirmPasswordController,
          hintText: '••••••••',
          obscureText: _obscureConfirm,
          suffix: ShowHideButton(
            obscured: _obscureConfirm,
            color: labelColorFor(context),
            onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        _error(_passwordError),
        const SizedBox(height: 16),
        _primaryButton(
          label: 'Update Password',
          busy: _controller.isSavingPassword,
          onPressed: _changePassword,
        ),
      ],
    );
  }
}
