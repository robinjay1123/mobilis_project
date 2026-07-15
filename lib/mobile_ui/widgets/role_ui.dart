import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RolePageHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const RolePageHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 6,
        16,
        6,
      ),
      child: SizedBox(
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (trailing != null)
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 34),
                  child: trailing,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class RoleTabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;

  const RoleTabHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102033) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F3A55) : const Color(0xFFD8E0EA),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.black, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF9DAEC4)
                        : AppColors.lightTextSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RoleEmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const RoleEmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A3548) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.lightTextPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class RoleBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Map<int, int> badgeCounts;

  const RoleBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.badgeCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF07111D) : Colors.white;
    final border = isDark ? const Color(0xFF1B3047) : const Color(0xFFD8E0EA);
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: border)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex < 0
            ? 0
            : currentIndex > 4
            ? 4
            : currentIndex,
        backgroundColor: background,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark
            ? const Color(0xFF7E8CA3)
            : AppColors.lightTextSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        onTap: onTap,
        items: [
          BottomNavigationBarItem(
            icon: _RoleBottomNavigationIcon(
              icon: Icons.home,
              count: badgeCounts[0] ?? 0,
              backgroundColor: background,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _RoleBottomNavigationIcon(
              icon: Icons.calendar_month_outlined,
              count: badgeCounts[1] ?? 0,
              backgroundColor: background,
            ),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: _RoleBottomNavigationIcon(
              icon: Icons.chat_bubble_outline,
              count: badgeCounts[2] ?? 0,
              backgroundColor: background,
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: _RoleBottomNavigationIcon(
              icon: Icons.notifications_outlined,
              count: badgeCounts[3] ?? 0,
              backgroundColor: background,
            ),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: _RoleBottomNavigationIcon(
              icon: Icons.person_outline,
              count: badgeCounts[4] ?? 0,
              backgroundColor: background,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _RoleBottomNavigationIcon extends StatelessWidget {
  const _RoleBottomNavigationIcon({
    required this.icon,
    required this.count,
    required this.backgroundColor,
  });

  final IconData icon;
  final int count;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            top: -6,
            right: -10,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: EdgeInsets.symmetric(horizontal: count > 9 ? 4 : 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: backgroundColor, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
