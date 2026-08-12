import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NotificationItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String timestamp;
  final Color iconColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isRead;

  const NotificationItem({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.timestamp,
    this.iconColor = AppColors.primary,
    this.onTap,
    this.onLongPress,
    this.isRead = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFF2A3548) : const Color(0xFF354156),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead ? AppColors.borderColor : Colors.white70,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 25),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timestamp,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isRead) ...[
              const SizedBox(width: 10),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
