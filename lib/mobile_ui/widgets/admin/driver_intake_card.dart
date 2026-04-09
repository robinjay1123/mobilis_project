import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class DriverIntakeCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String appliedTime;
  final String location;
  final String experienceYears;
  final String licenseType;
  final String licenseStatus;
  final String nbiStatus;
  final String? nbiExpiry;
  final String tier;
  final TextEditingController? noteController;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const DriverIntakeCard({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.appliedTime,
    required this.location,
    required this.experienceYears,
    required this.licenseType,
    required this.licenseStatus,
    required this.nbiStatus,
    this.nbiExpiry,
    required this.tier,
    this.noteController,
    this.onApprove,
    this.onReject,
  });

  Color _getTierColor() {
    switch (tier.toLowerCase()) {
      case 'elite':
      case 'elite tier':
        return Colors.purple;
      case 'pro':
      case 'pro driver':
        return Colors.blue;
      case 'standard':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar and tier
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _getTierColor().withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tier.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _getTierColor(),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Applied $appliedTime',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: isDark
                              ? AppColors.textTertiary
                              : AppColors.lightTextTertiary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Experience
          _buildInfoRow(
            context,
            Icons.access_time,
            'Experience',
            experienceYears,
            isDark,
          ),

          const SizedBox(height: 12),

          // License Status
          _buildInfoRow(
            context,
            Icons.badge_outlined,
            'License Status',
            '$licenseType • $licenseStatus',
            isDark,
            valueColor: AppColors.success,
          ),

          const SizedBox(height: 12),

          // NBI Clearance
          _buildInfoRow(
            context,
            Icons.verified_user_outlined,
            'NBI Clearance',
            nbiStatus == 'Verified'
                ? 'Verified${nbiExpiry != null ? ' • Exp: $nbiExpiry' : ''}'
                : nbiStatus,
            isDark,
            valueColor: nbiStatus == 'Verified'
                ? AppColors.success
                : nbiStatus == 'Pending Upload'
                ? AppColors.warning
                : AppColors.textSecondary,
          ),

          const SizedBox(height: 16),

          // Note field
          TextField(
            controller: noteController,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Note for decision reason (optional)',
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textTertiary
                    : AppColors.lightTextTertiary,
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkBgSecondary
                  : AppColors.lightBgTertiary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color:
                  valueColor ??
                  (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
