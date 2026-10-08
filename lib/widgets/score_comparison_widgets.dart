import 'package:flutter/material.dart';

import '../services/score_comparison_service.dart';
import 'home_widgets.dart'
    show kMaroon, kGold, primaryTextColor, secondaryTextColor;

class ScoreComparisonCard extends StatelessWidget {
  final ScoreComparison comparison;

  const ScoreComparisonCard({super.key, required this.comparison});

  @override
  Widget build(BuildContext context) {
    final c = comparison;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Score Comparison',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor(context),
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
              if (c.isNewBest)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'New personal best!',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kMaroon,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (c.isFirstAttempt)
            Text(
              'This is your first attempt at this quiz — your score is '
              '${c.currentPercent}%. Retake it later to see how you improve.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: secondaryTextColor(context),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatColumn(
                  label: 'This attempt',
                  percent: c.currentPercent,
                  highlight: true,
                ),
                _StatColumn(
                  label: 'Previous',
                  percent: c.previousPercent!,
                  delta: c.deltaVsPrevious,
                ),
                _StatColumn(
                  label: 'Average',
                  percent: c.averagePercent!,
                  delta: c.deltaVsAverage,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Best earlier score: ${c.bestPercent}% · '
              '${c.previousCount} earlier attempt'
              '${c.previousCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor(context),
              ),
            ),
            const SizedBox(height: 16),
            _AttemptBars(percents: c.recentPercents),
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final int percent;
  final int? delta;
  final bool highlight;

  const _StatColumn({
    required this.label,
    required this.percent,
    this.delta,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: highlight ? kMaroon : primaryTextColor(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: secondaryTextColor(context),
            ),
          ),
          const SizedBox(height: 6),
          if (delta != null)
            _DeltaChip(delta: delta!)
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final int delta;
  const _DeltaChip({required this.delta});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    if (delta > 0) {
      color = Colors.green;
      icon = Icons.arrow_drop_up_rounded;
    } else if (delta < 0) {
      color = Colors.red;
      icon = Icons.arrow_drop_down_rounded;
    } else {
      color = Colors.grey;
      icon = Icons.remove_rounded;
    }

    return Container(
      padding: const EdgeInsets.only(left: 2, right: 8, top: 1, bottom: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          Text(
            delta == 0 ? 'same' : '${delta.abs()} pts',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bars for the last few attempts; the final (current) bar is gold.
class _AttemptBars extends StatelessWidget {
  final List<int> percents; // oldest → newest

  const _AttemptBars({required this.percents});

  @override
  Widget build(BuildContext context) {
    const maxBarHeight = 80.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent attempts',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: primaryTextColor(context),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: maxBarHeight + 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < percents.length; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${percents[i]}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: i == percents.length - 1
                              ? kMaroon
                              : secondaryTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 22,
                        height: (percents[i].clamp(0, 100) / 100 *
                                maxBarHeight)
                            .clamp(3.0, maxBarHeight),
                        decoration: BoxDecoration(
                          color: i == percents.length - 1
                              ? kGold
                              : kMaroon.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        i == percents.length - 1 ? 'Now' : '#${i + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: secondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
