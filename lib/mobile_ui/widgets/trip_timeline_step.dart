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
                        : AppColors.darkBgSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.borderColor,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isCompleted || isActive
                        ? Colors.black
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                if (label != 'Dropoff')
                  Container(width: 2, height: 40, color: AppColors.borderColor),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
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
