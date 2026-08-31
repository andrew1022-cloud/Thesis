import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color kMaroon = Color(0xFF6E1B24);
const Color kCream = Color(0xFFF5EDE3);
const Color kGold = Color(0xFFC9A24B);
const Color kLabelBlue = Color(0xFF1F3A5F);

/// Default per-subject accent colors, keyed by subject code, used
/// when a subject document doesn't specify its own colorHex.
const Map<String, Color> kSubjectFallbackColors = {
  'GE': Color(0xFF3E5C76), // slate blue
  'PE': Color(0xFF2F6F4F), // forest green
  'SP': Color(0xFFC8860D), // amber / gold
};

Color subjectColorFor(String? code, String? hex) {
  if (hex != null && hex.isNotEmpty) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      // fall through to the default palette
    }
  }
  return kSubjectFallbackColors[code] ?? kLabelBlue;
}

/// Theme-aware "label blue" — the default blue reads poorly on a
/// near-black card, so lighten it in dark mode.
Color labelColorFor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF9DB6DE)
      : kLabelBlue;
}

/// Primary body text color that follows the current theme.
Color primaryTextColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

/// Secondary / muted text color that follows the current theme.
Color secondaryTextColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white60
        : Colors.grey.shade600;

/// Card / surface background color that follows the current theme.
Color surfaceColor(BuildContext context) => Theme.of(context).cardColor;

/// Donut-style progress ring: "60% Completed" inside a circular track.
class ProgressRing extends StatelessWidget {
  final int percent; // 0-100
  final double size;
  final Color trackColor;
  final Color progressColor;
  final Color centerColor;
  final Color textColor;

  const ProgressRing({
    super.key,
    required this.percent,
    this.size = 100,
    this.trackColor = Colors.white24,
    this.progressColor = kGold,
    this.centerColor = kCream,
    this.textColor = kMaroon,
  });

  @override
  Widget build(BuildContext context) {
    // ProgressRing is always placed on a maroon card by design, so its
    // center/text stay brand-constant (cream/maroon) rather than
    // following light/dark theme — otherwise it loses contrast in dark
    // mode against the (theme-independent) maroon card behind it.
    final resolvedCenter = centerColor;
    final resolvedText = textColor;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          percent: percent.clamp(0, 100),
          trackColor: trackColor,
          progressColor: progressColor,
        ),
        child: Center(
          child: Container(
            width: size * 0.66,
            height: size * 0.66,
            decoration: BoxDecoration(
              color: resolvedCenter,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: size * 0.19,
                      fontWeight: FontWeight.w900,
                      color: resolvedText,
                    ),
                  ),
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: size * 0.09,
                      fontWeight: FontWeight.w600,
                      color: resolvedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int percent;
  final Color trackColor;
  final Color progressColor;

  _RingPainter({
    required this.percent,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.14;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * math.pi * (percent / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

/// One of the three small stat tiles (Day Streak / Lessons Done / Average Score).
class StatTile extends StatelessWidget {
  final String value;
  final String label;

  const StatTile({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin rounded progress bar used under subject rows.
class ThinProgressBar extends StatelessWidget {
  final int percent;
  final Color color;

  const ThinProgressBar({
    super.key,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(
                height: 6,
                width: constraints.maxWidth,
                color: color.withOpacity(0.15),
              ),
              Container(
                height: 6,
                width: constraints.maxWidth * (percent.clamp(0, 100) / 100),
                color: color,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One row in the "Continue by Subject" list.
class SubjectContinueCard extends StatelessWidget {
  final String code;
  final String name;
  final String? lessonTitle;
  final int progressPercent;
  final Color color;
  final VoidCallback? onTap;

  const SubjectContinueCard({
    super.key,
    required this.code,
    required this.name,
    required this.lessonTitle,
    required this.progressPercent,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color,
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: primaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lessonTitle ?? 'Not started yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ThinProgressBar(percent: progressPercent, color: color),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bottom "Do you wish to continue?" call-to-action card.
class ContinuePromptCard extends StatelessWidget {
  final String subjectLabel; // e.g. "Majorship - Animation"
  final int progressPercent;
  final VoidCallback? onTap;

  const ContinuePromptCard({
    super.key,
    required this.subjectLabel,
    required this.progressPercent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Do you wish to continue?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor(context),
                      ),
                    ),
                  ),
                  Text(
                    '$progressPercent%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subjectLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kMaroon,
                ),
              ),
              const SizedBox(height: 10),
              ThinProgressBar(percent: progressPercent, color: kGold),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static bottom navigation bar. Only Home is wired up for now — the
/// other tabs are shown but disabled until those screens exist.
class HomeBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const HomeBottomNavBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (_NavItem(Icons.home_rounded, 'Home')),
      (_NavItem(Icons.menu_book_rounded, 'Subjects')),
      (_NavItem(Icons.bar_chart_rounded, 'Analytics')),
      (_NavItem(Icons.person_outline_rounded, 'Profile')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final selected = index == currentIndex;
          final item = items[index];
          final color = selected
              ? kMaroon
              : (isDark ? Colors.white38 : Colors.grey.shade400);

          return InkWell(
            onTap: onTap == null ? null : () => onTap!(index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, color: color, size: 24),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
