import 'package:flutter/material.dart';

import '../controllers/profile_controller.dart';
import 'home_widgets.dart'
    show kMaroon, kGold, kLabelBlue, kCream, labelColorFor, primaryTextColor, secondaryTextColor;

// ── User info row (avatar + username + email) ─────────────────────────────────

class UserInfoRow extends StatelessWidget {
  final String username;
  final String email;

  const UserInfoRow({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: kMaroon,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoLine(label: 'Username:', value: username),
            const SizedBox(height: 4),
            _InfoLine(label: 'Email:', value: email),
          ],
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: primaryTextColor(context),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: secondaryTextColor(context),
          ),
        ),
      ],
    );
  }
}

// ── User Ledger card (maroon, points + badges) ────────────────────────────────
// Always sits on a maroon background by design, so its inner colors
// (gold/white) stay brand-constant across light and dark theme.

class UserLedgerCard extends StatelessWidget {
  final int points;
  final List<UserBadge> badges;

  const UserLedgerCard({
    super.key,
    required this.points,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: kMaroon,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'User Ledger',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kGold,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 14),

          // Points row
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Points: ',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: '$points',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Badges label
          const Text(
            'Badges:',
            style: TextStyle(
              color: kGold,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          // Badge grid
          badges.isEmpty
              ? const Text(
                  'No badges earned yet.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                )
              : _BadgeGrid(badges: badges),
        ],
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  final List<UserBadge> badges;

  const _BadgeGrid({required this.badges});

  @override
  Widget build(BuildContext context) {
    // 3 columns, auto-wrapping
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: badges.map((b) => _BadgeItem(badge: b)).toList(),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final UserBadge badge;

  const _BadgeItem({required this.badge});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BadgeIcon(assetPath: badge.assetPath, label: badge.label),
          const SizedBox(height: 6),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final String? assetPath;
  final String label;

  const _BadgeIcon({this.assetPath, required this.label});

  /// Picks a fallback icon based on known badge labels.
  IconData _fallbackIcon() {
    final l = label.toLowerCase();
    if (l.contains('profed') || l.contains('professional')) {
      return Icons.school_rounded;
    } else if (l.contains('spec') || l.contains('specializ')) {
      return Icons.star_rounded;
    } else if (l.contains('anim')) {
      return Icons.movie_creation_rounded;
    } else if (l.contains('gen') || l.contains('gened')) {
      return Icons.menu_book_rounded;
    } else if (l.contains('rizal')) {
      return Icons.history_edu_rounded;
    } else if (l.contains('teacher')) {
      return Icons.person_pin_rounded;
    }
    return Icons.military_tech_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (assetPath != null && assetPath!.isNotEmpty) {
      return ClipOval(
        child: Image.asset(
          assetPath!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultCircle(),
        ),
      );
    }
    return _defaultCircle();
  }

  Widget _defaultCircle() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 2),
      ),
      child: Icon(_fallbackIcon(), color: kGold, size: 28),
    );
  }
}

// ── Menu buttons ──────────────────────────────────────────────────────────

/// The plain "Account" row: filled maroon icon circle + bold label.
class AccountRow extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const AccountRow({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: kMaroon,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: labelColorFor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bordered pill-shaped menu button.
class ProfileMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ProfileMenuButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: kMaroon, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kMaroon, width: 1.4),
                ),
                child: Icon(icon, color: kMaroon, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: labelColorFor(context),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
