import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../widgets/dialog_status_indicator.dart';
import '../../widgets/optimized_network_image.dart';
import '../../../services/auth_service.dart';
import '../../../services/mpin_service.dart';
import '../../../services/reservation_payment_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/web_html.dart' as html;

class ReservationPaymentScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> vehicleData;
  final double rentalTotal;
  final double rentalSubtotal;
  final double deliveryFee;
  final double discountAmount;
  final double reservationFeeAmount;
  final bool requiresLongBookingReservation;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? pickupLocation;
  final String? dropoffLocation;
  final bool withDriver;
  final double driverFee;

  const ReservationPaymentScreen({
    super.key,
    required this.userId,
    required this.vehicleData,
    required this.rentalTotal,
    required this.rentalSubtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.reservationFeeAmount,
    required this.requiresLongBookingReservation,
    this.startDate,
    this.endDate,
    this.pickupLocation,
    this.dropoffLocation,
    this.withDriver = false,
    this.driverFee = 0.0,
  });

  @override
  State<ReservationPaymentScreen> createState() =>
      _ReservationPaymentScreenState();
}

class _ReservationPaymentScreenState extends State<ReservationPaymentScreen> {
  final ReservationPaymentService _paymentService = ReservationPaymentService();
  bool _isLoadingSettings = true;
  ReservationPaymentSettings _settings = const ReservationPaymentSettings(
    amount: 1000.0,
    qrUrl: '',
    accountName: 'PSDC Mobilis',
    instructions: 'Scan QR and submit receipt proof.',
  );

  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _senderPhoneController = TextEditingController();
  List<String> _savedNumbers = [];
  String? _selectedSavedNumber;
  bool _isCustomNumber = false;
  XFile? _receiptFile;
  bool _isUploading = false;
  bool _payFullAmount = false;
  String _selectedPaymentChannel = 'qr'; // 'qr' or 'desk'
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _senderPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingSettings = true);
    try {
      final settings = await _paymentService.getSettings();
      final savedNumbers =
          await ReservationPaymentService.getSavedSenderNumbers(widget.userId);
      final user = AuthService().currentUser;
      final userProfilePhone =
          user?.phone?.trim() ??
          (user?.userMetadata?['phone']?.toString().trim() ?? '');
      final defaultPhone = savedNumbers.isNotEmpty
          ? savedNumbers.first
          : (userProfilePhone.isNotEmpty ? userProfilePhone : '');

      if (mounted) {
        setState(() {
          _settings = settings;
          _savedNumbers = savedNumbers;
          _selectedSavedNumber = savedNumbers.isNotEmpty ? savedNumbers.first : null;
          _isCustomNumber = savedNumbers.isEmpty;
          _senderPhoneController.text = defaultPhone;
          _isLoadingSettings = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reservation payment settings: $e');
      if (mounted) {
        setState(() => _isLoadingSettings = false);
      }
    }
  }

  Future<void> _pickReceipt() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _receiptFile = picked;
      _errorText = null;
    });
  }

  Future<void> _downloadReservationQr(String qrUrl) async {
    final cleanUrl = qrUrl.trim();
    if (cleanUrl.isEmpty) return;

    if (kIsWeb) {
      final anchor = html.AnchorElement(href: cleanUrl)
        ..target = '_blank'
        ..download = 'psdc-reservation-payment-qr';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      return;
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || !await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open QR download link'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmPayment() async {
    final senderPhone = (_isCustomNumber
            ? _senderPhoneController.text.trim()
            : (_selectedSavedNumber ?? _senderPhoneController.text.trim()))
        .trim();

    final isPartnerVehicle =
        widget.vehicleData['source']?.toString().toLowerCase() == 'partner' ||
        widget.vehicleData['is_partner_vehicle'] == true ||
        widget.vehicleData['partner_vehicle_id'] != null ||
        widget.vehicleData['partner_name'] != null;
    final partnerCommission =
        isPartnerVehicle ? widget.rentalTotal * 0.10 : 0.0;
    final principalRentalSubtotal = (widget.rentalSubtotal +
            widget.driverFee +
            widget.deliveryFee +
            partnerCommission -
            widget.discountAmount)
        .clamp(0.0, double.infinity);
    final seats = (widget.vehicleData['seats'] as num?)?.toInt() ?? 5;
    final securityDeposit = _settings.getDepositForSeats(seats);
    final reservationFee = widget.requiresLongBookingReservation
        ? widget.reservationFeeAmount
        : _settings.amount; // default ₱1,000
    final grandTotal = principalRentalSubtotal + securityDeposit;
    final payableAmount = _payFullAmount ? grandTotal : reservationFee;

    if (senderPhone.isEmpty) {
      setState(() {
        _errorText =
            'Please enter your mobile phone number for operator verification.';
      });
      return;
    }
    if (!RegExp(r'^\d{10,13}$').hasMatch(senderPhone) &&
        !RegExp(r'^(09|\+639)\d{9}$').hasMatch(senderPhone)) {
      setState(() {
        _errorText =
            'Please enter a valid Philippine mobile number (e.g. 09171234567).';
      });
      return;
    }

    // PSDC Desk / Over-the-counter payment (Requires Operator MPIN Authorization)
    if (_selectedPaymentChannel == 'desk') {
      await _handleDeskPaymentWithOperatorMpin(
        payableAmount: payableAmount,
        senderPhone: senderPhone,
        securityDeposit: securityDeposit,
        reservationFee: reservationFee,
      );
      return;
    }

    // Online QR Payment validation
    final reference = _referenceController.text.trim();
    if (_settings.qrUrl.trim().isEmpty) {
      setState(() {
        _errorText =
            'Payment QR is not configured yet. Please contact support or choose PSDC Desk payment.';
      });
      return;
    }
    if (!RegExp(r'^\d{6,13}$').hasMatch(reference)) {
      setState(() {
        _errorText = 'Enter a 6 to 13-digit transaction reference number.';
      });
      return;
    }
    if (_receiptFile == null) {
      setState(() {
        _errorText = 'Upload the payment screenshot / receipt first.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorText = null;
    });

    try {
      final receiptUpload = await _paymentService.uploadReceiptProof(
        userId: widget.userId,
        file: _receiptFile!,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        ReservationPaymentProof(
          amount: payableAmount,
          method: 'psdc_qr_payment',
          paymentType: _payFullAmount ? 'full_payment' : 'reservation_only',
          referenceNumber: reference,
          proofUrl: receiptUpload.publicUrl,
          proofStoragePath: receiptUpload.storagePath,
          senderPhone: senderPhone,
          securityDeposit: securityDeposit,
          reservationFee: _payFullAmount ? 0.0 : reservationFee,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorText = 'Could not upload receipt: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final vehicle = widget.vehicleData;
    final vehicleName =
        vehicle['vehicle_name']?.toString() ??
        '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
    final plateNumber = vehicle['plate_number']?.toString() ?? '';
    final imageUrl = vehicle['image_url']?.toString() ?? '';

    final isPartnerVehicle =
        vehicle['source']?.toString().toLowerCase() == 'partner' ||
        vehicle['is_partner_vehicle'] == true ||
        vehicle['partner_vehicle_id'] != null ||
        vehicle['partner_name'] != null;

    final partnerCommission =
        isPartnerVehicle ? widget.rentalTotal * 0.10 : 0.0;

    final principalRentalSubtotal = (widget.rentalSubtotal +
            widget.driverFee +
            widget.deliveryFee +
            partnerCommission -
            widget.discountAmount)
        .clamp(0.0, double.infinity);

    final seats = (vehicle['seats'] as num?)?.toInt() ?? 5;
    final securityDeposit = _settings.getDepositForSeats(seats);
    final reservationFee = widget.requiresLongBookingReservation
        ? widget.reservationFeeAmount
        : _settings.amount; // default ₱1,000

    // Grand total = Principal rental charges + Refundable security deposit
    final grandTotal = principalRentalSubtotal + securityDeposit;

    // Full Payment: Grand Total (Principal + Security Deposit; No Reservation Fee)
    // Reservation Only: Reservation Fee now to hold booking
    final payableAmount = _payFullAmount ? grandTotal : reservationFee;

    // Remaining balance due upon vehicle turnover
    final remainingBalance =
        _payFullAmount ? 0.0 : (grandTotal - reservationFee).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Reservation Payment & Checkout',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? Colors.white10 : Colors.black12,
            height: 1,
          ),
        ),
      ),
      body: _isLoadingSettings
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                    children: [
                      // VEHICLE & BOOKING SUMMARY CARD
                      _buildVehicleSummaryCard(
                        isDark: isDark,
                        vehicleName: vehicleName.isNotEmpty ? vehicleName : 'Mobilis Vehicle',
                        plateNumber: plateNumber,
                        imageUrl: imageUrl,
                        isPartnerVehicle: isPartnerVehicle,
                      ),
                      const SizedBox(height: 16),

                      // PAYMENT CHANNEL SELECTOR (Online via QR vs PSDC Desk)
                      _buildChannelSelector(isDark),
                      const SizedBox(height: 16),

                      // FULL AMOUNT TOGGLE (placed ABOVE the breakdown)
                      _buildFullAmountSwitchCard(isDark),
                      const SizedBox(height: 16),

                      // COMPUTATION & TOTAL BREAKDOWN CARD
                      _buildBreakdownCard(
                        isDark: isDark,
                        isPartnerVehicle: isPartnerVehicle,
                        partnerCommission: partnerCommission,
                        principalRentalSubtotal: principalRentalSubtotal,
                        securityDeposit: securityDeposit,
                        reservationFee: reservationFee,
                        grandTotal: grandTotal,
                        payableAmount: payableAmount,
                        remainingBalance: remainingBalance,
                      ),
                      const SizedBox(height: 16),

                      // CHANNEL SPECIFIC INSTRUCTIONS & INPUTS
                      if (_selectedPaymentChannel == 'desk')
                        _buildDeskCounterCard(isDark)
                      else
                        _buildQrPaymentSection(isDark),

                      const SizedBox(height: 16),

                      // CONTACT / VERIFICATION MOBILE PHONE INPUT
                      _buildMobileVerificationCard(isDark),

                      if (_selectedPaymentChannel == 'qr') ...[
                        const SizedBox(height: 16),
                        _buildReferenceAndProofCard(isDark),
                      ],

                      if (_errorText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorText!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 100), // Spacing for bottom bar
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _isLoadingSettings
          ? null
          : _buildStickyBottomBar(
              isDark: isDark,
              payableAmount: payableAmount,
            ),
    );
  }

  Widget _buildVehicleSummaryCard({
    required bool isDark,
    required String vehicleName,
    required String plateNumber,
    required String imageUrl,
    required bool isPartnerVehicle,
  }) {
    final dateFormat = DateFormat('MMM dd, yyyy • h:mm a');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? OptimizedNetworkImage(
                        imageUrl: imageUrl,
                        width: 72,
                        height: 52,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          width: 72,
                          height: 52,
                          color: AppColors.primary.withValues(alpha: 0.15),
                          child: const Icon(Icons.directions_car, color: AppColors.primary),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 52,
                        color: AppColors.primary.withValues(alpha: 0.15),
                        child: const Icon(Icons.directions_car, color: AppColors.primary),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleName,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (plateNumber.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              plateNumber,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (isPartnerVehicle)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Partner Fleet',
                              style: TextStyle(
                                color: Color(0xFF3B82F6),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.startDate != null && widget.endDate != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Icon(Icons.event_available_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${dateFormat.format(widget.startDate!)} → ${dateFormat.format(widget.endDate!)}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isUploading
                  ? null
                  : () {
                      setState(() {
                        _selectedPaymentChannel = 'qr';
                        _errorText = null;
                      });
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedPaymentChannel == 'qr'
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedPaymentChannel == 'qr'
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 18,
                      color: _selectedPaymentChannel == 'qr'
                          ? Colors.black
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Online via QR',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _selectedPaymentChannel == 'qr'
                            ? Colors.black
                            : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isUploading
                  ? null
                  : () {
                      setState(() {
                        _selectedPaymentChannel = 'desk';
                        _errorText = null;
                      });
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedPaymentChannel == 'desk'
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedPaymentChannel == 'desk'
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 18,
                      color: _selectedPaymentChannel == 'desk'
                          ? Colors.black
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PSDC Desk Counter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _selectedPaymentChannel == 'desk'
                            ? Colors.black
                            : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard({
    required bool isDark,
    required bool isPartnerVehicle,
    required double partnerCommission,
    required double principalRentalSubtotal,
    required double securityDeposit,
    required double reservationFee,
    required double grandTotal,
    required double payableAmount,
    required double remainingBalance,
  }) {
    final vehicle = widget.vehicleData;

    final isHourly = vehicle['pricing_type']?.toString().toLowerCase() == 'hourly' ||
        (vehicle['hourly_rate'] != null && widget.rentalSubtotal < (vehicle['daily_rate'] ?? 99999));

    final dailyRate = ((vehicle['price_per_day'] ??
            vehicle['daily_rate'] ??
            vehicle['rental_rate'] ??
            0) as num)
        .toDouble();
    final hourlyRate = ((vehicle['hourly_rate'] ??
            vehicle['price_per_hour'] ??
            0) as num)
        .toDouble();
    final unitRate = isHourly
        ? (hourlyRate > 0 ? hourlyRate : (dailyRate > 0 ? dailyRate / 24 : widget.rentalSubtotal))
        : (dailyRate > 0 ? dailyRate : widget.rentalSubtotal);

    final duration = (widget.startDate != null && widget.endDate != null)
        ? widget.endDate!.difference(widget.startDate!)
        : null;
    final durationDays = duration != null
        ? (duration.inHours / 24).ceil().clamp(1, 999)
        : 1;
    final durationHours = duration != null ? duration.inHours.clamp(1, 9999) : 1;
    final durationText = isHourly
        ? '$durationHours ${durationHours == 1 ? 'Hour' : 'Hours'}'
        : '$durationDays ${durationDays == 1 ? 'Day' : 'Days'}';
    final rateLabel = isHourly
        ? 'PHP ${formatAmount(unitRate, decimalDigits: 0)} / hour'
        : 'PHP ${formatAmount(unitRate, decimalDigits: 0)} / day';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Computation & Payment Breakdown',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Unit Rate & Duration Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Unit Rental Rate:',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      rateLabel,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Booking Duration:',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      durationText,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (widget.startDate != null && widget.endDate != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${DateFormat('MMM dd, yyyy').format(widget.startDate!)} → ${DateFormat('MMM dd, yyyy').format(widget.endDate!)}',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Computation details: Principal Rental Charges
          _buildBreakdownRow(
            'Base unit rental ($rateLabel × $durationText)',
            widget.rentalSubtotal,
            isDark: isDark,
          ),
          if (widget.withDriver && widget.driverFee > 0) ...[
            const SizedBox(height: 8),
            _buildBreakdownRow(
              'PSDC Driver Fee (PHP 1,500/day × $durationDays Day${durationDays > 1 ? 's' : ''})',
              widget.driverFee,
              isDark: isDark,
            ),
          ],
          if (widget.deliveryFee > 0) ...[
            const SizedBox(height: 8),
            _buildBreakdownRow('Delivery fee', widget.deliveryFee, isDark: isDark),
          ],
          if (widget.discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildBreakdownRow('Voucher / Loyalty discount', widget.discountAmount, isDark: isDark, isDiscount: true),
          ],
          if (isPartnerVehicle && partnerCommission > 0) ...[
            const SizedBox(height: 8),
            _buildBreakdownRow('Partner commission (10%)', partnerCommission, isDark: isDark),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _buildBreakdownRow(
            'Principal Rental Subtotal (PSDC Collected)',
            principalRentalSubtotal,
            isDark: isDark,
            isBold: true,
          ),
          const SizedBox(height: 12),

          // Security Deposit Card (Refundable)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
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
                        const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 6),
                        Text(
                          'Security Deposit (${((widget.vehicleData['seats'] as num?)?.toInt() ?? 5) >= 6 ? '6+ Seater' : '4–5 Seater'})',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'PHP ${formatAmount(securityDeposit, decimalDigits: 0)}',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '• Added to total rental price\n• 100% Refundable upon vehicle return with no damages/violations',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildBreakdownRow(
            'Grand Total (Principal Rent + Security Deposit)',
            grandTotal,
            isDark: isDark,
            isBold: true,
          ),
          const SizedBox(height: 12),

          // Reservation Fee Section (If paying reservation only) or Full Payment Info
          if (!_payFullAmount) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bookmark_added_rounded, size: 16, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 6),
                          Text(
                            widget.requiresLongBookingReservation
                                ? 'Reservation Fee (20% to hold booking)'
                                : 'Reservation Fee (To hold booking)',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'PHP ${formatAmount(reservationFee, decimalDigits: 0)}',
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Deducted from Grand Total to secure your booking request\n• Remaining principal rental & security deposit will be settled upon vehicle turnover',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Full Payment Mode: Paying Principal Rent + Refundable Security Deposit upfront (No reservation fee required).',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF065F46),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Payable Now Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _payFullAmount
                            ? 'Payable Now (Full Rent + Deposit)'
                            : widget.requiresLongBookingReservation
                                ? 'Payable Now (20% Reservation Fee)'
                                : 'Payable Now (Reservation Fee Only)',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedPaymentChannel == 'qr' ? 'via Official QR Code' : 'at PSDC Desk Counter',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'PHP ${formatAmount(payableAmount, decimalDigits: 0)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
          ),
          if (!_payFullAmount && remainingBalance > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remaining balance (Due upon vehicle pickup):',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '(Covers remaining rental + ₱${formatAmount(securityDeposit, decimalDigits: 0)} refundable deposit)',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'PHP ${formatAmount(remainingBalance, decimalDigits: 0)}',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    double amount, {
    required bool isDark,
    bool isBold = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          '${isDiscount ? '-' : ''}PHP ${formatAmount(amount, decimalDigits: 0)}',
          style: TextStyle(
            color: isDiscount
                ? const Color(0xFF10B981)
                : (isBold
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white70 : const Color(0xFF475569))),
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFullAmountSwitchCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay full rental amount now',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _payFullAmount
                      ? 'Paying principal rent + refundable security deposit upfront. No reservation fee.'
                      : 'Pay reservation fee now to hold vehicle. Remaining rent balance + security deposit payable upon pickup.',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _payFullAmount,
            activeColor: AppColors.primary,
            onChanged: _isUploading
                ? null
                : (value) {
                    setState(() {
                      _payFullAmount = value;
                      _errorText = null;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildDeskCounterCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5A93C).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.storefront_rounded,
            color: Color(0xFFE5A93C),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Over-the-Counter Settlement',
                  style: TextStyle(
                    color: Color(0xFFE5A93C),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Settle your payment in Cash or POS at the PSDC branch cashier desk upon vehicle inspection and handover. The operator will enter their 6-digit MPIN upon payment confirmation to instantly authorize and approve your payment.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeskPaymentWithOperatorMpin({
    required double payableAmount,
    required String senderPhone,
    required double securityDeposit,
    required double reservationFee,
  }) async {
    final mpinController = TextEditingController();
    bool isVerifying = false;
    String? dialogError;
    bool isApproved = false;
    String? approvedOperatorName;

    final authorized = await showDialog<MpinVerificationResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            if (isApproved) {
              return AlertDialog(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment Approved & Verified',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Authorized by ${approvedOperatorName ?? 'PSDC Desk Operator'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total: PHP ${formatAmount(payableAmount, decimalDigits: 0)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFFE5A93C),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PSDC Desk Authorization',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Operator MPIN required to confirm',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
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
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Amount to Settle:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                'PHP ${formatAmount(payableAmount, decimalDigits: 0)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Settlement Type:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                _payFullAmount ? 'Full Rental Payment' : 'Reservation Deposit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please have the PSDC Cashier / Desk Operator enter their 6-digit MPIN:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: mpinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      autofocus: true,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: 10,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '••••••',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black26,
                          letterSpacing: 10,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final pin = mpinController.text.trim();
                          if (pin.length != 6) {
                            setDialogState(() {
                              dialogError = 'Please enter a 6-digit MPIN.';
                            });
                            return;
                          }
                          setDialogState(() {
                            isVerifying = true;
                            dialogError = null;
                          });

                          final vehicleTitle = widget.vehicleData['vehicle_name']?.toString() ??
                              '${widget.vehicleData['brand'] ?? ''} ${widget.vehicleData['model'] ?? ''}'.trim();
                          final vehicleId = widget.vehicleData['id']?.toString();

                          final result = await MpinService().verifyOperatorMpin(
                            pin,
                            amount: payableAmount,
                            contextDescription: 'Desk counter settlement for $vehicleTitle (User: ${widget.userId})',
                            bookingId: vehicleId,
                          );
                          if (!result.success) {
                            setDialogState(() {
                              isVerifying = false;
                              dialogError = result.errorMessage ?? 'Invalid Operator MPIN.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isVerifying = false;
                            isApproved = true;
                            approvedOperatorName = result.operatorName;
                          });

                          await Future.delayed(const Duration(milliseconds: 900));
                          if (context.mounted) {
                            Navigator.pop(dialogContext, result);
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Authorize Settlement',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    if (authorized == null || !authorized.success || !mounted) return;

    final operatorName = authorized.operatorName ?? 'Desk Operator';
    final operatorId = authorized.operatorId ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PSDC Desk settlement authorized by $operatorName.'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );

    Navigator.pop(
      context,
      ReservationPaymentProof(
        amount: payableAmount,
        method: 'psdc_desk_counter',
        paymentType: _payFullAmount ? 'full_payment' : 'reservation_only',
        referenceNumber: 'DESK_${operatorName.replaceAll(' ', '_').toUpperCase()}${operatorId.isNotEmpty ? "_${operatorId.substring(0, operatorId.length > 6 ? 6 : operatorId.length).toUpperCase()}" : ""}',
        proofUrl: '',
        proofStoragePath: null,
        senderPhone: senderPhone,
        securityDeposit: securityDeposit,
        reservationFee: _payFullAmount ? 0.0 : reservationFee,
      ),
    );
  }

  Widget _buildQrPaymentSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Official PSDC Payment QR',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _settings.instructions.isNotEmpty
                ? _settings.instructions
                : 'Scan or screenshot this QR code using GCash, Maya, or any InstaPay banking app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (_settings.qrUrl.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: const Column(
                children: [
                  Icon(Icons.qr_code_2, color: Colors.grey, size: 80),
                  SizedBox(height: 8),
                  Text(
                    'Payment QR is not configured yet.\nPlease select PSDC Desk Payment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: OptimizedNetworkImage(
                      imageUrl: _settings.qrUrl,
                      height: 230,
                      fit: BoxFit.contain,
                      isThumbnail: false,
                      errorWidget: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.error,
                        size: 72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _settings.accountName.isNotEmpty ? _settings.accountName : 'PSDC Mobilis Account',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          if (_settings.qrUrl.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _isUploading
                  ? null
                  : () => _downloadReservationQr(_settings.qrUrl),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download QR Image'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileVerificationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Renter Contact / Verification Phone',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Used by operator to verify payment and coordinate handover',
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          if (_savedNumbers.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: _isCustomNumber ? 'other' : _selectedSavedNumber,
              dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                ..._savedNumbers.map(
                  (phoneItem) => DropdownMenuItem(
                    value: phoneItem,
                    child: Text('📱 $phoneItem (Saved Phone)'),
                  ),
                ),
                const DropdownMenuItem(
                  value: 'other',
                  child: Text('➕ Use a different number'),
                ),
              ],
              onChanged: _isUploading
                  ? null
                  : (val) {
                      setState(() {
                        if (val == 'other') {
                          _isCustomNumber = true;
                          _selectedSavedNumber = null;
                        } else {
                          _isCustomNumber = false;
                          _selectedSavedNumber = val;
                          if (val != null) {
                            _senderPhoneController.text = val;
                          }
                        }
                        _errorText = null;
                      });
                    },
            ),
            if (_isCustomNumber) const SizedBox(height: 10),
          ],
          if (_isCustomNumber || _savedNumbers.isEmpty)
            TextField(
              controller: _senderPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: 13,
              enabled: !_isUploading,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'e.g. 09171234567',
                counterText: '',
                prefixIcon: const Icon(Icons.phone, color: AppColors.primary, size: 18),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReferenceAndProofCard(bool isDark) {
    final hasValidRef = RegExp(r'^\d{6,13}$').hasMatch(_referenceController.text.trim());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attachment_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transaction Reference & Receipt',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _referenceController,
            keyboardType: TextInputType.number,
            maxLength: 13,
            enabled: !_isUploading,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Transaction Reference Number (6 to 13 digits)',
              hintText: 'e.g. 1002345678',
              counterText: '',
              labelStyle: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                fontSize: 12,
              ),
              prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primary, size: 18),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isUploading ? null : _pickReceipt,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _receiptFile != null
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _receiptFile != null
                      ? const Color(0xFF10B981)
                      : AppColors.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _receiptFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                    color: _receiptFile != null ? const Color(0xFF10B981) : AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _receiptFile == null
                          ? 'Upload Payment Screenshot / Receipt'
                          : 'Receipt Attached: ${_receiptFile!.name}',
                      style: TextStyle(
                        color: _receiptFile != null ? const Color(0xFF10B981) : AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DialogStatusIndicator(
            compact: true,
            isComplete: _settings.qrUrl.trim().isNotEmpty && _receiptFile != null && hasValidRef,
            completeLabel: 'Payment proof ready for submission',
            incompleteLabel: 'Payment proof incomplete',
            completeDetail: 'QR setup, receipt attachment, and valid reference number are all set.',
            incompleteDetail: 'Please ensure both the receipt is uploaded and a 6-13 digit reference is entered.',
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar({
    required bool isDark,
    required double payableAmount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payable Now',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'PHP ${formatAmount(payableAmount, decimalDigits: 0)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _confirmPayment,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isUploading
                        ? 'Uploading Proof...'
                        : _selectedPaymentChannel == 'desk'
                            ? 'Confirm PSDC Desk Payment'
                            : 'Submit Payment Proof',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
