import 'package:flutter/material.dart';

import '../services/weak_area_quest_db.dart';
import 'home_widgets.dart'
    show kMaroon, kGold, primaryTextColor, secondaryTextColor;

/// One weak-area quest row on Home: the competency, why it was picked,
/// and the (small) reward. Tapping it opens that competency's lesson.
class WeakAreaQuestCard extends StatelessWidget {
  final WeakAreaQuest quest;
  final VoidCallback? onTap;

  const WeakAreaQuestCard({super.key, required this.quest, this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = quest.completedThisWeek;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: done ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done ? Colors.green.withOpacity(0.5) : kGold,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (done ? Colors.green : kGold).withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.flag_rounded,
                  color: done ? Colors.green : kMaroon,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.lessonTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done
                          ? 'Completed this week'
                          : 'Average ${quest.avgPercent}% · score '
                              '$kWeakAreaTargetPercent% or higher',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kMaroon.withOpacity(done ? 0.35 : 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+$kWeakAreaQuestPoints pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
