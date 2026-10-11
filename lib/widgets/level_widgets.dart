import 'package:flutter/material.dart';

import '../data/level_data.dart';
import 'home_widgets.dart' show kMaroon, kGold;

/// Small pill: "Lv. 3 · Competent Reviewee".
/// Set [onMaroon] when placing it on a maroon card.
class LevelBadge extends StatelessWidget {
  final UserLevel level;
  final bool onMaroon;

  const LevelBadge({super.key, required this.level, this.onMaroon = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fill;
    final Color text;
    if (onMaroon) {
      fill = kGold;
      text = kMaroon;
    } else {
      fill = kGold.withOpacity(0.2);
      text = isDark ? kGold : kMaroon;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Lv. ${level.number} · ${level.title}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }
}

/// Progress toward the next level, for use on a maroon card.
class LevelProgressBar extends StatelessWidget {
  final int points;

  const LevelProgressBar({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final current = levelForPoints(points);
    final next = nextLevelAfter(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: levelProgress(points),
            minHeight: 6,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(kGold),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          next == null
              ? 'Highest level reached 🎉'
              : '${next.minPoints - points} pts to ${next.title}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
