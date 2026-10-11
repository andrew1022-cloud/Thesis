import 'package:flutter/material.dart';

import 'level_data.dart';

/// Everything that unlocks automatically as a user's level goes up.
/// Edit `requiredLevel`s / colors / icons here — nothing else needs to
/// change. Levels come from level_data.dart (based on total points,
/// which never go down, so an unlock is never lost).

enum UnlockableType { frame, flair }

class Unlockable {
  final String id;
  final String name;
  final UnlockableType type;
  final int requiredLevel;

  /// Frames: ring colors. Empty = no ring, one = solid, two or more =
  /// a gradient ring.
  final List<Color> colors;

  /// Flair: the little icon shown next to the level badge. Null = none.
  final IconData? icon;

  const Unlockable({
    required this.id,
    required this.name,
    required this.type,
    required this.requiredLevel,
    this.colors = const [],
    this.icon,
  });
}

// ── Avatar frames ─────────────────────────────────────────────────

const List<Unlockable> kFrames = [
  Unlockable(
    id: 'frame_plain',
    name: 'Plain',
    type: UnlockableType.frame,
    requiredLevel: 1,
  ),
  Unlockable(
    id: 'frame_bronze',
    name: 'Bronze',
    type: UnlockableType.frame,
    requiredLevel: 2,
    colors: [Color(0xFFCD7F32)],
  ),
  Unlockable(
    id: 'frame_silver',
    name: 'Silver',
    type: UnlockableType.frame,
    requiredLevel: 3,
    colors: [Color(0xFFB8BEC6)],
  ),
  Unlockable(
    id: 'frame_gold',
    name: 'Gold',
    type: UnlockableType.frame,
    requiredLevel: 4,
    colors: [Color(0xFFC9A24B)],
  ),
  Unlockable(
    id: 'frame_emerald',
    name: 'Emerald',
    type: UnlockableType.frame,
    requiredLevel: 5,
    colors: [Color(0xFF2F6F4F), Color(0xFF58C089)],
  ),
  Unlockable(
    id: 'frame_royal',
    name: 'Royal Blue',
    type: UnlockableType.frame,
    requiredLevel: 6,
    colors: [Color(0xFF1F3A5F), Color(0xFF5B8DEF)],
  ),
  Unlockable(
    id: 'frame_rose',
    name: 'Rose',
    type: UnlockableType.frame,
    requiredLevel: 7,
    colors: [Color(0xFF6E1B24), Color(0xFFE0566B)],
  ),
  Unlockable(
    id: 'frame_platinum',
    name: 'Platinum',
    type: UnlockableType.frame,
    requiredLevel: 8,
    colors: [Color(0xFFE5E4E2), Color(0xFF9DB6DE), Color(0xFFE5E4E2)],
  ),
  Unlockable(
    id: 'frame_board_ready',
    name: 'Board-Ready',
    type: UnlockableType.frame,
    requiredLevel: 9,
    colors: [
      Color(0xFFC9A24B),
      Color(0xFF6E1B24),
      Color(0xFFF1D98A),
      Color(0xFF6E1B24),
    ],
  ),
];

// ── Flair (icon beside the level badge) ───────────────────────────

const List<Unlockable> kFlairs = [
  Unlockable(
    id: 'flair_none',
    name: 'None',
    type: UnlockableType.flair,
    requiredLevel: 1,
  ),
  Unlockable(
    id: 'flair_bookworm',
    name: 'Bookworm',
    type: UnlockableType.flair,
    requiredLevel: 2,
    icon: Icons.menu_book_rounded,
  ),
  Unlockable(
    id: 'flair_sharp_mind',
    name: 'Sharp Mind',
    type: UnlockableType.flair,
    requiredLevel: 3,
    icon: Icons.lightbulb_rounded,
  ),
  Unlockable(
    id: 'flair_on_fire',
    name: 'On Fire',
    type: UnlockableType.flair,
    requiredLevel: 4,
    icon: Icons.local_fire_department_rounded,
  ),
  Unlockable(
    id: 'flair_rising_star',
    name: 'Rising Star',
    type: UnlockableType.flair,
    requiredLevel: 5,
    icon: Icons.star_rounded,
  ),
  Unlockable(
    id: 'flair_scholar',
    name: 'Scholar',
    type: UnlockableType.flair,
    requiredLevel: 6,
    icon: Icons.school_rounded,
  ),
  Unlockable(
    id: 'flair_champion',
    name: 'Champion',
    type: UnlockableType.flair,
    requiredLevel: 7,
    icon: Icons.emoji_events_rounded,
  ),
  Unlockable(
    id: 'flair_diamond',
    name: 'Diamond',
    type: UnlockableType.flair,
    requiredLevel: 8,
    icon: Icons.diamond_rounded,
  ),
  Unlockable(
    id: 'flair_crown',
    name: 'Crown',
    type: UnlockableType.flair,
    requiredLevel: 9,
    icon: Icons.workspace_premium_rounded,
  ),
];

Unlockable? unlockableById(String? id) {
  if (id == null) return null;
  for (final u in [...kFrames, ...kFlairs]) {
    if (u.id == id) return u;
  }
  return null;
}

/// Everything (frames + flair) that unlocks exactly at [level].
List<Unlockable> unlocksAtLevel(int level) => [
      for (final u in [...kFrames, ...kFlairs])
        if (u.requiredLevel == level) u,
    ];

// ── Streak freeze ─────────────────────────────────────────────────
//
// From Level 3, a missed day no longer breaks the day streak: each
// calendar week (Mon–Sun) forgives [streakFreezesPerWeek] missed days.
// Nothing is stored or "used up" by hand — the streak calculation in
// streak_freeze_db.dart applies it automatically.

int streakFreezesPerWeek(int level) {
  if (level >= 6) return 2;
  if (level >= 3) return 1;
  return 0;
}

/// The next level above [level] that gives MORE freezes per week, or
/// null if the user already has the maximum.
int? nextStreakFreezeLevel(int level) {
  final current = streakFreezesPerWeek(level);
  for (var n = level + 1; n <= kLevels.length; n++) {
    if (streakFreezesPerWeek(n) > current) return n;
  }
  return null;
}
