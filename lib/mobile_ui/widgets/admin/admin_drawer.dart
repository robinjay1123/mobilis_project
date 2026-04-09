import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AdminDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String adminName;
  final String adminRole;
  final String? avatarUrl;
  final VoidCallback? onClose;

  const AdminDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.adminName = 'Admin User',
    this.adminRole = 'Super Admin',
    this.avatarUrl,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final menuItems = [
      _MenuItem(Icons.dashboard_outlined, 'Dashboard Overview', 0),
      _MenuItem(Icons.people_outline, 'User Management', 1),
      _MenuItem(Icons.directions_car_outlined, 'Fleet Control', 2),
      _MenuItem(Icons.calendar_today_outlined, 'Booking Management', 3),
      _MenuItem(Icons.analytics_outlined, 'Revenue & Analytics', 4),
      _MenuItem(Icons.person_add_outlined, 'Driver Intake', 5),
      _MenuItem(Icons.car_rental_outlined, 'Vehicle Intake', 6),
      _MenuItem(Icons.settings_outlined, 'System Settings', 7),
    ];

    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fleet Control',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              color: isDark
                  ? AppColors.borderColor
                  : AppColors.lightBorderColor,
              height: 1,
            ),

            // Menu Items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  final isSelected = selectedIndex == item.index;

                  return _buildMenuItem(
                    context,
                    item.icon,
                    item.title,
                    isSelected,
                    () {
                      onItemSelected(item.index);
                      if (onClose != null) {
                        onClose!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    isDark,
                  );
                },
              ),
            ),

            // Admin Profile at bottom
            Divider(
              color: isDark
                  ? AppColors.borderColor
                  : AppColors.lightBorderColor,
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            adminName.isNotEmpty
                                ? adminName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          adminRole,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.more_vert,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppColors.primary.withOpacity(0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.textPrimary
                                : AppColors.lightTextPrimary),
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final int index;

  _MenuItem(this.icon, this.title, this.index);
}
