part of '../partner_home_screen.dart';

extension _PartnerDashboardTab on _PartnerHomeScreenState {
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with profile
          _buildDashboardHeader(),

          // Verification Banner
          if (!_isPartnerVerified && !dismissedVerificationBanner)
            _buildVerificationBanner(),

          const SizedBox(height: 20),

          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildStatCard(
                  label: 'EARNINGS',
                  value: '₱${formatAmount(totalEarnings, decimalDigits: 0)}',
                  subtext: '+12%',
                  subtextColor: AppColors.success,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  label: 'ACTIVE',
                  value: '$activeVehicles',
                  subtext: 'Cars on road',
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  label: 'RATING',
                  value: ratingCount > 0 ? rating.toStringAsFixed(1) : '0.0',
                  subtext: ratingCount > 0 ? 'From reviews' : 'No reviews yet',
                  subtextColor: AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUICK ACTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      _buildQuickAction(
                        icon: Icons.add_circle_outline,
                        label: 'Add Vehicle',
                        width: 86,
                        onTap: _handleApplyVehicleNavigation,
                      ),
                      const SizedBox(width: 10),
                      _buildQuickAction(
                        icon: Icons.radar_rounded,
                        label: 'Live Tracking',
                        width: 86,
                        onTap: _openLiveTracking,
                      ),
                      const SizedBox(width: 10),
                      _buildQuickAction(
                        icon: Icons.directions_car,
                        label: 'Manage Fleet',
                        width: 86,
                        onTap: () =>
                            Navigator.pushNamed(context, '/vehicle-availability'),
                      ),
                      const SizedBox(width: 10),
                      _buildQuickAction(
                        icon: Icons.bar_chart,
                        label: 'View Revenue',
                        width: 86,
                        onTap: _openRevenuePayoutScreen,
                      ),
                      const SizedBox(width: 10),
                      _buildQuickAction(
                        icon: Icons.star_rate,
                        label: 'Rates & Reviews',
                        width: 86,
                        onTap: _showRatesReviewsDialog,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Partner value proposition
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildWhyPartnerWithPsdcSection(),
          ),
          const SizedBox(height: 24),

          // Live Tracking shortcut
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildLiveTrackingSection(),
          ),
          const SizedBox(height: 24),

          // Recent Requests Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildRecentRequestsSection(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 8,
        20,
        12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: _buildPartnerAvatar(size: 44, radius: 12, fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      partnerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_isPartnerVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              color: AppColors.success,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _isPartnerCertified ? 'CERTIFIED' : 'VERIFIED',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const Text(
                  'Mobilis Certified Partner',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    final isPending =
        verificationStatus == 'pending' || verificationStatus == 'submitted';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPending ? Icons.hourglass_top : Icons.pending,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPending
                          ? 'Verification Under Review'
                          : 'Complete Verification',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                    Text(
                      isPending
                          ? 'Your verification documents have been submitted and are under review.'
                          : 'Unlock full features and build trust with renters',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      dismissedVerificationBanner = true;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.warning.withAlpha(50)),
                  ),
                  child: const Text(
                    'Later',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    isPending
                        ? '/account-verification'
                        : '/owner-verification',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    isPending ? 'Check Status' : 'Verify Now',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.verified_user,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPartnerCertified
                      ? 'Certified Partner'
                      : 'Verified Partner',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'Your fleet is ready for listings',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Details',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String subtext,
    Color? subtextColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.2),
          boxShadow: isDark ? null : AppColors.cardShadowOf(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: tertiaryText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: subtextColor ?? (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    double? width,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;

    final card = GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: 86,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.2),
            boxShadow: isDark ? null : AppColors.cardShadowOf(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isDark ? AppColors.primary : AppColors.primaryDark, size: 24),
              const SizedBox(height: 10),
              SizedBox(
                height: 14,
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (width != null) {
      return card;
    }
    return Expanded(child: card);
  }

  Widget _buildWhyPartnerWithPsdcSection() {
    const benefits = [
      (
        icon: Icons.verified_user_outlined,
        title: 'Trusted Platform',
        description: 'Connect with renters through a trusted rental platform.',
      ),
      (
        icon: Icons.trending_up_rounded,
        title: 'More Income',
        description: 'Unlock more booking opportunities for your vehicles.',
      ),
      (
        icon: Icons.visibility_outlined,
        title: 'More Visibility',
        description: 'Help more potential renters discover your fleet.',
      ),
      (
        icon: Icons.event_available_outlined,
        title: 'Easy Management',
        description: 'Manage bookings and availability in one place.',
      ),
      (
        icon: Icons.lock_outline_rounded,
        title: 'Secure Transactions',
        description: 'Keep rental activity organized and easy to follow.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102E45), Color(0xFF17374F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.handshake_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why Partner with PSDC?',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Grow your fleet with tools built for confident, organized rentals.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            itemCount: benefits.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 88,
            ),
            itemBuilder: (context, index) {
              final benefit = benefits[index];
              return Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(benefit.icon, color: AppColors.primary, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            benefit.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            benefit.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingSection() {
    final activeBookings = bookings
        .where(
          (booking) =>
              bookingStatusGroup(booking['status']) ==
              BookingStatusGroup.ongoing,
        )
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF102A3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF24516D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_searching_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Tracking',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Monitor vehicles on an active trip',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: activeBookings.isEmpty
                      ? AppColors.darkBgSecondary
                      : AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${activeBookings.length} active',
                  style: TextStyle(
                    color: activeBookings.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (activeBookings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.darkBg.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No active trips right now. Live vehicle updates will appear here.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...activeBookings.take(3).map(_buildLiveTrackingBookingTile),
          if (activeBookings.length > 3) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _openLiveTracking(),
                child: const Text('View all active trips'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveTrackingBookingTile(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['users'] as Map<String, dynamic>?;
    final tracking = _trackingForBooking(booking);
    final vehicleName =
        [vehicle?['vehicle_name'], vehicle?['brand'], vehicle?['model']]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .join(' ');
    final status = _bookingStatusLabel(booking, tracking);
    final renterName = renter?['full_name']?.toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.darkBg.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF24516D)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car_filled_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicleName.isEmpty ? 'Active vehicle' : vehicleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${renterName?.isNotEmpty == true ? renterName : 'Renter'} • $status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _bookingStatusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _openLiveTracking(
              focusBookingId: booking['id']?.toString(),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Track',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatesReviewsDialog() {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingsReviewsScreen(
          userId: userId,
          title: 'Partner Ratings & Reviews',
        ),
      ),
    );
  }

  void _openPartnerSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (settingsContext) => SettingsScreen(
          isDarkMode: widget.isDarkMode,
          onThemeToggle: widget.onThemeToggle,
          onBack: () => Navigator.of(settingsContext).pop(),
          onOpenSupport: _openCustomerServiceConversation,
          onProfileUpdated: _loadPartnerData,
        ),
      ),
    );
  }

  void _contactSupport() {
    _openCustomerServiceConversation();
  }

  Future<void> _maybeShowRestrictionNotification() async {
    for (final notification in notifications) {
      final notificationId = notification['id']?.toString();
      final type = notification['type']?.toString().trim().toLowerCase();
      final data = notification['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(notification['data'])
          : <String, dynamic>{};

      if (notificationId == null ||
          _shownRestrictionNotificationIds.contains(notificationId) ||
          type != 'policy_restriction' ||
          data['event']?.toString() != 'booking_void') {
        continue;
      }

      _shownRestrictionNotificationIds.add(notificationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restriction notice added to your notifications'),
          backgroundColor: AppColors.warning,
        ),
      );
      break;
    }
  }

  Future<void> _showBookingVoidDialog(Map<String, dynamic> notification) async {
    final notificationId = notification['id']?.toString();
    final data = notification['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(notification['data'])
        : <String, dynamic>{};
    final affectedBookings = (data['affected_bookings'] as num?)?.toInt() ?? 0;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2134),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  ),
                  const Expanded(
                    child: Text(
                      'Important Safety Update',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4B2430),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFFF7B7B),
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Booking Cancelled',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your account has been suspended from booking activity for violating our Community Guidelines. For safety, ${affectedBookings <= 0 ? 'affected bookings' : '$affectedBookings active booking${affectedBookings == 1 ? '' : 's'}'} are no longer active.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF112A43),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A3D72),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Refund Initiated',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'The renter reservation fee is being returned to their E-wallet.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.circle,
                      color: Colors.greenAccent,
                      size: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showPolicyDetailsSheet(this.context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF083562),
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.policy_outlined, size: 18),
                  label: const Text(
                    'View Policy Details',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _contactSupport();
                },
                child: const Center(
                  child: Text(
                    'Contact Support',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (notificationId != null) {
      await NotificationService().markAsRead(notificationId);
      if (!mounted) return;
      setState(() {
        final index = notifications.indexWhere(
          (item) => item['id']?.toString() == notificationId,
        );
        if (index != -1) {
          notifications[index] = {...notifications[index], 'is_read': true};
        }
      });
    }
  }

  void _openRevenuePayoutScreen() {
    final currentPartnerId = partnerId;
    if (currentPartnerId == null || currentPartnerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner account is still loading.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerRevenueScreen(
          partnerId: currentPartnerId,
          partnerName: partnerName,
          bookings: bookings,
          completedTrips: bookingCounts['completed'] ?? 0,
          recordedTotalEarnings: totalEarnings,
        ),
      ),
    );
  }

  Widget _buildRecentRequestsSection() {
    final filteredBookings = _filteredBookingsForDashboard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Requests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => selectedNavIndex = 1),
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildBookingTabButton('All', -1, badgeCount: _countBookingsForTab(-1)),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Pending', 0, badgeCount: _countBookingsForTab(0)),
                    const SizedBox(width: 8),
                    _buildBookingTabButton(
                      'Extensions',
                      5,
                      badgeCount: _countBookingsForTab(5),
                    ),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Ongoing', 2, badgeCount: _countBookingsForTab(2)),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Approved', 1, badgeCount: _countBookingsForTab(1)),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Completed', 3, badgeCount: _countBookingsForTab(3)),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Cancelled', 4, badgeCount: _countBookingsForTab(4)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (filteredBookings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.darkBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 40,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No ${_dashboardTabLabel(selectedBookingTab).toLowerCase()} requests yet',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filteredBookings
                    .take(3)
                    .map((booking) => _buildRecentRequestShowcaseCard(booking)),
            ],
          ),
        ),
      ],
    );
  }

  int _countBookingsForTab(int tabIndex) {
    if (tabIndex == -1) return bookings.length;
    if (tabIndex == 5) return _partnerPendingExtensionRequestsCount;
    final tabKey = switch (tabIndex) {
      0 => 'pending',
      1 => 'approved',
      2 => 'ongoing',
      3 => 'completed',
      _ => 'cancelled',
    };
    final fallbackStatuses = switch (tabIndex) {
      0 => {'pending'},
      1 => {'approved', 'confirmed'},
      2 => {'ongoing', 'active', 'in_progress', 'in transit', 'in_transit'},
      3 => {'completed', 'successful', 'done', 'finished'},
      _ => {'cancelled', 'canceled', 'declined', 'rejected'},
    };
    return bookings.where((b) {
      if (_matchesBookingTab(b, tabKey)) return true;
      final s = (b['status'] ?? '').toString().toLowerCase().trim();
      return fallbackStatuses.contains(s);
    }).length;
  }

  Widget _buildBookingTabButton(String label, int index, {int badgeCount = 0}) {
    final isSelected = selectedBookingTab == index;
    return SizedBox(
      width: label.length > 8 ? 104 : (label.length > 6 ? 94 : (label.length <= 3 ? 68 : 84)),
      child: GestureDetector(
        onTap: () => setState(() => selectedBookingTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.darkBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.black : AppColors.textSecondary,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingRequestCard(Map<String, dynamic> booking) {
    final vehicle = (booking['vehicles'] ??
            booking['partner_vehicles'] ??
            booking['partner_vehicle'] ??
            booking['vehicle']) as Map<String, dynamic>?;
    final renter = (booking['users'] ?? booking['renter']) as Map<String, dynamic>?;
    final status = (booking['status'] ?? 'pending').toString().toLowerCase();
    final statusColor = _dashboardBookingStatusColor(status);
    final statusLabel = _dashboardBookingStatusLabel(status);
    final brand = vehicle?['brand']?.toString().trim() ?? '';
    final model = vehicle?['model']?.toString().trim() ?? '';
    final rawName = vehicle?['vehicle_name']?.toString().trim() ?? '';
    final combo = [brand, model].where((part) => part.isNotEmpty).join(' ');
    final vehicleTitle = rawName.isNotEmpty && rawName.toLowerCase() != 'partner vehicle'
        ? rawName
        : (combo.isNotEmpty ? combo : (rawName.isNotEmpty ? rawName : 'Vehicle Request'));
    final vehicleYear = vehicle?['year']?.toString().trim();
    final imageUrl = _bookingVehicleImageUrl(vehicle);
    final pricePerDay =
        (vehicle?['price_per_day'] as num?)?.toDouble() ??
        double.tryParse(vehicle?['price_per_day']?.toString() ?? '') ??
        0;
    final totalPrice =
        (booking['total_price'] as num?)?.toDouble() ??
        double.tryParse(booking['total_price']?.toString() ?? '') ??
        0;
    final lateReturnFee =
        (booking['late_return_fee'] as num?)?.toDouble() ??
        double.tryParse(booking['late_return_fee']?.toString() ?? '') ??
        0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.darkBgTertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? OptimizedNetworkImage(
                        imageUrl: imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: Image.asset(
                          'assets/icon/logo1.png',
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.asset(
                        'assets/icon/logo1.png',
                        fit: BoxFit.contain,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '₱${vehicle?['price_per_day']?.toString() ?? '0'}/day',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicle?['year']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderColor, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₱${booking['total_price']?.toString() ?? '0'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Requested Rental Price',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateRange(
                        booking['start_date'],
                        booking['end_date'],
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Booking Period',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      renter?['full_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Renter',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPaymentStateBadge(booking),
            ],
          ),
          if (resolveBookingPaymentState(booking) == BookingPaymentState.paymentReview) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showVerifyPaymentProofDialog(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.verified_user_rounded, size: 16),
                label: const Text('Verify Renter Payment Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
          if (status == 'pending' || status == 'driver_accepted') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showPartnerDeclineDialog(booking),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleBookingAction(booking['id'], 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      resolveBookingPaymentState(booking) == BookingPaymentState.pendingConfirmation
                          ? 'Confirm & Accept'
                          : 'Accept',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'cancelled' || status == 'rejected') ...[
            Builder(
              builder: (_) {
                final payState = resolveBookingPaymentState(booking);
                final refundNeeded = payState == BookingPaymentState.refundRequired ||
                    booking['refund_status'] == 'refund_needed' ||
                    booking['refund_status'] == 'refund_required' ||
                    booking['refund_required'] == true;
                final refundComplete = payState == BookingPaymentState.refunded ||
                    booking['refund_status'] == 'refunded' ||
                    booking['refund_completed'] == true;

                if (refundNeeded && !refundComplete) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPartnerBookingRefundDialog(booking),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                        label: const Text('Process Booking Refund', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  );
                } else if (refundComplete) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showPartnerBookingRefundDialog(booking),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA855F7),
                          side: const BorderSide(color: Color(0xFFA855F7)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const Text('Refund Completed ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ] else if (status == 'active' ||
              status == 'ongoing' ||
              status == 'return_pending_inspection') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleBookingAction(
                  booking['id']?.toString() ?? '',
                  'return_confirmed',
                ),
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.black,
                  size: 18,
                ),
                label: Text(
                  status == 'return_pending_inspection'
                      ? 'Confirm Return Inspection'
                      : 'Confirm Return',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
          if (status == 'active' ||
              status == 'ongoing' ||
              status == 'return_pending_inspection' ||
              status == 'completed' ||
              status == 'returned') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final bId = booking['id']?.toString() ?? '';
                  if (bId.isNotEmpty) {
                    TripRouteHistoryScreen.open(
                      context: context,
                      bookingId: bId,
                      vehicleName: vehicleTitle,
                      plateNumber: vehicle?['plate_number']?.toString(),
                      renterName: renter?['full_name']?.toString(),
                    );
                  }
                },
                icon: const Icon(Icons.route_rounded, size: 16, color: AppColors.primary),
                label: const Text('Audit Traveled Route & GPS Playback'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentRequestShowcaseCard(Map<String, dynamic> booking) {
    final vehicle = (booking['vehicles'] ??
            booking['partner_vehicles'] ??
            booking['partner_vehicle'] ??
            booking['vehicle']) as Map<String, dynamic>?;
    final renter = (booking['users'] ?? booking['renter']) as Map<String, dynamic>?;
    final status = (booking['status'] ?? 'pending').toString().toLowerCase();
    final statusColor = _dashboardBookingStatusColor(status);
    final statusLabel = _dashboardBookingStatusLabel(status);
    final brand = vehicle?['brand']?.toString().trim() ?? '';
    final model = vehicle?['model']?.toString().trim() ?? '';
    final rawName = vehicle?['vehicle_name']?.toString().trim() ?? '';
    final combo = [brand, model].where((part) => part.isNotEmpty).join(' ');
    final vehicleTitle = rawName.isNotEmpty && rawName.toLowerCase() != 'partner vehicle'
        ? rawName
        : (combo.isNotEmpty ? combo : (rawName.isNotEmpty ? rawName : 'Vehicle Request'));
    final vehicleYear = vehicle?['year']?.toString().trim();
    final imageUrl = _bookingVehicleImageUrl(vehicle);
    final pricePerDay =
        (vehicle?['price_per_day'] as num?)?.toDouble() ??
        double.tryParse(vehicle?['price_per_day']?.toString() ?? '') ??
        0;
    final totalPrice =
        (booking['total_price'] as num?)?.toDouble() ??
        double.tryParse(booking['total_price']?.toString() ?? '') ??
        0;
    final lateReturnFee =
        (booking['late_return_fee'] as num?)?.toDouble() ??
        double.tryParse(booking['late_return_fee']?.toString() ?? '') ??
        0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            vehicleTitle.isEmpty
                                ? 'Vehicle Request'
                                : vehicleTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildPaymentStateBadge(booking),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${renter?['full_name'] ?? 'Unknown renter'}${vehicleYear != null && vehicleYear.isNotEmpty ? ' • $vehicleYear' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 154,
              width: double.infinity,
              color: AppColors.darkBgSecondary,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    OptimizedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: _buildBookingImageFallback(),
                    )
                  else
                    _buildBookingImageFallback(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Colors.black,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _bookingDestinationLabel(booking),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatDateRange(
                            booking['start_date']?.toString(),
                            booking['end_date']?.toString(),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildBookingMetricCard(
                title: 'Price / Day',
                value: 'PHP ${_formatMoney(pricePerDay)}',
              ),
              _buildBookingMetricCard(
                title: 'Requested Price',
                value: 'PHP ${_formatMoney(totalPrice)}',
              ),
              if (lateReturnFee > 0)
                _buildBookingMetricCard(
                  title: 'Late Return Fee',
                  value: 'PHP ${_formatMoney(lateReturnFee)}',
                ),
              _buildBookingMetricCard(
                title: 'Renter',
                value: renter?['full_name'] ?? 'Unknown',
              ),
            ],
          ),
          if (booking['extension_status'] != null &&
              booking['extension_status'].toString().isNotEmpty &&
              booking['extension_status'].toString() != 'none') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5A93C).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.update_rounded,
                        color: Color(0xFFE5A93C),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Trip Extension Request',
                          style: TextStyle(
                            color: Color(0xFFE5A93C),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          booking['extension_status'].toString().toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFE5A93C),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+${booking['extension_days'] ?? 1} Extra Days (Fee: PHP ${_formatMoney((booking['extension_additional_price'] as num?)?.toDouble() ?? 0)})',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (booking['extension_requested_end_at'] != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Requested Return: ${_formatDateShort(booking['extension_requested_end_at']?.toString())}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedNavIndex = 1;
                          _partnerBookingSubSection = 'extensions';
                        });
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Review Extension in Bookings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A93C),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (resolveBookingPaymentState(booking) == BookingPaymentState.paymentReview) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showVerifyPaymentProofDialog(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.verified_user_rounded, size: 16),
                label: const Text('Verify Renter Payment Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
          if (status == 'pending' || status == 'driver_accepted') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleBookingAction(booking['id'], 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success.withValues(
                        alpha: 0.18,
                      ),
                      foregroundColor: AppColors.success,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      resolveBookingPaymentState(booking) == BookingPaymentState.pendingConfirmation
                          ? 'Confirm & Accept'
                          : 'Accept',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showPartnerDeclineDialog(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD96B8A),
                      side: const BorderSide(color: Color(0xFF7B3146)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'cancelled' || status == 'rejected') ...[
            Builder(
              builder: (_) {
                final payState = resolveBookingPaymentState(booking);
                final refundNeeded = payState == BookingPaymentState.refundRequired ||
                    booking['refund_status'] == 'refund_needed' ||
                    booking['refund_status'] == 'refund_required' ||
                    booking['refund_required'] == true;
                final refundComplete = payState == BookingPaymentState.refunded ||
                    booking['refund_status'] == 'refunded' ||
                    booking['refund_completed'] == true;

                if (refundNeeded && !refundComplete) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPartnerBookingRefundDialog(booking),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                        label: const Text('Process Booking Refund', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  );
                } else if (refundComplete) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showPartnerBookingRefundDialog(booking),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA855F7),
                          side: const BorderSide(color: Color(0xFFA855F7)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const Text('Refund Completed ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingImageFallback() {
    return Container(
      color: AppColors.darkBgSecondary,
      alignment: Alignment.center,
      child: const Icon(
        Icons.directions_car_filled_rounded,
        color: AppColors.textSecondary,
        size: 48,
      ),
    );
  }

  Widget _buildBookingMetricCard({
    required String title,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filteredBookingsForDashboard() {
    if (selectedBookingTab == -1) {
      final list = List<Map<String, dynamic>>.from(bookings);
      list.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return list;
    }

    if (selectedBookingTab == 5) {
      final extList = bookings.where((booking) {
        final ext =
            booking['extension_status']?.toString().toLowerCase().trim();
        return ext != null && ext.isNotEmpty && ext != 'none';
      }).toList();
      extList.sort((a, b) {
        final aDate = DateTime.tryParse(
              a['extension_requested_at']?.toString() ??
                  a['created_at']?.toString() ??
                  '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(
              b['extension_requested_at']?.toString() ??
                  b['created_at']?.toString() ??
                  '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return extList;
    }

    final tabKey = switch (selectedBookingTab) {
      0 => 'pending',
      1 => 'approved',
      2 => 'ongoing',
      3 => 'completed',
      _ => 'cancelled',
    };
    final fallbackStatuses = switch (selectedBookingTab) {
      0 => {'pending'},
      1 => {'approved', 'confirmed'},
      2 => {'ongoing', 'active', 'in_progress', 'in transit', 'in_transit'},
      3 => {'completed', 'successful', 'done', 'finished'},
      _ => {'cancelled', 'canceled', 'declined', 'rejected'},
    };

    final filtered = bookings.where((booking) {
      if (_matchesBookingTab(booking, tabKey)) return true;
      final status = (booking['status'] ?? '').toString().toLowerCase().trim();
      return fallbackStatuses.contains(status);
    }).toList();

    filtered.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  String _dashboardTabLabel(int index) {
    switch (index) {
      case -1:
        return 'Recent';
      case 0:
        return 'Pending';
      case 1:
        return 'Approved';
      case 2:
        return 'Ongoing';
      case 3:
        return 'Completed';
      case 5:
        return 'Extension';
      default:
        return 'Cancelled';
    }
  }

  String _dashboardBookingStatusLabel(String status) {
    switch (status) {
      case 'confirmed':
      case 'ongoing':
      case 'active':
      case 'in_progress':
      case 'in transit':
      case 'in_transit':
        return 'Active';
      case 'completed':
      case 'successful':
      case 'done':
      case 'finished':
        return 'Completed';
      case 'cancelled':
      case 'canceled':
      case 'declined':
      case 'rejected':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  Color _dashboardBookingStatusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'ongoing':
      case 'active':
      case 'in_progress':
      case 'in transit':
      case 'in_transit':
        return AppColors.success;
      case 'completed':
      case 'successful':
      case 'done':
      case 'finished':
        return AppColors.primary;
      case 'cancelled':
      case 'canceled':
      case 'declined':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String? _bookingVehicleImageUrl(Map<String, dynamic>? vehicle) {
    if (vehicle == null) return null;

    String normalize(dynamic val) {
      if (val is List && val.isNotEmpty) return normalize(val.first);
      var raw = val?.toString().trim() ?? '';
      if (raw.isEmpty || raw == 'null') return '';
      if (raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('data:')) return raw;
      raw = raw.replaceFirst(RegExp(r'^/+'), '');
      const knownBuckets = [
        'vehicle_images',
        'vehicle-images',
        'partner_documents',
        'vehicle_documents',
        'cars',
        'vehicles',
        'avatars',
        'profiles',
      ];
      try {
        for (final bucket in knownBuckets) {
          if (raw.startsWith('$bucket/')) {
            final path = raw.substring(bucket.length + 1);
            return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
          }
        }
        return Supabase.instance.client.storage.from('vehicle_images').getPublicUrl(raw);
      } catch (_) {
        return raw;
      }
    }

    for (final key in const [
      'primary_image_url',
      'image_url',
      'imageUrl',
      'photo_url',
      'vehicle_photo_url',
      'vehicle_image_url',
      'thumbnail_url',
    ]) {
      final value = vehicle[key];
      final norm = normalize(value);
      if (norm.isNotEmpty) {
        return norm;
      }
    }

    final rawImages = vehicle['vehicle_images'] ?? vehicle['images'] ?? vehicle['photos'];
    if (rawImages is List) {
      for (final image in rawImages) {
        if (image is Map<String, dynamic>) {
          for (final key in const ['image_url', 'url', 'image', 'photo_url']) {
            final norm = normalize(image[key]);
            if (norm.isNotEmpty) return norm;
          }
        } else {
          final norm = normalize(image);
          if (norm.isNotEmpty) return norm;
        }
      }
    }

    return null;
  }

  String _bookingDestinationLabel(Map<String, dynamic> booking) {
    for (final candidate in [
      booking['destination'],
      booking['dropoff_location'],
      booking['pickup_location'],
      booking['meeting_point'],
    ]) {
      final text = candidate?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }

    return 'Trip route pending';
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return formatAmount(value, decimalDigits: 0);
    }
    return formatAmount(value, decimalDigits: 2);
  }

  String _formatDateRange(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) return 'N/A';
    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[start.month - 1]} ${start.day}-${end.day}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _handleBookingAction(String bookingId, String status, {String? reason}) async {
    final currentPartnerId = partnerId ?? AuthService().currentUser?.id;
    final bookingIndex =
        bookings.indexWhere((b) => b['id']?.toString() == bookingId);
    final originalBooking = bookingIndex != -1
        ? Map<String, dynamic>.from(bookings[bookingIndex])
        : null;

    if (status == 'return_confirmed' && currentPartnerId != null) {
      final booking = originalBooking ?? <String, dynamic>{'id': bookingId};
      await _showPartnerInspectionDialog(booking, inspectionType: 'after');
      _loadPartnerData(silent: true);
      return;
    }

    final effectiveReason = reason ?? 'Declined by vehicle owner';

    // ⚡ Optimistic UI update: instantly update local list and counts
    if (bookingIndex != -1) {
      setState(() {
        final target = Map<String, dynamic>.from(bookings[bookingIndex]);
        if (status == 'confirmed') {
          target['status'] = 'confirmed';
          target['partner_booking_confirmed_at'] =
              DateTime.now().toIso8601String();
          target['partner_booking_confirmed_by'] = currentPartnerId;
        } else if (status == 'cancelled' || status == 'rejected') {
          target['status'] = 'rejected';
          target['partner_booking_rejected_at'] =
              DateTime.now().toIso8601String();
          target['rejection_reason'] = effectiveReason;
        } else {
          target['status'] = status;
        }
        bookings[bookingIndex] = target;

        if (status == 'cancelled' || status == 'rejected') {
          bookingCounts['pending'] =
              ((bookingCounts['pending'] ?? 1) - 1).clamp(0, 999999);
          bookingCounts['cancelled'] =
              (bookingCounts['cancelled'] ?? 0) + 1;
        } else if (status == 'confirmed') {
          bookingCounts['pending'] =
              ((bookingCounts['pending'] ?? 1) - 1).clamp(0, 999999);
          bookingCounts['active'] =
              (bookingCounts['active'] ?? 0) + 1;
        }
      });
    }

    _showSuccessSnackBar(
      status == 'confirmed'
          ? 'Booking confirmed!'
          : status == 'return_confirmed'
          ? 'Vehicle return confirmed!'
          : 'Booking declined',
    );

    try {
      final bookingService = BookingService();

      if (status == 'confirmed' && currentPartnerId != null) {
        await bookingService.confirmPartnerBooking(
          bookingId: bookingId,
          partnerId: currentPartnerId,
          cachedBooking: originalBooking,
        );
      } else if ((status == 'cancelled' || status == 'rejected') &&
          currentPartnerId != null) {
        await bookingService.rejectPartnerBooking(
          bookingId: bookingId,
          partnerId: currentPartnerId,
          reason: effectiveReason,
          cachedBooking: originalBooking,
        );
      } else {
        await bookingService.updateBookingStatus(
          bookingId,
          status,
        );
      }

      // Silent sync in the background so local changes aren't interrupted
      _loadPartnerData(silent: true);
    } catch (e) {
      debugPrint('Partner booking action error: $e');
      if (originalBooking != null && bookingIndex != -1 && mounted) {
        setState(() {
          bookings[bookingIndex] = originalBooking;
          if (status == 'cancelled' || status == 'rejected') {
            bookingCounts['pending'] =
                (bookingCounts['pending'] ?? 0) + 1;
            bookingCounts['cancelled'] =
                ((bookingCounts['cancelled'] ?? 1) - 1).clamp(0, 999999);
          } else if (status == 'confirmed') {
            bookingCounts['pending'] =
                (bookingCounts['pending'] ?? 0) + 1;
            bookingCounts['active'] =
                ((bookingCounts['active'] ?? 1) - 1).clamp(0, 999999);
          }
        });
      }
      _showErrorSnackBar('Failed to update booking: $e');
    }
  }

  Widget _buildPaymentStateBadge(Map<String, dynamic> booking) {
    final state = resolveBookingPaymentState(booking);
    final color = bookingPaymentStateColor(state);
    final label = bookingPaymentStateLabel(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVerifyPaymentProofDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renter = booking['users'] as Map<String, dynamic>? ?? booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renterName = renter['full_name']?.toString() ?? 'Renter';
    final vehicleTitle = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
    final proofUrl = (booking['reservation_payment_proof_url'] ??
            booking['final_payment_proof_url'] ??
            booking['payment_proof_url'] ??
            booking['payment_receipt_url'] ??
            booking['proof_url'])
        ?.toString()
        .trim();
    final reference = (booking['reservation_payment_reference'] ??
            booking['final_payment_reference'] ??
            booking['payment_reference'])
        ?.toString()
        .trim();
    final totalAmount = (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_amount'] as num?)?.toDouble() ??
        0.0;
    final notesController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Color(0xFF38BDF8),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verify Renter Payment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$renterName • $vehicleTitle',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Booking Amount', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : Colors.grey.shade600)),
                                      const SizedBox(height: 4),
                                      Text('PHP ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Reference No.', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : Colors.grey.shade600)),
                                      const SizedBox(height: 4),
                                      Text(
                                        reference != null && reference.isNotEmpty ? reference : 'N/A',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Receipt Preview
                          const Text('Uploaded Receipt / Proof', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          if (proofUrl != null && proofUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.network(
                                  proofUrl,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 120,
                                    alignment: Alignment.center,
                                    child: const Text('Failed to load image preview'),
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.4)),
                              ),
                              child: const Center(
                                child: Text('No receipt image attached. Reference provided above.', style: TextStyle(fontSize: 11, color: Colors.amber)),
                              ),
                            ),
                          const SizedBox(height: 14),

                          // Notes
                          const Text('Verification Notes (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'e.g., GCash payment confirmed',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setDialogState(() => isSubmitting = true);
                                    try {
                                      await BookingService().verifyRenterReservationPayment(
                                        bookingId,
                                        notes: notesController.text.trim(),
                                      );
                                      booking['reservation_payment_status'] = 'verified';
                                      booking['payment_verified'] = true;
                                      final idx = bookings.indexWhere((b) => b['id']?.toString() == bookingId);
                                      if (idx != -1) {
                                        bookings[idx]['reservation_payment_status'] = 'verified';
                                        bookings[idx]['payment_verified'] = true;
                                      }
                                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                                      _loadPartnerData(silent: true);
                                      _showSuccessSnackBar('✅ Payment verified! Booking is ready for acceptance.');
                                    } catch (e) {
                                      setDialogState(() => isSubmitting = false);
                                      _showErrorSnackBar('Failed to verify payment: $e');
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: Text(
                              isSubmitting ? 'Verifying...' : 'Verify & Accept Payment',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    notesController.dispose();
  }

  Future<void> _showPartnerDeclineDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payState = resolveBookingPaymentState(booking);
    final hasPaidFunds = payState == BookingPaymentState.paid ||
        payState == BookingPaymentState.pendingConfirmation ||
        payState == BookingPaymentState.paymentReview;

    final reasonController = TextEditingController();
    const reasons = [
      'Vehicle unavailable for the selected dates',
      'Scheduled maintenance / repair',
      'Distance / Location issue',
      'Safety policy violation',
      'Other',
    ];
    String selectedReason = reasons.first;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Decline Booking Request',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasPaidFunds) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Payment Alert: The renter has submitted or completed payment. Declining will initiate a refund requirement for reimbursement.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Text('Reason for decline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          ...reasons.map((reason) {
                            final selected = selectedReason == reason;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => setDialogState(() => selectedReason = reason),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected ? AppColors.primary : (isDark ? Colors.white12 : Colors.grey.shade300),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                        size: 18,
                                        color: selected ? AppColors.primary : Colors.grey,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          reason,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (selectedReason == 'Other') ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: reasonController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Please specify the reason...',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final finalReason = selectedReason == 'Other' && reasonController.text.trim().isNotEmpty
                                  ? reasonController.text.trim()
                                  : selectedReason;
                              Navigator.pop(dialogContext);
                              _handleBookingAction(bookingId, 'cancelled', reason: finalReason);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Decline Booking', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    reasonController.dispose();
  }

  Future<void> _showPartnerBookingRefundDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renter = booking['users'] as Map<String, dynamic>? ?? booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renterName = renter['full_name']?.toString() ?? 'Renter';
    final renterPhone = renter['phone_number']?.toString() ?? renter['phone']?.toString() ?? '';
    final vehicleTitle = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();

    final renterUserId = (booking['renter_id'] ?? renter['id'] ?? renter['user_id'])?.toString();
    List<PayoutMethod> renterPayoutMethods = [];
    String? discoveredQrUrl;

    if (renterUserId != null && renterUserId.isNotEmpty) {
      try {
        renterPayoutMethods = await PayoutMethodService().getPayoutMethods(renterUserId);
      } catch (_) {}
      try {
        discoveredQrUrl = await PayoutMethodService().getRenterQrCodeUrl(renterUserId);
      } catch (_) {}
    }

    final directQrUrl = (discoveredQrUrl != null && discoveredQrUrl.isNotEmpty)
        ? discoveredQrUrl
        : (renter['qr_code_url']?.toString() ?? renter['gcash_qr_url']?.toString() ?? renter['payout_qr_url']?.toString());

    final isAlreadyRefunded = booking['refund_status'] == 'refunded' || booking['refund_completed'] == true;
    final defaultRefundAmount = resolveBookingRefundAmount(booking);

    final refundAmountController = TextEditingController(text: defaultRefundAmount.toStringAsFixed(2));
    final referenceController = TextEditingController(text: booking['refund_ref']?.toString() ?? '');
    final notesController = TextEditingController(text: booking['refund_notes']?.toString() ?? '');
    String selectedMethod = booking['refund_method']?.toString() ?? (renterPayoutMethods.isNotEmpty ? renterPayoutMethods.first.provider : 'GCash');
    PlatformFile? receiptFile;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final refundAmount = double.tryParse(refundAmountController.text) ?? defaultRefundAmount;

          final activeMethod = renterPayoutMethods.firstWhere(
            (m) => m.provider.toLowerCase() == selectedMethod.toLowerCase(),
            orElse: () => renterPayoutMethods.isNotEmpty
                ? renterPayoutMethods.first
                : PayoutMethod(
                    id: '',
                    provider: selectedMethod,
                    accountName: renterName,
                    accountNumber: renterPhone,
                    qrCodeUrl: directQrUrl,
                    createdAt: DateTime.now(),
                  ),
          );

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isAlreadyRefunded
                                ? const Color(0xFFA855F7).withOpacity(0.15)
                                : const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isAlreadyRefunded ? Icons.check_circle_rounded : Icons.currency_exchange_rounded,
                            color: isAlreadyRefunded ? const Color(0xFFA855F7) : const Color(0xFFEF4444),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAlreadyRefunded ? 'Refund Details' : 'Process Booking Refund',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$renterName • $vehicleTitle',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isAlreadyRefunded
                                  ? const Color(0xFFA855F7).withOpacity(0.12)
                                  : const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAlreadyRefunded
                                    ? const Color(0xFFA855F7).withOpacity(0.35)
                                    : const Color(0xFFEF4444).withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isAlreadyRefunded ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                  color: isAlreadyRefunded ? const Color(0xFFA855F7) : const Color(0xFFEF4444),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isAlreadyRefunded
                                        ? 'Refund completed: PHP ${refundAmount.toStringAsFixed(2)} was disbursed to renter.'
                                        : 'Booking was declined after payment. Please disburse the refund to the renter.',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Payout Method Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF101928) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Renter Payout Destination', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (activeMethod.qrCodeUrl != null && activeMethod.qrCodeUrl!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          activeMethod.qrCodeUrl!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.account_balance_wallet_outlined, size: 24),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activeMethod.accountName.isNotEmpty ? activeMethod.accountName : renterName,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${activeMethod.provider}: ${activeMethod.accountNumber.isNotEmpty ? activeMethod.accountNumber : renterPhone}',
                                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Refund Amount
                          const Text('Refund Amount (PHP)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: refundAmountController,
                            readOnly: isAlreadyRefunded,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: 'PHP ',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Method & Ref
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Payout Method', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: selectedMethod,
                                      isDense: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      items: ['GCash', 'Maya', 'Bank Transfer', 'Cash']
                                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 11))))
                                          .toList(),
                                      onChanged: isAlreadyRefunded ? null : (v) => setDialogState(() => selectedMethod = v ?? 'GCash'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Reference No.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: referenceController,
                                      readOnly: isAlreadyRefunded,
                                      decoration: InputDecoration(
                                        hintText: 'e.g. 1002345892',
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Screenshot upload
                          const Text('Transfer Screenshot / Receipt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          if (isAlreadyRefunded)
                            Builder(
                              builder: (_) {
                                final receipt = booking['refund_receipt_url']?.toString();
                                if (receipt != null && receipt.isNotEmpty) {
                                  return Text('Proof URL: $receipt', style: const TextStyle(fontSize: 11, color: AppColors.primary));
                                }
                                return const Text('No receipt attached.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic));
                              },
                            )
                          else if (receiptFile == null)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
                                  withData: true,
                                );
                                if (result != null && result.files.isNotEmpty) {
                                  setDialogState(() => receiptFile = result.files.first);
                                }
                              },
                              icon: const Icon(Icons.upload_file_rounded, size: 16),
                              label: const Text('Upload Transfer Receipt', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(receiptFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    onPressed: () => setDialogState(() => receiptFile = null),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        if (!isAlreadyRefunded) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final ref = referenceController.text.trim();
                                      if (ref.isEmpty) {
                                        _showErrorSnackBar('Please provide a reference number for the refund transfer.');
                                        return;
                                      }
                                      setDialogState(() => isSubmitting = true);
                                      try {
                                        String uploadedReceiptUrl = '';
                                        if (receiptFile?.bytes != null) {
                                          final currentUserId = AuthService().currentUser?.id ?? '';
                                          uploadedReceiptUrl = await BookingInspectionService().uploadEvidenceBytes(
                                            userId: currentUserId,
                                            bookingId: bookingId,
                                            bytes: receiptFile!.bytes!,
                                            extension: receiptFile!.extension ?? 'jpg',
                                          );
                                        }

                                        await BookingService().settleBookingRefund(
                                          bookingId: bookingId,
                                          amount: refundAmount,
                                          method: selectedMethod,
                                          reference: ref,
                                          receiptUrl: uploadedReceiptUrl,
                                          notes: notesController.text.trim(),
                                        );

                                        booking['refund_status'] = 'refunded';
                                        booking['refund_completed'] = true;
                                        booking['refund_amount'] = refundAmount;
                                        booking['refund_ref'] = ref;
                                        booking['refund_method'] = selectedMethod;
                                        booking['refund_receipt_url'] = uploadedReceiptUrl;

                                        final idx = bookings.indexWhere((b) => b['id']?.toString() == bookingId);
                                        if (idx != -1) {
                                          bookings[idx]['refund_status'] = 'refunded';
                                          bookings[idx]['refund_completed'] = true;
                                          bookings[idx]['refund_amount'] = refundAmount;
                                          bookings[idx]['refund_ref'] = ref;
                                          bookings[idx]['refund_method'] = selectedMethod;
                                          bookings[idx]['refund_receipt_url'] = uploadedReceiptUrl;
                                        }

                                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                                        _loadPartnerData(silent: true);
                                        _showSuccessSnackBar('✅ Refund of PHP ${refundAmount.toStringAsFixed(2)} recorded successfully.');
                                      } catch (e) {
                                        setDialogState(() => isSubmitting = false);
                                        _showErrorSnackBar('Failed to complete refund: $e');
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                              label: Text(
                                isSubmitting ? 'Recording...' : 'Confirm & Complete Refund',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    refundAmountController.dispose();
    referenceController.dispose();
    notesController.dispose();
  }

  /// Dialog for Partner to process/settle an extension fee refund when paid extension is declined.
  Future<void> _showPartnerExtensionRefundDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renter = booking['users'] as Map<String, dynamic>? ?? booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renterName = renter['full_name']?.toString() ?? 'Renter';
    final renterPhone = renter['phone_number']?.toString() ?? renter['phone']?.toString() ?? '';
    final vehicleTitle = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();

    final renterUserId = (booking['renter_id'] ?? renter['id'] ?? renter['user_id'])?.toString();
    List<PayoutMethod> renterPayoutMethods = [];
    String? discoveredQrUrl;

    if (renterUserId != null && renterUserId.isNotEmpty) {
      try {
        renterPayoutMethods = await PayoutMethodService().getPayoutMethods(renterUserId);
      } catch (_) {}
      try {
        discoveredQrUrl = await PayoutMethodService().getRenterQrCodeUrl(renterUserId);
      } catch (_) {}
    }

    final directQrUrl = (discoveredQrUrl != null && discoveredQrUrl.isNotEmpty)
        ? discoveredQrUrl
        : (renter['qr_code_url']?.toString() ?? renter['gcash_qr_url']?.toString() ?? renter['payout_qr_url']?.toString());

    final isAlreadyRefunded = booking['extension_refund_status'] == 'refunded' || booking['extension_refund_completed'] == true;
    final defaultRefundAmount = (booking['extension_additional_price'] as num?)?.toDouble() ??
        (booking['extension_refund_amount'] as num?)?.toDouble() ??
        0.0;

    final refundAmountController = TextEditingController(text: defaultRefundAmount.toStringAsFixed(2));
    final referenceController = TextEditingController(text: booking['extension_refund_ref']?.toString() ?? '');
    final notesController = TextEditingController(text: booking['extension_refund_notes']?.toString() ?? '');
    String selectedMethod = booking['extension_refund_method']?.toString() ??
        booking['extension_payment_method']?.toString() ??
        (renterPayoutMethods.isNotEmpty ? renterPayoutMethods.first.provider : 'GCash');
    PlatformFile? receiptFile;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final refundAmount = double.tryParse(refundAmountController.text) ?? defaultRefundAmount;

          final activeMethod = renterPayoutMethods.firstWhere(
            (m) => m.provider.toLowerCase() == selectedMethod.toLowerCase(),
            orElse: () => renterPayoutMethods.isNotEmpty
                ? renterPayoutMethods.first
                : PayoutMethod(
                    id: '',
                    provider: selectedMethod,
                    accountName: renterName,
                    accountNumber: renterPhone,
                    qrCodeUrl: directQrUrl,
                    createdAt: DateTime.now(),
                  ),
          );

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isAlreadyRefunded
                                ? const Color(0xFFA855F7).withValues(alpha: 0.15)
                                : const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isAlreadyRefunded ? Icons.check_circle_rounded : Icons.currency_exchange_rounded,
                            color: isAlreadyRefunded ? const Color(0xFFA855F7) : const Color(0xFFEF4444),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAlreadyRefunded ? 'Extension Refund Details' : 'Process Extension Fee Refund',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$renterName • $vehicleTitle',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isAlreadyRefunded
                                  ? const Color(0xFFA855F7).withValues(alpha: 0.12)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAlreadyRefunded
                                    ? const Color(0xFFA855F7).withValues(alpha: 0.35)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isAlreadyRefunded ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                  color: isAlreadyRefunded ? const Color(0xFFA855F7) : const Color(0xFFEF4444),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isAlreadyRefunded
                                        ? 'Extension fee refund completed: PHP ${refundAmount.toStringAsFixed(2)} was disbursed to renter.'
                                        : 'Trip extension was declined after payment was received. Please disburse the refund of PHP ${refundAmount.toStringAsFixed(2)} to the renter.',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Renter Original Payment info
                          if (booking['extension_payment_reference'] != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF101928) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Renter Extension Payment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${booking['extension_payment_method'] ?? 'E-Wallet'} • Ref: ${booking['extension_payment_reference'] ?? 'N/A'} • Amount: PHP ${defaultRefundAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Payout Destination Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF101928) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Renter Payout Destination', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (activeMethod.qrCodeUrl != null && activeMethod.qrCodeUrl!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          activeMethod.qrCodeUrl!,
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.qr_code, size: 50),
                                        ),
                                      ),
                                    if (activeMethod.qrCodeUrl != null && activeMethod.qrCodeUrl!.isNotEmpty)
                                      const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activeMethod.provider.toUpperCase(),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text('Name: ${activeMethod.accountName}', style: const TextStyle(fontSize: 11)),
                                          Text('No: ${activeMethod.accountNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Refund Form
                          const Text('Refund Disbursement Amount (PHP)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: refundAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            readOnly: isAlreadyRefunded,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              prefixText: 'PHP ',
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Refund Method', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: selectedMethod,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      items: ['GCash', 'Maya', 'Bank Transfer', 'Cash']
                                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 11))))
                                          .toList(),
                                      onChanged: isAlreadyRefunded ? null : (v) => setDialogState(() => selectedMethod = v ?? 'GCash'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Reference No.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: referenceController,
                                      readOnly: isAlreadyRefunded,
                                      decoration: InputDecoration(
                                        hintText: 'e.g. 1002345892',
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Screenshot upload
                          const Text('Transfer Screenshot / Receipt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          if (isAlreadyRefunded)
                            Builder(
                              builder: (_) {
                                final receipt = booking['extension_refund_receipt_url']?.toString();
                                if (receipt != null && receipt.isNotEmpty) {
                                  return Text('Proof URL: $receipt', style: const TextStyle(fontSize: 11, color: AppColors.primary));
                                }
                                return const Text('No receipt attached.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic));
                              },
                            )
                          else if (receiptFile == null)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
                                  withData: true,
                                );
                                if (result != null && result.files.isNotEmpty) {
                                  setDialogState(() => receiptFile = result.files.first);
                                }
                              },
                              icon: const Icon(Icons.upload_file_rounded, size: 16),
                              label: const Text('Upload Transfer Receipt', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(receiptFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    onPressed: () => setDialogState(() => receiptFile = null),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        if (!isAlreadyRefunded) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final ref = referenceController.text.trim();
                                      if (ref.isEmpty) {
                                        _showErrorSnackBar('Please provide a reference number for the refund transfer.');
                                        return;
                                      }
                                      setDialogState(() => isSubmitting = true);
                                      try {
                                        String uploadedReceiptUrl = '';
                                        if (receiptFile?.bytes != null) {
                                          final currentUserId = AuthService().currentUser?.id ?? '';
                                          uploadedReceiptUrl = await BookingInspectionService().uploadEvidenceBytes(
                                            userId: currentUserId,
                                            bookingId: bookingId,
                                            bytes: receiptFile!.bytes!,
                                            extension: receiptFile!.extension ?? 'jpg',
                                          );
                                        }

                                        final currentPartnerId = partnerId ?? AuthService().currentUser?.id;
                                        await BookingService().settleExtensionRefund(
                                          bookingId: bookingId,
                                          amount: refundAmount,
                                          method: selectedMethod,
                                          reference: ref,
                                          receiptUrl: uploadedReceiptUrl,
                                          notes: notesController.text.trim(),
                                          settlerId: currentPartnerId,
                                        );

                                        booking['extension_refund_status'] = 'refunded';
                                        booking['extension_refund_completed'] = true;
                                        booking['extension_refund_amount'] = refundAmount;
                                        booking['extension_refund_ref'] = ref;
                                        booking['extension_refund_method'] = selectedMethod;
                                        booking['extension_refund_receipt_url'] = uploadedReceiptUrl;

                                        final idx = bookings.indexWhere((b) => b['id']?.toString() == bookingId);
                                        if (idx != -1) {
                                          bookings[idx]['extension_refund_status'] = 'refunded';
                                          bookings[idx]['extension_refund_completed'] = true;
                                          bookings[idx]['extension_refund_amount'] = refundAmount;
                                          bookings[idx]['extension_refund_ref'] = ref;
                                          bookings[idx]['extension_refund_method'] = selectedMethod;
                                          bookings[idx]['extension_refund_receipt_url'] = uploadedReceiptUrl;
                                        }

                                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                                        _loadPartnerData(silent: true);
                                        _showSuccessSnackBar('✅ Extension fee refund of PHP ${refundAmount.toStringAsFixed(2)} recorded successfully.');
                                      } catch (e) {
                                        setDialogState(() => isSubmitting = false);
                                        _showErrorSnackBar('Failed to complete extension refund: $e');
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                              label: Text(
                                isSubmitting ? 'Recording...' : 'Confirm & Complete Refund',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    refundAmountController.dispose();
    referenceController.dispose();
    notesController.dispose();
  }
}

