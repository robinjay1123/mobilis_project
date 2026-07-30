import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/booking_service.dart';

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

  @override
  void initState() {
    super.initState();
    _operatorId = AuthService().currentUser?.id;
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
            onNavigate: (tab) => setState(() => _selectedTab = tab),
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
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.pending_actions_outlined),
            selectedIcon: Icon(Icons.pending_actions),
            label: 'Pending',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Active',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
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
    final pending =
        all.where((b) => _status(b) == 'pending').length;
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
    final completed =
        all.where((b) => _status(b) == 'completed').toList();

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
    final textSecondary =
        isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final pendingCount = stats['pending_count'] as int? ?? 0;
        final activeCount = stats['active_count'] as int? ?? 0;
        final completedCount = stats['completed_count'] as int? ?? 0;
        final revenue = stats['total_revenue'] as double? ?? 0;
        final activeBookings = (stats['active_bookings'] as List?)
                ?.cast<Map<String, dynamic>>() ??
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
                      'From $completedCount completed bookings',
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
                    .map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BookingCard(booking: b, isDark: isDark),
                        )),
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

  String _formatCurrency(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
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
          return const {'completed', 'cancelled', 'rejected', 'expired'}.contains(s);
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
    final textSecondary =
        isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final inputFill = isDark ? AppColors.darkCard : Colors.white;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final bookings = _filter(snapshot.data ?? []);
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting;

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
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final booking = bookings[index];
                          return _BookingCard(
                            booking: booking,
                            isDark: isDark,
                            showActions: widget.filter == 'pending',
                            onRefresh: _load,
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

  const _BookingCard({
    required this.booking,
    required this.isDark,
    this.showActions = false,
    this.onRefresh,
  });

  String get _status => booking['status']?.toString().toLowerCase() ?? '';

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

  String get _dateRange {
    final raw = booking['start_at'] ?? booking['start_date'];
    final rawEnd = booking['end_at'] ?? booking['end_date'];
    final start = DateTime.tryParse(raw?.toString() ?? '');
    final end = DateTime.tryParse(rawEnd?.toString() ?? '');
    if (start == null) return 'Date TBD';
    const m = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
    final textSecondary =
        isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
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
                    border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
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
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: textSecondary),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top,
                        size: 14, color: AppColors.warning),
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
            if (showActions && _status == 'pending') ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _showRejectDialog(
                          context, booking['id']?.toString()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _showApproveDialog(
                          context, booking['id']?.toString()),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showApproveDialog(
      BuildContext context, String? bookingId) async {
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
      BuildContext context, String? bookingId) async {
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
    final textSecondary =
        isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
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
