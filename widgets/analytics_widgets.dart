import 'package:flutter/material.dart';

import 'home_widgets.dart' show ProgressRing, kGold, kCream, kMaroon;

/// A small progress ring with a label underneath it, used for the
/// three per-category rings (General/Professional/Specialization).
class LabeledMiniProgressRing extends StatelessWidget {
  final int percent;
  final String label;

  const LabeledMiniProgressRing({
    super.key,
    required this.percent,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressRing(
          percent: percent,
          size: 76,
          trackColor: Colors.white24,
          progressColor: kGold,
          centerColor: kCream,
          textColor: kMaroon,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// One bullet row in the Strongest/Weakest Competency lists:
/// "Lesson Title - Category", colored by category.
class CompetencyBulletRow extends StatelessWidget {
  final String lessonTitle;
  final String categoryLabel;
  final Color color;

  const CompetencyBulletRow({
    super.key,
    required this.lessonTitle,
    required this.categoryLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: lessonTitle,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: ' - $categoryLabel',
                    style: TextStyle(
                      color: color.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One ranked row inside the leaderboard card.
class LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final int points;
  final bool highlighted;

  const LeaderboardRow({
    super.key,
    required this.rank,
    required this.name,
    required this.points,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = highlighted ? kMaroon : kGold;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? kGold : Colors.transparent,
        borderRadius:
            highlighted ? BorderRadius.circular(10) : BorderRadius.zero,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            '${points}pts',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// The maroon "Leaderboard" card: top-N ranked rows plus a
/// gold-highlighted row for the current user's own rank/points,
/// shown even when they're outside the top N.
class LeaderboardCard extends StatelessWidget {
  final List<LeaderboardRow> topRows;
  final LeaderboardRow? currentUserRow;

  const LeaderboardCard({
    super.key,
    required this.topRows,
    this.currentUserRow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: kMaroon,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (final row in topRows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: row,
            ),
          if (currentUserRow != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: currentUserRow,
            ),
          ],
        ],
      ),
    );
  }
}
