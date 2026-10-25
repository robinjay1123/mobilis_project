part of '../dashboard_screen.dart';

extension _DashboardBookingSheets on _DashboardScreenState {
  void _showBookingDetails(Map<String, dynamic> booking) {
    final rawStatus = (booking['rawStatus'] ?? booking['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final statusGroup = booking['statusGroup']?.toString() ?? '';
    final isOngoingTrip = statusGroup == 'Ongoing' ||
        {'active', 'ongoing', 'picked_up', 'in_progress'}.contains(rawStatus);
    final isApprovedTrip = statusGroup == 'Approved' ||
        {'approved', 'confirmed', 'pending_release', 'assigned'}.contains(rawStatus) ||
        isOngoingTrip;
    final canExtendTrip = (statusGroup == 'Ongoing' ||
            statusGroup == 'Approved' ||
            {
              'active',
              'ongoing',
              'picked_up',
              'in_progress',
              'approved',
              'confirmed',
              'pending_release',
            }.contains(rawStatus)) &&
        !_isBookingWithDriver(booking);

    final isPendingTrip = statusGroup == 'Pending';
    final completionState = BookingService().getTripCompletionState(booking);
    final pendingRoles =
        (completionState['pendingRoles'] as List<dynamic>? ?? const [])
            .map((role) => role.toString())
            .toList();
    final completionStage =
        completionState['completionStage']?.toString() ?? 'not_started';
    const completedStatuses = {
      'completed',
      'returned',
      'successful',
      'success',
      'awaiting_ratings',
    };
    final isCompletedTrip =
        completionStage == 'completed' ||
        completedStatuses.contains(rawStatus) ||
        completionState['status'] == 'completed';
    final effectiveCompletionStage =
        completionStage == 'not_started' &&
            completedStatuses.contains(rawStatus)
        ? 'completed'
        : completionStage;

    if (isPendingTrip) {
      _showPendingBookingDetails(booking);
      return;
    }

    final isPaidInFull = BookingService().isBookingFullyPaid(booking) ||
        BookingService().getBookingRemainingBalance(booking) <= 0.01;
    final isApprovedOrReady = statusGroup == 'Approved' ||
        rawStatus == 'approved' ||
        rawStatus == 'confirmed' ||
        rawStatus == 'pending_release';
    final showPayNow = isApprovedOrReady && !isPaidInFull;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RenterBookingDetailsPage(
          booking: booking,
          isApprovedTrip: isApprovedTrip,
          isCompletedTrip: isCompletedTrip,
          completionStage: effectiveCompletionStage,
          pendingRoles: pendingRoles,
          paymentTypeLabel: _bookingPaymentTypeLabel(booking),
          amountPaidLabel: _bookingAmountPaidLabel(booking),
          isPaidInFull: isPaidInFull,
          onPayRemainingBalance: showPayNow
              ? () => _handlePreTripReleasePayment(booking)
              : null,
          onMessage: _canOpenBookingConversation(booking)
              ? () => _openBookingConversation(booking)
              : null,
          onNavigate:
              {
                'active',
                'ongoing',
              }.contains(booking['rawStatus']?.toString().toLowerCase())
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripNavigationScreen(
                      bookingId: booking['id'].toString(),
                      participantRole: 'renter',
                    ),
                  ),
                )
              : null,
          onCancel: _isCancellableStatusForUi(booking)
              ? () => _handleBookingCancellation(booking)
              : null,
          onExtend: canExtendTrip
              ? () => _showTripExtensionDialog(booking)
              : null,
          onReturn: isOngoingTrip
              ? () => _handleRenterReturnVehicle(booking)
              : null,
          onSuccessfulTrip:
              ({
                    'renter_rating',
                    'completed',
                    'awaiting_completion',
                    'awaiting_ratings',
                  }.contains(effectiveCompletionStage) ||
                  completedStatuses.contains(rawStatus))
              ? () => _handleSuccessfulTripFromDetails(
                  booking: booking,
                  completionStage: effectiveCompletionStage,
                  pendingRoles: pendingRoles,
                )
              : null,
          onReceipt: () => _showTripReceipt(booking),
          isAlreadyRated: _isRenterBookingFullyRated(booking),
          onRateTrip: () async {
            final bookingId = booking['id']?.toString() ?? '';
            final submitted = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => TripRatingFlowScreen(
                  bookingId: bookingId,
                  reviewerRole: 'renter',
                  title: 'Rate Trip',
                  subtitle: 'Leave your ratings and reviews for this trip.',
                ),
              ),
            );
            if (submitted == true) {
              await TripRatingService().reconcileCompletedBooking(bookingId);
              _loadBookings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Rating saved successfully! Thank you.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            }
          },
        ),
      ),
    );

    return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trip Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isApprovedTrip) ...[
              _buildActiveTripHero(booking),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.darkBgTertiary,
                      borderRadius: BorderRadius.circular(8),
                      image:
                          booking['vehicles'] != null &&
                              booking['vehicles']['image_url'] != null
                          ? DecorationImage(
                              image: OptimizedNetworkImageProvider(
                                booking['vehicles']['image_url'] as String,
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child:
                        booking['vehicles'] == null ||
                            booking['vehicles']['image_url'] == null
                        ? const Icon(
                            Icons.directions_car,
                            color: AppColors.textSecondary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['carName'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          booking['rentalPartner'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: booking['status']),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Booking Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  _buildBookingDetailRow(
                    icon: Icons.directions_car,
                    label: 'Car',
                    value: booking['carName']?.toString() ?? 'Vehicle',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.person_pin_circle_outlined,
                    label: 'Driver',
                    value: booking['driverName']?.toString() ?? 'Not requested',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.flag_circle_outlined,
                    label: 'Status',
                    value: booking['status']?.toString() ?? 'Pending',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.payment,
                    label: 'Reservation Payment',
                    value:
                        booking['paymentStatus']?.toString() ??
                        'Reservation pending',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Payment Type',
                    value: _bookingPaymentTypeLabel(booking),
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.payments,
                    label: 'Amount Paid',
                    value: _bookingAmountPaidLabel(booking),
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.payments_outlined,
                    label: 'Booking Cost',
                    value:
                        '₱${formatAmount(booking['totalCost'] as num, decimalDigits: 0)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Trip Timeline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TripTimelineStep(
              label: 'Pickup',
              date: booking['startDate'],
              time: booking['startTime'] ?? 'N/A',
              icon: Icons.location_on,
              isActive: true,
            ),
            const SizedBox(height: 16),
            TripTimelineStep(
              label: 'Dropoff',
              date: booking['endDate'],
              time: booking['endTime'] ?? 'N/A',
              icon: Icons.location_on,
              isCompleted: booking['statusGroup'] == 'Completed',
            ),
            const SizedBox(height: 16),
            const Text(
              'Cost Breakdown',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            CostBreakdownRow(
              label:
                  '${booking['days']} days × ₱${formatAmount(booking['totalCost'] ~/ booking['days'], decimalDigits: 0)}/day',
              amount:
                  '₱${formatAmount(booking['totalCost'] as num, decimalDigits: 0)}',
            ),
            if (((booking['destination_fee'] ?? booking['destinationFee']) as num?)?.toDouble() != null &&
                ((booking['destination_fee'] ?? booking['destinationFee']) as num).toDouble() > 0)
              CostBreakdownRow(
                label: 'Destination Surcharge (${booking['days'] ?? 1} days)',
                amount:
                    '₱${formatAmount(((booking['destination_fee'] ?? booking['destinationFee']) as num).toDouble(), decimalDigits: 0)}',
              ),
            const CostBreakdownRow(label: 'Insurance', amount: '₱50'),
            CostBreakdownRow(
              label: 'Tax (10%)',
              amount:
                  '₱${formatAmount((booking['totalCost'] + 50) * 0.1, decimalDigits: 0)}',
            ),
            const Divider(color: AppColors.borderColor),
            CostBreakdownRow(
              label: 'Total',
              amount:
                  '₱${formatAmount(booking['totalCost'] + 50 + ((booking['totalCost'] + 50) * 0.1), decimalDigits: 0)}',
              isBold: true,
              amountColor: AppColors.primary,
            ),
            const SizedBox(height: 20),
            if (isCompletedTrip && pendingRoles.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                ),
                child: Text(
                  'Waiting for ${_formatRoleList(pendingRoles)} to confirm this trip as successful before you can finish it.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isApprovedTrip || isCompletedTrip) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final bookingId = booking['id']?.toString() ?? '';
                    if (bookingId.isEmpty) return;

                    await _handleSuccessfulTripFromDetails(
                      booking: booking,
                      completionStage: completionStage,
                      pendingRoles: pendingRoles,
                    );
                  },
                  icon: const Icon(Icons.star_rate_rounded, size: 18),
                  label: Text(
                    isCompletedTrip ? 'Successful Trip' : 'View Trip Status',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final bookingId = booking['id']?.toString() ?? '';
                    if (bookingId.isNotEmpty) {
                      TripRouteHistoryDialog.show(
                        context: context,
                        bookingId: bookingId,
                        vehicleName: booking['vehicleName']?.toString(),
                        plateNumber: booking['plateNumber']?.toString(),
                      );
                    }
                  },
                  icon: const Icon(Icons.route_rounded, size: 18, color: AppColors.primary),
                  label: const Text('View Traveled Route & Destination Audit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isApprovedTrip || _isCancellableStatusForUi(booking)) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showRescheduleTripDialog(booking);
                  },
                  icon: const Icon(Icons.event_repeat_rounded, size: 18, color: Color(0xFFE5A93C)),
                  label: const Text('Reschedule Trip Dates (Keep Deposit)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE5A93C),
                    side: const BorderSide(color: Color(0xFFE5A93C)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isApprovedTrip && !_isBookingWithDriver(booking))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTripExtensionDialog(booking),
                  icon: const Icon(Icons.more_time, size: 18),
                  label: const Text('Check for Extend Trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            if (_isCancellableStatusForUi(booking))
              StreamBuilder<int>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (tick) => tick,
                ),
                initialData: 0,
                builder: (context, snapshot) {
                  final timeInfo = _getRemainingCancelTime(booking);
                  final canCancel = timeInfo['canCancel'] as bool;
                  final hours = timeInfo['hours'] as int;
                  final minutes = timeInfo['minutes'] as int;
                  final seconds = timeInfo['seconds'] as int;
                  final progress =
                      (timeInfo['totalSecondsRemaining'] as int) /
                      (24 * 60 * 60);

                  if (canCancel) {
                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _handleBookingCancellation(booking);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              booking['statusGroup'] == 'Pending'
                                  ? 'Cancel Request'
                                  : 'Cancel Booking',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD).withAlpha(230),
                            border: Border.all(
                              color: const Color(0xFFFFC107),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '⏱️ Cancel within: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8B6914),
                                    ),
                                  ),
                                  Text(
                                    '${hours}h ${minutes}m ${seconds}s',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8B6914),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: Colors.grey[300],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFFC107),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(25),
                        border: Border.all(color: AppColors.error),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⏰ Cancellation Window Closed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Bookings can only be cancelled within 24 hours after request.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSuccessfulTripFromDetails({
    required Map<String, dynamic> booking,
    required String completionStage,
    required List<String> pendingRoles,
  }) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    if ({
      'renter_rating',
      'completed',
      'awaiting_completion',
      'awaiting_ratings',
    }.contains(completionStage)) {
      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TripRatingFlowScreen(
            bookingId: bookingId,
            reviewerRole: 'renter',
            title: 'Complete Trip Ratings',
            subtitle:
                'Rate every required trip participant to complete this booking.',
          ),
        ),
      );
      if (submitted == true) {
        await TripRatingService().reconcileCompletedBooking(bookingId);
        await _loadBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ratings saved successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
      return;
    }

    if (completionStage == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This trip is already completed successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }

    final waitingFor = pendingRoles.isEmpty
        ? 'the required return steps'
        : _formatRoleList(pendingRoles);
    final message = switch (completionStage) {
      'awaiting_after_checklist' =>
        'Waiting for the vehicle owner to submit the after-return checklist and evidence.',
      'awaiting_payment' =>
        'Waiting for the vehicle owner to confirm the full payment and any late fees.',
      'operator_rating' =>
        'Waiting for the PSDC operator to submit the required renter rating.',
      'partner_rating' =>
        'Waiting for the vehicle partner to submit the required renter rating.',
      'driver_rating' =>
        'Waiting for the driver to submit the required renter rating.',
      _ =>
        'This trip is still ongoing. Complete the return before final ratings. Pending: $waitingFor.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.warning),
    );
  }

  void _showPendingBookingDetails(Map<String, dynamic> booking) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RenterBookingDetailsPage(
          booking: booking,
          isApprovedTrip: false,
          isCompletedTrip: false,
          completionStage: 'not_started',
          pendingRoles: const [],
          paymentTypeLabel: _bookingPaymentTypeLabel(booking),
          amountPaidLabel: _bookingAmountPaidLabel(booking),
          onCancel: _isCancellableStatusForUi(booking)
              ? () => _handleBookingCancellation(booking)
              : null,
          onReceipt: () => _showTripReceipt(booking),
          isAlreadyRated: false,
          onRateTrip: null,
        ),
      ),
    );
    return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pending Approval',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPendingApprovalCard(booking),
              const SizedBox(height: 14),
              _buildPendingVehicleCard(booking),
              const SizedBox(height: 18),
              const Text(
                'Trip Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildPendingSummaryTile(
                icon: Icons.calendar_today_outlined,
                title: '${booking['startDate']} - ${booking['endDate']}',
                subtitle:
                    'RENTAL DATES • ${booking['days']} DAY${booking['days'] == 1 ? '' : 'S'}',
              ),
              const SizedBox(height: 10),
              _buildPendingSummaryTile(
                icon: booking['withDriver'] == true
                    ? Icons.support_agent
                    : Icons.drive_eta_outlined,
                title: booking['withDriver'] == true
                    ? booking['driverName']?.toString() ?? 'With Driver'
                    : 'Self Drive',
                subtitle: 'SERVICE TYPE',
              ),
              const SizedBox(height: 10),
              _buildPendingSummaryTile(
                icon: Icons.location_on_outlined,
                title: booking['pickupLocation']?.toString() ?? 'N/A',
                subtitle: 'PICKUP & DROP-OFF',
              ),
              const SizedBox(height: 14),
              _buildPendingAgreementNotes(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.hourglass_empty, size: 18),
                  label: const Text("Waiting for Owner's Approval"),
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: AppColors.darkBgTertiary,
                    disabledForegroundColor: AppColors.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<int>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (tick) => tick,
                ),
                initialData: 0,
                builder: (context, snapshot) {
                  final timeInfo = _getRemainingCancelTime(booking);
                  final canCancel = timeInfo['canCancel'] as bool;
                  final remaining = timeInfo['remainingTime']?.toString() ?? '';

                  return Column(
                    children: [
                      TextButton(
                        onPressed: canCancel
                            ? () {
                                Navigator.pop(context);
                                _handleBookingCancellation(booking);
                              }
                            : null,
                        child: Text(
                          canCancel ? 'Cancel Request' : 'Cancel Window Closed',
                          style: TextStyle(
                            color: canCancel
                                ? AppColors.textSecondary
                                : AppColors.textTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        canCancel
                            ? 'Cancellation available for $remaining'
                            : 'Bookings can only be cancelled within 24 hours after request.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTripReceipt(Map<String, dynamic> booking) {
    final days = (booking['days'] as num?)?.toInt() ?? 1;
    final safeDays = days < 1 ? 1 : days;
    final recordedTotal = (booking['totalCost'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (booking['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final driverFee = (booking['driverFee'] as num?)?.toDouble() ?? 0.0;
    final lateReturnFee = (booking['lateReturnFee'] as num?)?.toDouble() ?? 0.0;
    final rentalSubtotal =
        (booking['rentalSubtotal'] as num?)?.toDouble() ??
        (recordedTotal - deliveryFee).clamp(0.0, double.infinity).toDouble();
    final dailyRate = rentalSubtotal / safeDays;
    final total = rentalSubtotal + deliveryFee + driverFee + lateReturnFee;
    final reservationFee =
        (booking['reservationFeeAmount'] as num?)?.toDouble() ?? 1000.0;
    final totalBalance = (total - reservationFee)
        .clamp(0.0, double.infinity)
        .toDouble();
    final securityDeposit =
        (booking['securityDeposit'] as num?)?.toDouble() ?? 0.0;
    final reference = booking['reservationPaymentReference']?.toString().trim();
    final method = booking['reservationPaymentMethod']?.toString().trim();
    final finalMethod =
        booking['final_payment_method']?.toString() ??
        booking['finalPaymentMethod']?.toString();
    final finalRef =
        booking['final_payment_reference']?.toString() ??
        booking['finalPaymentReference']?.toString();
    final finalAmount =
        (booking['renter_return_payment_amount'] as num?)?.toDouble() ??
        (booking['renterReturnPaymentAmount'] as num?)?.toDouble() ??
        0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Trip Receipt',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.darkBgTertiary,
                          borderRadius: BorderRadius.circular(12),
                          image:
                              booking['imageUrl']?.toString().isNotEmpty == true
                              ? DecorationImage(
                                  image: OptimizedNetworkImageProvider(
                                    booking['imageUrl'].toString(),
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            booking['imageUrl']?.toString().isNotEmpty == true
                            ? null
                            : const Icon(
                                Icons.directions_car,
                                color: AppColors.textSecondary,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking['carName']?.toString() ?? 'Vehicle',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${booking['startDate']} - ${booking['endDate']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: booking['status']),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildBookingDetailRow(
                    icon: Icons.person_pin_circle_outlined,
                    label: 'Driver',
                    value: booking['driverName']?.toString() ?? 'Not requested',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.payment,
                    label: 'Reservation Payment',
                    value:
                        booking['paymentStatus']?.toString() ??
                        'Reservation pending',
                  ),
                  if (reference != null && reference.isNotEmpty) ...[
                    const Divider(color: AppColors.borderColor),
                    _buildBookingDetailRow(
                      icon: Icons.numbers_rounded,
                      label: 'Reservation Reference',
                      value: reference,
                    ),
                  ],
                  if (method != null && method.isNotEmpty) ...[
                    const Divider(color: AppColors.borderColor),
                    _buildBookingDetailRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Reservation Method',
                      value: (method == 'psdc_desk_counter' ||
                              method.toLowerCase().contains('desk'))
                          ? 'The payment has been paid in desk (Authorized by ${(reference != null && reference.startsWith('DESK-')) ? reference.substring(5) : (booking['operator_name'] ?? 'Desk Operator')})'
                          : toProfessionalTitleCase(method),
                    ),
                  ],
                  if (finalMethod != null ||
                      finalRef != null ||
                      finalAmount > 0) ...[
                    const Divider(color: AppColors.borderColor),
                    _buildBookingDetailRow(
                      icon: Icons.receipt_long_rounded,
                      label: 'Final Payment Settlement',
                      value:
                          '₱${formatAmount(finalAmount, decimalDigits: 0)} (${(finalMethod ?? 'PSDC QR').toUpperCase()})',
                    ),
                    if (finalRef != null && finalRef.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildBookingDetailRow(
                        icon: Icons.tag_rounded,
                        label: 'Settlement Reference No.',
                        value: finalRef,
                      ),
                    ],
                  ],
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.schedule,
                    label: 'Pickup / Return',
                    value:
                        '${booking['startTime'] ?? 'N/A'} - ${booking['endTime'] ?? 'N/A'}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cost Receipt',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  CostBreakdownRow(
                    label:
                        '$safeDays day${safeDays == 1 ? '' : 's'} x PHP ${formatAmount(dailyRate)}/day',
                    amount: 'PHP ${formatAmount(rentalSubtotal)}',
                  ),
                  if (deliveryFee > 0)
                    CostBreakdownRow(
                      label: 'Delivery / Pickup Charge',
                      amount: 'PHP ${formatAmount(deliveryFee)}',
                    ),
                  if (driverFee > 0)
                    CostBreakdownRow(
                      label: 'Driver Fee',
                      amount: 'PHP ${formatAmount(driverFee)}',
                    ),
                  if (lateReturnFee > 0)
                    CostBreakdownRow(
                      label: 'Late Return Fee',
                      amount: 'PHP ${formatAmount(lateReturnFee)}',
                    ),
                  const Divider(color: AppColors.borderColor),
                  CostBreakdownRow(
                    label: 'Total',
                    amount: 'PHP ${formatAmount(total)}',
                    isBold: true,
                    amountColor: AppColors.primary,
                  ),
                  CostBreakdownRow(
                    label: 'Less Reservation Fee',
                    amount: '- PHP ${formatAmount(reservationFee)}',
                  ),
                  CostBreakdownRow(
                    label: 'Total Balance',
                    amount: 'PHP ${formatAmount(totalBalance)}',
                    isBold: true,
                  ),
                  CostBreakdownRow(
                    label: 'Security Deposit (Refundable)',
                    amount: 'PHP ${formatAmount(securityDeposit)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadTripReceipt(booking),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadTripReceipt(Map<String, dynamic> booking) async {
    try {
      await BookingReceiptService.shareReceipt(booking);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not download receipt: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCancellationDetails(Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cancellation Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORIGINAL BOOKING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking['carName']?.toString() ?? 'Vehicle',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${booking['startDate']} - ${booking['endDate']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 82,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.darkBgTertiary,
                      borderRadius: BorderRadius.circular(10),
                      image: booking['imageUrl']?.toString().isNotEmpty == true
                          ? DecorationImage(
                              image: OptimizedNetworkImageProvider(
                                booking['imageUrl'].toString(),
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: booking['imageUrl']?.toString().isNotEmpty == true
                        ? null
                        : const Icon(
                            Icons.directions_car,
                            color: AppColors.textSecondary,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withAlpha(120)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Booking Status: Cancelled',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This reservation is no longer active and has been removed from upcoming trips.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Reason for Cancellation',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildCancellationInfoCard(
              icon: Icons.info_outline,
              title:
                  booking['cancellationReason']?.toString() ??
                  'Booking was cancelled.',
              subtitle:
                  'Cancelled ${_formatTimeAgo(booking['cancelledAt']?.toString())}',
            ),
            const SizedBox(height: 18),
            const Text(
              'Refund Information',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withAlpha(70)),
              ),
              child: Column(
                children: [
                  _buildBookingDetailRow(
                    icon: Icons.receipt_long,
                    label: 'Reservation Fee',
                    value:
                        '₱${formatAmount(booking['totalCost'] as num, decimalDigits: 0)}',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.payments_outlined,
                    label: 'Refund Status',
                    value:
                        booking['paymentStatus']?.toString() ??
                        'Contact support for refund status',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Original Trip Route',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  _buildBookingDetailRow(
                    icon: Icons.radio_button_checked,
                    label: 'Pickup',
                    value: booking['pickupLocation']?.toString() ?? 'N/A',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.location_on,
                    label: 'Destination',
                    value: booking['dropoffLocation']?.toString() ?? 'N/A',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _contactCancellationSupport(booking),
                icon: const Icon(Icons.support_agent, size: 18),
                label: const Text('Contact Support'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getRemainingCancelTime(Map<String, dynamic> booking) {
    try {
      final createdAtStr = booking['created_at']?.toString();
      if (createdAtStr == null) {
        return {
          'canCancel': false,
          'hours': 0,
          'minutes': 0,
          'seconds': 0,
          'totalSecondsRemaining': 0,
          'remainingTime': 'Unknown',
          'isExpired': true,
        };
      }

      final createdAt = DateTime.parse(createdAtStr);
      final now = DateTime.now();
      final cancelUntil = createdAt.add(const Duration(hours: 24));
      final remaining = cancelUntil.difference(now);
      final totalSecondsRemaining = remaining.inSeconds.clamp(0, 24 * 60 * 60);
      final hoursRemaining = totalSecondsRemaining ~/ 3600;
      final minRemaining = (totalSecondsRemaining % 3600) ~/ 60;
      final secondsRemaining = totalSecondsRemaining % 60;

      final canCancel = totalSecondsRemaining > 0;
      final remainingTimeStr = canCancel
          ? '${hoursRemaining}h ${minRemaining}m ${secondsRemaining}s remaining'
          : 'Expired';

      return {
        'canCancel': canCancel,
        'hours': hoursRemaining,
        'minutes': minRemaining,
        'seconds': secondsRemaining,
        'totalSecondsRemaining': totalSecondsRemaining,
        'remainingTime': remainingTimeStr,
        'isExpired': !canCancel,
      };
    } catch (e) {
      debugPrint('Error checking cancellation time: $e');
      return {
        'canCancel': false,
        'hours': 0,
        'minutes': 0,
        'seconds': 0,
        'totalSecondsRemaining': 0,
        'remainingTime': 'Error',
        'isExpired': true,
      };
    }
  }

  Widget _buildActiveTripHero(Map<String, dynamic> booking) {
    final imageUrl = booking['imageUrl']?.toString().trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: _buildFastVehicleImage(
                imageUrl: hasImage ? imageUrl : null,
                fit: BoxFit.cover,
                width: double.infinity,
                backgroundColor: AppColors.darkBgTertiary,
                iconColor: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            booking['carName']?.toString() ?? 'Active Trip',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${booking['startDate']} - ${booking['endDate']}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primary.withAlpha(120)),
            ),
            child: Text(
              booking['status']?.toString() ?? 'Approved',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTripMetric(
                  label: 'Start',
                  value: booking['startTime']?.toString() ?? 'N/A',
                ),
              ),
              Expanded(
                child: _buildTripMetric(
                  label: 'Duration',
                  value:
                      '${booking['days']} day${booking['days'] == 1 ? '' : 's'}',
                  highlight: true,
                ),
              ),
              Expanded(
                child: _buildTripMetric(
                  label: 'Return',
                  value: booking['endTime']?.toString() ?? 'N/A',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildRentalAgreementCard(),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalCard(Map<String, dynamic> booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    final createdAt = DateTime.tryParse(
      booking['created_at']?.toString() ?? '',
    )?.toLocal();
    final elapsed = createdAt == null
        ? const Duration(hours: 1)
        : DateTime.now().difference(createdAt);
    final approvalProgress = (elapsed.inMinutes / 120).clamp(0.05, 0.95);
    final percent = (approvalProgress * 100).round();

    return Container(
      width: double.infinity,
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
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PENDING APPROVAL',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    color: primaryText,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.primary : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: approvalProgress.toDouble(),
              minHeight: 6,
              backgroundColor: isDark ? AppColors.darkBgTertiary : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.primary : AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting for owner to confirm your request.',
            style: TextStyle(fontSize: 12, color: secondaryText),
          ),
          const SizedBox(height: 2),
          Text(
            'Usually takes less than 2 hours.',
            style: TextStyle(fontSize: 12, color: secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingVehicleCard(Map<String, dynamic> booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    final imageUrl = booking['imageUrl']?.toString().trim() ?? '';
    final totalCost = (booking['totalCost'] as num?)?.toDouble() ?? 0;
    final days = ((booking['days'] as num?)?.toInt() ?? 1).clamp(1, 365);
    final dailyRate = totalCost / days;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        boxShadow: isDark ? null : AppColors.cardShadowOf(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REQUESTED VEHICLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: tertiaryText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  booking['carName']?.toString() ?? 'Vehicle',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '₱${formatAmount(dailyRate, decimalDigits: 0)} / day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.primary : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 112,
              height: 70,
              child: _buildFastVehicleImage(
                imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
                fit: BoxFit.cover,
                backgroundColor: isDark ? AppColors.darkBgTertiary : const Color(0xFFE2E8F0),
                iconColor: tertiaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSummaryTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        boxShadow: isDark ? null : AppColors.cardShadowOf(context),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: tertiaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAgreementNotes() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
          width: 1.2,
        ),
        boxShadow: isDark ? null : AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gavel_outlined,
                size: 15,
                color: isDark ? AppColors.primary : AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                'Rental Agreement Notes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _AgreementNote('Late penalty: ₱300/hr after scheduled return.'),
          const SizedBox(height: 7),
          const _AgreementNote(
            'Fuel Policy: Same-to-same. Return with the same fuel level.',
          ),
          const SizedBox(height: 7),
          const _AgreementNote(
            'Cleanliness: Please return the car in the same clean state.',
          ),
        ],
      ),
    );
  }

  Widget _buildTripMetric({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary.withAlpha(18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 9, color: tertiaryText),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: highlight
                  ? (isDark ? AppColors.primary : const Color(0xFFD97706))
                  : primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalAgreementCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: isDark ? AppColors.primary : AppColors.primaryDark,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Rental Agreement',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Keep vehicle clean and return it on schedule.',
            style: TextStyle(fontSize: 11, color: secondaryText),
          ),
          SizedBox(height: 4),
          Text(
            '• Extension is allowed only when the next booking slot is available.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          SizedBox(height: 4),
          Text(
            '• Late returns may include penalties after the grace period.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePreTripReleasePayment(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final renterId = AuthService().currentUser?.id ?? '';
    if (bookingId.isEmpty || renterId.isEmpty) return;

    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final seats = (vehicle['seats'] as num?)?.toInt() ??
        (booking['seats'] as num?)?.toInt() ??
        5;
    final totalCost =
        (booking['totalCost'] as num?)?.toDouble() ??
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final rentalSubtotal =
        (booking['rentalSubtotal'] as num?)?.toDouble() ?? totalCost;
    final deliveryFee =
        (booking['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final reservationFee =
        (booking['reservationFeeAmount'] as num?)?.toDouble() ??
        (booking['reservation_fee_amount'] as num?)?.toDouble() ??
        1000.0;

    final proof = await Navigator.of(context).push<ReservationPaymentProof>(
      MaterialPageRoute(
        builder: (_) => ReservationPaymentScreen(
          userId: renterId,
          vehicleData: vehicle.isNotEmpty
              ? vehicle
              : {
                  'id': booking['vehicle_id'],
                  'vehicle_name': booking['carName'],
                  'brand': booking['carName'],
                  'seats': seats,
                  'image_url': booking['imageUrl'],
                },
          rentalTotal: totalCost,
          rentalSubtotal: rentalSubtotal,
          deliveryFee: deliveryFee,
          discountAmount: (booking['discount_amount'] as num?)?.toDouble() ?? 0.0,
          reservationFeeAmount: reservationFee,
          requiresLongBookingReservation: false,
          paymentPurpose: PaymentPurpose.releaseSettlement,
          paidReservationFee: reservationFee,
          bookingId: bookingId,
        ),
      ),
    );

    if (proof == null) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final isDeskPayment = proof.method == 'psdc_desk_counter';

      await BookingService.safeUpdateBooking(bookingId, {
        'reservation_payment_covers_total': true,
        'reservation_payment_type': 'full_payment',
        'reservation_payment_status': isDeskPayment ? 'verified' : 'pending_review',
        'reservation_payment_method': proof.method,
        'reservation_payment_reference': proof.referenceNumber,
        if (proof.proofUrl.isNotEmpty)
          'reservation_payment_proof_url': proof.proofUrl,
        if (proof.senderPhone != null && proof.senderPhone!.isNotEmpty)
          'reservation_payment_sender_phone': proof.senderPhone,
        'reservation_payment_submitted_at': now,
        'final_payment_status': isDeskPayment ? 'paid' : 'submitted',
        'final_payment_method': proof.method,
        'final_payment_reference': proof.referenceNumber,
        if (proof.proofUrl.isNotEmpty)
          'final_payment_proof_url': proof.proofUrl,
        if (isDeskPayment) ...{
          'final_payment_confirmed_at': now,
          if (proof.operatorId != null && proof.operatorId!.isNotEmpty)
            'final_payment_confirmed_by': proof.operatorId,
        },
        'updated_at': now,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDeskPayment
                ? 'Remaining balance payment verified at PSDC Desk! Vehicle is ready for release.'
                : 'Remaining balance payment submitted! You are ready for vehicle release.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording payment: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleRenterReturnVehicle(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final renterId = AuthService().currentUser?.id ?? '';
    if (bookingId.isEmpty || renterId.isEmpty) return;

    final endRaw =
        booking['end_at']?.toString() ??
        booking['end_date']?.toString() ??
        booking['end_date_raw']?.toString();
    final scheduledEnd = endRaw != null
        ? DateTime.tryParse(endRaw)?.toLocal()
        : null;
    final now = DateTime.now();

    int lateHours = 0;
    if (scheduledEnd != null && now.isAfter(scheduledEnd)) {
      final lateMinutes = now.difference(scheduledEnd).inMinutes;
      lateHours = (lateMinutes / 60.0).ceil();
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final seats = (vehicle['seats'] as num?)?.toInt() ??
        (booking['seats'] as num?)?.toInt() ??
        5;
    final dailyRate = (vehicle['price_per_day'] as num?)?.toDouble() ??
        (booking['totalCost'] as num?)?.toDouble() ??
        1500.0;

    final extStatus =
        booking['extension_status']?.toString().toLowerCase().trim();
    final isApprovedExtension = booking['is_approved_extension'] == true ||
        extStatus == 'finalized' ||
        extStatus == 'payment_completed' ||
        extStatus == 'approved';

    ReservationPaymentSettings? settings;
    try {
      settings = await ReservationPaymentService().getSettings();
    } catch (_) {}
    final latePenaltyFee = (settings ?? const ReservationPaymentSettings()).calculateLateFee(
      seats: seats,
      lateHours: lateHours,
      dailyRate: dailyRate,
      isApproved: isApprovedExtension,
    );

    final totalCost =
        (booking['totalCost'] as num?)?.toDouble() ??
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;

    final coversTotal =
        booking['reservationPaymentCoversTotal'] == true ||
        booking['reservation_payment_covers_total'] == true ||
        booking['reservationPaymentType'] == 'full_payment' ||
        booking['reservation_payment_type'] == 'full_payment' ||
        booking['final_payment_status'] == 'paid' ||
        BookingService().isBookingFullyPaid(booking);
    final reservationFee =
        (booking['reservationFeeAmount'] as num?)?.toDouble() ??
        (booking['reservation_fee_amount'] as num?)?.toDouble() ??
        0.0;
    final amountPaid = coversTotal
        ? totalCost
        : reservationFee > 0
        ? reservationFee
        : (booking['amount_paid'] as num?)?.toDouble() ?? 0.0;

    final remainingRentalBalance = (totalCost - amountPaid).clamp(
      0.0,
      double.infinity,
    );

    // If late, open ReservationPaymentScreen in lateReturnPenalty mode
    if (lateHours > 0) {
      final proof = await Navigator.of(context).push<ReservationPaymentProof>(
        MaterialPageRoute(
          builder: (_) => ReservationPaymentScreen(
            userId: renterId,
            vehicleData: vehicle.isNotEmpty
                ? vehicle
                : {
                    'id': booking['vehicle_id'],
                    'vehicle_name': booking['carName'],
                    'brand': booking['carName'],
                    'seats': seats,
                    'price_per_day': dailyRate,
                    'image_url': booking['imageUrl'],
                  },
            rentalTotal: totalCost,
            rentalSubtotal: (booking['rentalSubtotal'] as num?)?.toDouble() ?? totalCost,
            deliveryFee: (booking['deliveryFee'] as num?)?.toDouble() ?? 0.0,
            discountAmount: 0.0,
            reservationFeeAmount: 0.0,
            requiresLongBookingReservation: false,
            paymentPurpose: PaymentPurpose.lateReturnPenalty,
            lateFeeAmount: latePenaltyFee,
            lateHours: lateHours,
            returnTimestamp: now,
            bookingId: bookingId,
            isApprovedExtension: isApprovedExtension,
          ),
        ),
      );

      if (proof == null) return; // Renter cancelled or went back

      // Show immediate loading indicator
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            color: AppColors.darkBgSecondary,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Processing vehicle return...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        await BookingService().renterInitiateReturn(
          bookingId: bookingId,
          renterId: renterId,
          paymentMethod: proof.method,
          paymentReference: proof.referenceNumber,
          proofUrl: proof.proofUrl,
          lateHours: lateHours,
          lateFee: latePenaltyFee,
          settledAmount: proof.amount,
          cachedBooking: booking,
        );

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        }

        if (!mounted) return;

        await ReturnInspectionNoticeModal.show(
          context,
          vehicleTitle: booking['carName']?.toString() ??
              booking['vehicleName']?.toString() ??
              'Vehicle',
        );

        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripRatingFlowScreen(
              bookingId: bookingId,
              reviewerRole: 'renter',
            ),
          ),
        );

        _loadBookings();
        return;
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating vehicle return: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // If remaining rental balance > 0 (not late, but unsettled remaining rental balance)
    if (remainingRentalBalance > 0) {
      final proof = await Navigator.of(context).push<ReservationPaymentProof>(
        MaterialPageRoute(
          builder: (_) => ReservationPaymentScreen(
            userId: renterId,
            vehicleData: vehicle.isNotEmpty
                ? vehicle
                : {
                    'id': booking['vehicle_id'],
                    'vehicle_name': booking['carName'],
                    'brand': booking['carName'],
                    'seats': seats,
                    'price_per_day': dailyRate,
                    'image_url': booking['imageUrl'],
                  },
            rentalTotal: totalCost,
            rentalSubtotal: (booking['rentalSubtotal'] as num?)?.toDouble() ?? totalCost,
            deliveryFee: (booking['deliveryFee'] as num?)?.toDouble() ?? 0.0,
            discountAmount: (booking['discount_amount'] as num?)?.toDouble() ?? 0.0,
            reservationFeeAmount: reservationFee,
            requiresLongBookingReservation: false,
            paymentPurpose: PaymentPurpose.releaseSettlement,
            paidReservationFee: reservationFee,
            bookingId: bookingId,
          ),
        ),
      );

      if (proof == null) return;

      // Show immediate loading indicator
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            color: AppColors.darkBgSecondary,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Processing vehicle return...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        await BookingService().renterInitiateReturn(
          bookingId: bookingId,
          renterId: renterId,
          paymentMethod: proof.method,
          paymentReference: proof.referenceNumber,
          proofUrl: proof.proofUrl,
          lateHours: 0,
          lateFee: 0.0,
          settledAmount: proof.amount,
          cachedBooking: booking,
        );

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        }

        if (!mounted) return;

        await ReturnInspectionNoticeModal.show(
          context,
          vehicleTitle: booking['carName']?.toString() ??
              booking['vehicleName']?.toString() ??
              'Vehicle',
        );

        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripRatingFlowScreen(
              bookingId: bookingId,
              reviewerRole: 'renter',
            ),
          ),
        );

        _loadBookings();
        return;
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating vehicle return: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Fully paid on-time return
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          color: AppColors.darkBgSecondary,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Processing vehicle return...',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await BookingService().renterInitiateReturn(
        bookingId: bookingId,
        renterId: renterId,
        paymentMethod: 'none',
        paymentReference: '',
        proofUrl: null,
        lateHours: 0,
        lateFee: 0.0,
        settledAmount: 0.0,
        cachedBooking: booking,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
      }

      if (!mounted) return;

      await ReturnInspectionNoticeModal.show(
        context,
        vehicleTitle: booking['carName']?.toString() ??
            booking['vehicleName']?.toString() ??
            'Vehicle',
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TripRatingFlowScreen(
            bookingId: bookingId,
            reviewerRole: 'renter',
          ),
        ),
      );

      _loadBookings();
      return;
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating vehicle return: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
  }

  Future<void> _showTripExtensionDialog(Map<String, dynamic> booking) async {
    if (_isBookingWithDriver(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Trip extension is only applicable for Self Drive rentals. Bookings with an assigned driver cannot be extended.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final vehicleId = booking['vehicle_id']?.toString() ??
        (booking['vehicles'] as Map<String, dynamic>?)?['id']?.toString() ??
        '';
    final bookingId = booking['id']?.toString() ?? '';
    final endRaw = booking['end_at']?.toString() ??
        booking['end_date_raw']?.toString() ??
        booking['endDate']?.toString() ??
        booking['end_date']?.toString();

    if (vehicleId.isEmpty || bookingId.isEmpty || endRaw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read booking details for trip extension.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final startRaw = booking['start_at']?.toString() ??
        booking['start_date_raw']?.toString() ??
        booking['startDate']?.toString() ??
        booking['start_date']?.toString();

    final currentEndAt = DateTime.tryParse(endRaw)?.toLocal();
    if (currentEndAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not parse the current trip end date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final currentStartAt = (startRaw != null ? DateTime.tryParse(startRaw)?.toLocal() : null) ??
        booking['startDateObj'] as DateTime? ??
        currentEndAt.subtract(const Duration(days: 1));

    final availability = await BookingService().getTripExtensionAvailability(
      bookingId: bookingId,
    );

    if (!availability.canExtend) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            availability.blockingReason ??
                'This vehicle cannot be extended because another customer has reserved it.',
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final explicitDailyRate =
        (vehicle?['daily_rate'] as num?)?.toDouble() ??
        (vehicle?['price_per_day'] as num?)?.toDouble();
    final totalCost =
        (booking['totalCost'] as num?)?.toDouble() ??
        (booking['total_price'] as num?)?.toDouble() ??
        1000.0;
    final days = (booking['days'] as num?)?.toInt() ?? 1;
    final dailyRate = explicitDailyRate ?? (totalCost / (days > 0 ? days : 1));

    // Extension must strictly start contiguous from the current booking's last day
    final currentEndDay = DateTime(currentEndAt.year, currentEndAt.month, currentEndAt.day);
    final initialFirstDate = currentEndDay.add(const Duration(days: 1));
    final maxLastDate = availability.maxAllowedExtensionDate ??
        initialFirstDate.add(const Duration(days: 30));

    final hasNextBooking = availability.nextBookingStart != null;
    final formattedMaxDate =
        '${maxLastDate.month}/${maxLastDate.day}/${maxLastDate.year}';

    final unavailableDays = await _fetchUnavailableDatesForReschedule(
      vehicleId: vehicleId,
      bookingId: bookingId,
    );

    final pickedDate = await _showExtensionCalendarDialog(
      firstDate: initialFirstDate,
      lastDate: maxLastDate,
      initialDate: initialFirstDate,
      currentStart: currentStartAt,
      currentEnd: currentEndAt,
      unavailableDays: unavailableDays,
      carName: booking['carName']?.toString() ?? 'Selected Vehicle',
    );

    if (pickedDate == null || !mounted) return;

    final selectedNewEndAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      currentEndAt.hour,
      currentEndAt.minute,
    );

    final extensionDays = pickedDate
        .difference(
          DateTime(currentEndAt.year, currentEndAt.month, currentEndAt.day),
        )
        .inDays;
    if (extensionDays <= 0) return;

    final additionalPrice = extensionDays * dailyRate;
    final destinationController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.cardBorderOf(context)),
        ),
        title: Row(
          children: [
            const Icon(Icons.av_timer_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Confirm Trip Extension',
              style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorderOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Extension Start (Locked):',
                        style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 12),
                      ),
                      Text(
                        _formatDateShort(currentEndAt.toIso8601String()),
                        style: TextStyle(color: AppColors.textPrimaryOf(context), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'New Extended Return:',
                        style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 12),
                      ),
                      Text(
                        _formatDateShort(selectedNewEndAt.toIso8601String()),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Extension Duration:',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Text(
                        '+$extensionDays day${extensionDays == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daily Unit Rate:',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Text(
                        'PHP ${formatAmount(dailyRate, decimalDigits: 0)} / day',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Additional Price Due:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '+PHP ${formatAmount(additionalPrice, decimalDigits: 0)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasNextBooking) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy_rounded, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Another renter has booked this car starting ${_formatDateShort(availability.nextBookingStart!.toIso8601String())}. The latest allowed extension date is ${_formatDateShort(maxLastDate.toIso8601String())}.',
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (ctx, setFieldState) {
                return TextField(
                  controller: destinationController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'New Destination *',
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    hintText: 'e.g. Baguio City or same as current',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Pin destination on map',
                      icon: const Icon(
                        Icons.map_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      onPressed: () async {
                        final selection = await MobilisLocationPickerModal.show(
                          context,
                          title: 'Pin trip destination',
                          subtitle: 'Search an address or place a pin for your extended trip destination.',
                          confirmLabel: 'Use this destination',
                          initialAddress: destinationController.text.trim(),
                        );
                        if (selection != null) {
                          setFieldState(() {
                            destinationController.text = selection.address;
                          });
                        }
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trip extensions require review and approval by the Partner/Operator before becoming finalized.',
                      style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (destinationController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter or pin a new trip destination before proceeding.'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text(
              'Proceed to Payment & Request',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      destinationController.dispose();
      return;
    }

    final requestedDestination = destinationController.text.trim();
    destinationController.dispose();

    if (!mounted) return;
    await _showInstantExtensionPaymentModal(
      context: context,
      bookingId: bookingId,
      newEndAt: selectedNewEndAt,
      additionalPrice: additionalPrice,
      extensionDays: extensionDays,
      dailyRate: dailyRate,
      newDestination: requestedDestination.isNotEmpty ? requestedDestination : null,
    );
  }

  Future<void> _showInstantExtensionPaymentModal({
    required BuildContext context,
    required String bookingId,
    required DateTime newEndAt,
    required double additionalPrice,
    required int extensionDays,
    required double dailyRate,
    String? newDestination,
  }) async {
    final referenceController = TextEditingController();
    String selectedMethod = 'GCash';
    XFile? pickedReceipt;
    bool isSubmitting = false;

    ReservationPaymentSettings? settings;
    try {
      settings = await ReservationPaymentService().getSettings();
    } catch (_) {}

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final qrUrl = settings?.qrUrl ?? '';
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pay & Request Extension',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Requires Partner / Operator Approval',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'PHP ${formatAmount(additionalPrice, decimalDigits: 0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // EXTENSION PRICE BREAKDOWN BANNER (BEFORE QR CODE)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Extension Cost Breakdown',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Extension Duration:',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            Text(
                              '+$extensionDays day${extensionDays == 1 ? '' : 's'}',
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Daily Rate:',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            Text(
                              'PHP ${formatAmount(dailyRate, decimalDigits: 0)} / day',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                        const Divider(height: 14, color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount Due:',
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'PHP ${formatAmount(additionalPrice, decimalDigits: 0)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (qrUrl.isNotEmpty) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            qrUrl,
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Scan QR to Pay with GCash, Maya, or any Banking App',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings?.accountName.isNotEmpty == true
                              ? 'Account: ${settings!.accountName}'
                              : 'PSDC Payment Accounts',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• GCash / Maya / QR Ph: 0917-123-4567\n• BDO / Bank Transfer: 0012-3456-7890',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Payment Method Used',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    dropdownColor: AppColors.darkBg,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.darkBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                      DropdownMenuItem(value: 'Maya', child: Text('Maya / PayMaya')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (BDO/BPI/QR Ph)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: referenceController,
                    keyboardType: selectedMethod == 'GCash'
                        ? TextInputType.number
                        : TextInputType.text,
                    textCapitalization: selectedMethod == 'GCash'
                        ? TextCapitalization.none
                        : TextCapitalization.characters,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(13),
                      if (selectedMethod == 'GCash')
                        FilteringTextInputFormatter.digitsOnly
                      else
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9\-]'),
                        ),
                    ],
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Payment Reference Number / Transaction ID *',
                      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      hintText: selectedMethod == 'GCash'
                          ? 'e.g. 10023458921 (6-13 digits)'
                          : 'e.g. MAYA1002345, GT94021, SB84920',
                      hintStyle: const TextStyle(color: Colors.white24),
                      helperText: selectedMethod == 'GCash'
                          ? '⚠️ GCash Ref No. must be 6 to 13 digits only'
                          : '⚠️ Enter Alphanumeric Transaction ID (6 to 13 characters)',
                      helperStyle: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: AppColors.darkBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final image = await _pickReceiptImageWithSource(context);
                      if (image != null) {
                        setModalState(() => pickedReceipt = image);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.darkBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pickedReceipt != null
                              ? AppColors.primary
                              : AppColors.borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            pickedReceipt != null
                                ? Icons.check_circle_rounded
                                : Icons.upload_file_rounded,
                            color: pickedReceipt != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              pickedReceipt != null
                                  ? 'Receipt: ${pickedReceipt!.name}'
                                  : 'Upload Payment Receipt (Camera or Gallery)',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: pickedReceipt != null
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final ref = referenceController.text.trim().toUpperCase();
                              if (ref.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter your online payment reference number.'),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                                return;
                              }
                              if (ref.length < 6 || ref.length > 13) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('⚠️ Payment Reference Number must be between 6 and 13 characters long.'),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                                return;
                              }
                              if (selectedMethod == 'GCash' &&
                                  !RegExp(r'^\d+$').hasMatch(ref)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('⚠️ GCash Reference Number must contain digits only (e.g. 10023458921).'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }
                              if (selectedMethod != 'GCash' &&
                                  !RegExp(r'^[A-Z0-9\-]+$').hasMatch(ref)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('⚠️ Transaction ID must contain valid letters & numbers only.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                String proofUrl = '';
                                if (pickedReceipt != null) {
                                  proofUrl = await _uploadTripExtensionReceipt(
                                    bookingId: bookingId,
                                    file: pickedReceipt!,
                                    prefix: 'ext_instant',
                                  );
                                }

                                await BookingService().submitInstantTripExtensionWithPayment(
                                  bookingId: bookingId,
                                  newEndAt: newEndAt,
                                  additionalPrice: additionalPrice,
                                  extensionDays: extensionDays,
                                  paymentMethod: selectedMethod,
                                  paymentReference: ref,
                                  proofUrl: proofUrl.isNotEmpty ? proofUrl : null,
                                  newDestination: newDestination,
                                );

                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Extension request submitted! Waiting for Partner review and confirmation.',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                                _loadBookings();
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to extend trip: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Submit Extension Request & Payment',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCancellationInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
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

  Future<void> _contactCancellationSupport(Map<String, dynamic> booking) async {
    final authService = AuthService();
    final currentUser = authService.currentUser;
    final bookingId = booking['id']?.toString() ?? '';
    if (currentUser == null || bookingId.isEmpty) return;

    try {
      final operatorId = await _resolveBookingOperatorId(booking);
      if (operatorId == null || operatorId.isEmpty) {
        throw Exception('No operator is assigned to this booking yet');
      }

      final conversation = await ChatService().createGroupConversation(
        bookingId: bookingId,
        participantIds: [currentUser.id, operatorId],
      );
      final conversationId = conversation['id']?.toString();
      if (conversationId == null || conversationId.isEmpty) {
        throw Exception('Could not create support conversation');
      }

      await Supabase.instance.client
          .from('conversations')
          .update({
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);

      final supportMessage =
          'Cancellation support request\n'
          'Booking: ${booking['carName'] ?? 'Vehicle'} ($bookingId)\n'
          'Status: ${booking['status'] ?? 'Cancelled'}\n'
          'Reason: ${booking['cancellationReason'] ?? 'N/A'}\n'
          'Refund status: ${booking['paymentStatus'] ?? 'N/A'}';

      await ChatService().sendMessage(
        conversationId: conversationId,
        senderId: currentUser.id,
        content: supportMessage,
      );

      await Supabase.instance.client.from('notifications').insert({
        'user_id': operatorId,
        'title': 'Cancellation Support Request',
        'message':
            'A renter needs help with cancelled booking ${booking['carName'] ?? bookingId}.',
        'type': 'booking_support',
        'data': {
          'booking_id': bookingId,
          'conversation_id': conversationId,
          'status': 'cancelled',
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.of(context)
          .pushNamed(
            '/chat-detail',
            arguments: {
              'conversationId': conversationId,
              'recipientName': 'Cancellation Support',
              'recipientAvatar': '',
              'isAutoGenerated': true,
            },
          )
          .then((_) {
            _loadConversations();
            _loadNotifications();
          });
    } catch (e) {
      debugPrint('Error contacting cancellation support: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not contact support: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatRoleList(List<String> roles) {
    final labels = roles
        .map((role) {
          switch (role.trim().toLowerCase()) {
            case 'operator':
              return 'operator';
            case 'partner':
              return 'partner';
            case 'driver':
              return 'driver';
            case 'renter':
              return 'renter';
            default:
              return role;
          }
        })
        .where((label) => label.isNotEmpty)
        .toList();

    if (labels.isEmpty) return 'the trip participants';
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels.first} and ${labels.last}';
    return '${labels.sublist(0, labels.length - 1).join(', ')}, and ${labels.last}';
  }

  Future<String?> _resolveBookingOperatorId(
    Map<String, dynamic> booking,
  ) async {
    final directOperatorId = booking['operator_id']?.toString();
    if (directOperatorId != null && directOperatorId.isNotEmpty) {
      return directOperatorId;
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleOperatorId = vehicle?['operator_id']?.toString();
    if (vehicleOperatorId != null && vehicleOperatorId.isNotEmpty) {
      return vehicleOperatorId;
    }

    final operator = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('role', 'operator')
        .limit(1)
        .maybeSingle();
    return operator?['id']?.toString();
  }

  bool _isCancelledBooking(Map<String, dynamic> booking) {
    final rawStatus = booking['rawStatus']?.toString().toLowerCase() ?? '';
    return rawStatus == 'cancelled' || rawStatus == 'canceled';
  }

  bool _isCancellableStatusForUi(Map<String, dynamic> booking) {
    final rawStatus = booking['rawStatus']?.toString().toLowerCase();
    return rawStatus == 'pending';
  }

  bool _canCancelBooking(Map<String, dynamic> booking) {
    final rawStatus = booking['rawStatus']?.toString().toLowerCase();
    if (rawStatus != 'pending') return false;

    final timeInfo = _getRemainingCancelTime(booking);
    return timeInfo['canCancel'] as bool;
  }

  Future<void> _showRescheduleTripDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final rescheduleCount = (booking['reschedule_count'] as num?)?.toInt() ??
        (booking['rescheduleCount'] as num?)?.toInt() ?? 0;
    if (rescheduleCount >= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This booking has already been rescheduled once. Rescheduling of booking is one time only.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    DateTime? currentStart = booking['startDateObj'] as DateTime? ??
        (booking['start_at'] != null ? DateTime.tryParse(booking['start_at']) : null);
    DateTime? currentEnd = booking['endDateObj'] as DateTime? ??
        (booking['end_at'] != null ? DateTime.tryParse(booking['end_at']) : null);

    final durationDays = (currentStart != null && currentEnd != null)
        ? (currentEnd.difference(currentStart).inMinutes / Duration.minutesPerDay).ceil().clamp(1, 365)
        : 1;

    DateTime selectedStartDate = DateTime.now().add(const Duration(days: 2));
    DateTime selectedEndDate = selectedStartDate.add(Duration(days: durationDays));

    final initialDestination = booking['dropoff_location']?.toString().trim() ??
        booking['dropoffLocation']?.toString().trim() ??
        booking['destination']?.toString().trim() ??
        '';
    final initialDropoffLat = (booking['dropoff_latitude'] ??
            booking['dropoffLatitude'] as num?)
        ?.toDouble();
    final initialDropoffLng = (booking['dropoff_longitude'] ??
            booking['dropoffLongitude'] as num?)
        ?.toDouble();

    final destinationController = TextEditingController(text: initialDestination);
    double? selectedDropoffLat = initialDropoffLat;
    double? selectedDropoffLng = initialDropoffLng;

    final reasonController = TextEditingController(text: 'Change of schedule');
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.darkBgSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_repeat_rounded,
                      color: Color(0xFFE5A93C),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reschedule Trip',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '100% of your ₱1,000 deposit is transferred',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.darkBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['carName']?.toString() ?? 'Selected Vehicle',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Current Dates: ${booking['startDate'] ?? 'N/A'} - ${booking['endDate'] ?? 'N/A'}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (initialDestination.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Current Destination: $initialDestination',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ONE-TIME RESCHEDULE NOTICE BANNER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A93C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFE5A93C), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Note: Reschedule of booking is one time only.',
                              style: TextStyle(
                                color: Color(0xFFE5A93C),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Select New Trip Dates',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Unified Date Range Picker Button
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.borderColor),
                      ),
                      tileColor: AppColors.darkBg,
                      leading: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFFE5A93C),
                        size: 22,
                      ),
                      title: const Text(
                        'New Trip Dates',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      subtitle: Text(
                        '${DateFormat('EEE, MMM d, yyyy').format(selectedStartDate)} – ${DateFormat('EEE, MMM d, yyyy').format(selectedEndDate)} (${selectedEndDate.difference(selectedStartDate).inDays} day${selectedEndDate.difference(selectedStartDate).inDays > 1 ? 's' : ''})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.edit_calendar_rounded,
                        color: Color(0xFFE5A93C),
                        size: 20,
                      ),
                      onTap: isSubmitting
                          ? null
                          : () async {
                              final vehicleId = booking['vehicle_id']?.toString() ??
                                  booking['vehicleId']?.toString() ??
                                  booking['vehicles']?['id']?.toString() ??
                                  '';
                              final unavailableDays = await _fetchUnavailableDatesForReschedule(
                                vehicleId: vehicleId,
                                bookingId: bookingId,
                              );

                              final picked = await _showRescheduleCalendarDialog(
                                firstDate: DateTime.now().add(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                                initialStart: selectedStartDate,
                                initialEnd: selectedEndDate,
                                fixedDurationDays: durationDays,
                                previousStart: currentStart,
                                previousEnd: currentEnd,
                                unavailableDays: unavailableDays,
                                carName: booking['carName']?.toString() ?? 'Selected Vehicle',
                              );

                              if (picked != null) {
                                setModalState(() {
                                  selectedStartDate = DateTime(
                                    picked.start.year,
                                    picked.start.month,
                                    picked.start.day,
                                    currentStart?.hour ?? 9,
                                    currentStart?.minute ?? 0,
                                  );
                                  selectedEndDate = DateTime(
                                    picked.end.year,
                                    picked.end.month,
                                    picked.end.day,
                                    currentEnd?.hour ?? 18,
                                    currentEnd?.minute ?? 0,
                                  );
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Trip Destination',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Leave as is or pin a new destination on map',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Destination Text Field with Pin Destination Map Picker
                    TextField(
                      controller: destinationController,
                      maxLines: 2,
                      minLines: 1,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Destination Address',
                        hintText: 'Enter destination or pin on map',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        prefixIcon: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Pin destination on map',
                          icon: const Icon(
                            Icons.map_outlined,
                            color: Color(0xFFE5A93C),
                            size: 22,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final selection = await MobilisLocationPickerModal.show(
                                    context,
                                    title: 'Pin trip destination',
                                    subtitle:
                                        'Search an address or place a pin for your rescheduled trip destination.',
                                    confirmLabel: 'Use this destination',
                                    initialAddress: destinationController.text.trim().isNotEmpty
                                        ? destinationController.text.trim()
                                        : initialDestination,
                                    initialLatitude: selectedDropoffLat,
                                    initialLongitude: selectedDropoffLng,
                                  );
                                  if (selection != null) {
                                    setModalState(() {
                                      destinationController.text = selection.address;
                                      selectedDropoffLat = selection.latitude;
                                      selectedDropoffLng = selection.longitude;
                                    });
                                  }
                                },
                        ),
                        filled: true,
                        fillColor: AppColors.darkBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5A93C)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Reason for Date / Destination Change',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: AppColors.darkBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.borderColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);
                          try {
                            await BookingService().rescheduleBooking(
                              bookingId: bookingId,
                              newStartAt: selectedStartDate.toUtc(),
                              newEndAt: selectedEndDate.toUtc(),
                              newDropoffLocation: destinationController.text.trim().isNotEmpty
                                  ? destinationController.text.trim()
                                  : null,
                              newDropoffLatitude: selectedDropoffLat,
                              newDropoffLongitude: selectedDropoffLng,
                              reason: reasonController.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Trip rescheduled successfully! 100% of your ₱1,000 deposit has been transferred.',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              await _loadBookings();
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Reschedule error: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(
                    isSubmitting ? 'Rescheduling...' : 'Confirm Reschedule',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A93C),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Set<DateTime>> _fetchUnavailableDatesForReschedule({
    required String vehicleId,
    required String bookingId,
  }) async {
    final unavailable = <DateTime>{};
    if (vehicleId.isEmpty) return unavailable;

    try {
      final bookingsResp = await Supabase.instance.client
          .from('bookings')
          .select('id, start_at, end_at, start_date, end_date, status')
          .eq('vehicle_id', vehicleId)
          .neq('id', bookingId)
          .inFilter('status', ['pending', 'approved', 'ongoing', 'confirmed']);

      for (final row in List<Map<String, dynamic>>.from(bookingsResp)) {
        final start = DateTime.tryParse(row['start_at']?.toString() ?? '') ??
            DateTime.tryParse(row['start_date']?.toString() ?? '');
        final end = DateTime.tryParse(row['end_at']?.toString() ?? '') ??
            DateTime.tryParse(row['end_date']?.toString() ?? '');
        if (start == null || end == null) continue;

        var cur = _dateOnly(start);
        final last = _dateOnly(end);
        while (!cur.isAfter(last)) {
          unavailable.add(cur);
          cur = cur.add(const Duration(days: 1));
        }
      }

      final explicitUnavailable =
          await VehicleService().getUnavailableDates(vehicleId);
      for (final d in explicitUnavailable) {
        unavailable.add(_dateOnly(d));
      }
    } catch (e) {
      debugPrint('Error fetching reschedule unavailable dates: $e');
    }

    return unavailable;
  }

  Future<DateTime?> _showExtensionCalendarDialog({
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime initialDate,
    required DateTime currentStart,
    required DateTime currentEnd,
    required Set<DateTime> unavailableDays,
    required String carName,
  }) {
    var focusedDay = initialDate;
    DateTime? selectedDay = initialDate;
    final unavailable = unavailableDays.map(_dateOnly).toSet();
    final currentBookingDays = <DateTime>{};
    var cur = _dateOnly(currentStart);
    final currentLast = _dateOnly(currentEnd);
    while (!cur.isAfter(currentLast)) {
      currentBookingDays.add(cur);
      cur = cur.add(const Duration(days: 1));
    }

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.darkBgSecondary,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderColor),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Extension Return Date',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  carName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE5A93C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: const [
                          _CalendarLegendDot(
                            color: Color(0xFFE5A93C),
                            label: 'New Return Date',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.error,
                            label: 'Already Booked (Unavailable)',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: Color(0xFF3B82F6),
                            label: 'Current Trip Dates',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.success,
                            label: 'Available Dates',
                            textColor: AppColors.textPrimary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TableCalendar(
                        firstDay: firstDate,
                        lastDay: lastDate,
                        focusedDay: focusedDay,
                        selectedDayPredicate: (day) =>
                            selectedDay != null && isSameDay(selectedDay, day),
                        enabledDayPredicate: (day) {
                          final date = _dateOnly(day);
                          return !unavailable.contains(date) &&
                              !date.isBefore(_dateOnly(firstDate));
                        },
                        onDaySelected: (day, focused) {
                          final date = _dateOnly(day);
                          if (unavailable.contains(date)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('That date is already booked / unavailable for this car.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            selectedDay = day;
                            focusedDay = focused;
                          });
                        },
                        headerStyle: const HeaderStyle(
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          formatButtonVisible: false,
                          leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFFE5A93C)),
                          rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFFE5A93C)),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          weekendStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        calendarStyle: const CalendarStyle(
                          outsideDaysVisible: false,
                          defaultTextStyle: TextStyle(color: AppColors.textPrimary),
                          weekendTextStyle: TextStyle(color: AppColors.textPrimary),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            final date = _dateOnly(day);
                            final endLimit = selectedDay != null ? _dateOnly(selectedDay!) : null;
                            final prevEnd = _dateOnly(currentEnd);

                            if (endLimit != null && date.isAfter(prevEnd) && !date.isAfter(endLimit)) {
                              final isSelectedEnd = isSameDay(date, endLimit);
                              return _buildCalendarDayCell(
                                day: day,
                                backgroundColor: isSelectedEnd
                                    ? const Color(0xFFE5A93C)
                                    : const Color(0xFFE5A93C).withAlpha(90),
                                borderColor: const Color(0xFFE5A93C),
                                textColor: isSelectedEnd ? Colors.black : Colors.white,
                              );
                            }

                            return _buildRescheduleDayCell(
                              day,
                              unavailable,
                              currentBookingDays,
                            );
                          },
                          todayBuilder: (context, day, focusedDay) {
                            final date = _dateOnly(day);
                            final endLimit = selectedDay != null ? _dateOnly(selectedDay!) : null;
                            final prevEnd = _dateOnly(currentEnd);

                            if (endLimit != null && date.isAfter(prevEnd) && !date.isAfter(endLimit)) {
                              final isSelectedEnd = isSameDay(date, endLimit);
                              return _buildCalendarDayCell(
                                day: day,
                                backgroundColor: isSelectedEnd
                                    ? const Color(0xFFE5A93C)
                                    : const Color(0xFFE5A93C).withAlpha(90),
                                borderColor: const Color(0xFFE5A93C),
                                textColor: isSelectedEnd ? Colors.black : Colors.white,
                              );
                            }

                            return _buildRescheduleDayCell(
                              day,
                              unavailable,
                              currentBookingDays,
                              isToday: true,
                            );
                          },
                          selectedBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: const Color(0xFFE5A93C),
                              textColor: Colors.black,
                            );
                          },
                          disabledBuilder: (context, day, focusedDay) {
                            final date = _dateOnly(day);
                            if (unavailable.contains(date)) {
                              return _buildCalendarDayCell(
                                day: day,
                                backgroundColor: AppColors.error,
                                textColor: Colors.white,
                                strikethrough: true,
                              );
                            }
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: Colors.transparent,
                              textColor: AppColors.textTertiary,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.borderColor),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: selectedDay == null
                                  ? null
                                  : () => Navigator.pop(dialogContext, selectedDay),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE5A93C),
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Confirm Date', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTimeRange?> _showRescheduleCalendarDialog({
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime initialStart,
    required DateTime initialEnd,
    required int fixedDurationDays,
    required DateTime? previousStart,
    required DateTime? previousEnd,
    required Set<DateTime> unavailableDays,
    required String carName,
  }) {
    var focusedDay = initialStart;
    DateTime rangeStart = _dateOnly(initialStart);
    DateTime rangeEnd = rangeStart.add(Duration(days: fixedDurationDays));
    final unavailable = unavailableDays.map(_dateOnly).toSet();

    final previousDays = <DateTime>{};
    if (previousStart != null && previousEnd != null) {
      var cur = _dateOnly(previousStart);
      final last = _dateOnly(previousEnd);
      while (!cur.isAfter(last)) {
        previousDays.add(cur);
        cur = cur.add(const Duration(days: 1));
      }
    }

    return showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasInvalidRange = _rangeContainsBlockedDate(rangeStart, rangeEnd, unavailable);

            void selectStartDate(DateTime selectedDay) {
              final start = _dateOnly(selectedDay);
              final end = start.add(Duration(days: fixedDurationDays));

              if (_rangeContainsBlockedDate(start, end, unavailable)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cannot reschedule to this start date: $fixedDurationDays-day trip overlaps with booked / unavailable dates.',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              }

              setDialogState(() {
                rangeStart = start;
                rangeEnd = end;
                focusedDay = selectedDay;
              });
            }

            return Dialog(
              backgroundColor: AppColors.darkBgSecondary,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderColor),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Reschedule Start Date',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  carName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE5A93C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Locked Duration Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5A93C).withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_clock_rounded, size: 16, color: Color(0xFFE5A93C)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Fixed Duration: $fixedDurationDays day${fixedDurationDays > 1 ? 's' : ''} (Original booking duration. Extending trip days is not permitted during reschedule).',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: const [
                          _CalendarLegendDot(
                            color: Color(0xFFE5A93C),
                            label: 'Rescheduled Trip Period',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.error,
                            label: 'Already Booked (Unavailable)',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: Color(0xFF3B82F6),
                            label: 'Your Previous Dates',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.success,
                            label: 'Available Dates',
                            textColor: AppColors.textPrimary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TableCalendar(
                        firstDay: firstDate,
                        lastDay: lastDate,
                        focusedDay: focusedDay,
                        rangeStartDay: rangeStart,
                        rangeEndDay: rangeEnd,
                        rangeSelectionMode: RangeSelectionMode.toggledOn,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        onDaySelected: (selectedDay, focused) {
                          selectStartDate(selectedDay);
                        },
                        onRangeSelected: (start, end, focused) {
                          if (start != null) {
                            selectStartDate(start);
                          }
                        },
                        headerStyle: const HeaderStyle(
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          formatButtonVisible: false,
                          leftChevronIcon: Icon(
                            Icons.chevron_left,
                            color: Color(0xFFE5A93C),
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right,
                            color: Color(0xFFE5A93C),
                          ),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          weekendStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          rangeHighlightColor: const Color(0xFFE5A93C).withAlpha(55),
                          defaultTextStyle: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          weekendTextStyle: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            return _buildRescheduleDayCell(
                              day,
                              unavailable,
                              previousDays,
                            );
                          },
                          todayBuilder: (context, day, focusedDay) {
                            return _buildRescheduleDayCell(
                              day,
                              unavailable,
                              previousDays,
                              isToday: true,
                            );
                          },
                          selectedBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: const Color(0xFFE5A93C),
                              textColor: Colors.black,
                            );
                          },
                          rangeStartBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: const Color(0xFFE5A93C),
                              textColor: Colors.black,
                            );
                          },
                          rangeEndBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: const Color(0xFFE5A93C),
                              textColor: Colors.black,
                            );
                          },
                          withinRangeBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: const Color(0xFFE5A93C).withAlpha(90),
                              textColor: Colors.black,
                              borderColor: const Color(0xFFE5A93C),
                            );
                          },
                          disabledBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: Colors.transparent,
                              textColor: AppColors.textTertiary,
                            );
                          },
                        ),
                      ),
                      if (hasInvalidRange) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Selected range includes booked / unavailable dates.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: hasInvalidRange
                                  ? null
                                  : () => Navigator.pop(
                                      dialogContext,
                                      DateTimeRange(
                                        start: rangeStart,
                                        end: rangeEnd,
                                      ),
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE5A93C),
                                foregroundColor: Colors.black,
                              ),
                              child: const Text(
                                'Apply Dates',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRescheduleDayCell(
    DateTime day,
    Set<DateTime> unavailable,
    Set<DateTime> previousDays, {
    bool isToday = false,
  }) {
    final date = _dateOnly(day);
    if (unavailable.contains(date)) {
      return _buildCalendarDayCell(
        day: day,
        backgroundColor: AppColors.error,
        borderColor: isToday ? const Color(0xFFE5A93C) : null,
        textColor: Colors.white,
        strikethrough: true,
      );
    }
    if (previousDays.contains(date)) {
      return _buildCalendarDayCell(
        day: day,
        backgroundColor: const Color(0xFF3B82F6).withAlpha(50),
        borderColor: const Color(0xFF3B82F6),
        textColor: const Color(0xFF93C5FD),
      );
    }
    return _buildCalendarDayCell(
      day: day,
      backgroundColor: AppColors.success.withAlpha(45),
      borderColor: isToday ? const Color(0xFFE5A93C) : AppColors.success,
      textColor: isToday ? const Color(0xFFE5A93C) : AppColors.textPrimary,
    );
  }

  Future<void> _handleBookingCancellation(Map<String, dynamic> booking) async {
    final reasonController = TextEditingController();
    final rescheduleCount = (booking['reschedule_count'] as num?)?.toInt() ??
        (booking['rescheduleCount'] as num?)?.toInt() ?? 0;

    final actionChoice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cancel or Reschedule Trip',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // STRICT NON-REFUNDABLE NOTICE BANNER
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE53935).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFE53935), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Deposit Policy Notice',
                            style: TextStyle(
                              color: Color(0xFFE53935),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Per platform policy, the ₱1,000 security deposit / reservation fee is NON-REFUNDABLE upon cancellation. However, you can Reschedule your trip to new dates and keep 100% of your deposit!\n\nNote: Reschedule of booking is one time only.',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Vehicle: ${booking['carName'] ?? 'Selected vehicle'}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Scheduled: ${booking['startDate'] ?? ''} - ${booking['endDate'] ?? ''}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              // OPTION 1 (RECOMMENDED): RESCHEDULE TRIP
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: rescheduleCount >= 1
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('This booking has already been rescheduled once. Rescheduling of booking is one time only.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      : () => Navigator.pop(dialogContext, 'reschedule'),
                  icon: const Icon(Icons.event_repeat_rounded, size: 18),
                  label: Text(
                    rescheduleCount >= 1
                        ? 'Reschedule Trip (Limit Reached - 1 Time Only)'
                        : 'Reschedule Trip (Keep ₱1,000 Deposit)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rescheduleCount >= 1 ? Colors.grey.shade700 : const Color(0xFFE5A93C),
                    foregroundColor: rescheduleCount >= 1 ? Colors.white60 : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // OPTION 2: OUTRIGHT CANCELLATION (FORFEIT DEPOSIT)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, 'cancel_forfeit'),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                  label: const Text(
                    'Proceed to Cancel & Forfeit Deposit',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'keep'),
            child: const Text('Keep Booking', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );

    if (actionChoice == 'reschedule') {
      await _showRescheduleTripDialog(booking);
      return;
    }

    if (actionChoice != 'cancel_forfeit') {
      return;
    }

    // Prompt for cancellation reason before forfeiting
    final reasonConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Cancellation & Deposit Forfeiture',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for cancelling. Note that the ₱1,000 deposit is retained per non-refundable policy.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 3,
              maxLength: 160,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cancellation reason',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a cancellation reason.'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (reasonConfirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    try {
      await BookingService().cancelBookingWithDepositForfeit(
        bookingId: booking['id'].toString(),
        cancellationReason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled. Deposit retained per policy.'),
            backgroundColor: AppColors.warning,
          ),
        );
        await _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling booking: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildTripImageFallback(Color backgroundColor, Color iconColor) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Icon(Icons.directions_car, size: 38, color: iconColor),
    );
  }

  Widget _buildVehicleImageLoading(Color backgroundColor, Color iconColor) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
              backgroundColor: iconColor.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Loading image...',
            style: TextStyle(
              color: iconColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastVehicleImage({
    required String? imageUrl,
    required BoxFit fit,
    required Color backgroundColor,
    required Color iconColor,
    double? width,
    double? height,
  }) {
    final cleanUrl = imageUrl?.trim();
    if (cleanUrl == null || cleanUrl.isEmpty) {
      return _buildTripImageFallback(backgroundColor, iconColor);
    }

    return OptimizedNetworkImage(
      imageUrl: cleanUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: _buildVehicleImageLoading(backgroundColor, iconColor),
      errorWidget: _buildTripImageFallback(backgroundColor, iconColor),
    );
  }

  Widget _buildFeatureIcon(IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Icon(
      icon,
      size: 14,
      color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
    );
  }
}

