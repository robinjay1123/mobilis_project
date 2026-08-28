import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobilis_by_psdc_app/mobile_ui/theme/app_colors.dart';
import 'package:mobilis_by_psdc_app/mobile_ui/widgets/optimized_network_image.dart';
import 'package:mobilis_by_psdc_app/services/auth_service.dart';
import 'package:mobilis_by_psdc_app/services/booking_inspection_service.dart';
import 'package:mobilis_by_psdc_app/services/booking_service.dart';
import 'package:mobilis_by_psdc_app/services/booking_viewed_service.dart';
import 'package:mobilis_by_psdc_app/services/payout_method_service.dart';
import 'package:mobilis_by_psdc_app/services/reservation_payment_service.dart';
import 'package:mobilis_by_psdc_app/utils/action_guard.dart';
import 'package:mobilis_by_psdc_app/utils/pricing_policy.dart';
import 'package:mobilis_by_psdc_app/widgets/upcoming_release_countdown_badge.dart';

bool _bookingNeedsDriver(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == 'yes' || normalized == '1';
  }
  return false;
}

/// Mobile-first home screen for Operator role.
///
/// Provides 4 tabs:
///   0  Dashboard   — stats summary + active bookings at a glance
///   1  Pending     — bookings needing operator action
///   2  Active      — approved / ongoing bookings
///   3  History     — completed / cancelled bookings
class OperatorMobileHomeScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const OperatorMobileHomeScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = false,
  });

  @override
  State<OperatorMobileHomeScreen> createState() =>
      _OperatorMobileHomeScreenState();
}

class _OperatorMobileHomeScreenState extends State<OperatorMobileHomeScreen> {
  int _selectedTab = 0;
  String? _operatorId;
  int _pendingBookingBadgeCount = 0;
  RealtimeChannel? _pendingBookingChannel;
  Timer? _pendingBookingRefreshDebounce;

  @override
  void initState() {
    super.initState();
    _operatorId = AuthService().currentUser?.id;
    _loadPendingBookingBadge();
    _setupPendingBookingListener();
  }

  @override
  void dispose() {
    _pendingBookingRefreshDebounce?.cancel();
    _pendingBookingChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/icon/logo1.png', height: 28),
            const SizedBox(width: 8),
            Text(
              'Operator Dashboard',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () => widget.onThemeToggle?.call(!widget.isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _DashboardTab(
            operatorId: _operatorId,
            isDark: isDark,
            onNavigate: _selectTab,
          ),
          _BookingsTab(
            operatorId: _operatorId,
            isDark: isDark,
            filter: 'pending',
          ),
          _BookingsTab(
            operatorId: _operatorId,
            isDark: isDark,
            filter: 'active',
          ),
          _BookingsTab(
            operatorId: _operatorId,
            isDark: isDark,
            filter: 'history',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        selectedIndex: _selectedTab,
        onDestinationSelected: _selectTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: _buildPendingTabIcon(Icons.pending_actions_outlined),
            selectedIcon: _buildPendingTabIcon(Icons.pending_actions),
            label: 'Pending',
          ),
          const NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Active',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    if (!mounted) return;
    setState(() {
      _selectedTab = index;
    });
    if (index == 1) {
      _markPendingBookingsAsViewed();
    } else {
      _loadPendingBookingBadge();
    }
  }

  Future<void> _markPendingBookingsAsViewed() async {
    final operatorId = _operatorId;
    if (operatorId == null || operatorId.isEmpty) return;
    try {
      final pending = await BookingService().getOperatorPendingApproval(
        operatorId,
      );
      final pendingIds = pending
          .map((b) => b['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (pendingIds.isNotEmpty) {
        await BookingViewedService().markAllBookingsAsViewed(
          pendingIds,
          role: 'operator',
          userId: operatorId,
        );
      }
      if (mounted && _pendingBookingBadgeCount != 0) {
        setState(() => _pendingBookingBadgeCount = 0);
      }
    } catch (e) {
      debugPrint('Error marking pending bookings as viewed: $e');
    }
  }

  Widget _buildPendingTabIcon(IconData icon) {
    final badgeCount = _pendingBookingBadgeCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (badgeCount > 0)
          Positioned(
            right: -10,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadPendingBookingBadge() async {
    final operatorId = _operatorId;
    if (operatorId == null || operatorId.isEmpty) return;

    try {
      final pending = await BookingService().getOperatorPendingApproval(
        operatorId,
      );
      if (!mounted) return;

      final pendingIds = pending
          .map((b) => b['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (_selectedTab == 1) {
        if (pendingIds.isNotEmpty) {
          await BookingViewedService().markAllBookingsAsViewed(
            pendingIds,
            role: 'operator',
            userId: operatorId,
          );
        }
        if (mounted && _pendingBookingBadgeCount != 0) {
          setState(() => _pendingBookingBadgeCount = 0);
        }
        return;
      }

      final viewedIds = await BookingViewedService().getViewedBookingIds(
        role: 'operator',
        userId: operatorId,
      );
      final unviewedCount =
          pendingIds.where((id) => !viewedIds.contains(id)).length;

      if (mounted && _pendingBookingBadgeCount != unviewedCount) {
        setState(() => _pendingBookingBadgeCount = unviewedCount);
      }
    } catch (e) {
      debugPrint('Error loading operator pending booking badge: $e');
    }
  }

  void _setupPendingBookingListener() {
    final operatorId = _operatorId;
    if (operatorId == null || operatorId.isEmpty) return;

    void scheduleRefresh(PostgresChangePayload _) {
      if (!mounted) return;
      _pendingBookingRefreshDebounce?.cancel();
      _pendingBookingRefreshDebounce = Timer(
        const Duration(milliseconds: 350),
        _loadPendingBookingBadge,
      );
    }

    _pendingBookingChannel = Supabase.instance.client.realtime
        .channel('op-pending-badge-$operatorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: scheduleRefresh,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_job_assignments',
          callback: scheduleRefresh,
        )
        .subscribe();
  }

  Future<void> _handleLogout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }
}

// ─────────────────────────────────────────────
// Dashboard Tab
// ─────────────────────────────────────────────

class _DashboardTab extends StatefulWidget {
  final String? operatorId;
  final bool isDark;
  final ValueChanged<int> onNavigate;

  const _DashboardTab({
    required this.operatorId,
    required this.isDark,
    required this.onNavigate,
  });

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  late Future<Map<String, dynamic>> _statsFuture;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _setupRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _load() {
    setState(() {
      _statsFuture = _fetchStats();
    });
  }

  void _setupRealtime() {
    if (widget.operatorId == null) return;
    _channel = Supabase.instance.client.realtime
        .channel('op-dash-${widget.operatorId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'operator_id',
            value: widget.operatorId!,
          ),
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    if (widget.operatorId == null) return {};
    final service = BookingService();
    final all = await service.getOperatorBookings(widget.operatorId!);
    final pending = all.where((b) => _status(b) == 'pending').length;
    final active = all.where((b) {
      final s = _status(b);
      return const {
        'approved',
        'confirmed',
        'active',
        'ongoing',
        'return_pending_inspection',
        'awaiting_completion',
      }.contains(s);
    }).toList();
    final completed = all.where((b) => _status(b) == 'completed').toList();

    final totalRevenue = completed.fold<double>(
      0,
      (sum, b) =>
          sum +
          ((b['total_price'] as num?)?.toDouble() ??
              (b['total_cost'] as num?)?.toDouble() ??
              0),
    );

    return {
      'pending_count': pending,
      'active_count': active.length,
      'completed_count': completed.length,
      'total_revenue': totalRevenue,
      'active_bookings': active,
    };
  }

  String _status(Map<String, dynamic> b) =>
      b['status']?.toString().toLowerCase() ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;

    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final pendingCount = stats['pending_count'] as int? ?? 0;
        final activeCount = stats['active_count'] as int? ?? 0;
        final completedCount = stats['completed_count'] as int? ?? 0;
        final revenue = stats['total_revenue'] as double? ?? 0;
        final activeBookings =
            (stats['active_bookings'] as List?)?.cast<Map<String, dynamic>>() ??
            [];

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _StatCard(
                    label: 'Pending',
                    value: '$pendingCount',
                    icon: Icons.pending_actions,
                    color: AppColors.warning,
                    isDark: isDark,
                    onTap: () => widget.onNavigate(1),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Active',
                    value: '$activeCount',
                    icon: Icons.directions_car,
                    color: AppColors.success,
                    isDark: isDark,
                    onTap: () => widget.onNavigate(2),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Done',
                    value: '$completedCount',
                    icon: Icons.check_circle_outline,
                    color: AppColors.primary,
                    isDark: isDark,
                    onTap: () => widget.onNavigate(3),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Revenue',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PHP ${_formatCurrency(revenue)}',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'From ${_formatNumber(completedCount)} completed bookings',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (activeBookings.isNotEmpty) ...[
                Text(
                  'Active Bookings',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ...activeBookings
                    .take(5)
                    .map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BookingCard(booking: b, isDark: isDark),
                      ),
                    ),
              ],
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatCurrency(num value, {int decimals = 2}) {
    final parts = value.toStringAsFixed(decimals).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    if (parts.length > 1 && decimals > 0) {
      return '$integerPart.${parts[1]}';
    }
    return integerPart;
  }

  String _formatNumber(num value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

// ─────────────────────────────────────────────
// Bookings Tab (Pending / Active / History)
// ─────────────────────────────────────────────

class _BookingsTab extends StatefulWidget {
  final String? operatorId;
  final bool isDark;
  final String filter;

  const _BookingsTab({
    required this.operatorId,
    required this.isDark,
    required this.filter,
  });

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  late Future<List<Map<String, dynamic>>> _future;
  RealtimeChannel? _channel;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyExtensionRequests = false;

  @override
  void initState() {
    super.initState();
    _load();
    _setupRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = _fetchBookings();
    });
  }

  void _setupRealtime() {
    if (widget.operatorId == null) return;
    _channel = Supabase.instance.client.realtime
        .channel('op-${widget.filter}-${widget.operatorId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (_) {
            if (mounted) _load();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_job_assignments',
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> _fetchBookings() async {
    if (widget.operatorId == null) return [];
    final service = BookingService();
    switch (widget.filter) {
      case 'pending':
        return service.getOperatorPendingApproval(widget.operatorId!);
      case 'active':
        return service.getOperatorActiveBookings(widget.operatorId!);
      case 'history':
        final all = await service.getOperatorBookings(widget.operatorId!);
        return all.where((b) {
          final s = b['status']?.toString().toLowerCase() ?? '';
          return const {
            'completed',
            'cancelled',
            'rejected',
            'expired',
          }.contains(s);
        }).toList();
      default:
        return service.getOperatorBookings(widget.operatorId!);
    }
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> bookings) {
    var list = bookings;
    if (_onlyExtensionRequests) {
      list = list.where((b) {
        final ext = b['extension_status']?.toString().toLowerCase().trim();
        return ext == 'pending_operator' || ext == 'pending';
      }).toList();
    }
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((b) {
      final renter = b['users'] as Map? ?? {};
      final vehicle = b['vehicles'] as Map? ?? {};
      final renterName = renter['full_name']?.toString().toLowerCase() ?? '';
      final vehicleName = _vehicleName(vehicle).toLowerCase();
      return renterName.contains(q) || vehicleName.contains(q);
    }).toList();
  }

  bool _isPartnerBookingVehicle(Map<String, dynamic> vehicle) {
    final ownerRole =
        vehicle['owner_role']?.toString().trim().toLowerCase() ?? '';
    final source = vehicle['source']?.toString().trim().toLowerCase() ?? '';
    final isPartner =
        vehicle['is_partner_vehicle'] == true ||
        vehicle['partner_vehicle_id'] != null ||
        vehicle['partner_name'] != null;
    final owner = vehicle['owner'] as Map<String, dynamic>?;
    final ownerRoleNested =
        owner?['role']?.toString().trim().toLowerCase() ?? '';
    return ownerRole == 'partner' ||
        source == 'partner' ||
        isPartner ||
        ownerRoleNested == 'partner';
  }

  double? _coordinateValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  List<Map<String, double>> _driverProximityTargets(
    Map<String, dynamic> booking,
    Map<String, dynamic> vehicle,
    Map<String, dynamic> renter,
  ) {
    final targets = <Map<String, double>>[];

    void addTarget(dynamic latitudeValue, dynamic longitudeValue) {
      final latitude = _coordinateValue(latitudeValue);
      final longitude = _coordinateValue(longitudeValue);
      if (latitude == null || longitude == null) return;
      final duplicate = targets.any(
        (target) =>
            (target['latitude']! - latitude).abs() < 0.000001 &&
            (target['longitude']! - longitude).abs() < 0.000001,
      );
      if (!duplicate) {
        targets.add({'latitude': latitude, 'longitude': longitude});
      }
    }

    addTarget(vehicle['latitude'], vehicle['longitude']);
    final owner = vehicle['owner'] as Map<String, dynamic>? ?? {};
    addTarget(owner['latitude'], owner['longitude']);
    addTarget(renter['latitude'], renter['longitude']);
    addTarget(booking['pickup_latitude'], booking['pickup_longitude']);
    return targets;
  }

  Future<void> _showDriverAssignmentDialog(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return;

    final bookingDate = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );

    final vehicle = (booking['vehicles'] as Map<String, dynamic>?) ?? {};
    final renter = (booking['users'] as Map<String, dynamic>?) ??
        (booking['renter'] as Map<String, dynamic>?) ??
        {};
    final partnerVehicle = _isPartnerBookingVehicle(vehicle);
    final proximityTargets = partnerVehicle
        ? _driverProximityTargets(booking, vehicle, renter)
        : const <Map<String, double>>[];

    try {
      final drivers = await BookingService().getAvailableVerifiedDrivers(
        bookingDate: bookingDate,
        proximityTargets: proximityTargets,
        prioritizeProximity: partnerVehicle,
        prioritizePsdc: !partnerVehicle,
      );
      if (!context.mounted) return;

      final isDark = widget.isDark;
      final bgCard = isDark ? AppColors.darkCard : Colors.white;
      final textPrimary = isDark ? Colors.white : AppColors.lightTextPrimary;
      final textSecondary = isDark
          ? AppColors.textSecondary
          : AppColors.lightTextSecondary;

      final selectedDriver = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: bgCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (dialogContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: partnerVehicle
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              partnerVehicle
                                  ? 'PARTNER VEHICLE'
                                  : 'PSDC OFFICIAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: partnerVehicle
                                    ? AppColors.primary
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                          Text(
                            '${drivers.length} available',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Assign Driver',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        partnerVehicle
                            ? 'Drivers near the partner vehicle & renter are ranked first.'
                            : 'Official PSDC-flagged drivers are prioritized.',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: drivers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final driver = drivers[index];
                      final user =
                          driver['users'] as Map<String, dynamic>? ?? {};
                      final name =
                          user['full_name']?.toString().trim() ??
                              'Unknown Driver';
                      final isPsdcDriver =
                          driver['is_psdc_driver'] == true;
                      final rating =
                          (driver['rating'] as num?)?.toDouble() ?? 0.0;
                      final trips =
                          (driver['total_trips'] as num?)?.toInt() ?? 0;
                      final distance =
                          (driver['distance_km'] as num?)?.toDouble();

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isPsdcDriver
                              ? AppColors.warning.withValues(alpha: 0.2)
                              : AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPsdcDriver
                                  ? AppColors.warning
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            if (isPsdcDriver)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PSDC',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              if (rating > 0) ...[
                                const Icon(
                                  Icons.star,
                                  size: 13,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                '$trips trips',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                              const Spacer(),
                              if (distance != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index == 0 && partnerVehicle
                                        ? AppColors.success
                                            .withValues(alpha: 0.15)
                                        : Colors.grey
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${distance.toStringAsFixed(1)} km away',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: index == 0 && partnerVehicle
                                          ? AppColors.success
                                          : textSecondary,
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                        onTap: () =>
                            Navigator.pop(dialogContext, driver),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (selectedDriver == null || !context.mounted) return;
      final driverId = selectedDriver['user_id']?.toString() ??
          selectedDriver['id']?.toString();
      if (driverId == null || driverId.isEmpty) {
        throw Exception('Selected driver is missing a user account');
      }

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await BookingService().assignDriver(
          bookingId,
          driverId,
          0.0,
          operatorId: widget.operatorId,
        );
      } finally {
        if (context.mounted) Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver job offer sent. Waiting for acceptance.'),
            backgroundColor: AppColors.success,
          ),
        );
        _load();
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not assign driver: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _vehicleName(Map vehicle) {
    final name = vehicle['vehicle_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final brand = vehicle['brand']?.toString().trim() ?? '';
    final model = vehicle['model']?.toString().trim() ?? '';
    final combo = '$brand $model'.trim();
    return combo.isEmpty ? 'Vehicle' : combo;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textPrimary = isDark ? Colors.white : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    final inputFill = isDark ? AppColors.darkCard : Colors.white;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final rawList = snapshot.data ?? [];
        final bookings = _filter(rawList);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final totalExtensions = rawList.where((b) {
          final ext = b['extension_status']?.toString().toLowerCase().trim();
          return ext == 'pending_operator' || ext == 'pending';
        }).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by renter or vehicle...',
                  hintStyle: TextStyle(color: textSecondary),
                  filled: true,
                  fillColor: inputFill,
                  prefixIcon: Icon(Icons.search, color: textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  FilterChip(
                    selected: !_onlyExtensionRequests,
                    label: const Text('All'),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _onlyExtensionRequests = false);
                      }
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          !_onlyExtensionRequests ? FontWeight.w700 : FontWeight.w500,
                      color:
                          !_onlyExtensionRequests ? AppColors.primary : textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: _onlyExtensionRequests,
                    label: Text(
                      totalExtensions > 0
                          ? 'Extension Requests ($totalExtensions)'
                          : 'Extension Requests',
                    ),
                    onSelected: (selected) {
                      setState(() => _onlyExtensionRequests = selected);
                    },
                    selectedColor: const Color(0xFFFFD740).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFFFFD740),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          _onlyExtensionRequests ? FontWeight.w700 : FontWeight.w500,
                      color: _onlyExtensionRequests
                          ? (isDark
                              ? const Color(0xFFFFD740)
                              : Colors.orange.shade800)
                          : textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading && bookings.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : bookings.isEmpty
                  ? _EmptyState(filter: widget.filter, isDark: isDark)
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async => _load(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final booking = bookings[index];
                          return _BookingCard(
                            booking: booking,
                            isDark: isDark,
                            showActions: widget.filter == 'pending',
                            onRefresh: _load,
                            onAssignDriver: _bookingNeedsDriver(booking['with_driver']) &&
                                    !{
                                      'cancelled',
                                      'rejected',
                                      'completed',
                                      'expired',
                                    }.contains(
                                      (booking['status'] ?? '').toString().toLowerCase().trim(),
                                    )
                                ? () => _showDriverAssignmentDialog(
                                    context,
                                    booking,
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Shared booking card
// ─────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isDark;
  final bool showActions;
  final VoidCallback? onRefresh;
  final VoidCallback? onAssignDriver;

  const _BookingCard({
    required this.booking,
    required this.isDark,
    this.showActions = false,
    this.onRefresh,
    this.onAssignDriver,
  });

  String get _status => booking['status']?.toString().toLowerCase() ?? '';

  bool get _needsDriver => _bookingNeedsDriver(booking['with_driver']);

  Map<String, dynamic>? get _latestAssignment {
    final rawAssignments = booking['job_assignments'];
    if (rawAssignments is! List || rawAssignments.isEmpty) return null;
    final assignments = rawAssignments
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (assignments.isEmpty) return null;
    assignments.sort((a, b) {
      final aDate = DateTime.tryParse(
        (a['created_at'] ?? a['offered_at'])?.toString() ?? '',
      );
      final bDate = DateTime.tryParse(
        (b['created_at'] ?? b['offered_at'])?.toString() ?? '',
      );
      return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
    });
    return assignments.first;
  }

  String? get _driverName {
    final driver = booking['driver'] as Map?;
    final user = (driver?['users'] ?? driver?['user']) as Map?;
    final name = user?['full_name']?.toString().trim();
    return name == null || name.isEmpty ? null : name;
  }

  int get _offerRemainingSec {
    final status = _latestAssignment?['status']?.toString().toLowerCase();
    final waitingForDriver = status == 'pending_offer' || status == 'assigned';
    final assignedAtRaw = booking['driver_assigned_at'] ??
        _latestAssignment?['offered_at'] ??
        _latestAssignment?['created_at'];
    final assignedAt = assignedAtRaw != null
        ? DateTime.tryParse(assignedAtRaw.toString())?.toLocal()
        : null;
    if (waitingForDriver && assignedAt != null) {
      return (600 - DateTime.now().difference(assignedAt).inSeconds).clamp(0, 600);
    }
    return 0;
  }

  bool get _isOfferExpired {
    final status = _latestAssignment?['status']?.toString().toLowerCase();
    final waitingForDriver = status == 'pending_offer' || status == 'assigned';
    final assignedAtRaw = booking['driver_assigned_at'] ??
        _latestAssignment?['offered_at'] ??
        _latestAssignment?['created_at'];
    final assignedAt = assignedAtRaw != null
        ? DateTime.tryParse(assignedAtRaw.toString())?.toLocal()
        : null;
    return waitingForDriver && (assignedAt == null || _offerRemainingSec <= 0);
  }

  bool get _effectiveWaitingForDriver {
    final status = _latestAssignment?['status']?.toString().toLowerCase();
    final waitingForDriver = status == 'pending_offer' || status == 'assigned';
    return waitingForDriver && !_isOfferExpired;
  }

  String get _driverStatus {
    if (!_needsDriver) return 'No driver requested';
    final status = _latestAssignment?['status']?.toString().toLowerCase();
    if (status == 'accepted' || status == 'confirmed') {
      return _driverName == null
          ? 'Driver accepted'
          : '$_driverName • Accepted';
    }
    if (status == 'pending_offer' || status == 'assigned') {
      if (_isOfferExpired) {
        return 'Driver offer expired (10 mins) • Reassign';
      }
      final mm = (_offerRemainingSec ~/ 60).toString().padLeft(2, '0');
      final ss = (_offerRemainingSec % 60).toString().padLeft(2, '0');
      return _driverName == null
          ? 'Awaiting driver ($mm:$ss)'
          : '$_driverName • Awaiting ($mm:$ss)';
    }
    if (status == 'rejected' || status == 'declined') {
      return 'Driver declined • Assign another';
    }
    return 'Driver needed';
  }

  bool get _driverAccepted {
    final status = _latestAssignment?['status']?.toString().toLowerCase();
    return status == 'accepted' || status == 'confirmed';
  }

  String get _vehicleName {
    final v = booking['vehicles'] as Map? ?? {};
    final brand = v['brand']?.toString().trim() ?? '';
    final model = v['model']?.toString().trim() ?? '';
    final year = v['year']?.toString().trim() ?? '';
    final combo = '$brand $model'.trim();
    if (combo.isNotEmpty) return year.isEmpty ? combo : '$combo ($year)';

    final pv = booking['partner_vehicles'] as Map? ?? {};
    final pvBrand = pv['brand']?.toString().trim() ?? '';
    final pvModel = pv['model']?.toString().trim() ?? '';
    final pvYear = pv['year']?.toString().trim() ?? '';
    final pvCombo = '$pvBrand $pvModel'.trim();
    if (pvCombo.isNotEmpty) return pvYear.isEmpty ? pvCombo : '$pvCombo ($pvYear)';

    final name = v['vehicle_name']?.toString().trim() ??
        pv['vehicle_name']?.toString().trim();
    if (name != null &&
        name.isNotEmpty &&
        name.toLowerCase() != 'partner vehicle' &&
        name.toLowerCase() != 'unknown vehicle' &&
        name.toLowerCase() != 'vehicle') {
      return name;
    }
    return combo.isEmpty ? 'Vehicle' : combo;
  }

  String get _vehicleImageUrl {
    final v = booking['vehicles'] as Map? ?? {};
    final direct = (v['image_url'] ??
            v['vehicle_photo_url'] ??
            v['photo_url'] ??
            booking['vehicle_image_url'] ??
            booking['image_url'])
        ?.toString()
        .trim() ??
        '';
    if (direct.isNotEmpty) return direct;
    final imgs = v['vehicle_images'];
    if (imgs is List && imgs.isNotEmpty) {
      for (final img in imgs) {
        if (img is Map) {
          final u = (img['image_url'] ?? img['file_url'] ?? img['url'])
              ?.toString()
              .trim() ??
              '';
          if (u.isNotEmpty) return u;
        }
      }
    }
    final pv = booking['partner_vehicles'] as Map? ?? {};
    final pvDirect = (pv['image_url'] ??
            pv['vehicle_photo_url'] ??
            pv['photo_url'])
        ?.toString()
        .trim() ??
        '';
    if (pvDirect.isNotEmpty) return pvDirect;
    return '';
  }

  String get _renterName {
    final u = booking['users'] as Map? ?? {};
    final name = u['full_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return u['email']?.toString().split('@').first ?? 'Renter';
  }

  String get _renterPhone {
    final senderPhone =
        booking['reservation_payment_sender_phone']?.toString().trim();
    if (senderPhone != null && senderPhone.isNotEmpty) return senderPhone;
    final refundPhone = booking['refund_phone']?.toString().trim();
    if (refundPhone != null && refundPhone.isNotEmpty) return refundPhone;
    final u = booking['users'] as Map? ?? {};
    final phone = u['phone']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return booking['renter_phone']?.toString().trim() ?? '';
  }

  String get _reservationPaymentRef {
    return booking['reservation_payment_reference']?.toString().trim() ?? '';
  }

  double get _refundAmount {
    final amt = (booking['reservation_payment_amount'] as num?)?.toDouble() ??
        (booking['reservation_fee'] as num?)?.toDouble() ??
        (booking['refund_amount'] as num?)?.toDouble() ??
        (booking['total_amount'] as num?)?.toDouble() ??
        (booking['total_price'] as num?)?.toDouble() ??
        0.0;
    return amt;
  }

  String get _refundStatus =>
      booking['refund_status']?.toString().toLowerCase().trim() ?? '';

  String get _dateRange {
    final raw = booking['start_at'] ?? booking['start_date'];
    final rawEnd = booking['end_at'] ?? booking['end_date'];
    final start = DateTime.tryParse(raw?.toString() ?? '');
    final end = DateTime.tryParse(rawEnd?.toString() ?? '');
    if (start == null) return 'Date TBD';
    const m = [
      '',
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
    final fmt = '${m[start.month]} ${start.day}';
    if (end == null) return fmt;
    return '$fmt - ${m[end.month]} ${end.day}';
  }

  Color get _statusColor {
    switch (_status) {
      case 'pending':
        return AppColors.warning;
      case 'approved':
      case 'confirmed':
        return const Color(0xFF3B82F6);
      case 'active':
      case 'ongoing':
        return AppColors.success;
      case 'completed':
        return AppColors.primary;
      case 'cancelled':
      case 'rejected':
      case 'expired':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'confirmed':
        return 'Confirmed';
      case 'active':
      case 'ongoing':
        return 'Ongoing';
      case 'return_pending_inspection':
        return 'Return Inspection';
      case 'awaiting_completion':
        return 'Awaiting Completion';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      case 'expired':
        return 'Expired';
      default:
        return _status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    final partnerConfirmed = booking['partner_booking_confirmed_at'] != null;
    final v = booking['vehicles'] as Map? ?? {};
    final ownerRole = v['owner_role']?.toString().toLowerCase();
    final owner = v['owner'] as Map? ?? {};
    final oRole = owner['role']?.toString().toLowerCase();
    final isPartnerVehicle = ownerRole == 'partner' ||
        oRole == 'partner' ||
        booking['is_partner_vehicle'] == true ||
        v['is_partner_vehicle'] == true ||
        v['partner_vehicle_id'] != null ||
        booking['partner_vehicle_id'] != null ||
        booking['partner_vehicles'] != null;
    final needsPartnerConfirmation =
        isPartnerVehicle && !partnerConfirmed && _status == 'pending';

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_vehicleImageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 34,
                      child: OptimizedNetworkImage(
                        imageUrl: _vehicleImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Icon(
                          Icons.directions_car_outlined,
                          size: 20,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _vehicleName,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isPartnerVehicle) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.purple.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.handshake_outlined,
                                size: 12,
                                color: Colors.purpleAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Partner',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.purple[200]
                                      : Colors.purple[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (isPartnerVehicle) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.handshake_outlined, size: 14, color: Colors.purpleAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _status == 'pending'
                            ? 'Partner Unit • View Only (Awaiting Partner Approval)'
                            : 'Partner Unit • View Only (Managed by Partner)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.purple[200] : Colors.purple[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (booking['safety_freeze'] == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'SAFETY FREEZE • Renter Under Review (Tracking Active)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_needsDriver) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      (_driverAccepted ? AppColors.success : AppColors.warning)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        (_driverAccepted
                                ? AppColors.success
                                : AppColors.warning)
                            .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _driverAccepted
                          ? Icons.check_circle_outline
                          : Icons.directions_car_outlined,
                      size: 16,
                      color: _driverAccepted
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _driverStatus,
                        style: TextStyle(
                          color: _driverAccepted
                              ? AppColors.success
                              : AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (UpcomingReleaseCountdownBadge.isWithin24Hours(booking)) ...[
              const SizedBox(height: 6),
              UpcomingReleaseCountdownBadge(booking: booking, isDark: isDark),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Text(
                  _renterName,
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _dateRange,
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
            if (needsPartnerConfirmation) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Awaiting partner vehicle confirmation',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (booking['extension_status'] == 'pending_operator' &&
                !isPartnerVehicle) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.more_time,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Trip Extension Requested',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requested End: ${booking['extension_requested_end_at'] != null ? DateTime.tryParse(booking['extension_requested_end_at'].toString())?.toLocal().toString().split('.').first : "N/A"}',
                      style: TextStyle(color: textPrimary, fontSize: 11),
                    ),
                    Text(
                      'Additional Price: +PHP ${(booking['extension_additional_price'] as num?)?.toStringAsFixed(2) ?? "0.00"}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                            ),
                            onPressed: () async {
                              final bId = booking['id']?.toString();
                              final oId = AuthService().currentUser?.id;
                              if (bId != null && oId != null) {
                                await BookingService().rejectTripExtension(
                                  bookingId: bId,
                                  operatorId: oId,
                                );
                                onRefresh?.call();
                              }
                            },
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Reject Ext.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final bId = booking['id']?.toString();
                              final oId = AuthService().currentUser?.id;
                              if (bId != null && oId != null) {
                                await BookingService().approveTripExtension(
                                  bookingId: bId,
                                  operatorId: oId,
                                );
                                onRefresh?.call();
                              }
                            },
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Approve Ext.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if ((_status == 'return_pending_inspection' ||
                    _status == 'active' ||
                    _status == 'ongoing') &&
                !isPartnerVehicle) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Colors.black,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _status == 'return_pending_inspection'
                          ? 'Confirm Return Inspection'
                          : 'Confirm Return',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final bId = booking['id']?.toString();
                    final uId = AuthService().currentUser?.id;
                    if (bId != null && uId != null) {
                      await BookingService().confirmVehicleReturn(
                        bookingId: bId,
                        reviewerId: uId,
                        reviewerRole: 'operator',
                      );
                      onRefresh?.call();
                    }
                  },
                ),
              ),
            ],
            if (_status != 'pending' &&
                _needsDriver &&
                onAssignDriver != null &&
                !isPartnerVehicle &&
                !{
                  'cancelled',
                  'rejected',
                  'completed',
                  'expired',
                }.contains(_status)) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: Text(
                    _driverStatus == 'Driver needed' ||
                            _driverStatus.startsWith('Driver declined')
                        ? 'Assign Driver'
                        : 'Change Assigned Driver',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(
                      color: AppColors.warning.withValues(alpha: 0.7),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: onAssignDriver,
                ),
              ),
            ],
            if (showActions && _status == 'pending' && !isPartnerVehicle) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (onAssignDriver != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: Text(
                      _driverStatus == 'Driver needed' ||
                              _driverStatus.startsWith('Driver declined')
                          ? 'Assign Driver'
                          : 'Change Driver',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: BorderSide(
                        color: AppColors.warning.withValues(alpha: 0.7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onAssignDriver,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Reject'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                      ),
                      onPressed: () =>
                          _showRejectDialog(context, booking['id']?.toString()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(
                        _effectiveWaitingForDriver
                            ? Icons.hourglass_top
                            : (_needsDriver && !_driverAccepted
                                ? Icons.person_search
                                : Icons.check),
                        size: 16,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _effectiveWaitingForDriver
                              ? 'Awaiting (${(_offerRemainingSec ~/ 60).toString().padLeft(2, '0')}:${(_offerRemainingSec % 60).toString().padLeft(2, '0')})'
                              : (_needsDriver && !_driverAccepted
                                  ? (_isOfferExpired ? 'Assign Again' : 'Select Driver')
                                  : 'Approve'),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _effectiveWaitingForDriver
                            ? Colors.amber.shade700
                            : (_needsDriver && !_driverAccepted
                                ? Colors.amber.shade800
                                : AppColors.primary),
                        foregroundColor: (_effectiveWaitingForDriver || (_needsDriver && !_driverAccepted))
                            ? Colors.white
                            : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        elevation: 0,
                      ),
                      onPressed: _effectiveWaitingForDriver
                          ? null
                          : () => _showApproveDialog(
                              context,
                              booking['id']?.toString(),
                            ),
                    ),
                  ),
                ],
              ),
            ],
            if (_refundStatus == 'refund_needed' ||
                (_status == 'cancelled' &&
                    _reservationPaymentRef.isNotEmpty &&
                    _refundStatus != 'refunded')) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.currency_exchange,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Refund Needed',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (_refundAmount > 0)
                          Text(
                            'PHP ${_refundAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                    if (UpcomingReleaseCountdownBadge.isWithin24Hours(booking)) ...[
                      const SizedBox(height: 6),
                      UpcomingReleaseCountdownBadge(booking: booking, isDark: isDark),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Renter: $_renterName',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_renterPhone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_android,
                            size: 13,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'GCash: $_renterPhone',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _renterPhone),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Copied GCash number: $_renterPhone',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.copy,
                              size: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_reservationPaymentRef.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Original Payment Ref: $_reservationPaymentRef',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Cancelled by Renter • ₱1,000 Deposit Forfeited (Non-Refundable)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_refundStatus == 'refunded') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Refund Disbursed ${booking['refund_reference'] != null ? '• Ref: ${booking['refund_reference']}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if ((_status == 'completed' ||
                    _status == 'awaiting_completion' ||
                    _status == 'return_pending_inspection' ||
                    booking['security_deposit_return_eligible'] == true) &&
                booking['security_deposit_refunded'] != true) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.assignment_return_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Return Security Deposit',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _showMobileSecurityDepositRefundDialog(
                    context,
                    booking,
                    isDark,
                    onRefresh,
                  ),
                ),
              ),
            ],
            if (booking['security_deposit_refunded'] == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text(
                      'Security Deposit Refunded',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isPartnerVehicle) ...[
              if (booking['partner_payout_disbursed'] == true ||
                  (booking['partner_payout_status']?.toString().toLowerCase() == 'disbursed')) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.purpleAccent),
                      SizedBox(width: 6),
                      Text(
                        'Partner Payout Disbursed',
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_status == 'completed' || _status == 'awaiting_completion') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.payments_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Disburse Partner Payout',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _showMobileDisbursePartnerPayoutDialog(
                      context,
                      booking,
                      isDark,
                      onRefresh,
                    ),
                  ),
                ),
              ],
            ],
            if (_needsDriver) ...[
              if (booking['driver_payout_disbursed'] == true ||
                  (booking['driver_payout_status']?.toString().toLowerCase() == 'disbursed')) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Color(0xFF0284C7)),
                      SizedBox(width: 6),
                      Text(
                        'Driver Payout Disbursed',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_status == 'completed' || _status == 'awaiting_completion') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.paid_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Disburse Driver Fee',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _showMobileDisburseDriverPayoutDialog(
                      context,
                      booking,
                      isDark,
                      onRefresh,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showMobileSecurityDepositRefundDialog(
    BuildContext context,
    Map<String, dynamic> booking,
    bool isDark,
    VoidCallback? onRefresh,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    return ActionGuard.runGuarded('mobile_deposit_refund_dialog_$bookingId', () async {
      final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renterName = renter['full_name']?.toString() ?? 'Renter';
    final renterPhone = renter['phone_number']?.toString() ??
        renter['phone']?.toString() ??
        booking['renter_phone']?.toString() ??
        '';
    final vehicleName =
        '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
    final renterUserId = (booking['renter_id'] ?? renter['id'] ?? renter['user_id'])?.toString();
    List<PayoutMethod> renterPayoutMethods = [];
    if (renterUserId != null && renterUserId.isNotEmpty) {
      try {
        renterPayoutMethods = await PayoutMethodService().getPayoutMethods(renterUserId);
      } catch (e) {
        debugPrint('Could not load renter payout methods: $e');
      }
    }

    final directQrUrl = renter['qr_code_url']?.toString() ??
        renter['gcash_qr_url']?.toString() ??
        renter['payout_qr_url']?.toString() ??
        booking['renter_qr_url']?.toString();

    // Fetch dynamic Admin Settings for Security Deposit
    ReservationPaymentSettings adminSettings = const ReservationPaymentSettings();
    try {
      adminSettings = await ReservationPaymentService().getSettings();
    } catch (e) {
      debugPrint('Could not load admin deposit settings: $e');
    }

    // Determine seater capacity & deposit rule from Admin Settings
    final vehicleSeatsRaw = vehicle['seats'] ?? booking['seats'];
    int seats = 5;
    if (vehicleSeatsRaw != null) {
      if (vehicleSeatsRaw is num) {
        seats = vehicleSeatsRaw.toInt();
      } else {
        seats = int.tryParse(vehicleSeatsRaw.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 5;
      }
    }
    final double defaultSecurityDeposit = adminSettings.getDepositForSeats(seats);
    final depositAmount = (booking['security_deposit'] as num?)?.toDouble() ?? defaultSecurityDeposit;

    final refundAmountController =
        TextEditingController(text: depositAmount.toStringAsFixed(0));
    final deductionAmountController = TextEditingController(text: '0');
    final deductionNotesController = TextEditingController();
    final referenceController = TextEditingController();
    String selectedMethod = renterPayoutMethods.isNotEmpty
        ? renterPayoutMethods.first.provider
        : 'GCash';
    PlatformFile? receiptFile;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final deposit = double.tryParse(refundAmountController.text) ?? depositAmount;
          final deduction = double.tryParse(deductionAmountController.text) ?? 0.0;
          final netRefund = (deposit - deduction).clamp(0.0, double.infinity);

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

          final activeQrUrl = (activeMethod.qrCodeUrl != null && activeMethod.qrCodeUrl!.isNotEmpty)
              ? activeMethod.qrCodeUrl!
              : (directQrUrl != null && directQrUrl.isNotEmpty ? directQrUrl : '');

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF172235) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (booking['security_deposit_refunded'] == true) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Security Deposit Refund Completed: PHP ${((booking["security_deposit_refund_amount"] ?? depositAmount) as num).toStringAsFixed(0)} was already refunded.',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF10B981)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment_return_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Refund Security Deposit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '$vehicleName ($seats Seater)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Renter Info & QR / Linked Account Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2D44) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C3E5A) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          renterName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                renterPhone.isNotEmpty ? renterPhone : 'No phone recorded',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (renterPhone.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: renterPhone));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied $renterPhone'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Copy GCash',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (activeQrUrl.isNotEmpty || activeMethod.accountNumber.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (activeQrUrl.isNotEmpty) ...[
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF10B981)),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Image.network(
                                    activeQrUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => const Icon(Icons.qr_code_2, size: 36, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${activeMethod.provider} Linked QR & Account',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      activeMethod.accountName.isNotEmpty ? activeMethod.accountName : renterName,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Account: ${activeMethod.accountNumber.isNotEmpty ? activeMethod.accountNumber : renterPhone}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amounts
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Deposit (PHP)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: refundAmountController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Deduction (PHP)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: deductionAmountController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Net Refund Summary
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Refund:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(
                          'PHP ${netRefund.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Deduction policy note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFF59E0B)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Note: The security deposit may NOT be fully refunded if the vehicle was returned with cleanliness issues, scratches, damages, or any unresolved violations. The operator may deduct applicable charges before disbursing the refund. Enter the deduction amount above and provide notes for transparency.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFF59E0B),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),


                  // Method & Ref
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'Maya', child: Text('Maya')),
                      DropdownMenuItem(value: 'PSDC Cash Counter', child: Text('PSDC Cash Counter')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedMethod = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: referenceController,
                    keyboardType: TextInputType.number,
                    maxLength: 13,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Reference Number (13-digit max)',
                      hintText: 'e.g. 1002349817283',
                      counterText: '',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  // Show deduction reason field only if there is a deduction
                  if (deduction > 0) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: deductionNotesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Deduction Reason *',
                        hintText: 'e.g. Vehicle returned with scratches, cleanliness issues...',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        labelStyle: TextStyle(color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),


                  // Receipt Upload
                  if (receiptFile == null)
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
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Attach Receipt Proof', style: TextStyle(fontSize: 12)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Color(0xFF10B981), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              receiptFile!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            onPressed: () => setDialogState(() => receiptFile = null),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (isSubmitting || booking['security_deposit_refunded'] == true)
                          ? null
                          : () async {
                              final ref = referenceController.text.trim();
                              if (ref.isEmpty && receiptFile == null) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please provide a reference number or receipt.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              if (ref.isNotEmpty && ref.length > 13) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Transaction ID / Reference Number cannot exceed 13 digits.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
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

                                final currentUserId = AuthService().currentUser?.id ?? '';
                                await BookingService().refundSecurityDeposit(
                                  bookingId: bookingId,
                                  refundAmount: netRefund,
                                  deductionAmount: deduction,
                                  deductionNotes: deductionNotesController.text.trim(),
                                  refundMethod: selectedMethod,
                                  refundReference: ref,
                                  refundReceiptUrl: uploadedReceiptUrl,
                                  operatorId: currentUserId,
                                );

                                if (!context.mounted) return;
                                Navigator.pop(dialogContext);
                                onRefresh?.call();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Security deposit refunded to $renterName.',
                                    ),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() => isSubmitting = false);
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Refund error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: booking['security_deposit_refunded'] == true
                          ? const Text('Deposit Already Refunded', style: TextStyle(fontWeight: FontWeight.bold))
                          : (isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Submit Deposit Refund', style: TextStyle(fontWeight: FontWeight.bold))),
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
    deductionAmountController.dispose();
    deductionNotesController.dispose();
    referenceController.dispose();
    });
  }

  Future<void> _showMobileDisbursePartnerPayoutDialog(
    BuildContext context,
    Map<String, dynamic> booking,
    bool isDark,
    VoidCallback? onRefresh,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    return ActionGuard.runGuarded('mobile_disburse_partner_dialog_$bookingId', () async {
      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final partnerVehicle = booking['partner_vehicles'] as Map<String, dynamic>? ?? {};
    final partnerData = (partnerVehicle['partners'] ?? vehicle['partners'] ?? vehicle['owner']) as Map<String, dynamic>? ?? {};
    final partnerUserData = (partnerData['users'] ?? partnerData['user']) as Map<String, dynamic>? ?? {};

    final partnerUserId = (partnerData['user_id'] ?? partnerVehicle['partner_id'] ?? vehicle['owner_id'] ?? booking['partner_id'] ?? booking['partner_user_id'])?.toString();
    final partnerName = partnerData['business_name']?.toString() ??
        partnerUserData['full_name']?.toString() ??
        partnerData['full_name']?.toString() ??
        'Partner Owner';
    final partnerPhone = partnerData['business_phone']?.toString() ??
        partnerUserData['phone']?.toString() ??
        partnerData['phone']?.toString() ??
        '';
    final vehicleTitle = '${vehicle['brand'] ?? partnerVehicle['brand'] ?? ''} ${vehicle['model'] ?? partnerVehicle['model'] ?? ''}'.trim();

    final rawRental = (booking['rental_subtotal'] as num?)?.toDouble() ??
        ((booking['total_price'] as num?)?.toDouble() ?? 0.0);
    final deliveryFee = (booking['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final lateFee = (booking['late_return_fee'] as num?)?.toDouble() ?? 0.0;
    final rentalSubtotal = (rawRental > 0 ? rawRental : ((booking['total_price'] as num?)?.toDouble() ?? 0.0)) + deliveryFee + lateFee;
    final commission = rentalSubtotal * 0.05;
    final netPayout = (rentalSubtotal - commission).clamp(0.0, double.infinity);

    final payoutAmountController =
        TextEditingController(text: netPayout.toStringAsFixed(2));
    final referenceController = TextEditingController();
    String selectedMethod = 'GCash';
    PlatformFile? receiptFile;
    bool isSubmitting = false;

    // Load registered payout methods
    List<PayoutMethod> registeredMethods = [];
    if (partnerUserId != null && partnerUserId.isNotEmpty) {
      try {
        registeredMethods = await PayoutMethodService().getPayoutMethods(partnerUserId);
        if (registeredMethods.isNotEmpty) {
          selectedMethod = registeredMethods.first.provider;
        }
      } catch (e) {
        debugPrint('Could not load partner payout methods: $e');
      }
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final effectiveNet = double.tryParse(payoutAmountController.text) ?? netPayout;

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF172235) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (booking['partner_payout_disbursed'] == true ||
                      (booking['partner_payout_status']?.toString().toLowerCase() == 'disbursed')) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.purpleAccent),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.purpleAccent, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Partner Commission Disburse Completed: Earnings for this booking have already been disbursed.',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.purpleAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payments_outlined, color: Colors.purpleAccent, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Disburse Partner Payout',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '5% PSDC commission deducted',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Partner Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2D44) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C3E5A) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.purple.withValues(alpha: 0.2),
                          child: const Icon(Icons.handshake_outlined, size: 18, color: Colors.purpleAccent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(partnerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              if (registeredMethods.isNotEmpty)
                                Text(
                                  '${registeredMethods.first.provider}: ${registeredMethods.first.accountNumber} (${registeredMethods.first.accountName})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.purple[200] : Colors.purple[800],
                                  ),
                                )
                              else if (partnerPhone.isNotEmpty)
                                Text(
                                  'Phone / GCash: $partnerPhone',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                                )
                              else
                                const Text('No registered payout method', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (registeredMethods.isNotEmpty || partnerPhone.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.purpleAccent),
                            tooltip: 'Copy account',
                            onPressed: () {
                              final target = registeredMethods.isNotEmpty ? registeredMethods.first.accountNumber : partnerPhone;
                              Clipboard.setData(ClipboardData(text: target));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied $target to clipboard.'), backgroundColor: Colors.purple),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Financial Breakdown
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Rental Subtotal', style: TextStyle(fontSize: 12)),
                            Text('PHP ${rentalSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Platform Fee (5%)', style: TextStyle(fontSize: 12, color: Colors.orange)),
                            Text('- PHP ${commission.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Net Payout (95%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('PHP ${netPayout.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Method & Ref
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Disbursement Method',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'Maya', child: Text('Maya')),
                      DropdownMenuItem(value: 'PSDC Cash Counter', child: Text('PSDC Cash Counter')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedMethod = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: referenceController,
                    keyboardType: TextInputType.number,
                    maxLength: 13,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Reference Number (13-digit max)',
                      hintText: 'e.g. 2004918239012',
                      counterText: '',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Receipt
                  if (receiptFile == null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text('Attach Receipt / Screenshot', style: TextStyle(fontSize: 12)),
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
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long, size: 18, color: Colors.purpleAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              receiptFile!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            onPressed: () => setDialogState(() => receiptFile = null),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (isSubmitting ||
                              booking['partner_payout_disbursed'] == true ||
                              (booking['partner_payout_status']?.toString().toLowerCase() == 'disbursed'))
                          ? null
                          : () async {
                              final ref = referenceController.text.trim();
                              if (ref.isEmpty && receiptFile == null) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please provide a reference number or receipt.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              if (ref.isNotEmpty && ref.length > 13) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Transaction ID / Reference Number cannot exceed 13 digits.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              setDialogState(() => isSubmitting = true);

                              try {
                                String uploadedReceiptUrl = '';
                                if (receiptFile?.bytes != null) {
                                  final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
                                  uploadedReceiptUrl = await BookingInspectionService().uploadEvidenceBytes(
                                    userId: currentUserId,
                                    bookingId: bookingId,
                                    bytes: receiptFile!.bytes!,
                                    extension: receiptFile!.extension ?? 'jpg',
                                  );
                                }

                                final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
                                await BookingService().disbursePartnerCommission(
                                  bookingId: bookingId,
                                  operatorId: currentUserId,
                                  paymentMethod: selectedMethod,
                                  referenceNumber: ref,
                                  receiptUrl: uploadedReceiptUrl,
                                  netAmount: effectiveNet,
                                  commissionAmount: commission,
                                  partnerUserId: partnerUserId,
                                );

                                if (!context.mounted) return;
                                Navigator.pop(dialogContext);
                                onRefresh?.call();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Partner payout of PHP ${effectiveNet.toStringAsFixed(2)} disbursed to $partnerName.'),
                                    backgroundColor: Colors.purple,
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() => isSubmitting = false);
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Disbursement error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: (booking['partner_payout_disbursed'] == true ||
                              (booking['partner_payout_status']?.toString().toLowerCase() == 'disbursed'))
                          ? const Text('Partner Payout Already Disbursed', style: TextStyle(fontWeight: FontWeight.bold))
                          : (isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Confirm & Disburse Payout', style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    payoutAmountController.dispose();
    referenceController.dispose();
    });
  }

  Future<void> _showMobileDisburseDriverPayoutDialog(
    BuildContext context,
    Map<String, dynamic> booking,
    bool isDark,
    VoidCallback? onRefresh,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    return ActionGuard.runGuarded('mobile_disburse_driver_dialog_$bookingId', () async {
      final driverData = booking['driver'] as Map<String, dynamic>? ?? {};
    final driverUserData = (driverData['users'] ?? driverData['user']) as Map<String, dynamic>? ?? {};
    final driverUserJoined = (booking['driver_user'] ?? booking['driver_profile']) as Map<String, dynamic>? ?? {};

    final driverUserId = (driverData['user_id'] ??
            driverUserData['id'] ??
            driverUserJoined['id'] ??
            booking['driver_id'])
        ?.toString();
    final driverName = driverUserData['full_name']?.toString() ??
        driverUserJoined['full_name']?.toString() ??
        driverData['full_name']?.toString() ??
        booking['driver_name']?.toString() ??
        'Assigned Driver';
    final driverPhone = driverUserData['phone']?.toString() ??
        driverUserJoined['phone']?.toString() ??
        driverData['phone']?.toString() ??
        '';

    double driverGross = (booking['driver_fee'] as num?)?.toDouble() ?? 0.0;
    if (driverGross <= 0) {
      final start = DateTime.tryParse((booking['start_at'] ?? booking['start_date'])?.toString() ?? '');
      final end = DateTime.tryParse((booking['end_at'] ?? booking['end_date'])?.toString() ?? '');
      int days = 1;
      if (start != null && end != null && end.isAfter(start)) {
        days = (end.difference(start).inMinutes / Duration.minutesPerDay).ceil();
        if (days <= 0) days = 1;
      }
      driverGross = days * PricingPolicy.driverDailyRate;
    }
    final commission = driverGross * 0.05;
    final netPayout = (driverGross - commission).clamp(0.0, double.infinity);

    final payoutAmountController =
        TextEditingController(text: netPayout.toStringAsFixed(2));
    final referenceController = TextEditingController();
    String selectedMethod = 'GCash';
    PlatformFile? receiptFile;
    bool isSubmitting = false;

    // Load registered payout methods
    List<PayoutMethod> registeredMethods = [];
    if (driverUserId != null && driverUserId.isNotEmpty) {
      try {
        registeredMethods = await PayoutMethodService().getPayoutMethods(driverUserId);
        if (registeredMethods.isNotEmpty) {
          selectedMethod = registeredMethods.first.provider;
        }
      } catch (e) {
        debugPrint('Could not load driver payout methods: $e');
      }
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final effectiveNet = double.tryParse(payoutAmountController.text) ?? netPayout;

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF172235) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (booking['driver_payout_disbursed'] == true ||
                      (booking['driver_payout_status']?.toString().toLowerCase() == 'disbursed')) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF38BDF8)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Driver Trip Fee Disburse Completed: Driver fee for this booking has already been disbursed.',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF38BDF8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.paid_outlined, color: Color(0xFF0284C7), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Disburse Driver Fee',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '5% PSDC commission deducted',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Driver Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2D44) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C3E5A) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.2),
                          child: const Icon(Icons.drive_eta, size: 18, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              if (registeredMethods.isNotEmpty)
                                Text(
                                  '${registeredMethods.first.provider}: ${registeredMethods.first.accountNumber} (${registeredMethods.first.accountName})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF38BDF8),
                                  ),
                                )
                              else if (driverPhone.isNotEmpty)
                                Text(
                                  'Phone / GCash: $driverPhone',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                                )
                              else
                                const Text('No registered payout method', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (registeredMethods.isNotEmpty || driverPhone.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0284C7)),
                            tooltip: 'Copy account',
                            onPressed: () {
                              final target = registeredMethods.isNotEmpty ? registeredMethods.first.accountNumber : driverPhone;
                              Clipboard.setData(ClipboardData(text: target));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied $target to clipboard.'), backgroundColor: const Color(0xFF0284C7)),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Financial Breakdown
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Driver Gross Fee', style: TextStyle(fontSize: 12)),
                            Text('PHP ${driverGross.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Platform Fee (5%)', style: TextStyle(fontSize: 12, color: Colors.orange)),
                            Text('- PHP ${commission.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Net Driver Payout (95%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('PHP ${netPayout.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Method & Ref
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Disbursement Method',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'Maya', child: Text('Maya')),
                      DropdownMenuItem(value: 'PSDC Cash Counter', child: Text('PSDC Cash Counter')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedMethod = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: referenceController,
                    keyboardType: TextInputType.number,
                    maxLength: 13,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Reference Number (13-digit max)',
                      hintText: 'e.g. 3009218273849',
                      counterText: '',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Receipt
                  if (receiptFile == null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text('Attach Receipt / Screenshot', style: TextStyle(fontSize: 12)),
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
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long, size: 18, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              receiptFile!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            onPressed: () => setDialogState(() => receiptFile = null),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (isSubmitting ||
                              booking['driver_payout_disbursed'] == true ||
                              (booking['driver_payout_status']?.toString().toLowerCase() == 'disbursed'))
                          ? null
                          : () async {
                              final ref = referenceController.text.trim();
                              if (ref.isEmpty && receiptFile == null) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please provide a reference number or receipt.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              if (ref.isNotEmpty && ref.length > 13) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Transaction ID / Reference Number cannot exceed 13 digits.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              setDialogState(() => isSubmitting = true);

                              try {
                                String uploadedReceiptUrl = '';
                                if (receiptFile?.bytes != null) {
                                  final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
                                  uploadedReceiptUrl = await BookingInspectionService().uploadEvidenceBytes(
                                    userId: currentUserId,
                                    bookingId: bookingId,
                                    bytes: receiptFile!.bytes!,
                                    extension: receiptFile!.extension ?? 'jpg',
                                  );
                                }

                                final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
                                await BookingService().disburseDriverCommission(
                                  bookingId: bookingId,
                                  operatorId: currentUserId,
                                  paymentMethod: selectedMethod,
                                  referenceNumber: ref,
                                  receiptUrl: uploadedReceiptUrl,
                                  netAmount: effectiveNet,
                                  commissionAmount: commission,
                                  driverUserId: driverUserId,
                                );

                                if (!context.mounted) return;
                                Navigator.pop(dialogContext);
                                onRefresh?.call();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Driver payout of PHP ${effectiveNet.toStringAsFixed(2)} disbursed to $driverName.'),
                                    backgroundColor: const Color(0xFF0284C7),
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() => isSubmitting = false);
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Disbursement error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: (booking['driver_payout_disbursed'] == true ||
                              (booking['driver_payout_status']?.toString().toLowerCase() == 'disbursed'))
                          ? const Text('Driver Fee Already Disbursed', style: TextStyle(fontWeight: FontWeight.bold))
                          : (isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Confirm & Disburse Payout', style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    payoutAmountController.dispose();
    referenceController.dispose();
    });
  }

  Future<void> _showApproveDialog(
    BuildContext context,
    String? bookingId,
  ) async {
    if (bookingId == null) return;
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Booking'),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await BookingService().approveBooking(bookingId, notesController.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking approved'),
            backgroundColor: AppColors.success,
          ),
        );
        onRefresh?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    String? bookingId,
  ) async {
    if (bookingId == null) return;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Booking'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await BookingService().rejectBooking(bookingId, reasonController.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking rejected'),
            backgroundColor: AppColors.warning,
          ),
        );
        onRefresh?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  final bool isDark;

  const _EmptyState({required this.filter, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    final label = filter == 'pending'
        ? 'No pending bookings'
        : filter == 'active'
        ? 'No active bookings'
        : 'No past bookings yet';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
