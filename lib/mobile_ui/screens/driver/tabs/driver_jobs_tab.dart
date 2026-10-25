part of '../driver_home_screen.dart';

// JOBS TAB
class _JobsTab extends StatefulWidget {
  final VoidCallback? onOpenAvailability;

  const _JobsTab({this.onOpenAvailability});

  @override
  State<_JobsTab> createState() => __JobsTabState();
}

class __JobsTabState extends State<_JobsTab> {
  late Future<List<Map<String, dynamic>>> jobsFuture;
  late Future<bool> isAvailableFuture;
  late Future<bool> isVerifiedFuture;
  String _selectedStatus = 'pending';
  RealtimeChannel? _jobsChannel;
  Timer? _jobsRefreshDebounce;
  static const List<String> _statusTabs = [
    'pending',
    'approved',
    'ongoing',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadJobs();
    final userId = AuthService().currentUser?.id;
    if (userId != null) _setupJobsListener(userId);
  }

  @override
  void dispose() {
    _jobsRefreshDebounce?.cancel();
    _jobsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupJobsListener(String userId) {
    _jobsChannel = Supabase.instance.client.realtime.channel(
      'driver-bookings-tab-$userId',
    );
    void handleRefresh(PostgresChangePayload payload) {
      if (!mounted) return;
      _jobsRefreshDebounce?.cancel();
      _jobsRefreshDebounce = Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(_loadJobs);
      });
    }

    _jobsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: userId,
          ),
          callback: handleRefresh,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_job_assignments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: userId,
          ),
          callback: handleRefresh,
        )
        .subscribe();
  }

  void _loadJobs() {
    final authService = AuthService();
    final driverService = DriverService();
    final user = authService.currentUser;
    if (user != null) {
      jobsFuture = driverService.getAssignedBookings(user.id);
      isAvailableFuture = driverService.getDriverStats(user.id).then(
        (s) => s['is_available'] == true,
      ).catchError((_) => true);
      isVerifiedFuture = VerificationService.getUserVerificationState(user.id)
          .then((state) => state['is_verified'] == true)
          .catchError((_) => false);
    } else {
      jobsFuture = Future.value([]);
      isAvailableFuture = Future.value(true);
      isVerifiedFuture = Future.value(false);
    }
  }

  Future<void> _refreshJobs() async {
    setState(() => _loadJobs());
    await jobsFuture;
  }

  String _statusGroup(Map<String, dynamic> trip) {
    final status = (trip['status']?.toString() ?? '').trim().toLowerCase();
    final assignments = (trip['job_assignments'] as List?)
        ?.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList() ?? [];
    final latestAssignment = assignments.isNotEmpty ? assignments.last : null;
    final assignmentStatus = latestAssignment?['status']?.toString().toLowerCase();

    // If any assignment is still pending/accepted, never mark as cancelled
    final hasPendingOrAccepted = assignments.any((a) {
      final s = a['status']?.toString().toLowerCase();
      return s == 'pending_offer' || s == 'assigned' || s == 'accepted';
    });

    if (['completed', 'returned', 'successful', 'success'].contains(status)) {
      return 'completed';
    }
    if (!hasPendingOrAccepted &&
        (['cancelled', 'canceled', 'rejected', 'declined'].contains(status) ||
            assignmentStatus == 'rejected' ||
            assignmentStatus == 'declined')) {
      return 'cancelled';
    }
    if ([
      'active',
      'ongoing',
      'picked_up',
      'in_progress',
      'return_pending_inspection',
      'awaiting_completion',
      'awaiting_ratings',
    ].contains(status)) {
      return 'ongoing';
    }
    if (['approved', 'confirmed'].contains(status) &&
        assignmentStatus != 'pending_offer') {
      return 'approved';
    }
    return 'pending';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  Widget _buildStatusTabs(List<Map<String, dynamic>> trips) {
    final isDark = _driverIsDark(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusTabs.map((status) {
          final selected = _selectedStatus == status;
          final count = trips
              .where((trip) => _statusGroup(trip) == status)
              .length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _selectedStatus = status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: status == 'cancelled' ? 108 : 96,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBg : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.borderColor
                              : AppColors.lightBorderColor),
                  ),
                ),
                child: Text(
                  '${_statusLabel(status)} ($count)',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.black
                        : (isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshJobs,
      color: AppColors.primary,
      backgroundColor: _driverCardColor(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          const RoleTabHeader(
            title: 'Assigned Trips',
            subtitle: 'Accepted trips, pickups, and vehicle returns',
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<dynamic>>(
            future: Future.wait([isAvailableFuture, isVerifiedFuture]),
            builder: (context, snapshot) {
              final isAvailable = (snapshot.data?[0] as bool?) ?? true;
              final isVerified = (snapshot.data?[1] as bool?) ?? false;
              if (isAvailable || !isVerified) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1304),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFB300),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pause_circle_filled_rounded,
                      color: Color(0xFFFFB300),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'YOU ARE UNAVAILABLE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Set your availability now to receive job assignments!',
                            style: TextStyle(
                              color: Color(0xFFFFE082),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onOpenAvailability != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: widget.onOpenAvailability,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB300),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Set Availability',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: jobsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _DriverLoadingCard(
                  label: 'Loading assigned trips...',
                );
              }

              final trips = snapshot.data ?? [];
              final visibleTrips = trips
                  .where((trip) => _statusGroup(trip) == _selectedStatus)
                  .toList();

              if (trips.isEmpty) {
                return Column(
                  children: [
                    _buildStatusTabs(trips),
                    const SizedBox(height: 14),
                    const RoleEmptyStateCard(
                      icon: Icons.route_outlined,
                      title: 'No assigned trips yet',
                      message:
                          'When an operator assigns you to a booking, it will show here.',
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  _buildStatusTabs(trips),
                  const SizedBox(height: 14),
                  if (visibleTrips.isEmpty)
                    RoleEmptyStateCard(
                      icon: Icons.inbox_outlined,
                      title:
                          'No ${_statusLabel(_selectedStatus).toLowerCase()} trips',
                      message:
                          'Trips with this status will appear here once available.',
                    )
                  else
                    ...visibleTrips.map((trip) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TripCard(
                          trip: trip,
                          onChanged: () {
                            setState(() => _loadJobs());
                          },
                        ),
                      );
                    }),
                ],
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
  Map<String, dynamic> get trip => widget.trip;
  bool _hasAccepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startActiveTracking());
  }

  @override
  void didUpdateWidget(covariant _TripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip['status'] != widget.trip['status']) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startActiveTracking(),
      );
    }
  }

  Future<void> _startActiveTracking() async {
    final status = trip['status']?.toString().trim().toLowerCase() ?? '';
    if (!mounted || !{'active', 'ongoing'}.contains(status)) return;
    final bookingId = trip['id']?.toString() ?? '';
    final vehicleId = trip['vehicle_id']?.toString() ?? '';
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (bookingId.isEmpty || vehicleId.isEmpty || userId.isEmpty) return;
    final tracker = TrackingService();
    if (tracker.activeBookingId == bookingId) return;
    try {
      await tracker.startBookingTracking(
        bookingId: bookingId,
        vehicleId: vehicleId,
        trackedUserId: userId,
        source: 'driver_active_trip',
      );
    } catch (error) {
      debugPrint('Unable to start active-trip GPS evidence: $error');
    }
  }

  bool _isResponding = false;

  Future<void> _respondToJob(bool accept) async {
    final bookingId = trip['id']?.toString() ?? '';
    final assignments = (trip['job_assignments'] as List?)
        ?.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList() ?? [];
    // Use the most recent pending_offer/assigned assignment so we don't try
    // to accept an already-rejected/expired one when a newer offer exists.
    Map<String, dynamic>? pendingAssignment;
    for (final a in assignments.reversed) {
      final s = a['status']?.toString().toLowerCase();
      if (s == 'pending_offer' || s == 'assigned') {
        pendingAssignment = a;
        break;
      }
    }
    pendingAssignment ??= assignments.isNotEmpty ? assignments.last : null;
    final assignmentId = pendingAssignment?['id']?.toString() ?? '';


    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text(
          accept ? 'Accept Trip Assignment?' : 'Decline Trip Assignment?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          accept
              ? 'You are accepting this trip assignment. The booking will be marked as "Driver Accepted" so the operator or partner can finalize and approve it.'
              : 'Declining this offer will notify the operator or partner to assign another available driver.',
          style: TextStyle(
            color: isDark ? AppColors.textSecondary : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: accept ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(accept ? 'Accept Job' : 'Decline Job'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isResponding = true;
      if (accept) _hasAccepted = true;
    });
    try {
      if (assignmentId.isNotEmpty) {
        if (accept) {
          await DriverService().acceptJobOffer(assignmentId);
        } else {
          await DriverService().declineJobOffer(assignmentId);
        }
      } else {
        final now = DateTime.now().toIso8601String();
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (accept) {
          await Supabase.instance.client.from('bookings').update({
            'status': 'driver_accepted',
            'driver_id': currentUserId,
            'with_driver': true,
            'updated_at': now,
          }).eq('id', bookingId);
        } else {
          await Supabase.instance.client.from('bookings').update({
            'status': 'pending',
            'driver_id': null,
            'updated_at': now,
          }).eq('id', bookingId);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? '✅ Job accepted! Booking is marked as Driver Accepted. Waiting for operator/partner finalization.'
                : 'Job offer declined. Operator/partner notified to reassign.',
          ),
          backgroundColor: accept ? AppColors.success : AppColors.warning,
        ),
      );
      widget.onChanged();
    } catch (error) {
      if (mounted) {
        setState(() {
          if (accept) _hasAccepted = false;
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update job assignment: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  String _displayTripStatus(String status, {String? assignmentStatus}) {
    final s = status.trim().toLowerCase();
    final a = assignmentStatus?.trim().toLowerCase();
    if (s == 'driver_accepted' || a == 'accepted') {
      return 'Driver Accepted';
    }
    if (a == 'expired') {
      return 'Offer Expired';
    }
    if (s == 'pending' ||
        s == 'pending_approval' ||
        s == 'awaiting_driver' ||
        s == 'driver_assigned' ||
        s == 'pending_driver_confirmation' ||
        a == 'pending_offer' ||
        a == 'assigned') {
      return 'Pending Acceptance';
    }
    switch (s) {
      case 'approved':
      case 'confirmed':
        return 'Approved';
      case 'active':
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
      case 'returned':
        return 'Completed';
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'declined':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusBadgeColor(String status, {String? assignmentStatus}) {
    final s = status.trim().toLowerCase();
    final a = assignmentStatus?.trim().toLowerCase();
    if (s == 'driver_accepted' || a == 'accepted') {
      return Colors.cyan;
    }
    if (a == 'expired') {
      return Colors.orange.shade700;
    }
    if (s == 'pending' ||
        s == 'pending_approval' ||
        s == 'awaiting_driver' ||
        s == 'driver_assigned' ||
        s == 'pending_driver_confirmation' ||
        a == 'pending_offer' ||
        a == 'assigned') {
      return Colors.amber.shade700;
    }
    if (s == 'approved' || s == 'confirmed') {
      return AppColors.success;
    }
    if (s == 'active' || s == 'ongoing') {
      return AppColors.primary;
    }
    if (s == 'completed' || s == 'returned') {
      return Colors.blue;
    }
    return Colors.redAccent;
  }

  Future<void> _markReturned(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text(
          'Confirm Vehicle Return',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Mark this vehicle as returned now? This will notify the operator and vehicle owner to conduct the post-trip inspection and finalize billing.',
          style: TextStyle(
            color: isDark ? AppColors.textSecondary : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final total = await DriverService().completeAssignedBookingReturn(
        bookingId: trip['id'].toString(),
        returnedAt: now,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vehicle return recorded. Final total: PHP ${formatAmount(total, decimalDigits: 0)}. Waiting for the after checklist, payment, and required ratings.',
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

  Future<void> _rateRenter(BuildContext context) async {
    final bookingId = trip['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TripRatingFlowScreen(
          bookingId: bookingId,
          reviewerRole: 'driver',
          title: 'Rate Renter',
          subtitle:
              'Rate the renter and operator for this completed trip.',
        ),
      ),
    );
    if (submitted == true) {
      final actorId = AuthService().currentUser?.id;
      final reconciled = await TripRatingService().reconcileCompletedBooking(
        bookingId,
        operatorFallbackUserId: actorId,
      );
      widget.onChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reconciled
                ? 'Rating saved. Trip successfully completed!'
                : 'Rating saved. Waiting for remaining reviews.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _openConversation(BuildContext context) async {
    try {
      final conversation = await ChatService().getConversationByBookingId(
        trip['id'].toString(),
      );
      final conversationId = conversation?['id']?.toString() ?? '';
      if (conversationId.isEmpty) {
        final notEligibleYet = !BookingService().isEligibleForBookingChat(trip);
        throw Exception(
          notEligibleYet
              ? 'Group chat will automatically be available 3 days before the trip starts.'
              : 'The booking conversation is not ready yet.',
        );
      }
      if (!context.mounted) return;
      await Navigator.of(context).pushNamed(
        '/chat-detail',
        arguments: {
          'conversationId': conversationId,
          'recipientName': 'Booking Conversation',
          'isAutoGenerated': false,
          'userRole': 'driver',
        },
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openNavigation(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripNavigationScreen(
          bookingId: trip['id'].toString(),
          participantRole: 'driver',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildLegacyRevenueView(context);
  }

  Widget _buildLegacyRevenueView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = (trip['status']?.toString() ?? 'assigned').toLowerCase();
    final assignments = (trip['job_assignments'] as List?)
        ?.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList() ?? [];
    final latestAssignment = assignments.isNotEmpty ? assignments.last : null;
    final assignmentStatus = latestAssignment?['status']?.toString().toLowerCase();

    final isDriverAcceptedWaitingFinalize = _hasAccepted ||
        status == 'driver_accepted' ||
        (assignmentStatus == 'accepted' &&
            (status == 'pending' ||
                status == 'driver_accepted' ||
                status == 'driver_assigned' ||
                status == 'pending_driver_confirmation'));

    final isPendingDriverAcceptance = !isDriverAcceptedWaitingFinalize &&
        (status == 'pending' ||
            status == 'pending_approval' ||
            status == 'awaiting_driver' ||
            status == 'driver_assigned' ||
            status == 'pending_driver_confirmation') &&
        assignments.any((a) {
          final s = a['status']?.toString().toLowerCase();
          return s == 'pending_offer' || s == 'assigned';
        });

    final completionState = BookingService().getTripCompletionState(trip);
    final completionStage = completionState['completionStage']?.toString();
    final vehicle = trip['vehicles'] as Map<String, dynamic>?;
    final renter = trip['renter'] as Map<String, dynamic>?;
    final renterName = renter?['full_name']?.toString().trim();
    final renterPhone = renter?['phone']?.toString().trim();
    final renterId = trip['renter_id']?.toString() ?? '';
    final startLabel = _formatDriverScheduleDate(trip['start_at'] ?? trip['start_date']);
    final endLabel = _formatDriverScheduleDate(trip['end_at'] ?? trip['end_date']);
    final durationLabel = _formatDriverBookingDuration(trip);
    final isPartner = _isPartnerVehicleForDriver(trip);
    final total =
        (trip['total_price'] as num?)?.toDouble() ??
        (trip['total_cost'] as num?)?.toDouble();
    final tripFee = (trip['trip_fee'] as num?)?.toDouble() ??
        (latestAssignment?['trip_fee'] as num?)?.toDouble();
    final vehicleName = vehicle == null
        ? 'Assigned vehicle'
        : [vehicle['vehicle_name'], vehicle['brand'], vehicle['model']]
              .where(
                (part) => part != null && part.toString().trim().isNotEmpty,
              )
              .map((part) => part.toString().trim())
              .take(2)
              .join(' ');
    final plateNumber = vehicle?['plate_number']?.toString().trim() ?? '';

    final effectiveStatus = _hasAccepted ? 'driver_accepted' : (trip['status']?.toString() ?? 'assigned');
    final effectiveAssignmentStatus = _hasAccepted ? 'accepted' : assignmentStatus;
    final badgeColor = _statusBadgeColor(effectiveStatus, assignmentStatus: effectiveAssignmentStatus);
    final badgeLabel = _displayTripStatus(effectiveStatus, assignmentStatus: effectiveAssignmentStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
                    Text(
                      vehicleName.isEmpty ? 'Assigned vehicle' : vehicleName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (plateNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Plate: $plateNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  _buildDriverVehicleOwnershipBadge(isPartner: isPartner, isDark: isDark),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Route Destination Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.trip_origin_rounded, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pickup: ${trip['pickup_location'] ?? 'Declared Pickup Point'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Destination: ${trip['dropoff_location'] ?? 'Declared Destination'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Rentee Info
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 15,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Rentee: ${renterName?.isNotEmpty == true ? renterName : 'Unknown'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (renterId.isNotEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 21),
              child: Text(
                'Rentee ID: $renterId',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          // Schedule & Days of Booking
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Schedule: $startLabel → $endLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Duration: $durationLabel',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (total != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Total: PHP ${formatAmount(total, decimalDigits: 0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (tripFee != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                'Driver Fee: PHP ${formatAmount(tripFee, decimalDigits: 0)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // View Details Button (Careful padding, available across ALL status tabs)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDriverTripDetailsModal(context, trip),
              icon: const Icon(Icons.info_outline_rounded, size: 16),
              label: const Text('View Details'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
                foregroundColor: isDark ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Download Trip Receipt
          if (status != 'cancelled' && status != 'canceled') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await BookingReceiptService.shareReceipt(trip);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not download receipt: $error'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download Trip Receipt'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],

          if (isPendingDriverAcceptance) ...[
            const SizedBox(height: 10),
            const _DriverWaitingAction(
              icon: Icons.hourglass_top_rounded,
              message:
                  'You have been assigned to this trip. Please review the details and accept or decline this job offer.',
            ),
            const SizedBox(height: 10),
            if (_isResponding)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _respondToJob(false),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Decline Job'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _respondToJob(true),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Accept Job'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
          if (isDriverAcceptedWaitingFinalize) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 20, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You accepted this trip assignment! Waiting for the operator or partner to finalize and approve the booking.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == 'confirmed' || status == 'approved') ...[
            const SizedBox(height: 10),
            const _DriverWaitingAction(
              icon: Icons.fact_check_outlined,
              message:
                  'Waiting for the vehicle owner to submit the pre-trip checklist and start the trip.',
            ),
          ],
          if ({
            'approved',
            'confirmed',
            'active',
            'ongoing',
            'return_pending_inspection',
          }.contains(status)) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Builder(
                builder: (context) {
                  final isChatEligible =
                      BookingService().isEligibleForBookingChat(trip);
                  return OutlinedButton.icon(
                    onPressed: () => _openConversation(context),
                    icon: Icon(
                      isChatEligible
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.lock_clock,
                      size: 16,
                    ),
                    label: Text(
                      isChatEligible ? 'Message' : 'Chat (Unlocks 72h Prior)',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (status == 'active' || status == 'ongoing') ...[
            const SizedBox(height: 10),
            Column(
              children: [
                BookingReturnCountdown(booking: trip),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openNavigation(context),
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'return_pending_inspection') ...[
            const SizedBox(height: 10),
            const _DriverWaitingAction(
              icon: Icons.fact_check_outlined,
              message:
                  'Waiting for the vehicle owner to submit the after checklist.',
            ),
          ],
          if (status == 'awaiting_completion' &&
              completionStage != 'driver_rating') ...[
            const SizedBox(height: 10),
            const _DriverWaitingAction(
              icon: Icons.hourglass_bottom_rounded,
              message: 'Waiting for payment or the previous required rating.',
            ),
          ],
          if (completionStage == 'driver_rating' ||
              status == 'completed' ||
              status == 'returned') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _rateRenter(context),
                icon: const Icon(Icons.star_rate_rounded, size: 16),
                label: const Text('Rate Renter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverWaitingAction extends StatelessWidget {
  final IconData icon;
  final String message;

  const _DriverWaitingAction({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondary : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverOfferCard extends StatefulWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onChanged;

  const _DriverOfferCard({required this.offer, required this.onChanged});

  @override
  State<_DriverOfferCard> createState() => _DriverOfferCardState();
}

class _DriverOfferCardState extends State<_DriverOfferCard> {
  bool _isResponding = false;
  bool _hasAccepted = false;
  Timer? _offerCountdownTimer;

  Map<String, dynamic> get offer => widget.offer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _offerCountdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _offerCountdownTimer?.cancel();
    _offerCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _getRemainingSeconds();
      if (remaining <= 0) {
        _offerCountdownTimer?.cancel();
        BookingService().checkAndExpireDriverAssignments().then((_) {
          if (mounted) widget.onChanged();
        });
      } else {
        setState(() {});
      }
    });
  }

  int _getRemainingSeconds() {
    final offeredAtRaw = offer['offered_at'] ?? offer['created_at'];
    final offeredAt = offeredAtRaw != null
        ? DateTime.tryParse(offeredAtRaw.toString())?.toLocal()
        : null;
    if (offeredAt == null) return 0;
    final diff = 600 - DateTime.now().difference(offeredAt).inSeconds;
    return diff > 0 ? diff : 0;
  }

  Future<void> _respondToOffer(bool accept) async {
    final assignmentId = offer['id']?.toString() ?? '';
    if (assignmentId.isEmpty || _isResponding) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: Text(
          accept ? 'Accept job offer?' : 'Decline job offer?',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          accept
              ? 'The operator will be notified and can finalize the booking.'
              : 'The operator will be notified to select another driver.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: accept ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(accept ? 'Accept' : 'Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isResponding = true;
      if (accept) _hasAccepted = true;
    });
    try {
      if (accept) {
        await DriverService().acceptJobOffer(assignmentId);
      } else {
        await DriverService().declineJobOffer(assignmentId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Job accepted. Waiting for operator finalization.'
                : 'Job declined. The operator will select another driver.',
          ),
          backgroundColor: accept ? AppColors.success : AppColors.warning,
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() {
          if (accept) _hasAccepted = false;
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update job offer: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildLegacyRevenueView(context);
  }

  Widget _buildLegacyRevenueView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final booking = offer['bookings'] as Map<String, dynamic>?;
    final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
    final renter = booking?['renter'] as Map<String, dynamic>?;
    final assignmentRaw = offer['status']?.toString().toLowerCase().trim() ?? '';
    final bookingStatus = booking?['status']?.toString().toLowerCase().trim() ?? '';
    final isAccepted = _hasAccepted ||
        assignmentRaw == 'accepted' ||
        assignmentRaw == 'confirmed' ||
        bookingStatus == 'driver_accepted';
    final assignmentStatus = isAccepted
        ? 'Accepted'
        : (offer['status']?.toString().replaceAll('_', ' ') ?? 'assigned');
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
    final plateNumber = vehicle?['plate_number']?.toString().trim() ?? '';
    final isPartner = _isPartnerVehicleForDriver(booking ?? offer);
    final scheduleStart = _formatDriverScheduleDate(
      booking?['start_at'] ?? booking?['start_date'],
    );
    final scheduleEnd = _formatDriverScheduleDate(
      booking?['end_at'] ?? booking?['end_date'],
    );
    final durationLabel = _formatDriverBookingDuration(booking ?? offer);
    final total =
        (booking?['total_price'] as num?)?.toDouble() ??
        (booking?['total_cost'] as num?)?.toDouble();
    final tripFee = (offer['trip_fee'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAccepted
              ? Colors.green.withValues(alpha: 0.5)
              : (isDark ? AppColors.borderColor : Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAccepted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.45),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Job Offer Accepted! Waiting for operator or partner to finalize the booking.',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // 10-Minute Acceptance Window Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFE5A93C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getRemainingSeconds() > 0
                          ? 'Accept within 10 minutes (${(_getRemainingSeconds() ~/ 60).toString().padLeft(2, '0')}:${(_getRemainingSeconds() % 60).toString().padLeft(2, '0')} remaining)'
                          : 'Offer expired (10-minute window exceeded)',
                      style: const TextStyle(
                        color: Color(0xFFE5A93C),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleName.isEmpty ? 'Assigned vehicle' : vehicleName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (plateNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Plate: $plateNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  _buildDriverVehicleOwnershipBadge(isPartner: isPartner, isDark: isDark),
                  if (isAccepted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 11, color: Colors.green),
                          SizedBox(width: 3),
                          Text(
                            'ACCEPTED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        assignmentStatus.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Route Destination Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.trip_origin_rounded, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pickup: ${booking?['pickup_location'] ?? 'Declared Pickup Point'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Destination: ${booking?['dropoff_location'] ?? 'Declared Destination'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Rentee Info
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 15,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Rentee: ${renterName?.isNotEmpty == true ? renterName : 'Unknown'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (renterId.isNotEmpty && renterId != 'N/A') ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 21),
              child: Text(
                'Rentee ID: $renterId',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          // Schedule & Days
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Schedule: $scheduleStart → $scheduleEnd',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Duration: $durationLabel',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (total != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Total: PHP ${formatAmount(total, decimalDigits: 0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (tripFee != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                'Driver Fee: PHP ${formatAmount(tripFee, decimalDigits: 0)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          // View Details Button (Careful padding)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDriverTripDetailsModal(context, booking ?? offer),
              icon: const Icon(Icons.info_outline_rounded, size: 16),
              label: const Text('View Details'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
                foregroundColor: isDark ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (isAccepted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.45)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Job Accepted • Waiting For Approval',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isResponding
                        ? null
                        : () => _respondToOffer(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _isResponding ? null : () => _respondToOffer(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isResponding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Accept', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Helper methods for Driver vehicle badges, schedule formatting, and View Details modal
bool _isPartnerVehicleForDriver(Map<String, dynamic>? tripOrBooking) {
  if (tripOrBooking == null) return false;
  final vehicle = (tripOrBooking['vehicles'] ?? tripOrBooking['vehicle'] ?? tripOrBooking['partner_vehicles']) as Map<String, dynamic>?;
  final owner = vehicle?['owner'] as Map<String, dynamic>?;
  final ownerRole = owner?['role']?.toString().trim().toLowerCase();
  return tripOrBooking['is_partner_vehicle'] == true ||
      tripOrBooking['partner_id'] != null ||
      tripOrBooking['partner_vehicle_id'] != null ||
      vehicle?['is_partner_vehicle'] == true ||
      vehicle?['partner_id'] != null ||
      vehicle?['partner_vehicle_id'] != null ||
      ownerRole == 'partner';
}

String _resolveDriverVehicleImageUrl(Map<String, dynamic>? vehicle) {
  if (vehicle == null) return '';

  String normalize(dynamic val) {
    if (val is List && val.isNotEmpty) return normalize(val.first);
    var raw = val?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('data:')) {
      return raw;
    }
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
    if (norm.isNotEmpty) return norm;
  }

  final rawImages = vehicle['vehicle_images'] ?? vehicle['images'] ?? vehicle['photos'];
  if (rawImages is List && rawImages.isNotEmpty) {
    for (final image in rawImages) {
      if (image is Map) {
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

  return '';
}

class _DriverVehicleThumbnail extends StatefulWidget {
  final Map<String, dynamic>? vehicle;
  final String? vehicleId;
  final String? partnerVehicleId;
  final bool isDark;
  final double size;

  const _DriverVehicleThumbnail({
    this.vehicle,
    this.vehicleId,
    this.partnerVehicleId,
    required this.isDark,
    this.size = 54,
  });

  @override
  State<_DriverVehicleThumbnail> createState() => _DriverVehicleThumbnailState();
}

class _DriverVehicleThumbnailState extends State<_DriverVehicleThumbnail> {
  String? _imageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolveOrFetchImage();
  }

  @override
  void didUpdateWidget(covariant _DriverVehicleThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicle != widget.vehicle ||
        oldWidget.vehicleId != widget.vehicleId ||
        oldWidget.partnerVehicleId != widget.partnerVehicleId) {
      _resolveOrFetchImage();
    }
  }

  void _resolveOrFetchImage() {
    final direct = _resolveDriverVehicleImageUrl(widget.vehicle);
    if (direct.isNotEmpty) {
      _imageUrl = direct;
      return;
    }

    final targetId = widget.vehicleId ??
        widget.vehicle?['id']?.toString() ??
        widget.partnerVehicleId ??
        widget.vehicle?['partner_vehicle_id']?.toString();

    if (targetId == null || targetId.isEmpty) return;

    _isLoading = true;
    _fetchVehicleImageAsync(targetId);
  }

  Future<void> _fetchVehicleImageAsync(String vId) async {
    try {
      final supabase = Supabase.instance.client;
      final imgRows = await supabase
          .from('vehicle_images')
          .select('image_url, display_order')
          .or('vehicle_id.eq.$vId,partner_vehicle_id.eq.$vId')
          .order('display_order', ascending: true)
          .limit(1);
      if (imgRows.isNotEmpty) {
        final rawUrl = imgRows.first['image_url'];
        final resolved = _resolveDriverVehicleImageUrl({'image_url': rawUrl});
        if (resolved.isNotEmpty && mounted) {
          setState(() {
            _imageUrl = resolved;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error lazily fetching vehicle image for driver modal: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFullImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: OptimizedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageUrl != null && _imageUrl!.trim().isNotEmpty;

    if (!hasImage) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              )
            : const Center(
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
      );
    }

    return GestureDetector(
      onTap: () => _showFullImagePreview(context, _imageUrl!),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDark ? AppColors.borderColor : Colors.grey.shade300,
            width: 1,
          ),
          color: widget.isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            OptimizedNetworkImage(
              imageUrl: _imageUrl!,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(11),
              errorWidget: Container(
                color: AppColors.primary.withValues(alpha: 0.15),
                child: const Center(
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    color: AppColors.primary,
                    size: 26,
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

Widget _buildDriverVehicleOwnershipBadge({
  required bool isPartner,
  required bool isDark,
}) {
  final color = isPartner ? const Color(0xFFBA68C8) : const Color(0xFF26A69A);
  final bgColor = isPartner
      ? Colors.purple.withValues(alpha: 0.15)
      : Colors.teal.withValues(alpha: 0.15);
  final borderColor = isPartner
      ? Colors.purple.withValues(alpha: 0.5)
      : Colors.teal.withValues(alpha: 0.5);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: borderColor, width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPartner ? Icons.handshake_rounded : Icons.business_rounded,
          size: 11,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          isPartner ? 'PARTNER CAR' : 'PSDC FLEET',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
            color: color,
          ),
        ),
      ],
    ),
  );
}

String _formatDriverScheduleDate(dynamic dateVal) {
  if (dateVal == null) return 'N/A';
  final parsed = DateTime.tryParse(dateVal.toString());
  if (parsed == null) return dateVal.toString();
  return DateFormat('MMM dd, yyyy • h:mm a').format(parsed.toLocal());
}

String _formatDriverBookingDuration(Map<String, dynamic> trip) {
  final start = DateTime.tryParse(
    trip['start_at']?.toString() ?? trip['start_date']?.toString() ?? '',
  );
  final end = DateTime.tryParse(
    trip['end_at']?.toString() ?? trip['end_date']?.toString() ?? '',
  );
  if (trip['is_hourly'] == true || trip['rental_type'] == 'hourly') {
    if (start != null && end != null) {
      final hours = end.difference(start).inHours;
      return '$hours Hours (Hourly)';
    }
  }
  if (trip['days'] != null && (trip['days'] as num) > 0) {
    final d = (trip['days'] as num).toInt();
    return '$d Day${d == 1 ? '' : 's'}';
  }
  if (start != null && end != null) {
    final hours = end.difference(start).inHours;
    if (hours < 24 && hours > 0) {
      return '$hours Hours';
    }
    final days = (hours / 24).ceil();
    return '$days Day${days <= 1 ? '' : 's'}';
  }
  return '1 Day';
}

void _showDriverTripDetailsModal(BuildContext context, Map<String, dynamic> trip) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final booking = (trip['bookings'] as Map<String, dynamic>?) ?? trip;
  final vehicle = (booking['vehicles'] ?? booking['vehicle'] ?? booking['partner_vehicles'] ?? trip['vehicles'] ?? trip['vehicle']) as Map<String, dynamic>?;
  final renter = (booking['renter'] ?? trip['renter']) as Map<String, dynamic>?;
  final renterName = renter?['full_name']?.toString().trim();
  final isPartner = _isPartnerVehicleForDriver(booking);

  final vehicleName = vehicle == null
      ? 'Assigned Vehicle'
      : [vehicle['vehicle_name'], vehicle['brand'], vehicle['model']]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .map((part) => part.toString().trim())
            .join(' ');
  final plateNumber = vehicle?['plate_number']?.toString().trim() ?? '';
  final vehicleId = vehicle?['id']?.toString() ??
      booking['vehicle_id']?.toString() ??
      trip['vehicle_id']?.toString();
  final partnerVehicleId = vehicle?['partner_vehicle_id']?.toString() ??
      booking['partner_vehicle_id']?.toString() ??
      trip['partner_vehicle_id']?.toString();
  final total = (booking['total_price'] as num?)?.toDouble() ??
      (booking['total_cost'] as num?)?.toDouble() ??
      0.0;
  final tripFee = (trip['trip_fee'] as num?)?.toDouble();
  final startStr = _formatDriverScheduleDate(booking['start_at'] ?? booking['start_date']);
  final endStr = _formatDriverScheduleDate(booking['end_at'] ?? booking['end_date']);
  final durationStr = _formatDriverBookingDuration(booking);
  final status = (booking['status']?.toString().trim().isEmpty ?? true)
      ? 'Assigned'
      : booking['status'].toString().trim();
  final assignmentStatus = trip['status']?.toString().trim().toLowerCase() ?? '';
  final isDriverAccepted = status.toLowerCase() == 'driver_accepted' || assignmentStatus == 'accepted';

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16202E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top drag handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                // Header bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trip & Booking Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Booking ID: ${booking['id'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: const Icon(Icons.close_rounded),
                        color: isDark ? Colors.grey.shade400 : Colors.black54,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Scrollable content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Vehicle & Badges Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F1722) : const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DriverVehicleThumbnail(
                                  vehicle: vehicle,
                                  vehicleId: vehicleId,
                                  partnerVehicleId: partnerVehicleId,
                                  isDark: isDark,
                                  size: 54,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vehicleName.isEmpty ? 'Assigned Vehicle' : vehicleName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      if (plateNumber.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          'Plate: $plateNumber',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildDriverVehicleOwnershipBadge(isPartner: isPartner, isDark: isDark),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDriverAccepted
                                        ? Colors.green.withValues(alpha: 0.18)
                                        : AppColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDriverAccepted
                                          ? Colors.green.withValues(alpha: 0.6)
                                          : AppColors.success.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isDriverAccepted) ...[
                                        const Icon(Icons.check_rounded, size: 11, color: Colors.green),
                                        const SizedBox(width: 3),
                                      ],
                                      Text(
                                        isDriverAccepted ? 'DRIVER ACCEPTED' : status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                          color: isDriverAccepted ? Colors.green : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isDriverAccepted) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'You accepted this trip! Waiting for operator or partner to finalize and approve the booking.',
                                  style: TextStyle(
                                    color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Rentee Details Card
                      _buildDriverDetailSectionCard(
                        isDark: isDark,
                        icon: Icons.person_rounded,
                        title: 'Rentee (Customer) Details',
                        children: [
                          _buildDriverDetailRow(
                            label: 'Full Name',
                            value: renterName?.isNotEmpty == true ? renterName! : 'Unknown Customer',
                            isDark: isDark,
                            isEmphasized: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Route & Destination Card
                      _buildDriverDetailSectionCard(
                        isDark: isDark,
                        icon: Icons.alt_route_rounded,
                        title: 'Trip Route & Destination',
                        children: [
                          InkWell(
                            onTap: () {
                              TripLocationMapDialog.show(
                                context: context,
                                booking: booking,
                                vehicleName: vehicleName,
                                plateNumber: plateNumber,
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.trip_origin_rounded, color: Colors.green, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Pickup Location',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.map_rounded, size: 12, color: AppColors.primary),
                                            const SizedBox(width: 2),
                                            const Text(
                                              '(Tap to View Map)',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          booking['pickup_location']?.toString().trim().isNotEmpty == true
                                              ? booking['pickup_location'].toString()
                                              : 'Declared Pickup Point',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 8, top: 4, bottom: 4),
                            child: SizedBox(
                              height: 16,
                              child: VerticalDivider(thickness: 2, color: Colors.grey),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              TripLocationMapDialog.show(
                                context: context,
                                booking: booking,
                                vehicleName: vehicleName,
                                plateNumber: plateNumber,
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Destination (Drop-off)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.map_rounded, size: 12, color: AppColors.primary),
                                            const SizedBox(width: 2),
                                            const Text(
                                              '(Tap to View Map)',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          booking['dropoff_location']?.toString().trim().isNotEmpty == true
                                              ? booking['dropoff_location'].toString()
                                              : 'Declared Destination Point',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Schedule & Duration Card
                      _buildDriverDetailSectionCard(
                        isDark: isDark,
                        icon: Icons.calendar_month_rounded,
                        title: 'Schedule & Duration',
                        children: [
                          _buildDriverDetailRow(label: 'Booking Duration', value: durationStr, isDark: isDark, isEmphasized: true),
                          const SizedBox(height: 8),
                          _buildDriverDetailRow(label: 'Start Date & Time', value: startStr, isDark: isDark),
                          const SizedBox(height: 8),
                          _buildDriverDetailRow(label: 'End Date & Time', value: endStr, isDark: isDark),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Billing & Earnings Card
                      _buildDriverDetailSectionCard(
                        isDark: isDark,
                        icon: Icons.payments_outlined,
                        title: 'Booking Cost & Driver Fee',
                        children: [
                          _buildDriverDetailRow(
                            label: 'Total Booking Amount',
                            value: 'PHP ${formatAmount(total, decimalDigits: 2)}',
                            isDark: isDark,
                            isEmphasized: true,
                          ),
                          if (tripFee != null) ...[
                            const SizedBox(height: 8),
                            _buildDriverDetailRow(
                              label: 'Driver Assigned Fee / Payout',
                              value: 'PHP ${formatAmount(tripFee, decimalDigits: 2)}',
                              isDark: isDark,
                              isEmphasized: true,
                              valueColor: Colors.green,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Close Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(modalContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Close Details',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildDriverDetailSectionCard({
  required bool isDark,
  required IconData icon,
  required String title,
  required List<Widget> children,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF0F1722) : const Color(0xFFF7FAFC),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? AppColors.borderColor : Colors.grey.shade200,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

Widget _buildDriverDetailRow({
  required String label,
  required String value,
  required bool isDark,
  bool isEmphasized = false,
  Color? valueColor,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: isEmphasized ? 14 : 12,
          fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w600,
          color: valueColor ?? (isDark ? Colors.white : Colors.black87),
        ),
      ),
    ],
  );
}

