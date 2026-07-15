import 'package:flutter/material.dart';

import '../mobile_ui/theme/app_colors.dart';
import 'notification_target.dart';

class NotificationVisual {
  const NotificationVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

NotificationVisual notificationVisualFor(Map<String, dynamic> notification) {
  final target = resolveNotificationTarget(notification);
  switch (target.destination) {
    case NotificationDestination.booking:
      return const NotificationVisual(
        icon: Icons.calendar_month_outlined,
        color: AppColors.warning,
      );
    case NotificationDestination.messages:
      return const NotificationVisual(
        icon: Icons.chat_bubble_outline_rounded,
        color: AppColors.primary,
      );
    case NotificationDestination.tracking:
      return const NotificationVisual(
        icon: Icons.location_on_outlined,
        color: Color(0xFF42A5F5),
      );
    case NotificationDestination.application:
      return const NotificationVisual(
        icon: Icons.assignment_outlined,
        color: AppColors.warning,
      );
    case NotificationDestination.verification:
      return const NotificationVisual(
        icon: Icons.verified_user_outlined,
        color: AppColors.success,
      );
    case NotificationDestination.ratings:
      return const NotificationVisual(
        icon: Icons.star_outline_rounded,
        color: AppColors.primary,
      );
    case NotificationDestination.payment:
      return const NotificationVisual(
        icon: Icons.payments_outlined,
        color: AppColors.success,
      );
    case NotificationDestination.announcement:
      return const NotificationVisual(
        icon: Icons.campaign_outlined,
        color: AppColors.primary,
      );
    case NotificationDestination.vehicles:
      return const NotificationVisual(
        icon: Icons.directions_car_outlined,
        color: Color(0xFF42A5F5),
      );
    case NotificationDestination.general:
      return const NotificationVisual(
        icon: Icons.notifications_none_rounded,
        color: AppColors.textSecondary,
      );
  }
}
