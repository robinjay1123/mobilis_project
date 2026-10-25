part of '../driver_home_screen.dart';

// DASHBOARD TAB
class _DashboardTab extends StatefulWidget {
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenEarnings;
  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenApplication;
  final VoidCallback onOpenRatings;

  const _DashboardTab({
    required this.onOpenMenu,
    required this.onOpenBookings,
    required this.onOpenMessages,
    required this.onOpenEarnings,
    required this.onOpenAvailability,
    required this.onOpenApplication,
    required this.onOpenRatings,
  });

  @override
  State<_DashboardTab> createState() => __DashboardTabState();
}

class __DashboardTabState extends State<_DashboardTab> {
  late Future<Map<String, dynamic>> driverStatsFuture;
  late Future<List<Map<String, dynamic>>> pendingOffersFuture;
  late Future<List<Map<String, dynamic>>> assignedBookingsFuture;
  late Future<String?> avatarUrlFuture;
  String verificationStatus = 'pending';
  String certificationStatus = 'basic'; // 'basic', 'approved', 'certified'
  bool hasPendingVerification = false;
  bool hasLoadedDriverStatus = false;
  bool dismissedVerificationBanner = false;
  int verificationSkipCount = 0; // Track how many times skipped
  RealtimeChannel? _jobFlowChannel;
  Timer? _jobFlowRefreshDebounce;

  @override
  void initState() {
    super.initState();
    final authService = AuthService();
    final driverService = DriverService();
    if (authService.currentUser != null) {
      driverStatsFuture = _loadDriverStats(
        driverService,
        authService.currentUser!.id,
      );
      pendingOffersFuture = driverService.getPendingOffers(
        authService.currentUser!.id,
      );
      assignedBookingsFuture = driverService.getAssignedBookings(
        authService.currentUser!.id,
      );
      avatarUrlFuture = _loadDriverAvatarUrl(authService.currentUser!.id);
      _setupJobFlowListener(authService.currentUser!.id);
    } else {
      driverStatsFuture = Future.value({});
      pendingOffersFuture = Future.value([]);
      assignedBookingsFuture = Future.value([]);
      avatarUrlFuture = Future.value(null);
    }
  }

  @override
  void dispose() {
    _jobFlowRefreshDebounce?.cancel();
    _jobFlowChannel?.unsubscribe();
    super.dispose();
  }

  void _setupJobFlowListener(String userId) {
    _jobFlowChannel = Supabase.instance.client.realtime.channel(
      'driver-job-flow-$userId',
    );
    void refreshFlow(PostgresChangePayload payload) {
      if (!mounted) return;
      _jobFlowRefreshDebounce?.cancel();
      _jobFlowRefreshDebounce = Timer(
        const Duration(milliseconds: 350),
        _refreshDriverData,
      );
    }

    _jobFlowChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_job_assignments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: userId,
          ),
          callback: refreshFlow,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: userId,
          ),
          callback: refreshFlow,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'booking_payouts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_user_id',
            value: userId,
          ),
          callback: refreshFlow,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_earnings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: userId,
          ),
          callback: refreshFlow,
        )
        .subscribe();
  }

  void _refreshDriverData() {
    final userId = AuthService().currentUser?.id;
    setState(() {
      final driverService = DriverService();
      if (userId == null) {
        driverStatsFuture = Future.value({});
        pendingOffersFuture = Future.value([]);
        assignedBookingsFuture = Future.value([]);
        avatarUrlFuture = Future.value(null);
        hasLoadedDriverStatus = false;
      } else {
        hasLoadedDriverStatus = false;
        driverStatsFuture = _loadDriverStats(driverService, userId);
        pendingOffersFuture = driverService.getPendingOffers(userId);
        assignedBookingsFuture = driverService.getAssignedBookings(userId);
        avatarUrlFuture = _loadDriverAvatarUrl(userId);
      }
    });
  }

  Future<Map<String, dynamic>> _loadDriverStats(
    DriverService driverService,
    String userId,
  ) async {
    NotificationService()
        .checkAndNotifyExpiringDocuments(daysThreshold: 90)
        .catchError((error) {
          debugPrint('Driver expiry notification check skipped: $error');
          return 0;
        });
    final stats = await driverService.getDriverStats(userId);
    final verification = await VerificationService.getUserVerification(userId);
    final verificationRecordStatus =
        (verification?['verification_status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final nextVerificationStatus = _normalizeStatus(
      verificationRecordStatus.isNotEmpty
          ? verificationRecordStatus
          : (stats['verification_status'] ??
                stats['verification'] ??
                'pending'),
    );
    final certificationApplicationStatus = await driverService
        .getCertificationApplicationStatus(userId);
    final nextCertificationStatus = _normalizeStatus(
      certificationApplicationStatus.isNotEmpty
          ? certificationApplicationStatus
          : (stats['application_status'] ??
                stats['driver_application_status'] ??
                stats['driver_tier'] ??
                stats['tier'] ??
                'basic'),
      fallback: 'basic',
    );

    if (mounted) {
      setState(() {
        verificationStatus = nextVerificationStatus;
        certificationStatus = nextCertificationStatus;
        hasPendingVerification = verificationRecordStatus == 'pending' ||
            nextVerificationStatus == 'pending' ||
            nextCertificationStatus == 'pending';
        hasLoadedDriverStatus = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showVerificationPopupIfNeeded();
      });
    }

    return stats;
  }

  bool _hasCheckedAvailabilityPrompt = false;

  void _showVerificationPopupIfNeeded() {
    final isPending = hasPendingVerification ||
        verificationStatus == 'pending' ||
        verificationStatus == 'submitted' ||
        certificationStatus == 'pending';
    // 1. Only show popup if not yet verified and not pending and skip count is less than 3
    if (!_isVerified &&
        !isPending &&
        verificationSkipCount % 3 == 0) {
      _showVerificationPopup();
      return;
    }

    // 2. If already verified, prompt to set availability if not yet configured
    if (_isVerified && !_hasCheckedAvailabilityPrompt) {
      _hasCheckedAvailabilityPrompt = true;
      _checkAndShowAvailabilityPrompt();
    }
  }

  Future<void> _checkAndShowAvailabilityPrompt() async {
    final userId = AuthService().currentUser?.id;
    if (userId == null || !mounted) return;

    try {
      final schedule = await DriverService().getSchedule(userId);
      if (!mounted) return;
      if (schedule.isEmpty) {
        _showVerifiedSetAvailabilityDialog();
      }
    } catch (e) {
      debugPrint('Error checking driver schedule for prompt: $e');
    }
  }

  void _showVerifiedSetAvailabilityDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Set Your Availability',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎉 Congratulations! Your driver account has been verified.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Set your available working dates and hours so operators and partners can assign upcoming trips to you.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            _buildVerificationBenefit(
              icon: Icons.event_available,
              text: 'Choose the exact dates you want to work',
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildVerificationBenefit(
              icon: Icons.notifications_active_outlined,
              text: 'Receive trip offers directly on your active dates',
              isDark: isDark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Later',
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onOpenAvailability();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Set Availability',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeStatus(dynamic value, {String fallback = 'pending'}) {
    final status = value?.toString().trim().toLowerCase() ?? '';
    return status.isEmpty || status == 'null' ? fallback : status;
  }

  bool get _isVerified {
    return verificationStatus == 'verified' ||
        verificationStatus == 'approved' ||
        verificationStatus == 'certified';
  }

  bool get _isCertifiedDriver {
    return certificationStatus == 'certified' ||
        certificationStatus == 'approved';
  }

  void _showVerificationPopup() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPending =
        hasPendingVerification ||
        verificationStatus == 'pending' ||
        verificationStatus == 'submitted';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPending ? Icons.hourglass_top : Icons.verified_user,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isPending
                    ? 'Verification Under Review'
                    : 'Verify Your Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogStatusIndicator(
              isComplete: false,
              completeLabel: 'Verification complete',
              incompleteLabel:
                  isPending ? 'Under Review' : 'Verification required',
              incompleteDetail: isPending
                  ? 'Your verification documents have been submitted and are under review by admin.'
                  : 'Complete your identity verification to unlock driver features.',
            ),
            const SizedBox(height: 12),
            Text(
              isPending ? 'Review Timeline:' : 'Get verified to unlock:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildVerificationBenefit(
              icon: Icons.shield,
              text: isPending
                  ? 'Admin is reviewing your license and NBI documents'
                  : 'Higher visibility to customers',
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildVerificationBenefit(
              icon: Icons.schedule,
              text: isPending
                  ? 'Most reviews complete within 1-2 hours'
                  : 'Build trust and credibility',
              isDark: isDark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => verificationSkipCount++);
              Navigator.pop(context);
            },
            child: Text(
              isPending ? 'Close' : 'Skip for Now',
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                isPending
                    ? '/account-verification'
                    : '/driver-identity-verification',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isPending ? 'Check Status' : 'Verify Now',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBenefit({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String _displayName() {
    final user = AuthService().currentUser;
    final metadataName = user?.userMetadata?['full_name']?.toString().trim();
    if (metadataName != null && metadataName.isNotEmpty) return metadataName;
    return user?.email?.split('@').first ?? 'Driver';
  }

  double _numValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  Map<String, dynamic>? _activeBooking(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) return null;

    // Terminal statuses — never show these in the Active Booking card.
    const terminalStatuses = {
      'completed',
      'returned',
      'cancelled',
      'canceled',
      'rejected',
      'declined',
      'refunded',
      'expired',
    };

    // Filter out any bookings that are fully done/cancelled.
    final activeBookings = bookings.where((b) {
      final status = b['status']?.toString().toLowerCase() ?? '';
      return !terminalStatuses.contains(status);
    }).toList();

    if (activeBookings.isEmpty) return null;

    const preferredStatuses = {
      'active',
      'ongoing',
      'approved',
      'confirmed',
      'driver_accepted',
      'pending_inspection',
      'return_pending_inspection',
      'awaiting_completion',
      'pending',
    };

    for (final booking in activeBookings) {
      final status = booking['status']?.toString().toLowerCase();
      if (preferredStatuses.contains(status)) return booking;
    }

    // Fallback: the first non-terminal booking.
    return activeBookings.first;
  }

  String _bookingRenterName(Map<String, dynamic> booking) {
    final renter = booking['renter'];
    if (renter is Map) {
      final name = renter['full_name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      final email = renter['email']?.toString();
      if (email != null && email.isNotEmpty) return email.split('@').first;
    }
    return booking['renter_name']?.toString() ?? 'Renter';
  }

  String _bookingVehicleName(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'];
    if (vehicle is Map) {
      final vehicleName = vehicle['vehicle_name']?.toString().trim();
      if (vehicleName != null && vehicleName.isNotEmpty) return vehicleName;
      final brand = vehicle['brand']?.toString().trim() ?? '';
      final model = vehicle['model']?.toString().trim() ?? '';
      final combined = '$brand $model'.trim();
      if (combined.isNotEmpty) return combined;
    }
    return booking['vehicle_name']?.toString() ?? 'Assigned Vehicle';
  }

  String _bookingPickupLocation(Map<String, dynamic> booking) {
    final pickup = booking['pickup_location'] ?? booking['pickupLocation'];
    final value = pickup?.toString().trim();
    return value == null || value.isEmpty ? 'Pickup location pending' : value;
  }

  String _bookingStartLabel(Map<String, dynamic> booking) {
    final raw = booking['start_at'] ?? booking['start_date'];
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return 'Schedule pending';
    const months = [
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
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${months[parsed.month - 1]} ${parsed.day} • $hour:$minute $suffix';
  }

  Widget _buildHeader(Map<String, dynamic> stats) {
    final displayName = _displayName();
    final badge = _getDriverBadge();
    final badgeColor = _getDriverBadgeColor();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: widget.onOpenMenu,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFFFEDD6),
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<String?>(
                future: avatarUrlFuture,
                builder: (context, snapshot) {
                  final avatarUrl = snapshot.data ?? '';
                  if (avatarUrl.isNotEmpty) {
                    return OptimizedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorWidget: _DriverInitial(
                        displayName: displayName,
                        fontSize: 20,
                      ),
                    );
                  }
                  return _DriverInitial(displayName: displayName, fontSize: 20);
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _driverPrimaryText(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> stats) {
    final earnings = _numValue(stats, ['earnings', 'total_earnings']);
    final rating = _numValue(stats, ['rating', 'average_rating']);

    return Row(
      children: [
        Expanded(
          child: _DriverMetricCard(
            label: 'Earnings',
            value: formatAmount(earnings, decimalDigits: 0),
            footer: 'EARNED',
            footerColor: const Color(0xFF48E0B5),
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DriverMetricCard(
            label: 'Rating',
            value: rating <= 0 ? '0.0' : rating.toStringAsFixed(1),
            footer: rating >= 4.7 ? 'TOP RATED' : 'BUILDING',
            footerColor: AppColors.primary,
            icon: Icons.star,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DriverMetricCard(
            label: 'Identity',
            value: '',
            footer: _isVerified ? 'VERIFIED' : 'PENDING',
            footerColor: _isVerified
                ? const Color(0xFF48E0B5)
                : AppColors.primary,
            icon: Icons.verified_user,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveBookingSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: assignedBookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _DriverLoadingCard(label: 'Loading active booking...');
        }

        final booking = _activeBooking(snapshot.data ?? []);
        if (booking == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _driverCardColor(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _driverBorderColor(context)),
            ),
            child: Text(
              'No active booking yet. New assigned trips will appear here.',
              style: TextStyle(
                color: _driverSecondaryText(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _driverCardColor(context),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _driverBorderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (booking['status']?.toString().toLowerCase() == 'driver_accepted') ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.45)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You accepted this job! Waiting for operator/partner finalization.',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Next Pickup',
                              style: TextStyle(
                                color: Color(0xFF9DAEC4),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (booking['status']?.toString().toLowerCase() == 'driver_accepted') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                                ),
                                child: const Text(
                                  'ACCEPTED',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _bookingRenterName(booking),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Vehicle',
                        style: TextStyle(
                          color: Color(0xFF9DAEC4),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          _bookingVehicleName(booking),
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFF1B3047)),
              const SizedBox(height: 16),
              _DriverInfoLine(
                icon: Icons.calendar_month,
                text: _bookingStartLabel(booking),
              ),
              const SizedBox(height: 16),
              _DriverInfoLine(
                icon: Icons.location_on,
                text: _bookingPickupLocation(booking),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final bookingId = booking['id']?.toString() ?? '';
                        if (bookingId.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TripNavigationScreen(
                                bookingId: bookingId,
                                participantRole: 'driver',
                              ),
                            ),
                          );
                        } else {
                          widget.onOpenBookings();
                        }
                      },
                      icon: const Icon(Icons.navigation, color: Colors.black),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Navigate'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenMessages,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Message'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: Color(0xFF2F5D86)),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _DriverQuickActionCard(
          icon: Icons.calendar_month,
          label: 'Booking',
          onTap: widget.onOpenBookings,
        ),
        _DriverQuickActionCard(
          icon: Icons.event_available_rounded,
          label: 'Set Availability',
          onTap: () {
            if (!_isVerified) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Your driver account must be verified before setting availability.',
                  ),
                  backgroundColor: AppColors.warning,
                ),
              );
              return;
            }
            widget.onOpenAvailability();
          },
        ),
        _DriverQuickActionCard(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Application',
          onTap: widget.onOpenApplication,
        ),
        _DriverQuickActionCard(
          icon: Icons.payments,
          label: 'Revenue',
          onTap: widget.onOpenEarnings,
        ),
        _DriverQuickActionCard(
          icon: Icons.star_outline_rounded,
          label: 'Review & Ratings',
          onTap: widget.onOpenRatings,
        ),
        _DriverQuickActionCard(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Messages',
          onTap: widget.onOpenMessages,
        ),
      ],
    );
  }

  bool _isCertifiedFromStats(Map<String, dynamic> stats) {
    if (_isCertifiedDriver || _isVerified) return true;

    final resolvedCertification =
        certificationStatus.isNotEmpty && certificationStatus != 'basic'
            ? certificationStatus
            : null;

    final status = _normalizeStatus(
      resolvedCertification ??
          stats['application_status'] ??
          stats['driver_application_status'] ??
          stats['driver_tier'] ??
          stats['tier'] ??
          certificationStatus,
      fallback: 'basic',
    );

    return status == 'approved' ||
        status == 'certified' ||
        status == 'verified';
  }

  bool _isVerifiedFromStats(Map<String, dynamic> stats) {
    final status = _normalizeStatus(
      stats['verification_status'] ??
          stats['verification'] ??
          verificationStatus,
    );

    return status == 'verified' ||
        status == 'approved' ||
        status == 'certified';
  }

  bool _isDriverVerified(Map<String, dynamic> stats) {
    return _isVerified ||
        _isVerifiedFromStats(stats) ||
        _isCertifiedDriver ||
        _isCertifiedFromStats(stats);
  }

  Widget _buildDriverApplicationCta(Map<String, dynamic> stats) {
    final isCertified =
        _isCertifiedDriver || _isVerified || _isCertifiedFromStats(stats);
    if (isCertified) return const SizedBox.shrink();

    final isPending = hasPendingVerification ||
        verificationStatus == 'pending' ||
        verificationStatus == 'submitted' ||
        certificationStatus == 'pending';
    final isVerified = _isVerifiedFromStats(stats);
    final title = isPending
        ? 'Application Under Review'
        : isVerified
            ? 'Apply as a Driver'
            : 'Start Driver Application';
    final subtitle = isPending
        ? 'Your driver requirements and documents are currently under admin review.'
        : isVerified
            ? 'Submit your driver requirements and documents for final review.'
            : 'Complete identity verification and submit the documents needed to become a Mobilis driver.';
    final buttonLabel = isPending ? 'Check Status' : 'Apply';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF082E49),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPending
                  ? Icons.hourglass_top_rounded
                  : Icons.assignment_turned_in_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: widget.onOpenApplication,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableNotice(Map<String, dynamic> stats) {
    if (!_isDriverVerified(stats)) {
      return const SizedBox.shrink();
    }

    final isAvailable = stats['is_available'] == true;
    final accentColor =
        isAvailable ? const Color(0xFF10B981) : const Color(0xFFFFB300);
    final cardBgColor =
        isAvailable ? const Color(0xFF06281E) : const Color(0xFF1C1304);
    final subtextColor =
        isAvailable ? const Color(0xFFA7F3D0) : const Color(0xFFFFE082);
    final iconData = isAvailable
        ? Icons.check_circle_rounded
        : Icons.pause_circle_filled_rounded;
    final titleText =
        isAvailable ? 'YOU ARE AVAILABLE' : 'YOU ARE UNAVAILABLE';
    final subtitleText = isAvailable
        ? 'Active for trips! Tap to update dates or schedule.'
        : 'Set your availability now to receive job assignments!';

    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              iconData,
              color: accentColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitleText,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: widget.onOpenAvailability,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Set Availability',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondaryText = _driverSecondaryText(context);
    return RefreshIndicator(
      onRefresh: () async => _refreshDriverData(),
      color: AppColors.primary,
      backgroundColor: _driverCardColor(context),
      child: FutureBuilder<Map<String, dynamic>>(
        future: driverStatsFuture,
        builder: (context, snapshot) {
          final stats = snapshot.data ?? {};
          final statusLoaded =
              snapshot.connectionState == ConnectionState.done &&
              hasLoadedDriverStatus;
          final isCertified =
              _isCertifiedDriver || _isVerified || _isCertifiedFromStats(stats);
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            children: [
              _buildHeader(stats),
              const SizedBox(height: 16),
              _buildStats(stats),
              if (_isDriverVerified(stats)) _buildUnavailableNotice(stats),
              if (statusLoaded && !isCertified) ...[
                const SizedBox(height: 24),
                _buildDriverApplicationCta(stats),
                const SizedBox(height: 28),
              ] else
                const SizedBox(height: 24),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: pendingOffersFuture,
                builder: (context, offersSnapshot) {
                  final offers = offersSnapshot.data ?? const [];
                  if (offers.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JOB REQUESTS',
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 14,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...offers.map(
                        (offer) => _DriverOfferCard(
                          offer: offer,
                          onChanged: _refreshDriverData,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ACTIVE BOOKING',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 14,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: pendingOffersFuture,
                    builder: (context, offersSnapshot) {
                      final count = offersSnapshot.data?.length ?? 0;
                      return Container(
                        width: count > 0 ? null : 12,
                        height: count > 0 ? null : 12,
                        padding: count > 0
                            ? const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              )
                            : EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: count > 0
                              ? AppColors.primary
                              : const Color(0xFF12A37C),
                          borderRadius: count > 0
                              ? BorderRadius.circular(18)
                              : null,
                          shape: count > 0
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                        ),
                        child: count > 0
                            ? Text(
                                '$count requests',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildActiveBookingSection(),
              const SizedBox(height: 34),
              Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _buildQuickActions(),
            ],
          );
        },
      ),
    );
  }

  String? _getDriverBadge() {
    if (_isCertifiedDriver) {
      return 'Mobilis Certified Driver';
    }
    if (_isVerified) {
      return 'Basic Driver';
    }
    return null;
  }

  Color _getDriverBadgeColor() {
    if (_isCertifiedDriver) {
      return const Color.fromRGBO(16, 185, 129, 1); // Indigo for certified
    }
    if (_isVerified) {
      return AppColors.success;
    }
    return AppColors.primary;
  }
}

class _DriverMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String footer;
  final Color footerColor;
  final IconData icon;

  const _DriverMetricCard({
    required this.label,
    required this.value,
    required this.footer,
    required this.footerColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _driverBorderColor(context), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _driverSecondaryText(context),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (value.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: _driverPrimaryText(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            Icon(icon, color: footerColor, size: 18),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              footer,
              maxLines: 1,
              style: TextStyle(
                color: footerColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DriverInfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 26),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _driverPrimaryText(context),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverQuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DriverQuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _driverCardColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _driverBorderColor(context), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _driverIsDark(context)
                    ? const Color(0xFF071A2C)
                    : const Color(0xFFFFF6CC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _driverPrimaryText(context),
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverLoadingCard extends StatelessWidget {
  final String label;

  const _DriverLoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _driverBorderColor(context)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              color: _driverSecondaryText(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverTabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;

  const _DriverTabHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _driverBorderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.black, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _driverPrimaryText(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _driverSecondaryText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.45)),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverEmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _DriverEmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = _driverIsDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
          width: 1.2,
        ),
        boxShadow: isDark ? null : AppColors.cardShadowOf(context),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _driverPrimaryText(context),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _driverSecondaryText(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverConversationCard extends StatelessWidget {
  final String title;
  final String message;
  final String timestamp;
  final int unreadCount;
  final VoidCallback onTap;
  final String imageUrl;
  final bool isCustomerService;
  final String? statusBadge;

  const _DriverConversationCard({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.unreadCount,
    required this.onTap,
    this.imageUrl = '',
    this.isCustomerService = false,
    this.statusBadge,
  });

  Widget _buildStatusChip(String label) {
    final bool isOngoing = label.contains('Ongoing') || label.contains('Active');
    final bool isApproved = label.contains('Approved') || label.contains('Confirmed');
    final bool isReadOnly = label.contains('Completed') ||
        label.contains('Read-Only') ||
        label.contains('Cancelled');
    final bool isSupport = label.contains('Support');
    final Color chipColor = isOngoing
        ? AppColors.success
        : (isApproved
            ? AppColors.primary
            : (isSupport
                ? Colors.amber.shade700
                : (isReadOnly ? Colors.purple.shade300 : Colors.blue.shade400)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOngoing
                ? Icons.directions_car_rounded
                : (isApproved
                    ? Icons.verified_rounded
                    : (isReadOnly
                        ? Icons.lock_outline_rounded
                        : (isSupport
                            ? Icons.support_agent
                            : Icons.check_circle_outline_rounded))),
            size: 11,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unreadCount > 0
                  ? AppColors.primary
                  : AppColors.borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.trim().isNotEmpty
                    ? OptimizedNetworkImage(
                        imageUrl: imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(16),
                        errorWidget: const Icon(
                          Icons.directions_car_outlined,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(
                        isCustomerService
                            ? Icons.support_agent
                            : Icons.directions_car_outlined,
                        color: AppColors.primary,
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (statusBadge != null && statusBadge!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _buildStatusChip(statusBadge!),
                        ],
                        if (timestamp.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            timestamp,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

