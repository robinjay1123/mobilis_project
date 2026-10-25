part of '../driver_home_screen.dart';

// PROFILE TAB
class _ProfileTab extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;
  final VoidCallback onLogout;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenBookings;
  final VoidCallback onProfileUpdated;

  const _ProfileTab({
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.onLogout,
    required this.onOpenSupport,
    required this.onOpenBookings,
    required this.onProfileUpdated,
  });

  @override
  State<_ProfileTab> createState() => __ProfileTabState();
}

class __ProfileTabState extends State<_ProfileTab> {
  late Future<Map<String, dynamic>> _driverStatsFuture;

  @override
  void initState() {
    super.initState();
    final userId = AuthService().currentUser?.id;
    _driverStatsFuture = userId == null
        ? Future.value(<String, dynamic>{})
        : DriverService()
              .getDriverStats(userId)
              .catchError((_) => <String, dynamic>{});
  }

  Widget _buildDriverInitial(String displayName) {
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _driverStatsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final totalTrips =
            int.tryParse(
              (stats['total_trips'] ?? stats['trips'] ?? 0).toString(),
            ) ??
            0;
        final assignments =
            int.tryParse(
              (stats['assignments'] ?? stats['bookings'] ?? 0).toString(),
            ) ??
            0;
        final rating =
            (stats['rating'] as num?)?.toDouble() ??
            double.tryParse(stats['rating']?.toString() ?? '') ??
            0.0;

        return UnifiedProfileScreen(
          role: 'driver',
          isDarkMode: widget.isDarkMode,
          onThemeToggle: widget.onThemeToggle,
          onLogout: widget.onLogout,
          onOpenSupport: widget.onOpenSupport,
          onOpenVerification: () =>
              Navigator.pushNamed(context, '/driver-identity-verification'),
          onProfileUpdated: widget.onProfileUpdated,
          stats: [
            ProfileStatItem(
              label: 'Trips',
              value: totalTrips.toString(),
              onTap: widget.onOpenBookings,
            ),
            ProfileStatItem(
              label: 'Assignments',
              value: assignments.toString(),
              onTap: widget.onOpenBookings,
            ),
            ProfileStatItem(
              label: 'Rating',
              value: rating <= 0 ? '0.0' : rating.toStringAsFixed(1),
              onTap: () {
                final userId = AuthService().currentUser?.id;
                if (userId == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RatingsReviewsScreen(
                      userId: userId,
                      title: 'Driver Ratings & Reviews',
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey : Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _DriverProfileStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _DriverProfileDivider extends StatelessWidget {
  const _DriverProfileDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: AppColors.borderColor);
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isDark;
  final Color? textColor;
  final bool isLast;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.isDark,
    this.textColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.2),
          boxShadow: isDark ? null : AppColors.cardShadowOf(context),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: textColor ?? (isDark ? AppColors.primary : AppColors.primaryDark),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? primaryText,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(fontSize: 13, color: secondaryText),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: tertiaryText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
