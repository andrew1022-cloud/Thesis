import 'package:flutter/material.dart';

import 'home_widgets.dart' show kMaroon, kGold, primaryTextColor, secondaryTextColor;

/// One A/B/C/D option row inside a quiz question. Behaves two ways:
/// - Before submit: tappable, highlighted maroon when selected.
/// - After submit: locked, shows green on the correct answer and red
///   on a wrong pick (if the user picked wrong).
class QuizOptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool isSelected;
  final bool isSubmitted;
  final bool isCorrectAnswer;
  final VoidCallback? onTap;

  const QuizOptionTile({
    super.key,
    required this.letter,
    required this.text,
    required this.isSelected,
    required this.isSubmitted,
    required this.isCorrectAnswer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Theme.of(context).dividerColor;
    Color? fillColor;
    Color textColor = primaryTextColor(context);
    IconData? trailingIcon;
    Color? trailingColor;

    if (isSubmitted) {
      if (isCorrectAnswer) {
        borderColor = Colors.green;
        fillColor = Colors.green.withOpacity(0.08);
        trailingIcon = Icons.check_circle;
        trailingColor = Colors.green;
      } else if (isSelected) {
        borderColor = Colors.red;
        fillColor = Colors.red.withOpacity(0.08);
        trailingIcon = Icons.cancel;
        trailingColor = Colors.red;
      }
    } else if (isSelected) {
      borderColor = kMaroon;
      fillColor = kMaroon.withOpacity(0.08);
      textColor = kMaroon;
    }

    return Material(
      color: fillColor ?? Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isSubmitted ? null : onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isSelected || (isSubmitted && isCorrectAnswer) ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected && !isSubmitted
                      ? kMaroon
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected && !isSubmitted
                        ? kMaroon
                        : Colors.grey.shade400,
                  ),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected && !isSubmitted
                        ? Colors.white
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, color: trailingColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Question x of y" progress label shown above each question.
class QuizProgressLabel extends StatelessWidget {
  final int currentIndex; // 0-based
  final int total;

  const QuizProgressLabel({
    super.key,
    required this.currentIndex,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Question ${currentIndex + 1} of $total',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: secondaryTextColor(context),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 100,
            height: 6,
            child: LinearProgressIndicator(
              value: (currentIndex + 1) / total,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation(kGold),
            ),
          ),
        ),
      ],
    );
  }
}

/// The maroon score card shown after submitting a quiz.
class QuizResultSummaryCard extends StatelessWidget {
  final int score;
  final int total;
  final bool passed;

  const QuizResultSummaryCard({
    super.key,
    required this.score,
    required this.total,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : ((score / total) * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: kMaroon,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
            color: kGold,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            passed ? 'Nice work!' : 'Keep practicing!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$score / $total correct ($percent%)',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
