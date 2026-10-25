part of '../partner_home_screen.dart';

/// 🎯 Booking Detail Modal Widget
/// 🎯 Booking Detail Modal Widget (Upgraded with Rich Details & Driver Offer Status)
class BookingDetailModal extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? vehicle;
  final Map<String, dynamic>? renter;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onAssignDriver;
  final VoidCallback? onReviewDocs;
  final VoidCallback? onMessage;
  final VoidCallback? onBeforeInspection;
  final VoidCallback? onViewBeforeInspection;
  final VoidCallback? onAfterInspection;
  final VoidCallback? onConfirmPayment;
  final VoidCallback? onRateTrip;
  final VoidCallback? onReceipt;
  final VoidCallback? onRefresh;
  final bool showHeader;
  final bool? isLoading;

  const BookingDetailModal({
    super.key,
    required this.booking,
    this.vehicle,
    this.renter,
    required this.onApprove,
    required this.onReject,
    this.onAssignDriver,
    this.onReviewDocs,
    this.onMessage,
    this.onBeforeInspection,
    this.onViewBeforeInspection,
    this.onAfterInspection,
    this.onConfirmPayment,
    this.onRateTrip,
    this.onReceipt,
    this.onRefresh,
    this.showHeader = true,
    this.isLoading,
  });

  @override
  State<BookingDetailModal> createState() => _BookingDetailModalState();
}

class _BookingDetailModalState extends State<BookingDetailModal> {
  bool _isLoading = true;
  late Map<String, dynamic> _detailedBooking;
  Map<String, dynamic>? _vehicle;
  Map<String, dynamic>? _renter;
  Timer? _offerCountdownTimer;

  @override
  void initState() {
    super.initState();
    _detailedBooking = Map<String, dynamic>.from(widget.booking);
    _vehicle = widget.vehicle ??
        (_detailedBooking['vehicles'] is Map
            ? Map<String, dynamic>.from(_detailedBooking['vehicles'])
            : null);
    _renter = widget.renter ??
        (_detailedBooking['users'] is Map
            ? Map<String, dynamic>.from(_detailedBooking['users'])
            : null);

    if (widget.isLoading == false && _vehicle != null && _renter != null) {
      _isLoading = false;
    } else {
      _loadFullBookingDetails();
    }
    _initOfferTimer();
  }

  void _initOfferTimer() {
    _offerCountdownTimer?.cancel();
    _offerCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final rawAssignments = _detailedBooking['job_assignments'];
      final List<Map<String, dynamic>> assignments = (rawAssignments is List)
          ? rawAssignments.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      if (assignments.isNotEmpty) {
        assignments.sort((a, b) {
          final aDate = DateTime.tryParse((a['created_at'] ?? a['offered_at'])?.toString() ?? '');
          final bDate = DateTime.tryParse((b['created_at'] ?? b['offered_at'])?.toString() ?? '');
          return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
        });
      }
      final latest = assignments.isNotEmpty ? assignments.first : null;
      final status = latest?['status']?.toString().toLowerCase().trim();
      final hasDriver = _detailedBooking['driver_id'] != null && _detailedBooking['driver_id'].toString().isNotEmpty;
      final bStatus = (_detailedBooking['status'] as String? ?? 'pending').toLowerCase();

      if (status == 'pending_offer' || status == 'assigned' || (hasDriver && bStatus == 'pending')) {
        final assignedAtRaw = _detailedBooking['driver_assigned_at'] ??
            latest?['offered_at'] ??
            latest?['created_at'];
        final assignedAt = assignedAtRaw != null
            ? DateTime.tryParse(assignedAtRaw.toString())?.toLocal()
            : null;
        if (assignedAt != null) {
          final elapsed = DateTime.now().difference(assignedAt).inSeconds;
          if (elapsed >= 600) {
            _offerCountdownTimer?.cancel();
            BookingService().checkAndExpireDriverAssignments().then((_) {
              if (mounted) _loadFullBookingDetails();
            });
            setState(() {});
            return;
          }
        }
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant BookingDetailModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.booking != oldWidget.booking) {
      _detailedBooking = Map<String, dynamic>.from(widget.booking);
      _vehicle = widget.vehicle ??
          (_detailedBooking['vehicles'] is Map
              ? Map<String, dynamic>.from(_detailedBooking['vehicles'])
              : null);
      _renter = widget.renter ??
          (_detailedBooking['users'] is Map
              ? Map<String, dynamic>.from(_detailedBooking['users'])
              : null);
      _initOfferTimer();
    }
  }

  @override
  void dispose() {
    _offerCountdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFullBookingDetails() async {
    final bId = _detailedBooking['id']?.toString().trim();
    if (bId == null || bId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final fresh = await BookingService().getBookingById(bId);
      if (fresh != null && mounted) {
        final hydratedList =
            await BookingService().hydrateBookingVehicles([fresh]);
        final hydrated = hydratedList.isNotEmpty ? hydratedList.first : fresh;
        if (mounted) {
          setState(() {
            _detailedBooking = hydrated;
            _vehicle = widget.vehicle ??
                (hydrated['vehicles'] is Map
                    ? Map<String, dynamic>.from(hydrated['vehicles'])
                    : null);
            _renter = widget.renter ??
                (hydrated['users'] is Map
                    ? Map<String, dynamic>.from(hydrated['users'])
                    : null);
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading full booking details: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> get booking => _detailedBooking;
  Map<String, dynamic>? get vehicle =>
      _vehicle ?? (booking['vehicles'] as Map<String, dynamic>?);
  Map<String, dynamic>? get renter =>
      _renter ?? (booking['users'] as Map<String, dynamic>?);

  Future<void> _callPhone(String? phone) async {
    final clean = phone?.trim() ?? '';
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial phone: $clean')),
      );
    }
  }

  String _formatDateTime(dynamic dt) {
    if (dt == null) return 'N/A';
    final parsed = DateTime.tryParse(dt.toString())?.toLocal();
    if (parsed == null) return dt.toString();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[parsed.month - 1];
    final day = parsed.day.toString().padLeft(2, '0');
    final year = parsed.year;
    final hour24 = parsed.hour;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    return '$month $day, $year • $hour12:$minute $period';
  }

  String _formatDuration(Map<String, dynamic> b) {
    final start = DateTime.tryParse((b['start_at'] ?? b['start_date'])?.toString() ?? '')?.toLocal();
    final end = DateTime.tryParse((b['end_at'] ?? b['end_date'])?.toString() ?? '')?.toLocal();
    if (start == null || end == null) return '1 Day';
    final diff = end.difference(start);
    final hours = diff.inHours;
    if (hours < 24) {
      return hours <= 0 ? '1 Day' : '$hours Hours (Hourly)';
    }
    final days = (hours / 24).ceil();
    return days == 1 ? '1 Day' : '$days Days';
  }

  Widget _buildPaymentStateBadge(Map<String, dynamic> b) {
    final state = resolveBookingPaymentState(b);
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

  Color _statusColor(String status, {String? assignmentStatus}) {
    final s = status.trim().toLowerCase();
    final a = assignmentStatus?.trim().toLowerCase();
    if (s == 'driver_accepted' || a == 'accepted') return Colors.cyan;
    if (a == 'expired') return Colors.orange.shade700;
    if (s == 'pending' || a == 'pending_offer' || a == 'assigned') return Colors.amber.shade700;
    if (s == 'approved' || s == 'confirmed') return AppColors.success;
    if (s == 'active' || s == 'ongoing') return AppColors.primary;
    if (s == 'completed' || s == 'returned') return Colors.blue;
    return Colors.redAccent;
  }

  String _statusLabel(String status, {String? assignmentStatus}) {
    final s = status.trim().toLowerCase();
    final a = assignmentStatus?.trim().toLowerCase();
    if (s == 'driver_accepted' || a == 'accepted') return 'DRIVER ACCEPTED';
    if (a == 'expired') return 'DRIVER OFFER EXPIRED';
    if (a == 'pending_offer') return 'OFFER SENT • WAITING DRIVER';
    if (a == 'rejected' || a == 'declined') return 'DRIVER DECLINED';
    if (s == 'pending') return 'PENDING';
    if (s == 'approved' || s == 'confirmed') return 'APPROVED';
    if (s == 'active' || s == 'ongoing') return 'ONGOING';
    if (s == 'completed' || s == 'returned') return 'COMPLETED';
    if (s == 'cancelled' || s == 'canceled' || s == 'rejected') return 'CANCELLED';
    return status.toUpperCase();
  }

  /// Masks an email address: "renter@psdc.com" → "ren***@*****.com"
  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];

    // Mask local part: show first 3 chars, rest as ***
    final maskedLocal = local.length <= 3
        ? local
        : '${local.substring(0, 3)}${'*' * (local.length - 3)}';

    // Mask domain: show extension (after last dot), mask the rest
    final dotIndex = domain.lastIndexOf('.');
    final maskedDomain = dotIndex > 0
        ? '${'*' * dotIndex}.${domain.substring(dotIndex + 1)}'
        : '*****';

    return '$maskedLocal@$maskedDomain';
  }

  /// Masks a phone number: "09123532512" → "091***32512" (first 3, stars, last 5)
  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return phone;
    final visible = 3;
    final tail = 5;
    final masked = digits.length - visible - tail;
    if (masked <= 0) return phone;
    return '${digits.substring(0, visible)}${'*' * masked}${digits.substring(digits.length - tail)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading || widget.isLoading == true) {
      return MobilisSkeletonBookingDetail(
        isDark: isDark,
        showHeader: widget.showHeader,
        onClose: widget.showHeader ? () => Navigator.pop(context) : null,
      );
    }

    final totalPrice = (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final withDriver = _bookingNeedsDriver(booking['with_driver']);
    final driverId = booking['driver_id']?.toString().trim();
    final status = (booking['status'] as String? ?? 'pending').toLowerCase();
    final bookingId = booking['id']?.toString() ?? '';
    final shortId = bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase();

    // Resolve driver job assignments
    final rawAssignments = booking['job_assignments'];
    final List<Map<String, dynamic>> assignments = (rawAssignments is List)
        ? rawAssignments
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : [];
    if (assignments.isNotEmpty) {
      assignments.sort((a, b) {
        final aDate = DateTime.tryParse((a['created_at'] ?? a['offered_at'])?.toString() ?? '');
        final bDate = DateTime.tryParse((b['created_at'] ?? b['offered_at'])?.toString() ?? '');
        return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
      });
    }
    final latestAssignment = assignments.isNotEmpty ? assignments.first : null;
    final assignmentStatus = latestAssignment?['status']?.toString().toLowerCase().trim();

    // Driver user info
    final driverMap = booking['driver'] as Map<String, dynamic>?;
    final driverUserMap = driverMap?['users'] as Map<String, dynamic>? ??
        booking['driver_user'] as Map<String, dynamic>?;
    final driverName = driverUserMap?['full_name']?.toString() ??
        latestAssignment?['driver_name']?.toString() ??
        'Assigned Driver';
    final driverPhone = driverUserMap?['phone']?.toString() ?? '';

    final hasDriver = driverId != null && driverId.isNotEmpty;

    // Remaining seconds for 10-minute driver job offer
    final assignedAtRaw = booking['driver_assigned_at'] ??
        latestAssignment?['offered_at'] ??
        latestAssignment?['created_at'];
    final assignedAt = assignedAtRaw != null
        ? DateTime.tryParse(assignedAtRaw.toString())?.toLocal()
        : null;
    final isPendingOffer = assignmentStatus == 'pending_offer' ||
        assignmentStatus == 'assigned' ||
        (hasDriver && status == 'pending');
    final offerElapsedSec = assignedAt != null ? DateTime.now().difference(assignedAt).inSeconds : 0;
    final offerRemainingSec = (isPendingOffer && assignedAt != null)
        ? (600 - offerElapsedSec).clamp(0, 600)
        : (isPendingOffer && assignedAt == null ? 600 : 0);
    final isOfferExpired = (isPendingOffer && assignedAt != null && offerRemainingSec <= 0) ||
        assignmentStatus == 'expired';

    final isWaitingDriverResponse = withDriver &&
        isPendingOffer &&
        !isOfferExpired;

    final isDriverAccepted = withDriver &&
        (status == 'driver_accepted' ||
            assignmentStatus == 'accepted' ||
            assignmentStatus == 'confirmed');

    final isDriverDeclined = withDriver &&
        (assignmentStatus == 'rejected' ||
            assignmentStatus == 'declined' ||
            isOfferExpired);

    final startLabel = _formatDateTime(booking['start_at'] ?? booking['start_date']);
    final endLabel = _formatDateTime(booking['end_at'] ?? booking['end_date']);
    final durationLabel = _formatDuration(booking);

    final pickupLocation = booking['pickup_location']?.toString().trim();
    final dropoffLocation = booking['dropoff_location']?.toString().trim();

    final vehicleMap = booking['vehicles'] is Map
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    final vehicleTitle = vehicleMap['brand'] != null
        ? '${vehicleMap['brand']} ${vehicleMap['model'] ?? ''}'.trim()
        : (booking['vehicle_name']?.toString() ?? booking['vehicleTitle']?.toString() ?? 'Vehicle');
    final plateNumber = vehicleMap['plate_number']?.toString() ??
        booking['plate_number']?.toString() ??
        booking['plateNumber']?.toString();

    final badgeColor = _statusColor(status, assignmentStatus: assignmentStatus);
    final badgeText = _statusLabel(status, assignmentStatus: assignmentStatus);

    Widget detailContent({ScrollController? scrollController}) {
      return SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (when shown in bottom sheet)
            if (widget.showHeader) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Booking Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 1. Overview & Status Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Reference',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '#$shortId',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildPaymentStateBadge(booking),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Vehicle Information Card
            if (vehicle != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.directions_car_filled_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}'.trim(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (vehicle?['plate_number'] != null &&
                                  vehicle!['plate_number'].toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Plate: ${vehicle!['plate_number']}',
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.handshake_outlined, size: 12, color: Colors.purpleAccent),
                              const SizedBox(width: 4),
                              Text(
                                'PARTNER CAR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.purple[200] : Colors.purple[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (vehicle?['year'] != null)
                          _specBadge('Year: ${vehicle!['year']}', isDark),
                        if (vehicle?['transmission'] != null)
                          _specBadge(vehicle!['transmission'].toString(), isDark),
                        if (vehicle?['fuel_type'] != null)
                          _specBadge(vehicle!['fuel_type'].toString(), isDark),
                        if (vehicle?['seats'] != null)
                          _specBadge('${vehicle!['seats']} Seats', isDark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 3. Renter Information Card with Direct Call Button
            if (renter != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          child: Text(
                            (renter?['full_name']?.toString().isNotEmpty == true)
                                ? renter!['full_name'].toString().substring(0, 1).toUpperCase()
                                : 'R',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      renter?['full_name'] ?? 'Rentee',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'VERIFIED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (renter?['email'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  renter!['email'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 4. Trip Route & Destinations Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Route',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      TripLocationMapDialog.show(
                        context: context,
                        booking: booking,
                        vehicleName: vehicleTitle,
                        plateNumber: plateNumber,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.trip_origin_rounded, size: 14, color: Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text(
                                      'Pickup Point',
                                      style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.map_rounded, size: 11, color: AppColors.primary),
                                    SizedBox(width: 2),
                                    Text(
                                      '(Tap for Map)',
                                      style: TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (pickupLocation != null && pickupLocation.isNotEmpty)
                                      ? pickupLocation
                                      : 'PSDC Hub / Designated Pickup Point',
                                  style: const TextStyle(
                                    fontSize: 12,
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
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
                    child: Container(
                      width: 2,
                      height: 14,
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      TripLocationMapDialog.show(
                        context: context,
                        booking: booking,
                        vehicleName: vehicleTitle,
                        plateNumber: plateNumber,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on_rounded, size: 16, color: Colors.redAccent),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text(
                                      'Destination / Drop-off Point',
                                      style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.map_rounded, size: 11, color: AppColors.primary),
                                    SizedBox(width: 2),
                                    Text(
                                      '(Tap for Map)',
                                      style: TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (dropoffLocation != null && dropoffLocation.isNotEmpty)
                                      ? dropoffLocation
                                      : 'Declared Destination Area',
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
            ),
            const SizedBox(height: 12),

            // 5. Rental Schedule & Duration Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Rental Schedule',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _scheduleBlock('Start Date', startLabel, isDark),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _scheduleBlock('End Date', endLabel, isDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 6. Driver Assignment & Job Offer Status Card (Primary Focus)
            if (withDriver) ...[
              if (isWaitingDriverResponse) ...[
                // Offer Sent & Waiting
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.amber.shade700, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hourglass_top_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Driver Job Offer Requested',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.amber.shade700, width: 0.8),
                                      ),
                                      child: Text(
                                        '${(offerRemainingSec ~/ 60).toString().padLeft(2, '0')}:${(offerRemainingSec % 60).toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.amber.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Selected: $driverName',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A job offer has been sent to the driver (10-minute response window). Once accepted, you can approve and finalize the booking. If unanswered after 10 minutes, it will auto-decline so you can reassign immediately.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.onAssignDriver != null)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget.onAssignDriver,
                            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                            label: const Text('Reassign / Change Driver'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.amber.shade700,
                              side: BorderSide(color: Colors.amber.shade700),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (isDriverAccepted) ...[
                // Driver Accepted!
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.green, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Driver Accepted the Job Offer!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  driverName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The driver accepted this trip assignment! You can now click Approve below to finalize this booking.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                      if (widget.onAssignDriver != null && (status == 'pending' || status == 'driver_accepted')) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: widget.onAssignDriver,
                            icon: const Icon(Icons.swap_horiz, size: 14),
                            label: const Text('Change Driver'),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (isDriverDeclined) ...[
                // Driver Declined or Expired
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isOfferExpired ? Colors.orange.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    border: Border.all(color: isOfferExpired ? Colors.orange : Colors.redAccent, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isOfferExpired ? Icons.timer_off_rounded : Icons.cancel_rounded,
                            size: 18,
                            color: isOfferExpired ? Colors.orange : Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOfferExpired ? 'Driver Job Offer Expired' : 'Driver Declined Job Offer',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isOfferExpired ? Colors.orange : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isOfferExpired
                            ? 'The assigned driver did not accept the job offer within the 10-minute response window. You can select another driver now.'
                            : 'The previously requested driver was unavailable or declined this trip. Please assign another driver.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.onAssignDriver != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onAssignDriver,
                            icon: const Icon(Icons.person_search_rounded, size: 16),
                            label: const Text('Select Another Driver'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (driverId == null &&
                  (status == 'pending' || status == 'approved' || status == 'confirmed')) ...[
                // No Driver Assigned Yet
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.warning),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.drive_eta_rounded, color: AppColors.warning, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Professional Driver Required',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This reservation requires a certified driver. Select a driver from the verified pool to send a job offer.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onAssignDriver,
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                          label: const Text('Assign Driver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // 7. Total Price & Financial Breakdown Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Booking Price',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        withDriver ? 'Includes Vehicle & Driver' : 'Self-Drive Rental',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₱${formatAmount(totalPrice, decimalDigits: 2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 8. Quick Actions Row
            if (widget.onReviewDocs != null ||
                widget.onMessage != null ||
                widget.onBeforeInspection != null ||
                widget.onViewBeforeInspection != null ||
                widget.onAfterInspection != null ||
                widget.onReceipt != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.onReviewDocs != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        if (widget.showHeader) Navigator.pop(context);
                        widget.onReviewDocs?.call();
                      },
                      icon: const Icon(Icons.verified_user_outlined, size: 15),
                      label: const Text('Review Docs'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (widget.onMessage != null)
                    Builder(
                      builder: (context) {
                        final isChatEligible =
                            BookingService().isEligibleForBookingChat(widget.booking);
                        return OutlinedButton.icon(
                          onPressed: () {
                            if (widget.showHeader) Navigator.pop(context);
                            widget.onMessage?.call();
                          },
                          icon: Icon(
                            isChatEligible
                                ? Icons.chat_bubble_outline
                                : Icons.lock_clock,
                            size: 15,
                          ),
                          label: Text(
                            isChatEligible ? 'Message' : 'Chat (72h Prior)',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        );
                      },
                    ),
                  if (widget.onBeforeInspection != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onBeforeInspection?.call();
                      },
                      icon: const Icon(Icons.fact_check_outlined, size: 15),
                      label: const Text('Pre-Trip Inspection'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (widget.onViewBeforeInspection != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onViewBeforeInspection?.call();
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: const Text('View Pre-Trip Check'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (widget.onAfterInspection != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAfterInspection?.call();
                      },
                      icon: const Icon(Icons.assignment_turned_in_outlined, size: 15),
                      label: const Text('After Check'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (widget.onReceipt != null)
                    OutlinedButton.icon(
                      onPressed: widget.onReceipt,
                      icon: const Icon(Icons.download_rounded, size: 15),
                      label: const Text('Download Receipt'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (status == 'active' ||
                      status == 'ongoing' ||
                      status == 'return_pending_inspection' ||
                      status == 'completed' ||
                      status == 'returned' ||
                      status == 'return_inspected')
                    OutlinedButton.icon(
                      onPressed: () {
                        TripRouteHistoryScreen.open(
                          context: context,
                          bookingId: bookingId,
                          vehicleName: vehicleTitle,
                          plateNumber: plateNumber,
                          renterName: renter?['full_name']?.toString(),
                        );
                      },
                      icon: const Icon(Icons.route_rounded, size: 15, color: AppColors.primary),
                      label: const Text('Audit Traveled Route & Playback'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // 9. Bottom Decision Actions (Approve / Reject)
            if (status == 'pending' || status == 'driver_accepted') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onReject,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onApprove,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        status == 'driver_accepted'
                            ? 'Approve (Driver Accepted)'
                            : resolveBookingPaymentState(booking) ==
                                    BookingPaymentState.pendingConfirmation
                                ? 'Confirm & Accept'
                                : 'Approve',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (widget.onConfirmPayment != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onConfirmPayment?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text(
                    'Confirm Full Payment',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else if (widget.onRateTrip != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRateTrip?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.star_rate_rounded, size: 18),
                  label: const Text(
                    'Rate Trip',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    if (!widget.showHeader) {
      return detailContent();
    }

    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) =>
          detailContent(scrollController: scrollController),
    );
  }

  Widget _specBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _scheduleBlock(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Pulsing Dot for Partner GPS Tracker Status
// ─────────────────────────────────────────────────────────────────────────────

