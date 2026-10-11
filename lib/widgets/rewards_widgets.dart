import 'package:flutter/material.dart';

import '../data/level_data.dart';
import '../data/unlockable_data.dart';
import 'home_widgets.dart'
    show kMaroon, kGold, primaryTextColor, secondaryTextColor;

/// The maroon person avatar, optionally wrapped in an unlocked frame.
/// [size] is the avatar itself; the ring is drawn around it.
class FramedAvatar extends StatelessWidget {
  final double size;
  final Unlockable? frame;

  const FramedAvatar({super.key, this.size = 56, this.frame});

  @override
  Widget build(BuildContext context) {
    final colors = frame?.colors ?? const <Color>[];
    final ring = colors.isEmpty ? 0.0 : 4.0;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kMaroon,
        shape: BoxShape.circle,
        border: colors.isEmpty
            ? null
            : Border.all(color: Theme.of(context).cardColor, width: 2),
      ),
      child: Icon(Icons.person, color: Colors.white, size: size * 0.54),
    );

    if (colors.isEmpty) return avatar;

    return Container(
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.length == 1 ? colors.first : null,
        gradient: colors.length > 1
            ? SweepGradient(colors: [...colors, colors.first])
            : null,
      ),
      child: avatar,
    );
  }
}

/// Small gold circle with the equipped flair icon.
class FlairIcon extends StatelessWidget {
  final Unlockable flair;
  final double size;

  const FlairIcon({super.key, required this.flair, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final icon = flair.icon;
    if (icon == null) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kGold.withOpacity(0.2),
        border: Border.all(color: kGold, width: 1.2),
      ),
      child: Icon(icon, color: kGold, size: size * 0.62),
    );
  }
}

/// One selectable frame / flair in the Rewards screen. Locked items
/// are dimmed and show the level needed.
class UnlockableTile extends StatelessWidget {
  final Unlockable item;
  final bool unlocked;
  final bool equipped;
  final VoidCallback onTap;

  const UnlockableTile({
    super.key,
    required this.item,
    required this.unlocked,
    required this.equipped,
    required this.onTap,
  });

  Widget _preview() {
    if (item.type == UnlockableType.frame) {
      return FramedAvatar(size: 40, frame: item);
    }
    if (item.icon == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Icon(Icons.block_rounded, color: Colors.grey.shade500, size: 20),
      );
    }
    return FlairIcon(flair: item, size: 40);
  }

  @override
  Widget build(BuildContext context) {
    final level = kLevels[(item.requiredLevel - 1).clamp(0, kLevels.length - 1)];

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: unlocked ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: equipped ? kMaroon : Theme.of(context).dividerColor,
              width: equipped ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 52,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _preview(),
                      if (!unlocked)
                        const Positioned(
                          right: -4,
                          bottom: -4,
                          child: Icon(Icons.lock_rounded,
                              size: 16, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                equipped
                    ? 'Equipped'
                    : (unlocked ? 'Tap to equip' : 'Lv. ${level.number}'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: equipped ? kMaroon : secondaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains the streak-freeze perk and how close the user is to the
/// next tier.
class StreakFreezeCard extends StatelessWidget {
  final int level;

  const StreakFreezeCard({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final perWeek = streakFreezesPerWeek(level);
    final nextLevelNumber = nextStreakFreezeLevel(level);
    final nextLevel = nextLevelNumber == null
        ? null
        : kLevels[nextLevelNumber - 1];

    final String headline;
    final String detail;
    if (perWeek == 0) {
      headline = 'Streak Freeze — locked';
      detail = nextLevel == null
          ? ''
          : 'Reach Lv. ${nextLevel.number} (${nextLevel.title}) to forgive '
              '${streakFreezesPerWeek(nextLevel.number)} missed day per week.';
    } else {
      headline = 'Streak Freeze — active';
      detail = '$perWeek missed day${perWeek == 1 ? '' : 's'} per week won\'t '
          'break your day streak.'
          '${nextLevel == null ? '' : ' Reach Lv. ${nextLevel.number} for '
              '${streakFreezesPerWeek(nextLevel.number)} per week.'}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: perWeek == 0
                  ? Colors.grey.withOpacity(0.15)
                  : const Color(0xFF3E5C76).withOpacity(0.18),
            ),
            child: Icon(
              Icons.ac_unit_rounded,
              color: perWeek == 0 ? Colors.grey : const Color(0xFF5B8DEF),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor(context),
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: secondaryTextColor(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
