import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_service.dart';
import '../../../services/tracking_service.dart';
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';

class DriverHomeScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const DriverHomeScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/auth-processing',
        (route) => false,
        arguments: {'mode': 'logout'},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.directions_car,
                color: Colors.black,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Mobilis Driver',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: isDark ? AppColors.darkCard : Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Dashboard'),
                Tab(text: 'Jobs'),
                Tab(text: 'Earnings'),
                Tab(text: 'Availability'),
                Tab(text: 'Profile'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DashboardTab(),
                _JobsTab(),
                _EarningsTab(),
                _AvailabilityTab(),
                _ProfileTab(
                  onThemeToggle: widget.onThemeToggle,
                  isDarkMode: widget.isDarkMode,
                  onLogout: _handleLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// DASHBOARD TAB
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => __DashboardTabState();
}

class __DashboardTabState extends State<_DashboardTab> {
  late Future<Map<String, dynamic>> driverStatsFuture;
  late Future<List<Map<String, dynamic>>> pendingOffersFuture;
  String verificationStatus = 'pending';
  String certificationStatus = 'basic'; // 'basic', 'approved', 'certified'
  bool hasPendingVerification = false;
  bool dismissedVerificationBanner = false;
  int verificationSkipCount = 0; // Track how many times skipped

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
    } else {
      driverStatsFuture = Future.value({});
      pendingOffersFuture = Future.value([]);
    }
  }

  void _refreshPendingOffers() {
    final userId = AuthService().currentUser?.id;
    setState(() {
      pendingOffersFuture = userId == null
          ? Future.value([])
          : DriverService().getPendingOffers(userId);
    });
  }

  Future<Map<String, dynamic>> _loadDriverStats(
    DriverService driverService,
    String userId,
  ) async {
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
    final nextCertificationStatus = _normalizeStatus(
      stats['driver_tier'] ?? stats['tier'] ?? 'basic',
    );

    if (mounted) {
      setState(() {
        verificationStatus = nextVerificationStatus;
        certificationStatus = nextCertificationStatus;
        hasPendingVerification = verificationRecordStatus == 'pending';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showVerificationPopupIfNeeded();
      });
    }

    return stats;
  }

  void _showVerificationPopupIfNeeded() {
    // Only show popup if not yet verified and skip count is less than 3
    // (shows popup every 3 times they skip)
    if (!_isVerified &&
        !hasPendingVerification &&
        verificationSkipCount % 3 == 0) {
      _showVerificationPopup();
    }
  }

  String _normalizeStatus(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';
    if (status == 'approved') return 'verified';
    return status.isEmpty ? 'pending' : status;
  }

  bool get _isVerified {
    return verificationStatus == 'verified' ||
        verificationStatus == 'approved' ||
        verificationStatus == 'certified' ||
        certificationStatus == 'certified';
  }

  void _showVerificationPopup() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.verified_user,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verify Your Account',
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
            Text(
              'Get verified to unlock:',
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
              icon: Icons.trending_up,
              text: 'Higher visibility to customers',
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildVerificationBenefit(
              icon: Icons.shield,
              text: 'Build trust and credibility',
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildVerificationBenefit(
              icon: Icons.star,
              text: 'Access premium features',
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
              'Skip for Now',
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver-identity-verification');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Verify Now',
              style: TextStyle(fontWeight: FontWeight.w600),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Card
          FutureBuilder<Map<String, dynamic>>(
            future: driverStatsFuture,
            builder: (context, snapshot) {
              final stats = snapshot.data ?? {};
              final rating = (stats['rating'] as num?)?.toDouble() ?? 0.0;
              final totalTrips = stats['total_trips'] ?? 0;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderColor
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AuthService()
                                        .currentUser
                                        ?.userMetadata?['full_name'] ??
                                    'Driver',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getDriverBadgeColor().withOpacity(
                                    0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getDriverBadge(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getDriverBadgeColor(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatCard(
                          label: 'Rating',
                          value: rating.toStringAsFixed(1),
                          icon: Icons.star,
                        ),
                        _StatCard(
                          label: 'Trips',
                          value: totalTrips.toString(),
                          icon: Icons.local_taxi,
                        ),
                        _StatCard(
                          label: 'Status',
                          value: 'Active',
                          icon: Icons.check_circle,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Pending Offers Section
          Text(
            'Pending Job Offers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: pendingOffersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final offers = snapshot.data ?? [];
              if (offers.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No pending job offers at the moment',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: offers
                    .map((offer) => _DriverOfferCard(offer: offer))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getDriverBadge() {
    if (certificationStatus == 'certified') {
      return 'CERTIFIED PSDC DRIVER';
    } else if (_isVerified) {
      return 'VERIFIED DRIVER';
    } else if (hasPendingVerification) {
      return 'VERIFICATION PENDING';
    } else {
      return 'BASIC DRIVER';
    }
  }

  Color _getDriverBadgeColor() {
    if (certificationStatus == 'certified') {
      return const Color(0xFF6366F1); // Indigo for certified
    } else if (_isVerified) {
      return AppColors.success;
    } else if (hasPendingVerification) {
      return AppColors.primary;
    } else {
      return AppColors.warning;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// JOBS TAB
class _JobsTab extends StatefulWidget {
  const _JobsTab();

  @override
  State<_JobsTab> createState() => __JobsTabState();
}

class __JobsTabState extends State<_JobsTab> {
  late Future<List<Map<String, dynamic>>> jobsFuture;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  void _loadJobs() {
    final authService = AuthService();
    final driverService = DriverService();
    if (authService.currentUser != null) {
      jobsFuture = driverService.getAssignedBookings(
        authService.currentUser!.id,
      );
    } else {
      jobsFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assigned Trips',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: jobsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final trips = snapshot.data ?? [];

              if (trips.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No assigned trips yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return _TripCard(
                    trip: trip,
                    onChanged: () {
                      setState(() => _loadJobs());
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onChanged;

  const _TripCard({required this.trip, required this.onChanged});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _isTogglingTracking = false;

  Map<String, dynamic> get trip => widget.trip;

  Future<void> _markPickedUp(BuildContext context) async {
    try {
      await DriverService().markAssignedBookingPickedUp(trip['id'].toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip marked as picked up'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      widget.onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markReturned(BuildContext context) async {
    final startDate = DateTime.tryParse(trip['start_date']?.toString() ?? '');
    final scheduledEnd =
        DateTime.tryParse(trip['end_date']?.toString() ?? '') ?? DateTime.now();

    final returnedDate = await showDatePicker(
      context: context,
      initialDate: scheduledEnd,
      firstDate: startDate ?? DateTime(2020),
      lastDate: scheduledEnd.add(const Duration(days: 365)),
    );

    if (returnedDate == null) return;

    try {
      final total = await DriverService().completeAssignedBookingReturn(
        bookingId: trip['id'].toString(),
        returnedAt: returnedDate,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trip completed. Final total: PHP ${total.toStringAsFixed(0)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await TrackingService().stopTracking();
      widget.onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleTracking(BuildContext context) async {
    final userId = AuthService().currentUser?.id;
    final bookingId = trip['id']?.toString() ?? '';
    final vehicleId = trip['vehicle_id']?.toString() ?? '';
    if (userId == null || bookingId.isEmpty || vehicleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip tracking details are incomplete'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isTogglingTracking = true);
    try {
      final trackingService = TrackingService();
      if (trackingService.activeBookingId == bookingId) {
        await trackingService.stopTracking();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location tracking stopped')),
          );
        }
      } else {
        await trackingService.startBookingTracking(
          bookingId: bookingId,
          vehicleId: vehicleId,
          trackedUserId: userId,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location tracking started for this trip'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tracking error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingTracking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = (trip['status']?.toString() ?? 'assigned').toLowerCase();
    final isTrackingThisTrip =
        TrackingService().activeBookingId == (trip['id']?.toString() ?? '');
    final vehicle = trip['vehicles'] as Map<String, dynamic>?;
    final renter = trip['renter'] as Map<String, dynamic>?;
    final renterName = renter?['full_name']?.toString().trim();
    final renterPhone = renter?['phone']?.toString().trim();
    final renterId = trip['renter_id']?.toString() ?? '';
    final startLabel =
        trip['start_at']?.toString() ?? trip['start_date']?.toString() ?? 'N/A';
    final endLabel =
        trip['end_at']?.toString() ?? trip['end_date']?.toString() ?? 'N/A';
    final total =
        (trip['total_price'] as num?)?.toDouble() ??
        (trip['total_cost'] as num?)?.toDouble();
    final vehicleName = vehicle == null
        ? 'Assigned vehicle'
        : [vehicle['vehicle_name'], vehicle['brand'], vehicle['model']]
              .where(
                (part) => part != null && part.toString().trim().isNotEmpty,
              )
              .map((part) => part.toString().trim())
              .take(2)
              .join(' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vehicleName.isEmpty ? 'Assigned vehicle' : vehicleName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trip['status']?.toString() ?? 'assigned',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${trip['pickup_location'] ?? 'Pickup'} to '
            '${trip['dropoff_location'] ?? 'Destination'}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Renter: ${renterName?.isNotEmpty == true ? renterName : 'Unknown'}'
            '${renterPhone != null && renterPhone.isNotEmpty ? ' • $renterPhone' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Renter ID: ${renterId.isNotEmpty ? renterId : 'N/A'}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Schedule: $startLabel -> $endLabel',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          if (total != null) ...[
            const SizedBox(height: 4),
            Text(
              'Booking total: PHP ${total.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (status == 'confirmed' || status == 'approved')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markPickedUp(context),
                icon: const Icon(Icons.key, size: 16),
                label: const Text('Mark Picked Up'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          if (status == 'active')
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isTogglingTracking
                        ? null
                        : () => _toggleTracking(context),
                    icon: Icon(
                      isTrackingThisTrip
                          ? Icons.location_disabled
                          : Icons.my_location,
                      size: 16,
                    ),
                    label: Text(
                      _isTogglingTracking
                          ? 'Updating Tracking...'
                          : isTrackingThisTrip
                          ? 'Stop Location Tracking'
                          : 'Start Location Tracking',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTrackingThisTrip
                          ? AppColors.warning
                          : AppColors.success,
                      foregroundColor: isTrackingThisTrip
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markReturned(context),
                    icon: const Icon(Icons.assignment_turned_in, size: 16),
                    label: const Text('Mark Returned'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DriverOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;

  const _DriverOfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final booking = offer['bookings'] as Map<String, dynamic>?;
    final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
    final renter = booking?['renter'] as Map<String, dynamic>?;
    final assignmentStatus =
        offer['status']?.toString().replaceAll('_', ' ') ?? 'assigned';
    final renterName = renter?['full_name']?.toString().trim();
    final renterPhone = renter?['phone']?.toString().trim();
    final renterId =
        booking?['renter_id']?.toString() ?? renter?['id']?.toString() ?? 'N/A';
    final vehicleName = vehicle == null
        ? 'Assigned vehicle'
        : [vehicle['vehicle_name'], vehicle['brand'], vehicle['model']]
              .where(
                (part) => part != null && part.toString().trim().isNotEmpty,
              )
              .map((part) => part.toString().trim())
              .take(2)
              .join(' ');
    final scheduleStart =
        booking?['start_at']?.toString() ??
        booking?['start_date']?.toString() ??
        'N/A';
    final scheduleEnd =
        booking?['end_at']?.toString() ??
        booking?['end_date']?.toString() ??
        'N/A';
    final total =
        (booking?['total_price'] as num?)?.toDouble() ??
        (booking?['total_cost'] as num?)?.toDouble();
    final tripFee = (offer['trip_fee'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  vehicleName.isEmpty ? 'Assigned vehicle' : vehicleName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  assignmentStatus.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if ((vehicle?['plate_number']?.toString().trim().isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Plate: ${vehicle!['plate_number']}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '${booking?['pickup_location'] ?? 'Pickup'} to '
            '${booking?['dropoff_location'] ?? 'Destination'}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Renter: ${renterName?.isNotEmpty == true ? renterName : 'Unknown'}'
            '${renterPhone != null && renterPhone.isNotEmpty ? ' • $renterPhone' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Renter ID: $renterId',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Schedule: $scheduleStart -> $scheduleEnd',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          if (total != null) ...[
            const SizedBox(height: 4),
            Text(
              'Booking total: PHP ${total.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
          ],
          if (tripFee != null) ...[
            const SizedBox(height: 4),
            Text(
              'Driver fee: PHP ${tripFee.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// EARNINGS TAB
class _EarningsTab extends StatefulWidget {
  const _EarningsTab();

  @override
  State<_EarningsTab> createState() => __EarningsTabState();
}

class __EarningsTabState extends State<_EarningsTab> {
  late Future<double> earningsFuture;

  @override
  void initState() {
    super.initState();
    final authService = AuthService();
    final driverService = DriverService();
    if (authService.currentUser != null) {
      earningsFuture = driverService
          .getEarnings(
            authService.currentUser!.id,
            fromDate: DateTime.now().subtract(const Duration(days: 30)),
            toDate: DateTime.now(),
          )
          .catchError((_) => 0.0);
    } else {
      earningsFuture = Future.value(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<double>(
            future: earningsFuture,
            builder: (context, snapshot) {
              final earnings = snapshot.data ?? 0.0;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earnings (Last 30 Days)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₱${earnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Earnings History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                'No earnings history available',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// AVAILABILITY TAB
class _AvailabilityTab extends StatefulWidget {
  const _AvailabilityTab();

  @override
  State<_AvailabilityTab> createState() => __AvailabilityTabState();
}

class __AvailabilityTabState extends State<_AvailabilityTab> {
  final DriverService _driverService = DriverService();
  bool isAvailable = false;
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final userId = AuthService().currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      final stats = await _driverService.getDriverStats(userId);
      if (!mounted) return;
      setState(() {
        isAvailable = stats['is_available'] == true;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    final userId = AuthService().currentUser?.id;
    if (userId == null || isSaving) return;

    final previous = isAvailable;
    setState(() {
      isAvailable = value;
      isSaving = true;
    });

    try {
      await _driverService.setAvailability(userId, value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'You are now available for driver assignments'
                : 'You are now unavailable for driver assignments',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isAvailable = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update availability: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Availability Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isAvailable ? Icons.check_circle : Icons.pause_circle,
                    color: isAvailable ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are ${isAvailable ? 'Available' : 'Unavailable'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        isAvailable
                            ? 'Receiving job offers'
                            : 'Not receiving jobs',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isAvailable,
                  onChanged: isLoading || isSaving
                      ? null
                      : (value) => _toggleAvailability(value),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ),
          if (isLoading || isSaving) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  isLoading
                      ? 'Loading availability...'
                      : 'Saving availability...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Work Schedule',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                'Your schedule will appear here',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// PROFILE TAB
class _ProfileTab extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;
  final VoidCallback onLogout;

  const _ProfileTab({
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.onLogout,
  });

  @override
  State<_ProfileTab> createState() => __ProfileTabState();
}

class __ProfileTabState extends State<_ProfileTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = AuthService();
    final user = authService.currentUser;
    final displayName =
        user?.userMetadata?['full_name']?.toString().trim().isNotEmpty == true
        ? user!.userMetadata!['full_name'].toString().trim()
        : user?.email?.split('@').first ?? 'Driver';
    final phone = user?.userMetadata?['phone']?.toString() ?? 'Not set';
    final location = user?.userMetadata?['location']?.toString() ?? 'Not set';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: AppColors.success, size: 16),
                    SizedBox(width: 5),
                    Text(
                      'Verified Driver',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _InfoRow(
                  label: 'Email',
                  value: user?.email ?? 'N/A',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Phone', value: phone, isDark: isDark),
                const SizedBox(height: 12),
                _InfoRow(label: 'Location', value: location, isDark: isDark),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Settings Section
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                // Theme Toggle
                _SettingTile(
                  icon: isDark ? Icons.light_mode : Icons.dark_mode,
                  label: 'Appearance',
                  value: isDark ? 'Dark Mode' : 'Light Mode',
                  onTap: () {
                    widget.onThemeToggle?.call(!isDark);
                  },
                  isDark: isDark,
                  isFirst: true,
                ),
                // Logout
                _SettingTile(
                  icon: Icons.verified_user_outlined,
                  label: 'Verification',
                  value: '',
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/driver-identity-verification',
                    );
                  },
                  isDark: isDark,
                ),
                _SettingTile(
                  icon: Icons.logout,
                  label: 'Logout',
                  value: '',
                  onTap: widget.onLogout,
                  isDark: isDark,
                  textColor: Colors.red,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
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
            fontSize: 13,
            color: isDark ? Colors.grey : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isDark;
  final Color? textColor;
  final bool isFirst;
  final bool isLast;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.isDark,
    this.textColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: !isLast
                ? BorderSide(
                    color: isDark
                        ? AppColors.borderColor
                        : Colors.grey.shade200,
                  )
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: textColor ?? AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
