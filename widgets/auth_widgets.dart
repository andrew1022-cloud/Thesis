import 'package:flutter/material.dart';

/// Circular logo badge shown at the top of the auth screen.
/// Displays the real RevEduc gear-and-book logo from assets.
class Logo extends StatelessWidget {
  final Color maroon;
  final Color gold;
  final Color cream;

  const Logo({
    super.key,
    required this.maroon,
    required this.gold,
    required this.cream,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/logo.png',
        width: 100,
        height: 100,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// A single pill button used inside the Log-in / Sign-up toggle.
class ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const ToggleButton({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedColor = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : unselectedColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Label shown above a text field.
class FieldLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const FieldLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// "Show" / "Hide" text button used inside password fields.
class ShowHideButton extends StatelessWidget {
  final bool obscured;
  final Color color;
  final VoidCallback onTap;

  const ShowHideButton({
    super.key,
    required this.obscured,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        obscured ? 'Show' : 'Hide',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Rounded, bordered text field used throughout the form.
class StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Widget? suffix;

  const StyledTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey.shade500,
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
