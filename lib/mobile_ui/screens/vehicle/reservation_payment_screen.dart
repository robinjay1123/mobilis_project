import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../widgets/dialog_status_indicator.dart';
import '../../widgets/optimized_network_image.dart';
import '../profile/legal_terms_privacy_screen.dart';
import '../../../services/auth_service.dart';
import '../../../services/mpin_service.dart';
import '../../../services/reservation_payment_service.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/pricing_policy.dart';
import '../../../utils/web_html.dart' as html;

enum PaymentPurpose {
  initialBooking,
  releaseSettlement,
  lateReturnPenalty,
}

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
  final PaymentPurpose paymentPurpose;
  final double? paidReservationFee;
  final double? lateFeeAmount;
  final int? lateHours;
  final DateTime? returnTimestamp;
  final String? bookingId;

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
    this.paymentPurpose = PaymentPurpose.initialBooking,
    this.paidReservationFee,
    this.lateFeeAmount,
    this.lateHours,
    this.returnTimestamp,
    this.bookingId,
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
  final TextEditingController _deskMpinController = TextEditingController();
  List<String> _savedNumbers = [];
  String? _selectedSavedNumber;
  bool _isCustomNumber = false;
  XFile? _receiptFile;
  bool _isUploading = false;
  bool _payFullAmount = false;
  String _selectedPaymentChannel = 'qr'; // 'qr' or 'desk'
  String? _errorText;

  bool _isDeskMpinVerifying = false;
  bool _isDeskMpinApproved = false;
  String? _deskApprovedOperatorName;
  String? _deskApprovedOperatorId;
  int _deskMpinFailedAttempts = 0;
  bool _isDeskPaymentLocked = false;
  String? _deskMpinError;

  @override
  void initState() {
    super.initState();
    if (widget.paymentPurpose == PaymentPurpose.releaseSettlement ||
        widget.paymentPurpose == PaymentPurpose.lateReturnPenalty) {
      _payFullAmount = true;
    }
    _loadInitialData();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _senderPhoneController.dispose();
    _deskMpinController.dispose();
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

  Future<void> _verifyDeskMpin() async {
    if (_isDeskPaymentLocked) return;
    final pin = _deskMpinController.text.trim();
    if (pin.length != 6) {
      setState(() {
        _deskMpinError = 'Please enter a 6-digit Operator MPIN.';
      });
      return;
    }

    setState(() {
      _isDeskMpinVerifying = true;
      _deskMpinError = null;
    });

    final isPartnerVehicle =
        widget.vehicleData['source']?.toString().toLowerCase() == 'partner' ||
        widget.vehicleData['is_partner_vehicle'] == true ||
        widget.vehicleData['partner_vehicle_id'] != null ||
        widget.vehicleData['partner_name'] != null;
    final partnerCommission =
        isPartnerVehicle ? widget.rentalTotal * 0.05 : 0.0;
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
        : _settings.amount;
    final grandTotal = principalRentalSubtotal + securityDeposit;
    final payableAmount = _payFullAmount ? grandTotal : reservationFee;

    final vehicleTitle = widget.vehicleData['vehicle_name']?.toString() ??
        '${widget.vehicleData['brand'] ?? ''} ${widget.vehicleData['model'] ?? ''}'.trim();
    final vehicleId = widget.vehicleData['id']?.toString();

    final result = await MpinService().verifyOperatorMpin(
      pin,
      amount: payableAmount,
      contextDescription:
          'Desk counter settlement for $vehicleTitle (User: ${widget.userId})',
      bookingId: vehicleId,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isDeskMpinVerifying = false;
        _isDeskMpinApproved = true;
        _deskApprovedOperatorName = result.operatorName ?? 'PSDC Desk Operator';
        _deskApprovedOperatorId = result.operatorId;
        _deskMpinError = null;
        _errorText = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'MPIN accepted! Authorized by ${_deskApprovedOperatorName ?? 'Operator'}. You can now confirm payment.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      _deskMpinFailedAttempts++;
      if (_deskMpinFailedAttempts >= 3) {
        setState(() {
          _isDeskMpinVerifying = false;
          _isDeskPaymentLocked = true;
          _selectedPaymentChannel = 'qr';
          _isDeskMpinApproved = false;
          _deskApprovedOperatorName = null;
          _deskApprovedOperatorId = null;
          _deskMpinController.clear();
          _deskMpinError = null;
          _errorText =
              'PSDC Desk Payment is now unavailable after 3 failed MPIN attempts. Please proceed with Online QR Payment.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PSDC Desk Payment is unavailable due to 3 failed MPIN attempts. Switching to Online QR Payment.',
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        final remaining = 3 - _deskMpinFailedAttempts;
        setState(() {
          _isDeskMpinVerifying = false;
          _deskMpinError =
              '${result.errorMessage ?? 'Invalid Operator MPIN.'} ($remaining attempt${remaining == 1 ? '' : 's'} remaining)';
        });
      }
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
        isPartnerVehicle ? widget.rentalTotal * 0.05 : 0.0;
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
    final resFeePaid = widget.paidReservationFee ?? reservationFee;

    final dailyRate = (widget.vehicleData['price_per_day'] as num?)?.toDouble() ??
        (widget.vehicleData['daily_rate'] as num?)?.toDouble() ??
        widget.rentalTotal;
    final lateHours = widget.lateHours ?? 1;
    final lateFee = widget.lateFeeAmount ??
        _settings.calculateLateFee(
          seats: seats,
          lateHours: lateHours,
          dailyRate: dailyRate,
        );

    double payableAmount;
    String paymentType;

    if (widget.paymentPurpose == PaymentPurpose.lateReturnPenalty) {
      payableAmount = lateFee;
      paymentType = 'late_return_penalty';
    } else if (widget.paymentPurpose == PaymentPurpose.releaseSettlement) {
      payableAmount = (grandTotal - resFeePaid).clamp(0.0, double.infinity);
      paymentType = 'release_settlement';
    } else {
      payableAmount = _payFullAmount ? grandTotal : reservationFee;
      paymentType = _payFullAmount ? 'full_payment' : 'reservation_only';
    }

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

    // PSDC Desk / Over-the-counter payment (Requires Operator MPIN Authorization & Evidence)
    if (_selectedPaymentChannel == 'desk') {
      if (_isDeskPaymentLocked) {
        setState(() {
          _errorText =
              'PSDC Desk payment is unavailable. Please choose Online QR payment.';
        });
        return;
      }
      if (!_isDeskMpinApproved) {
        setState(() {
          _deskMpinError =
              'Please have the operator enter and authorize their 6-digit MPIN first.';
        });
        return;
      }
      if (_receiptFile == null) {
        setState(() {
          _errorText =
              'Please upload receipt / settlement evidence photo before confirming.';
        });
        return;
      }

      final opName = _deskApprovedOperatorName ?? 'PSDC Desk Operator';
      final refNum = 'DESK-${opName.replaceAll(' ', '').toUpperCase()}';
      final noteDesc =
          'The payment has been paid in desk (Authorized by $opName)';

      setState(() {
        _isUploading = true;
        _errorText = null;
      });

      String proofUrl = 'desk_payment_authorized';
      String? proofStoragePath;

      try {
        if (_receiptFile != null) {
          final receiptUpload = await _paymentService.uploadReceiptProof(
            userId: widget.userId,
            file: _receiptFile!,
          );
          proofUrl = receiptUpload.publicUrl;
          proofStoragePath = receiptUpload.storagePath;
        }
      } catch (e) {
        debugPrint('Receipt upload warning during desk payment: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment authorized and receipt attached at PSDC Desk by $opName.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      Navigator.pop(
        context,
        ReservationPaymentProof(
          amount: payableAmount,
          method: 'psdc_desk_counter',
          paymentType: paymentType,
          referenceNumber: refNum,
          proofUrl: proofUrl,
          proofStoragePath: proofStoragePath,
          senderPhone: senderPhone,
          securityDeposit: securityDeposit,
          reservationFee: (widget.paymentPurpose == PaymentPurpose.initialBooking && !_payFullAmount)
              ? reservationFee
              : 0.0,
          operatorName: opName,
          operatorId: _deskApprovedOperatorId,
          notes: noteDesc,
        ),
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
          paymentType: paymentType,
          referenceNumber: reference,
          proofUrl: receiptUpload.publicUrl,
          proofStoragePath: receiptUpload.storagePath,
          senderPhone: senderPhone,
          securityDeposit: securityDeposit,
          reservationFee: (widget.paymentPurpose == PaymentPurpose.initialBooking && !_payFullAmount)
              ? reservationFee
              : 0.0,
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
        isPartnerVehicle ? widget.rentalTotal * 0.05 : 0.0;

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

    final dailyRate = (vehicle['price_per_day'] as num?)?.toDouble() ??
        (vehicle['daily_rate'] as num?)?.toDouble() ??
        widget.rentalTotal;

    final lateHours = widget.lateHours ?? 1;
    final lateFee = widget.lateFeeAmount ??
        _settings.calculateLateFee(
          seats: seats,
          lateHours: lateHours,
          dailyRate: dailyRate,
        );

    final resFeePaid = widget.paidReservationFee ?? reservationFee;

    // Grand total = Principal rental charges + Refundable security deposit
    final grandTotal = principalRentalSubtotal + securityDeposit;

    final isReleaseSettlement = widget.paymentPurpose == PaymentPurpose.releaseSettlement;
    final isLatePenalty = widget.paymentPurpose == PaymentPurpose.lateReturnPenalty;

    double payableAmount;
    double remainingBalance = 0.0;

    if (isLatePenalty) {
      payableAmount = lateFee;
      remainingBalance = 0.0;
    } else if (isReleaseSettlement) {
      payableAmount = (grandTotal - resFeePaid).clamp(0.0, double.infinity);
      remainingBalance = 0.0;
    } else {
      payableAmount = _payFullAmount ? grandTotal : reservationFee;
      remainingBalance = _payFullAmount ? 0.0 : (grandTotal - reservationFee).clamp(0.0, double.infinity);
    }

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
          isLatePenalty
              ? 'Late Return Settlement'
              : (isReleaseSettlement
                  ? 'Trip Balance Settlement'
                  : 'Reservation Payment & Checkout'),
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
                      if (isLatePenalty) ...[
                        _buildLateReturnInfographicCard(isDark, seats, dailyRate),
                        const SizedBox(height: 16),
                      ],

                      // VEHICLE & BOOKING SUMMARY CARD
                      _buildVehicleSummaryCard(
                        isDark: isDark,
                        vehicleName: vehicleName.isNotEmpty ? vehicleName : 'Mobilis Vehicle',
                        plateNumber: plateNumber,
                        imageUrl: imageUrl,
                        isPartnerVehicle: isPartnerVehicle,
                      ),
                      const SizedBox(height: 16),

                      if (isReleaseSettlement) ...[
                        _buildPreReleaseNoticeCard(isDark),
                        const SizedBox(height: 16),
                      ],

                      // PAYMENT CHANNEL SELECTOR (Online via QR vs PSDC Desk)
                      _buildChannelSelector(isDark),
                      const SizedBox(height: 16),

                      if (!isReleaseSettlement && !isLatePenalty) ...[
                        // FULL AMOUNT TOGGLE (placed ABOVE the breakdown)
                        _buildFullAmountSwitchCard(isDark),
                        const SizedBox(height: 16),
                      ],

                      // COMPUTATION & TOTAL BREAKDOWN CARD
                      if (isLatePenalty)
                        _buildLatePenaltyBreakdownCard(
                          isDark: isDark,
                          lateHours: lateHours,
                          seats: seats,
                          dailyRate: dailyRate,
                          lateFeeAmount: lateFee,
                        )
                      else if (isReleaseSettlement)
                        _buildReleaseSettlementBreakdownCard(
                          isDark: isDark,
                          principalRentalSubtotal: principalRentalSubtotal,
                          securityDeposit: securityDeposit,
                          reservationFeePaid: resFeePaid,
                          remainingBalance: payableAmount,
                        )
                      else
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
                      if (_isDeskPaymentLocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'PSDC Desk payment is locked after 3 failed MPIN attempts. Please proceed with Online QR payment.',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _selectedPaymentChannel = 'desk';
                        _errorText = null;
                      });
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedPaymentChannel == 'desk'
                      ? (_isDeskPaymentLocked ? AppColors.error.withValues(alpha: 0.15) : AppColors.primary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: (_selectedPaymentChannel == 'desk' && !_isDeskPaymentLocked)
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
                      _isDeskPaymentLocked
                          ? Icons.lock_outline_rounded
                          : Icons.storefront_rounded,
                      size: 18,
                      color: _isDeskPaymentLocked
                          ? AppColors.error
                          : (_selectedPaymentChannel == 'desk'
                              ? Colors.black
                              : (isDark ? Colors.white70 : const Color(0xFF475569))),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isDeskPaymentLocked ? 'Desk (Locked)' : 'PSDC Desk Counter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isDeskPaymentLocked
                            ? AppColors.error
                            : (_selectedPaymentChannel == 'desk'
                                ? Colors.black
                                : (isDark ? Colors.white70 : const Color(0xFF475569))),
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
        (widget.startDate != null &&
            widget.endDate != null &&
            widget.endDate!.difference(widget.startDate!).inHours < 24 &&
            widget.rentalSubtotal <
                (((vehicle['price_per_day'] ?? vehicle['daily_rate'] ?? 0) as num).toDouble() > 0
                    ? ((vehicle['price_per_day'] ?? vehicle['daily_rate'] ?? 0) as num).toDouble()
                    : 99999));

    final dailyRate = ((vehicle['price_per_day'] ??
            vehicle['daily_rate'] ??
            vehicle['rental_rate'] ??
            0) as num)
        .toDouble();
    final hourlyRate = ((vehicle['hourly_rate'] ??
            vehicle['price_per_hour'] ??
            0) as num)
        .toDouble();

    final duration = (widget.startDate != null && widget.endDate != null)
        ? widget.endDate!.difference(widget.startDate!)
        : null;
    final durationDays = duration != null
        ? (duration.inHours / 24).ceil().clamp(1, 999)
        : 1;
    final rawHours = duration != null ? duration.inHours.clamp(1, 9999) : 1;
    final billableHours = isHourly
        ? (rawHours < PricingPolicy.minHourlyBookingHours
            ? PricingPolicy.minHourlyBookingHours
            : rawHours)
        : rawHours;
    final excessHours =
        isHourly && billableHours > PricingPolicy.minHourlyBookingHours
            ? billableHours - PricingPolicy.minHourlyBookingHours
            : 0;

    final halfDayPrice = dailyRate > 0
        ? dailyRate / 2.0
        : (hourlyRate * PricingPolicy.minHourlyBookingHours);
    final effectiveHourlyRate =
        hourlyRate > 0 ? hourlyRate : (dailyRate > 0 ? dailyRate / 24.0 : 0.0);

    final durationText = isHourly
        ? (rawHours <= PricingPolicy.minHourlyBookingHours
            ? '$rawHours hrs (Min. 12 hrs applied)'
            : '$rawHours hrs (12 hrs + $excessHours excess hrs)')
        : '$durationDays ${durationDays == 1 ? 'Day' : 'Days'}';

    final rateLabel = isHourly
        ? '12 hrs: ₱${formatAmount(halfDayPrice, decimalDigits: 0)} (Half-day) + ₱${formatAmount(effectiveHourlyRate, decimalDigits: 0)}/hr'
        : 'PHP ${formatAmount(dailyRate > 0 ? dailyRate : widget.rentalSubtotal, decimalDigits: 0)} / day';

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
            isHourly
                ? 'Base unit rental ($durationText)'
                : 'Base unit rental ($rateLabel × $durationText)',
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
                        _selectedPaymentChannel == 'qr'
                            ? 'via Official QR Code'
                            : (_isDeskMpinApproved
                                ? 'The payment has been paid in desk (Authorized by ${_deskApprovedOperatorName ?? 'PSDC Desk Operator'})'
                                : 'at PSDC Desk Counter (Requires Operator MPIN)'),
                        style: TextStyle(
                          color: _selectedPaymentChannel == 'desk' && _isDeskMpinApproved
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                          fontWeight: _selectedPaymentChannel == 'desk' && _isDeskMpinApproved
                              ? FontWeight.w700
                              : FontWeight.w500,
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
    if (_isDeskPaymentLocked) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.4),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_clock_rounded,
              color: AppColors.error,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PSDC Desk Payment Unavailable',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'This payment channel was locked due to 3 failed operator MPIN attempts. Please select Online (QR) payment to proceed.',
                    style: TextStyle(
                      color: AppColors.error,
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

    if (_isDeskMpinApproved) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operator MPIN Verified & Accepted',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Authorized by: ${_deskApprovedOperatorName ?? 'PSDC Desk Operator'}',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _receiptFile != null
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE5A93C).withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _receiptFile != null
                            ? Icons.check_circle_rounded
                            : Icons.add_a_photo_outlined,
                        color: _receiptFile != null
                            ? const Color(0xFF10B981)
                            : const Color(0xFFE5A93C),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _receiptFile != null
                            ? 'Evidence / Receipt Attached'
                            : 'Upload Proof / Receipt Evidence (Required)',
                        style: TextStyle(
                          color: _receiptFile != null
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _receiptFile != null
                        ? 'Attachment: ${_receiptFile!.name}'
                        : 'Please attach a photo of the desk receipt or transaction document to enable payment confirmation.',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickReceipt,
                      icon: Icon(
                        _receiptFile != null
                            ? Icons.change_circle_outlined
                            : Icons.upload_file_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _receiptFile != null
                            ? 'Change Attached Receipt'
                            : 'Attach Receipt / Evidence Photo',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _receiptFile != null
                            ? const Color(0xFF10B981)
                            : AppColors.primary,
                        side: BorderSide(
                          color: _receiptFile != null
                              ? const Color(0xFF10B981)
                              : AppColors.primary,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isDeskMpinApproved = false;
                    _deskApprovedOperatorName = null;
                    _deskApprovedOperatorId = null;
                    _deskMpinController.clear();
                    _deskMpinError = null;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Change MPIN', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5A93C).withValues(alpha: 0.5),
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
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
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
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Operator 6-Digit MPIN Required',
                      style: TextStyle(
                        color: Color(0xFFE5A93C),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Please have the PSDC Cashier / Desk Operator input their 6-digit MPIN to authorize and confirm this in-person desk payment:',
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deskMpinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: 10,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
            decoration: InputDecoration(
              hintText: '••••••',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black26,
                letterSpacing: 10,
              ),
              counterText: '',
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _verifyDeskMpin(),
          ),
          if (_deskMpinError != null) ...[
            const SizedBox(height: 8),
            Text(
              _deskMpinError!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_deskMpinFailedAttempts > 0 && !_isDeskPaymentLocked) ...[
            const SizedBox(height: 4),
            Text(
              'Attempts: $_deskMpinFailedAttempts of 3 (will lock after 3 failed attempts)',
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isDeskMpinVerifying ? null : _verifyDeskMpin,
              icon: _isDeskMpinVerifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.verified_user_rounded, size: 18),
              label: Text(
                _isDeskMpinVerifying
                    ? 'Verifying MPIN...'
                    : 'Authorize & Accept MPIN',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
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
    final isDesk = _selectedPaymentChannel == 'desk';
    final deskValid = _isDeskMpinApproved && !_isDeskPaymentLocked && _receiptFile != null;
    final canConfirm = !_isUploading && (!isDesk || deskValid);

    String btnLabel;
    if (_isUploading) {
      btnLabel = 'Uploading Proof...';
    } else if (isDesk) {
      if (!_isDeskMpinApproved) {
        btnLabel = 'Enter Operator MPIN';
      } else if (_receiptFile == null) {
        btnLabel = 'Upload Evidence to Confirm';
      } else {
        btnLabel = 'Confirm PSDC Desk Payment';
      }
    } else {
      btnLabel = widget.paymentPurpose == PaymentPurpose.lateReturnPenalty
          ? 'Pay Late Return Fee'
          : (widget.paymentPurpose == PaymentPurpose.releaseSettlement
              ? 'Settle Trip Balance'
              : 'Submit Payment Proof');
    }

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
                  onPressed: canConfirm ? _confirmPayment : null,
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
                    btnLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !canConfirm
                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                        : AppColors.primary,
                    foregroundColor: !canConfirm
                        ? (isDark ? Colors.white38 : Colors.black38)
                        : Colors.black,
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

  Widget _buildLateReturnInfographicCard(bool isDark, int seats, double dailyRate) {
    final hours = widget.lateHours ?? 1;
    final returnTime = widget.returnTimestamp ?? DateTime.now();
    final isWholeDayCap = hours >= _settings.lateFeeDayCapHours;
    final hourlyRate = seats >= 6 ? _settings.lateFee6PlusSeater : _settings.lateFee4to5Seater;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF451A1A), const Color(0xFF2D1214)]
              : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Oh no! You are late on returning the vehicle.',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Return initiated past scheduled return time',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF7F1D1D),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Return Click Timestamp:',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy • h:mm a').format(returnTime),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 12,
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
                      'Overdue Duration:',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$hours hour${hours > 1 ? 's' : ''} overdue',
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Vehicle Capacity Tier:',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$seats Seater (${seats >= 6 ? '₱350/hr tier' : '₱200/hr tier'})',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isWholeDayCap ? 'Late Fee Rule (≥ 6 hrs):' : 'Late Fee Rule (< 6 hrs):',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isWholeDayCap
                          ? 'Whole Day Price Cap'
                          : '₱${hourlyRate.toStringAsFixed(0)}/hr × $hours hr${hours > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 15, color: Color(0xFFE5A93C)),
                const SizedBox(width: 6),
                Text(
                  'All return procedures and penalty fees are based on the ',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 11.5,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LegalTermsPrivacyScreen(
                          initialTab: 'terms',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Terms and Rental Agreement',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  '.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreReleaseNoticeCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pre-Trip Release Settlement',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Please settle your remaining balance prior to vehicle handover at the station or delivery.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : const Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseSettlementBreakdownCard({
    required bool isDark,
    required double principalRentalSubtotal,
    required double securityDeposit,
    required double reservationFeePaid,
    required double remainingBalance,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pre-Release Payment Breakdown',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBreakdownRow('Rental Total (Subtotal & Services)', principalRentalSubtotal, isDark: isDark),
          const SizedBox(height: 8),
          _buildBreakdownRow('Refundable Security Deposit', securityDeposit, isDark: isDark),
          const SizedBox(height: 8),
          _buildBreakdownRow(
            'Less Reservation Fee Paid',
            reservationFeePaid,
            isDark: isDark,
            isDiscount: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _buildBreakdownRow(
            'Total Remaining Balance Due',
            remainingBalance,
            isDark: isDark,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLatePenaltyBreakdownCard({
    required bool isDark,
    required int lateHours,
    required int seats,
    required double dailyRate,
    required double lateFeeAmount,
  }) {
    final isWholeDayCap = lateHours >= _settings.lateFeeDayCapHours;
    final hourlyRate = seats >= 6 ? _settings.lateFee6PlusSeater : _settings.lateFee4to5Seater;

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.receipt_long_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              Text(
                'Late Return Fee Breakdown',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBreakdownRow(
            'Overdue duration',
            lateHours.toDouble(),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildBreakdownRow(
            isWholeDayCap
                ? 'Late fee rate (≥6 hrs: Full day price)'
                : 'Late fee rate (₱${hourlyRate.toStringAsFixed(0)}/hr × $lateHours hr${lateHours > 1 ? 's' : ''})',
            lateFeeAmount,
            isDark: isDark,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _buildBreakdownRow(
            'Total Penalty to Pay',
            lateFeeAmount,
            isDark: isDark,
            isBold: true,
          ),
        ],
      ),
    );
  }
}
