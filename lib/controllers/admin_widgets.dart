import 'package:flutter/material.dart';

import 'home_widgets.dart'
    show
        kMaroon,
        kSubjectFallbackColors,
        ThinProgressBar,
        primaryTextColor,
        secondaryTextColor;

/// One of the three top stat cards (Registered Users / Average
/// Preparedness / Completed Users). Bordered rather than shadowed,
/// to match the admin mockup.
class AdminStatCard extends StatelessWidget {
  final String value;
  final String label;

  const AdminStatCard({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// One "GenEd / ProfEd / Specialization" row inside a user card:
/// fixed-width label, a thin progress bar, and a percentage on the
/// right.
class AdminCategoryProgressRow extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;

  const AdminCategoryProgressRow({
    super.key,
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor(context),
              ),
            ),
          ),
          Expanded(child: ThinProgressBar(percent: percent, color: color)),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One card in the "All Users" list: name, email, the three category
/// progress rows, and a footer with last-active time + overall
/// completion percentage.
class AdminUserCard extends StatelessWidget {
  final String name;
  final String email;
  final int genEdPercent;
  final int profEdPercent;
  final int specializationPercent;
  final int overallPercent;
  final String lastActiveLabel;
  final VoidCallback? onTap;

  const AdminUserCard({
    super.key,
    required this.name,
    required this.email,
    required this.genEdPercent,
    required this.profEdPercent,
    required this.specializationPercent,
    required this.overallPercent,
    required this.lastActiveLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 14),
              AdminCategoryProgressRow(
                label: 'GenEd',
                percent: genEdPercent,
                color: kSubjectFallbackColors['GE']!,
              ),
              AdminCategoryProgressRow(
                label: 'ProfEd',
                percent: profEdPercent,
                color: kSubjectFallbackColors['PE']!,
              ),
              AdminCategoryProgressRow(
                label: 'Specialization',
                percent: specializationPercent,
                color: kSubjectFallbackColors['SP']!,
              ),
              const SizedBox(height: 4),
              Divider(color: Theme.of(context).dividerColor, height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last Active: $lastActiveLabel',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor(context),
                    ),
                  ),
                  Text(
                    '$overallPercent% Completion',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kMaroon,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small maroon pill showing an admin's role (e.g. "ADMIN",
/// "SUPERVISOR", "CONTENT MANAGER").
class AdminRoleBadge extends StatelessWidget {
  final String role;

  const AdminRoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kMaroon,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// One card in the "All Admins" list: name + role badge, email, and
/// "Added" / "Last Active" dates.
class AdminListItem extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String addedLabel;
  final String lastActiveLabel;
  final VoidCallback? onTap;

  const AdminListItem({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    required this.addedLabel,
    required this.lastActiveLabel,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AdminRoleBadge(role: role),
                  const SizedBox(height: 8),
                  Text(
                    'Added: $addedLabel',
                    style: TextStyle(
                      fontSize: 10,
                      color: secondaryTextColor(context),
                    ),
                  ),
                  Text(
                    'Last Active: $lastActiveLabel',
                    style: TextStyle(
                      fontSize: 10,
                      color: secondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom nav for the admin flow: Users / Admins / Contents. Only
/// "Users" is wired up to a real screen for now — the other two are
/// shown but not built out yet, same pattern as [HomeBottomNavBar].
class AdminBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const AdminBottomNavBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _AdminNavItem(Icons.people_alt_rounded, 'Users'),
      _AdminNavItem(Icons.admin_panel_settings_rounded, 'Admins'),
      _AdminNavItem(Icons.menu_book_rounded, 'Contents'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final selected = index == currentIndex;
          final item = items[index];
          final color = selected
              ? kMaroon
              : (isDark ? Colors.white38 : Colors.grey.shade400);

          return InkWell(
            onTap: onTap == null ? null : () => onTap!(index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, color: color, size: 24),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _AdminNavItem {
  final IconData icon;
  final String label;
  const _AdminNavItem(this.icon, this.label);
}
