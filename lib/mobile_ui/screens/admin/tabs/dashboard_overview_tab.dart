import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/admin/admin_stat_card.dart';

class DashboardOverviewTab extends StatelessWidget {
  final double totalRevenue;
  final int activeBookings;
  final int pendingVerifications;
  final int activeTrips;
  final VoidCallback? onUsersPressed;
  final VoidCallback? onFleetPressed;
  final VoidCallback? onBookingsPressed;
  final VoidCallback? onRevenuePressed;
  final VoidCallback? onSecurityPressed;
  final VoidCallback? onSettingsPressed;

  const DashboardOverviewTab({
    super.key,
    this.totalRevenue = 0,
    this.activeBookings = 0,
    this.pendingVerifications = 0,
    this.activeTrips = 0,
    this.onUsersPressed,
    this.onFleetPressed,
    this.onBookingsPressed,
    this.onRevenuePressed,
    this.onSecurityPressed,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Revenue Card
          AdminStatCard(
            title: 'Total Revenue',
            value: '\$${_formatNumber(totalRevenue)}',
            percentChange: '12.5%',
            isPositive: true,
            isLarge: true,
            icon: Icons.trending_up,
            iconColor: AppColors.success,
          ),

          const SizedBox(height: 12),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: AdminStatCard(
                  title: 'Active Bookings',
                  value: activeBookings.toString(),
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminStatCard(
                  title: 'Pending Verif.',
                  value: pendingVerifications.toString(),
                  icon: Icons.pending_actions_outlined,
                  iconColor: AppColors.warning,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Active Trips Card with avatar stack
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.borderColor
                    : AppColors.lightBorderColor,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Trips',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            activeTrips.toString(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Vehicles',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Avatar Stack
                SizedBox(
                  width: 100,
                  height: 36,
                  child: Stack(
                    children: [
                      ...List.generate(4, (index) {
                        return Positioned(
                          left: index * 22.0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: [
                                Colors.blue,
                                Colors.green,
                                Colors.orange,
                                Colors.purple,
                              ][index],
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkCard
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                ['J', 'M', 'S', 'A'][index],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      Positioned(
                        right: 0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? AppColors.darkBgSecondary
                                : AppColors.lightBgTertiary,
                            border: Border.all(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '+${activeTrips > 4 ? activeTrips - 4 : 0}',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Access Section
          Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),

          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
            children: [
              AdminQuickAccessCard(
                title: 'Users',
                icon: Icons.people_outline,
                iconColor: Colors.blue,
                onTap: onUsersPressed,
              ),
              AdminQuickAccessCard(
                title: 'Fleet',
                icon: Icons.directions_car_outlined,
                iconColor: Colors.purple,
                onTap: onFleetPressed,
              ),
              AdminQuickAccessCard(
                title: 'Bookings',
                icon: Icons.calendar_today_outlined,
                iconColor: Colors.orange,
                onTap: onBookingsPressed,
              ),
              AdminQuickAccessCard(
                title: 'Revenue',
                icon: Icons.attach_money,
                iconColor: AppColors.success,
                onTap: onRevenuePressed,
              ),
              AdminQuickAccessCard(
                title: 'Security',
                icon: Icons.shield_outlined,
                iconColor: AppColors.error,
                onTap: onSecurityPressed,
              ),
              AdminQuickAccessCard(
                title: 'Settings',
                icon: Icons.settings_outlined,
                iconColor: AppColors.textSecondary,
                onTap: onSettingsPressed,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // System Health Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.borderColor
                    : AppColors.lightBorderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Health',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const SystemHealthIndicator(
                  title: 'Cloud Servers Operational',
                  value: 'Uptime: 99.9%',
                  statusColor: AppColors.success,
                ),
                const SizedBox(height: 8),
                const SystemHealthIndicator(
                  title: 'API Response Time',
                  value: '142MS',
                  progress: 0.14,
                  statusColor: AppColors.success,
                ),
                const SizedBox(height: 8),
                const SystemHealthIndicator(
                  title: 'Database Load',
                  value: '24%',
                  progress: 0.24,
                  statusColor: AppColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 2)}K';
    }
    return number.toStringAsFixed(2);
  }
}
