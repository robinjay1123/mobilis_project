import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/admin/driver_intake_card.dart';

class DriverIntakeTab extends StatefulWidget {
  final List<Map<String, dynamic>> driverApplications;
  final Function(Map<String, dynamic>, String?)? onApprove;
  final Function(Map<String, dynamic>, String?)? onReject;

  const DriverIntakeTab({
    super.key,
    required this.driverApplications,
    this.onApprove,
    this.onReject,
  });

  @override
  State<DriverIntakeTab> createState() => _DriverIntakeTabState();
}

class _DriverIntakeTabState extends State<DriverIntakeTab> {
  final Map<String, TextEditingController> _noteControllers = {};

  @override
  void dispose() {
    for (var controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String id) {
    if (!_noteControllers.containsKey(id)) {
      _noteControllers[id] = TextEditingController();
    }
    return _noteControllers[id]!;
  }

  int get _todayCount {
    // Mock count - in real app, filter by today's date
    return widget.driverApplications.length > 5
        ? 5
        : widget.driverApplications.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Driver Intake',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reviewing ${widget.driverApplications.length} pending applications for PSDC Fleet.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),

        // Quick Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AppColors.borderColor
                    : AppColors.lightBorderColor,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+$_todayCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'High approval rate this week',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // NBI Clearance Notice
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NBI Clearance Mandate',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'All PSDC applicants must present valid 2024 clearance.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Driver Applications List
        Expanded(
          child: widget.driverApplications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppColors.success.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All applications reviewed!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No pending driver applications',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: widget.driverApplications.length + 1,
                  itemBuilder: (context, index) {
                    if (index == widget.driverApplications.length) {
                      // End of list indicator
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 1,
                                color: isDark
                                    ? AppColors.borderColor
                                    : AppColors.lightBorderColor,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'End of Priority List',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textTertiary
                                      : AppColors.lightTextTertiary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 40,
                                height: 1,
                                color: isDark
                                    ? AppColors.borderColor
                                    : AppColors.lightBorderColor,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final driver = widget.driverApplications[index];
                    final driverId =
                        driver['id']?.toString() ?? index.toString();

                    return DriverIntakeCard(
                      name: driver['full_name'] ?? 'Unknown Driver',
                      avatarUrl: driver['avatar_url'],
                      appliedTime: _formatAppliedTime(driver['created_at']),
                      location:
                          driver['city'] ?? driver['location'] ?? 'Manila',
                      experienceYears:
                          '${driver['experience_years'] ?? 3} years',
                      licenseType: driver['license_type'] ?? 'Professional',
                      licenseStatus:
                          driver['license_status'] ?? 'Non-Restricted',
                      nbiStatus: driver['nbi_status'] ?? 'Pending Upload',
                      nbiExpiry: driver['nbi_expiry'],
                      tier: _getTier(driver),
                      noteController: _getController(driverId),
                      onApprove: () {
                        final note = _getController(driverId).text;
                        widget.onApprove?.call(
                          driver,
                          note.isEmpty ? null : note,
                        );
                      },
                      onReject: () {
                        final note = _getController(driverId).text;
                        widget.onReject?.call(
                          driver,
                          note.isEmpty ? null : note,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatAppliedTime(dynamic createdAt) {
    if (createdAt == null) return '2 hours ago';
    // In a real app, calculate the time difference
    return '2 hours ago';
  }

  String _getTier(Map<String, dynamic> driver) {
    final experienceYears = driver['experience_years'] ?? 0;
    final rating = driver['rating'] ?? 0.0;

    if (experienceYears >= 10 || rating >= 4.9) {
      return 'Elite Tier';
    } else if (experienceYears >= 5 || rating >= 4.5) {
      return 'Pro Driver';
    } else {
      return 'Standard';
    }
  }
}
