import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TripTimelineStep extends StatelessWidget {
  final String label;
  final String date;
  final String time;
  final IconData icon;
  final bool isCompleted;
  final bool isActive;

  const TripTimelineStep({
    super.key,
    required this.label,
    required this.date,
    required this.time,
    required this.icon,
    this.isCompleted = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final inactiveBg = isDark ? AppColors.darkBgSecondary : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted || isActive
                        ? AppColors.primary
                        : inactiveBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? AppColors.primary
                          : border,
                      width: isActive ? 2 : 1.2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isCompleted || isActive
                        ? Colors.black
                        : secondaryText,
                    size: 20,
                  ),
                ),
                if (label != 'Dropoff')
                  Container(width: 2, height: 40, color: border),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: secondaryText,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: tertiaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
