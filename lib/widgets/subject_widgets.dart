import 'package:flutter/material.dart';

import 'home_widgets.dart'
    show
        kMaroon,
        kLabelBlue,
        ThinProgressBar,
        primaryTextColor,
        secondaryTextColor;

/// One subject row under a category header: code badge, subject
/// name, "x out of y Competencies", and a thin progress bar.
class SubjectCompetencyRow extends StatelessWidget {
  final String code;
  final String name;
  final int completedCount;
  final int totalCount;
  final int progressPercent;
  final Color color;
  final VoidCallback? onTap;

  const SubjectCompetencyRow({
    super.key,
    required this.code,
    required this.name,
    required this.completedCount,
    required this.totalCount,
    required this.progressPercent,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final competencyLabel = totalCount == 1
        ? '$completedCount out of $totalCount Competency'
        : '$completedCount out of $totalCount Competencies';

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color,
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
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
                    const SizedBox(height: 3),
                    Text(
                      competencyLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor(context),
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

/// Section header used above each category's subject list.
class SubjectSectionTitle extends StatelessWidget {
  final String title;

  const SubjectSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: primaryTextColor(context),
          fontFamily: 'Georgia',
        ),
      ),
    );
  }
}

/// The thin horizontal rule shown above each exam action button.
class ActionDivider extends StatelessWidget {
  const ActionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(color: Theme.of(context).dividerColor, height: 1),
    );
  }
}

/// The maroon "Take a Subject Exam" / "Take a Mock Exam" button.
class ExamActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const ExamActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kMaroon,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 2,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// The colored subject-info card at the top of the Subject Detail
/// screen: code badge, category label, subject name, progress bar,
/// and a "x/y Done" label.
class SubjectDetailHeaderCard extends StatelessWidget {
  final String code;
  final String categoryLabel;
  final String subjectName;
  final int completedCount;
  final int totalCount;
  final int progressPercent;
  final Color color;

  const SubjectDetailHeaderCard({
    super.key,
    required this.code,
    required this.categoryLabel,
    required this.subjectName,
    required this.completedCount,
    required this.totalCount,
    required this.progressPercent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subjectName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 6,
                            width: constraints.maxWidth,
                            color: Colors.white24,
                          ),
                          Container(
                            height: 6,
                            width: constraints.maxWidth *
                                (totalCount == 0
                                    ? 0
                                    : progressPercent.clamp(0, 100) / 100),
                            color: Colors.white,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completedCount/$totalCount Done',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One lesson row inside the Subject Detail screen: a filled circle
/// with a check mark if the lesson is completed (outline if not),
/// the lesson title, and an estimated "x mins read" caption.
class LessonProgressRow extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final int estimatedMinutes;
  final VoidCallback? onTap;

  const LessonProgressRow({
    super.key,
    required this.title,
    required this.isCompleted,
    required this.estimatedMinutes,
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
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? kLabelBlue : Colors.transparent,
                  border: Border.all(
                    color: isCompleted ? kLabelBlue : Colors.grey.shade400,
                    width: 1.6,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: primaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$estimatedMinutes mins read',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor(context),
                      ),
                    ),
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
