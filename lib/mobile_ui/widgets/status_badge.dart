import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final EdgeInsets? padding;
  final double borderRadius;

  const StatusBadge({
    super.key,
    required this.status,
    this.padding,
    this.borderRadius = 4,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'upcoming':
        return AppColors.warning;
      case 'completed':
        return AppColors.primary;
      case 'cancelled':
      case 'canceled':
      case 'declined':
        return AppColors.error;
      case 'pending':
      case 'required':
        return AppColors.warning;
      case 'approved':
      case 'verified':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'confirmed':
        return AppColors.success;
      case 'basic renter':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
