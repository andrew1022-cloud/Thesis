import 'package:flutter/material.dart';

import '../controllers/admin_management_controller.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/home_widgets.dart'
    show kMaroon, labelColorFor, primaryTextColor;

/// Popup shown when the "+" FAB on the Admins tab is tapped. Collects
/// email, username, password, and a role, then hands off to
/// [AdminManagementController.addAdmin].
class AddAdminDialog extends StatefulWidget {
  final AdminManagementController controller;

  const AddAdminDialog({super.key, required this.controller});

  @override
  State<AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<AddAdminDialog> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _role = AdminManagementController.availableRoles.first;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    final error = await widget.controller.addAdmin(
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      role: _role,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isSaving = widget.controller.isSaving;

        return Dialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add Admin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor(context),
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(height: 18),

                FieldLabel('Username:', color: labelColorFor(context)),
                const SizedBox(height: 6),
                StyledTextField(
                  controller: _usernameController,
                  hintText: 'Juan Dela Cruz',
                ),
                const SizedBox(height: 14),

                FieldLabel('Email Address:', color: labelColorFor(context)),
                const SizedBox(height: 6),
                StyledTextField(
                  controller: _emailController,
                  hintText: 'juandelacruz@gmail.com',
                ),
                const SizedBox(height: 14),

                FieldLabel('Password:', color: labelColorFor(context)),
                const SizedBox(height: 6),
                StyledTextField(
                  controller: _passwordController,
                  hintText: '••••••••',
                  obscureText: _obscurePassword,
                  suffix: ShowHideButton(
                    obscured: _obscurePassword,
                    color: labelColorFor(context),
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 14),

                FieldLabel('Role:', color: labelColorFor(context)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _role,
                      isExpanded: true,
                      icon: Icon(Icons.expand_more_rounded,
                          color: labelColorFor(context)),
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryTextColor(context),
                      ),
                      dropdownColor: Theme.of(context).cardColor,
                      items: AdminManagementController.availableRoles
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _role = value);
                      },
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed:
                              isSaving ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kMaroon),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: kMaroon,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kMaroon,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 2,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Add',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
