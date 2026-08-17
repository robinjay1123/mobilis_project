import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobilis_by_psdc_app/mobile_ui/theme/app_colors.dart';
import 'package:mobilis_by_psdc_app/services/auth_service.dart';
import 'package:mobilis_by_psdc_app/services/booking_service.dart';

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
    _loadPendingBookingBadge();
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
      final nextCount = pending.length;
      if (_pendingBookingBadgeCount != nextCount) {
        setState(() => _pendingBookingBadgeCount = nextCount);
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
    if (_searchQuery.isEmpty) return bookings;
    final q = _searchQuery.toLowerCase();
    return bookings.where((b) {
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
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: partnerVehicle
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              partnerVehicle
                                  ? 'PARTNER VEHICLE'
                                  : 'PSDC VEHICLE',
                              style: TextStyle(
                                fontSize: 10,
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
                            ? 'Drivers near the partner vehicle & renter are ranked first. All available verified drivers are listed below.'
                            : 'Official PSDC-flagged drivers are prioritized for this vehicle.',
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
                  child: drivers.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_off_outlined,
                                  size: 44,
                                  color: textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No available verified drivers found',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No drivers are active or eligible for this date.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          itemCount: drivers.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
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
                                        'PSDC DRIVER',
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
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${distance.toStringAsFixed(1)} km away${index == 0 && partnerVehicle ? ' (Nearest)' : ''}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: index == 0 && partnerVehicle
                                                ? AppColors.success
                                                : textSecondary,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        'Available',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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
        final bookings = _filter(snapshot.data ?? []);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
                            onAssignDriver:
                                widget.filter == 'pending' &&
                                    _bookingNeedsDriver(booking['with_driver'])
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

  String get _driverStatus {
    if (!_needsDriver) return 'No driver requested';
    final status = _latestAssignment?['status']?.toString().toLowerCase();
    if (status == 'accepted' || status == 'confirmed') {
      return _driverName == null
          ? 'Driver accepted'
          : '$_driverName • Accepted';
    }
    if (status == 'pending_offer' || status == 'assigned') {
      return _driverName == null
          ? 'Awaiting driver acceptance'
          : '$_driverName • Awaiting acceptance';
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
    final name = v['vehicle_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final brand = v['brand']?.toString().trim() ?? '';
    final model = v['model']?.toString().trim() ?? '';
    final combo = '$brand $model'.trim();
    return combo.isEmpty ? 'Vehicle' : combo;
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
    final isPartnerVehicle = ownerRole == 'partner' || oRole == 'partner';
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
                Expanded(
                  child: Text(
                    _vehicleName,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
            if (booking['extension_status'] == 'pending_operator') ...[
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
            if (_status == 'return_pending_inspection' ||
                _status == 'active' ||
                _status == 'ongoing') ...[
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
            if (showActions && _status == 'pending') ...[
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
                        _needsDriver && !_driverAccepted
                            ? Icons.hourglass_top
                            : Icons.check,
                        size: 16,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _needsDriver && !_driverAccepted
                              ? 'Awaiting Driver'
                              : 'Approve',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        elevation: 0,
                      ),
                      onPressed: _needsDriver && !_driverAccepted
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
          ],
        ),
      ),
    );
  }

                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirm & Notify Client',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
