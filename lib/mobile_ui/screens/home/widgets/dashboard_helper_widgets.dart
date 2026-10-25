part of '../dashboard_screen.dart';

class _AgreementNote extends StatelessWidget {
  final String text;

  const _AgreementNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 13,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

Future<String> _uploadTripExtensionReceipt({
  required String bookingId,
  required XFile file,
  String prefix = 'ext_payment',
}) async {
  final bytes = await file.readAsBytes();
  final fileExt = file.name.contains('.') ? file.name.split('.').last : 'jpg';
  final fileName =
      '${prefix}_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
  final supabase = Supabase.instance.client;

  final candidateBuckets = [
    'reservation_receipts',
    'booking_evidence',
    'chat_attachments',
    'driver_documents',
    'partner_documents',
    'vehicle_images',
    'public',
  ];

  for (final bucket in candidateBuckets) {
    try {
      await supabase.storage.from(bucket).uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return supabase.storage.from(bucket).getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Bucket $bucket upload failed: $e. Trying next bucket...');
    }
  }
  throw Exception('Storage bucket not available to store receipt image.');
}

class _RenterBookingDetailsPage extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isApprovedTrip;
  final bool isCompletedTrip;
  final String completionStage;
  final List<String> pendingRoles;
  final String paymentTypeLabel;
  final String amountPaidLabel;
  final VoidCallback? onMessage;
  final VoidCallback? onNavigate;
  final VoidCallback? onCancel;
  final VoidCallback? onExtend;
  final VoidCallback? onReturn;
  final VoidCallback? onSuccessfulTrip;
  final VoidCallback? onReceipt;
  final bool isAlreadyRated;
  final VoidCallback? onRateTrip;
  final VoidCallback? onPayRemainingBalance;
  final bool isPaidInFull;

  const _RenterBookingDetailsPage({
    required this.booking,
    required this.isApprovedTrip,
    required this.isCompletedTrip,
    required this.completionStage,
    required this.pendingRoles,
    required this.paymentTypeLabel,
    required this.amountPaidLabel,
    this.onMessage,
    this.onNavigate,
    this.onCancel,
    this.onExtend,
    this.onReturn,
    this.onSuccessfulTrip,
    this.onReceipt,
    this.isAlreadyRated = false,
    this.onRateTrip,
    this.onPayRemainingBalance,
    this.isPaidInFull = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = booking['status']?.toString() ?? 'Pending';
    final days = (booking['days'] as num?)?.toInt() ?? 1;
    final totalCost = (booking['totalCost'] as num?)?.toDouble() ?? 0;
    final lateReturnFee =
        (booking['lateReturnFee'] as num?)?.toDouble() ??
        (booking['late_return_fee'] as num?)?.toDouble() ??
        0.0;
    final lateHours = (booking['late_return_hours'] as num?)?.toInt() ?? 0;
    final finalReturnAmount =
        (booking['renter_return_payment_amount'] as num?)?.toDouble() ??
        (booking['renterReturnPaymentAmount'] as num?)?.toDouble() ??
        0.0;
    final finalPaymentMethod =
        booking['final_payment_method']?.toString() ??
        booking['finalPaymentMethod']?.toString();
    final finalPaymentRef =
        booking['final_payment_reference']?.toString() ??
        booking['finalPaymentReference']?.toString();
    final withDriver = booking['withDriver'] == true ||
        booking['with_driver'] == true ||
        booking['with_driver'] == 1 ||
        booking['with_driver']?.toString().toLowerCase() == 'true';
    const completionActionLabel = 'Rate Your Trip';
    const completionActionIcon = Icons.star_rate_rounded;

    final effectiveIsPaidInFull = isPaidInFull ||
        BookingService().isBookingFullyPaid(booking) ||
        BookingService().getBookingRemainingBalance(booking) <= 0.01;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVehicleSummary(status),
              const SizedBox(height: 14),
              if (effectiveIsPaidInFull && !isCompletedTrip) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have already paid for this trip in full. Bayad na lahat (Fully Paid).',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (!effectiveIsPaidInFull && onPayRemainingBalance != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.payment_rounded, color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payment required before vehicle release (1 day prior).',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildPrimaryButton(
                        icon: Icons.payment_rounded,
                        label: 'Pay Now (Remaining Balance)',
                        onPressed: onPayRemainingBalance!,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // Dedicated Rental Service & Driver Details Section
              _buildRentalServiceAndDriverSection(context),
              const SizedBox(height: 14),
              if (booking['extension_status'] != null &&
                  booking['extension_status'].toString().isNotEmpty &&
                  booking['extension_status'] != 'none') ...[
                _buildRenterTripExtensionCard(context),
                const SizedBox(height: 14),
              ],
              if (isApprovedTrip) ...[
                _buildOngoingTripPanel(),
                const SizedBox(height: 14),
              ] else if (onNavigate != null) ...[
                _buildPrimaryButton(
                  icon: Icons.navigation_rounded,
                  label: 'Navigate',
                  onPressed: onNavigate!,
                ),
                const SizedBox(height: 12),
              ],
              if (pendingRoles.isNotEmpty &&
                  completionStage != 'not_started') ...[
                _buildNotice(
                  'Required ratings remaining: ${pendingRoles.join(', ')}.',
                ),
                const SizedBox(height: 12),
              ],
              _buildSection(
                title: 'Trip Timeline',
                children: [
                  _detailRow(
                    Icons.calendar_today_outlined,
                    'Pickup Schedule',
                    '${booking['startDate'] ?? 'N/A'} ${booking['startTime'] ?? ''}',
                  ),
                  _detailRow(
                    Icons.event_available_outlined,
                    'Drop-off Schedule',
                    '${booking['endDate'] ?? 'N/A'} ${booking['endTime'] ?? ''}',
                  ),
                  _detailRow(
                    Icons.trip_origin_rounded,
                    'Pickup Location',
                    booking['pickupLocation']?.toString() ?? 'Not specified',
                    onTap: () {
                      TripLocationMapDialog.show(
                        context: context,
                        booking: booking,
                        vehicleName: booking['vehicleName']?.toString(),
                        plateNumber: booking['plateNumber']?.toString(),
                      );
                    },
                  ),
                  _detailRow(
                    Icons.location_on_rounded,
                    'Drop-off Location',
                    booking['dropoffLocation']?.toString() ?? 'Not specified',
                    onTap: () {
                      TripLocationMapDialog.show(
                        context: context,
                        booking: booking,
                        vehicleName: booking['vehicleName']?.toString(),
                        plateNumber: booking['plateNumber']?.toString(),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSection(
                title: 'Payment Summary',
                children: [
                  _detailRow(Icons.timer_outlined, 'Duration', '$days day(s)'),
                  _detailRow(
                    withDriver ? Icons.drive_eta_rounded : Icons.key_rounded,
                    'Rental Service',
                    withDriver ? 'With Professional Driver' : 'Self-Drive',
                  ),
                  _detailRow(
                    Icons.receipt_long_outlined,
                    'Payment Type',
                    paymentTypeLabel,
                  ),
                  _detailRow(
                    Icons.payments_outlined,
                    'Amount Paid',
                    amountPaidLabel,
                  ),
                  _detailRow(
                    Icons.account_balance_wallet_outlined,
                    'Total Cost',
                    'PHP ${formatAmount(totalCost, decimalDigits: 0)}',
                  ),
                  if (lateReturnFee > 0 || lateHours > 0)
                    _detailRow(
                      Icons.warning_amber_rounded,
                      'Late Return Penalty',
                      'PHP ${formatAmount(lateReturnFee > 0 ? lateReturnFee : (lateHours * 300.0), decimalDigits: 0)}${lateHours > 0 ? ' ($lateHours hrs late)' : ''}',
                    ),
                  if (finalReturnAmount > 0 || finalPaymentMethod != null)
                    _detailRow(
                      Icons.check_circle_outline_rounded,
                      'Final Settlement Paid',
                      'PHP ${formatAmount(finalReturnAmount > 0 ? finalReturnAmount : (totalCost - 1000.0).clamp(0, double.infinity), decimalDigits: 0)}${finalPaymentMethod != null ? ' via ${(finalPaymentMethod ?? '').toUpperCase()}' : ''}',
                    ),
                  if (finalPaymentRef != null && finalPaymentRef.isNotEmpty)
                    _detailRow(
                      Icons.tag_rounded,
                      'Settlement Reference',
                      finalPaymentRef,
                    ),
                  if (onReceipt != null) ...[
                    const SizedBox(height: 6),
                    _buildInlineAction(
                      icon: Icons.download_rounded,
                      label: 'View and Download Receipt',
                      onPressed: onReceipt!,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              if (onSuccessfulTrip != null)
                _buildPrimaryButton(
                  icon: completionActionIcon,
                  label: completionActionLabel,
                  onPressed: onSuccessfulTrip!,
                ),
              if (onSuccessfulTrip != null) const SizedBox(height: 12),
              if (onExtend != null)
                _buildSecondaryButton(
                  icon: Icons.more_time,
                  label: 'Check for Extend Trip',
                  onPressed: onExtend!,
                ),
              if (onExtend != null) const SizedBox(height: 12),
              if (onMessage != null && !isApprovedTrip)
                Builder(
                  builder: (context) {
                    final isChatEligible =
                        BookingService().isEligibleForBookingChat(booking);
                    return _buildSecondaryButton(
                      icon: isChatEligible
                          ? Icons.chat_bubble_outline
                          : Icons.lock_clock,
                      label: isChatEligible
                          ? 'Open Conversation'
                          : 'Conversation (Unlocks 72h Prior)',
                      onPressed: onMessage!,
                    );
                  },
                ),
              if (onMessage != null && !isApprovedTrip)
                const SizedBox(height: 12),
              if (onCancel != null)
                _buildDangerButton(
                  icon: Icons.cancel_outlined,
                  label: booking['statusGroup'] == 'Pending'
                      ? 'Cancel Request'
                      : 'Cancel Booking',
                  onPressed: onCancel!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callPhone(BuildContext context, String? phone) async {
    final clean = phone?.trim() ?? '';
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open phone dialer: $clean')),
      );
    }
  }

  /// 🚗 Dedicated Rental Service & Driver Details Section
  Widget _buildRentalServiceAndDriverSection(BuildContext context) {
    final withDriver = booking['withDriver'] == true ||
        booking['with_driver'] == true ||
        booking['with_driver'] == 1 ||
        booking['with_driver']?.toString().toLowerCase() == 'true';
    final rawDriverName = booking['driverName']?.toString().trim();
    final hasAssignedDriver = rawDriverName != null &&
        rawDriverName.isNotEmpty &&
        rawDriverName != 'To be assigned' &&
        rawDriverName != 'Not requested';
    final driverPhone = booking['driverPhone']?.toString().trim() ?? '';
    final driverEmail = booking['driverEmail']?.toString().trim() ?? '';

    if (!withDriver) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.key_rounded, size: 16, color: Colors.blueAccent),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Rental Service',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    '🔑 SELF-DRIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'You will be driving the vehicle. Please present your valid Driver\'s License and required government ID upon vehicle pickup.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    // With Professional Driver
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasAssignedDriver
              ? Colors.cyan.withValues(alpha: 0.45)
              : Colors.amber.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (hasAssignedDriver ? Colors.cyan : Colors.amber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.airline_seat_recline_normal_rounded,
                  size: 16,
                  color: hasAssignedDriver ? Colors.cyan : Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Rental Service',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (hasAssignedDriver ? Colors.cyan : Colors.amber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (hasAssignedDriver ? Colors.cyan : Colors.amber).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '🚗 WITH DRIVER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: hasAssignedDriver ? Colors.cyan : Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasAssignedDriver) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBgTertiary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                        child: Text(
                          rawDriverName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.cyan,
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
                                    rawDriverName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
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
                                    'CERTIFIED DRIVER',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (driverEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                driverEmail,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
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
            const SizedBox(height: 8),
            const Text(
              'Your assigned professional driver will meet you at the designated pickup location and operate the vehicle for your trip.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 18, color: Colors.amber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver Allocation in Progress',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'You booked this trip with a designated professional driver. Our dispatch team is assigning a certified driver. Contact details will appear here once confirmed.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleSummary(String status) {
    final imageUrl = booking['imageUrl']?.toString();
    final plate = booking['plateNumber']?.toString().trim() ?? '';
    final transmission = booking['transmission']?.toString().trim() ?? '';
    final fuel = booking['fuelType']?.toString().trim() ?? '';
    final seats = booking['seats'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.darkBgTertiary,
                  borderRadius: BorderRadius.circular(16),
                  image: imageUrl == null || imageUrl.isEmpty
                      ? null
                      : DecorationImage(
                          image: OptimizedNetworkImageProvider(imageUrl),
                          fit: BoxFit.cover,
                        ),
                ),
                child: imageUrl == null || imageUrl.isEmpty
                    ? const Icon(
                        Icons.directions_car,
                        color: AppColors.textSecondary,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking['carName']?.toString() ?? 'Vehicle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      booking['rentalPartner']?.toString() ?? 'Mobilis',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (plate.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Plate: $plate',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(status: status),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (transmission.isNotEmpty || fuel.isNotEmpty || seats != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (transmission.isNotEmpty)
                  _specChip(transmission),
                if (fuel.isNotEmpty)
                  _specChip(fuel),
                if (seats != null)
                  _specChip('$seats Seats'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _specChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.darkBgTertiary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final isClickable = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isClickable) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.map_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 3),
                          const Text(
                            '(Tap to View Map)',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        color: isClickable ? AppColors.primary : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: isClickable ? TextDecoration.underline : TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotice(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildOngoingTripPanel() {
    final rawStatus = (booking['status'] ?? booking['rawStatus'] ?? '')
        .toString()
        .toLowerCase();
    final isReturnSubmitted =
        rawStatus == 'return_pending_inspection' ||
        rawStatus == 'awaiting_completion' ||
        rawStatus == 'completed' ||
        rawStatus == 'returned' ||
        rawStatus == 'successful' ||
        rawStatus == 'success' ||
        rawStatus == 'awaiting_ratings' ||
        booking['returned_at'] != null ||
        booking['returnedAt'] != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route_rounded, color: AppColors.primary, size: 21),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Ongoing Trip',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _LiveTripBadge(),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Follow the return schedule and keep trip coordination in the booking conversation.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          BookingReturnCountdown(booking: booking),
          const SizedBox(height: 14),
          if (isReturnSubmitted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_clock_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vehicle Return Submitted — Waiting for Operator Verification & Inspection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: isAlreadyRated
                  ? OutlinedButton.icon(
                      onPressed: onRateTrip,
                      icon: const Icon(
                        Icons.star_rounded,
                        color: AppColors.ratingGold,
                        size: 18,
                      ),
                      label: const Text(
                        'Rating Submitted • View',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onRateTrip,
                      icon: const Icon(
                        Icons.star_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      label: const Text(
                        'Rate Trip',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ] else if (onReturn != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReturn,
                icon: const Icon(
                  Icons.assignment_return_rounded,
                  color: Colors.black,
                  size: 20,
                ),
                label: const Text(
                  'Return Vehicle',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (onNavigate != null)
                Expanded(
                  child: _buildCompactTripAction(
                    icon: Icons.navigation_rounded,
                    label: 'Navigate',
                    filled: false,
                    onPressed: onNavigate!,
                  ),
                ),
              if (onNavigate != null && onMessage != null)
                const SizedBox(width: 10),
              if (onMessage != null)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final isChatEligible =
                          BookingService().isEligibleForBookingChat(booking);
                      return _buildCompactTripAction(
                        icon: isChatEligible
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.lock_clock,
                        label: isChatEligible ? 'Message' : 'Chat (72h Prior)',
                        filled: false,
                        onPressed: onMessage!,
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTripAction({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
    );
    return SizedBox(
      height: 48,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: shape,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: shape,
              ),
              child: child,
            ),
    );
  }

  Widget _buildInlineAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildDangerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildRenterTripExtensionCard(BuildContext context) {
    final extStatus =
        booking['extension_status']?.toString().toLowerCase().trim() ?? 'pending';
    final requestedEndAt = DateTime.tryParse(
      booking['extension_requested_end_at']?.toString() ?? '',
    );
    final days = (booking['extension_days'] as num?)?.toInt() ?? 1;
    final additionalPrice =
        (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;
    final newDest =
        booking['extension_requested_destination']?.toString().trim();
    final payStatus =
        booking['extension_payment_status']?.toString().toLowerCase().trim() ??
        'unpaid';

    String statusText;
    Color statusColor;
    switch (extStatus) {
      case 'pending':
      case 'pending_operator':
      case 'pending_partner':
        statusText = 'Under Review';
        statusColor = Colors.amber;
        break;
      case 'accepted':
      case 'payment_pending':
        statusText = 'Accepted • Payment Due';
        statusColor = const Color(0xFF38BDF8);
        break;
      case 'payment_completed':
        statusText = 'Payment Submitted • Verifying';
        statusColor = Colors.purpleAccent;
        break;
      case 'pending_final_confirmation':
        statusText = 'Payment Verified • Confirming';
        statusColor = const Color(0xFF6366F1);
        break;
      case 'finalized':
      case 'approved':
        statusText = 'Extension Finalized';
        statusColor = Colors.greenAccent;
        break;
      case 'rejected':
      case 'cancelled':
        statusText = 'Extension Declined';
        statusColor = AppColors.error;
        break;
      default:
        statusText = extStatus.toUpperCase();
        statusColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.update_rounded, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Trip Extension Request',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow(
            Icons.event_repeat_rounded,
            'Requested Return Date',
            requestedEndAt != null
                ? '${requestedEndAt.year}-${requestedEndAt.month.toString().padLeft(2, '0')}-${requestedEndAt.day.toString().padLeft(2, '0')} (+$days days)'
                : 'N/A',
          ),
          if (newDest != null && newDest.isNotEmpty)
            _detailRow(Icons.flag_outlined, 'Requested Destination', newDest),
          _detailRow(
            Icons.payments_outlined,
            'Additional Extension Fee',
            '+PHP ${formatAmount(additionalPrice, decimalDigits: 0)}',
          ),
          if (extStatus == 'pending' ||
              extStatus == 'pending_partner' ||
              extStatus == 'pending_operator') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Extension request submitted! Waiting for the vehicle partner to review and accept.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (extStatus == 'accepted' || extStatus == 'payment_pending') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRenterExtensionPaymentModal(context),
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: Text(
                  'Pay Extension Fee (PHP ${formatAmount(additionalPrice, decimalDigits: 0)})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
          ] else if (extStatus == 'payment_completed') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.purpleAccent, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment receipt submitted! Waiting for partner to verify proof and confirm your dates.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (extStatus == 'pending_final_confirmation') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF818CF8), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment verified! Partner is performing final calendar confirmation.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (extStatus == 'finalized') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trip extension successfully confirmed! New return schedule and destinations are committed.',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (extStatus == 'rejected' || extStatus == 'cancelled') ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final reason = booking['extension_rejection_reason']?.toString() ?? 'Extension request declined.';
                final extPayStatus = booking['extension_payment_status']?.toString().toLowerCase().trim() ?? '';
                final extPayRef = booking['extension_payment_reference']?.toString().trim() ?? '';
                final hasPayment = (extPayStatus == 'paid' ||
                        extPayStatus == 'verified' ||
                        extPayStatus == 'pending_review') ||
                    (extPayRef.isNotEmpty && extPayRef != 'N/A');
                final refundStatus = booking['extension_refund_status']?.toString().toLowerCase().trim() ?? '';
                final isRefunded = refundStatus == 'refunded' || booking['extension_refund_completed'] == true;
                final refundAmount = (booking['extension_refund_amount'] as num?)?.toDouble() ??
                    (booking['extension_additional_price'] as num?)?.toDouble() ??
                    additionalPrice;
                final refundMethod = booking['extension_refund_method']?.toString() ?? 'Online';
                final refundRef = booking['extension_refund_ref']?.toString() ?? 'N/A';
                final refundReceipt = booking['extension_refund_receipt_url']?.toString();

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cancel_outlined, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your extension request was declined. Please return the vehicle according to your scheduled return time.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      if (isRefunded) ...[
                        const Divider(height: 16, color: Colors.white12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Extension Fee Refunded: PHP ${formatAmount(refundAmount, decimalDigits: 0)}',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Refund sent via $refundMethod • Ref: $refundRef',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                              if (refundReceipt != null && refundReceipt.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => Dialog(
                                        backgroundColor: Colors.black,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.network(refundReceipt),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'View Refund Transfer Receipt',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (hasPayment || booking['extension_refund_required'] == true) ...[
                        const Divider(height: 16, color: Colors.white12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.currency_exchange_rounded, color: Colors.amber, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Refund Initiated: PHP ${formatAmount(refundAmount, decimalDigits: 0)}',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'The vehicle partner has declined this extension. Your paid extension fee is being returned to your registered refund account/QR code.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3),
                              ),
                              if (extPayRef.isNotEmpty && extPayRef != 'N/A') ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Original Payment Ref: $extPayRef (${booking['extension_payment_method'] ?? 'Online'})',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRenterExtensionPaymentModal(BuildContext context) async {
    final bookingId = booking['id']?.toString() ?? '';
    final additionalPrice =
        (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;
    final referenceController = TextEditingController();
    String selectedMethod = 'GCash';
    XFile? pickedReceipt;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
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
                      const Text(
                        'Pay Trip Extension Fee',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'PHP ${formatAmount(additionalPrice, decimalDigits: 0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'PSDC Payment Accounts',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '• GCash: 0917-123-4567 (Mobilis PSDC Main)\n• Maya: 0917-123-4567\n• BDO Bank Transfer: 0012-3456-7890',
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
                    'Select Payment Method',
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
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (BDO/BPI)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedMethod = val);
                      }
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
                          Text(
                            pickedReceipt != null
                                ? 'Receipt Attached: ${pickedReceipt!.name}'
                                : 'Upload Payment Receipt Proof (Camera or Gallery)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: pickedReceipt != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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
                                    content: Text('Please enter a payment reference number.'),
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
                                    prefix: 'ext_payment',
                                  );
                                }

                                await BookingService().submitExtensionPayment(
                                  bookingId: bookingId,
                                  paymentMethod: selectedMethod,
                                  paymentReference: ref,
                                  proofUrl: proofUrl.isNotEmpty ? proofUrl : null,
                                );

                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Extension payment submitted successfully!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to submit payment: $e'),
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
                              'Submit Payment Proof',
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
}

class _CalendarLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const _CalendarLegendDot({
    required this.color,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }
}

class _LiveTripBadge extends StatelessWidget {
  const _LiveTripBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.45)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: AppColors.success, size: 7),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

Future<XFile?> _pickReceiptImageWithSource(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.darkBgSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload Payment Receipt',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text(
                'Take Photo (Camera)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Capture receipt or payment slip',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.textSecondary),
              title: const Text(
                'Choose from Gallery (Upload)',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Upload screenshot or saved image',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );

  if (source == null) return null;

  final picker = ImagePicker();
  return await picker.pickImage(
    source: source,
    imageQuality: 85,
  );
}

