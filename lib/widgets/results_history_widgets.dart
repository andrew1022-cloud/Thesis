import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/results_history_controller.dart';
import 'home_widgets.dart'
    show kMaroon, kGold, primaryTextColor, secondaryTextColor, subjectColorFor;

/// Maroon card: attempts / best / average for the current filter.
class ResultsSummaryCard extends StatelessWidget {
  final int attempts;
  final int bestPercent;
  final int averagePercent;

  const ResultsSummaryCard({
    super.key,
    required this.attempts,
    required this.bestPercent,
    required this.averagePercent,
  });

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: kGold, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: kMaroon,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _stat('$attempts', 'Attempts'),
          _stat('$bestPercent%', 'Best Score'),
          _stat('$averagePercent%', 'Average Score'),
        ],
      ),
    );
  }
}

/// All / Competency / Subject filter chips.
class HistoryFilterChips extends StatelessWidget {
  final HistoryFilter selected;
  final ValueChanged<HistoryFilter> onSelect;

  const HistoryFilterChips({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const labels = {
      HistoryFilter.all: 'All',
      HistoryFilter.competency: 'Competency Quizzes',
      HistoryFilter.subject: 'Subject Quizzes',
    };
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in HistoryFilter.values) ...[
            GestureDetector(
              onTap: () => onSelect(f),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected == f ? kMaroon : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected == f
                        ? kMaroon
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Text(
                  labels[f]!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected == f
                        ? Colors.white
                        : primaryTextColor(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// One past attempt: title, subject, date, score and pass/fail pill.
class AttemptCard extends StatelessWidget {
  final AttemptItem attempt;

  const AttemptCard({super.key, required this.attempt});

  @override
  Widget build(BuildContext context) {
    final color = subjectColorFor(attempt.subjectCode, null);
    final resultColor = attempt.passed ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: resultColor, width: 2.4),
            ),
            child: Text(
              '${attempt.percent}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: resultColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attempt.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: primaryTextColor(context),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                if (!attempt.isSubjectQuiz)
                  Text(
                    attempt.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill(
                      text: attempt.isSubjectQuiz ? 'Subject Quiz' : 'Competency',
                      color: kMaroon,
                    ),
                    _Pill(
                      text: attempt.passed ? 'Passed' : 'Retake',
                      color: resultColor,
                    ),
                    Text(
                      '${attempt.score}/${attempt.totalItems} correct',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('MMM d, yyyy · h:mm a').format(attempt.dateTaken),
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
