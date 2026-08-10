import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/leaflet_map.dart';
import '../../widgets/mpin_verification_dialog.dart';
import '../../widgets/booking_status_dialog.dart';
import '../../widgets/optimized_network_image.dart';
import '../../widgets/vehicle_image_carousel.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/booking_evidence_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/emergency_contact_service.dart';
import '../../../services/favorite_vehicle_service.dart';
import '../../../services/loyalty_service.dart';
import '../../../services/loyalty_reward_service.dart';
import '../../../services/reservation_payment_service.dart';
import '../../../services/terms_service.dart';
import '../../../services/trip_rating_service.dart';
import '../../../services/verification_service.dart';
import '../profile/emergency_contact_screen.dart';
import '../profile/ratings_reviews_screen.dart';
import 'signature_capture_screen.dart';
import '../../../utils/locations.dart';
import '../../../utils/pricing_policy.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/input_validation.dart';
import '../../../utils/web_html.dart' as html;

enum BookingMode { daily, hourly }

class VehicleDetailScreen extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic>? vehicleData;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const VehicleDetailScreen({
    super.key,
    required this.vehicleId,
    this.vehicleData,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  BookingMode _bookingMode = BookingMode.daily;
  Map<String, dynamic>? _vehicle;
  bool _isLoading = true;
  bool _isBooking = false;
  bool _isVehicleBookable = true;
  bool _isFavorite = false;
  bool _isLocatingPickup = false;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  List<DateTime> _unavailableDates = [];
  List<Map<String, dynamic>> _myBookings = [];
  bool _withDriver = false;
  bool _vehicleDelivery = false;
  TimeOfDay? _startTime;
  TimeOfDay? _returnTime;
  List<DateTime> _availableStartSlots = [];
  List<DateTime> _availableReturnSlots = [];
  bool _isLoadingTimeSlots = false;
  String? _acceptedTermsSnapshot;
  Map<String, dynamic>? _defaultEmergencyContact;
  bool _isLoadingEmergencyContact = false;
  double? _deliveryDistanceKm;
  bool _isCalculatingDeliveryFee = false;

  // Location selection state
  String? _pickupProvince;
  String? _pickupCity;
  String? _pickupBarangay;
  String? _pickupFreetext;
  _BookingLocationPin? _pickupMapPin;
  String? _dropoffProvince;
  String? _dropoffCity;
  String? _dropoffBarangay;
  String? _dropoffFreetext;
  _BookingLocationPin? _dropoffMapPin;
  final TextEditingController _pickupFreetextController =
      TextEditingController();
  final TextEditingController _dropoffFreetextController =
      TextEditingController();
  final TextEditingController _coTravelerNameController =
      TextEditingController();
  final TextEditingController _coTravelerPhoneController =
      TextEditingController();
  final TextEditingController _coTravelerLicenseController =
      TextEditingController();
  final Set<TextEditingController> _touchedEvidenceFields = {};
  Uint8List? _signatureBytes;
  Uint8List? _coTravelerSignatureBytes;
  XFile? _validIdPhoto;
  XFile? _selfiePhoto;
  XFile? _coTravelerValidIdPhoto;
  XFile? _coTravelerSelfiePhoto;

  @override
  void initState() {
    super.initState();
    _selectedStartDate = widget.initialStartDate == null
        ? null
        : DateTime(
            widget.initialStartDate!.year,
            widget.initialStartDate!.month,
            widget.initialStartDate!.day,
          );
    _selectedEndDate = widget.initialEndDate == null
        ? _selectedStartDate
        : DateTime(
            widget.initialEndDate!.year,
            widget.initialEndDate!.month,
            widget.initialEndDate!.day,
          );
    _loadVehicle();
  }

  @override
  void dispose() {
    _pickupFreetextController.dispose();
    _dropoffFreetextController.dispose();
    _coTravelerNameController.dispose();
    _coTravelerPhoneController.dispose();
    _coTravelerLicenseController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vehicleService = VehicleService();

      // Always prefer the latest database state. Passed data is only a visual
      // fallback so an approval/listing change cannot be bypassed by stale UI.
      _vehicle =
          await vehicleService.getVehicleById(widget.vehicleId) ??
          widget.vehicleData;
      _isVehicleBookable = await vehicleService.isVehicleBookable(
        widget.vehicleId,
      );

      // Get unavailable dates
      _unavailableDates = await vehicleService.getUnavailableDates(
        widget.vehicleId,
      );
      await _loadMyBookings();
      await _loadFavoriteState();
      await _loadEmergencyContact();
      await _loadLoyaltyVouchers();
      await _loadVehicleRating();
      if (_selectedStartDate != null) {
        await _loadStartTimeSlots();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vehicle: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadVehicleRating() async {
    try {
      final ratingSummary =
          await TripRatingService().getVehicleRatingSummary(widget.vehicleId);
      if (_vehicle != null) {
        _vehicle!['rating'] = ratingSummary['average'];
        _vehicle!['rating_count'] = ratingSummary['count'];
      }
    } catch (e) {
      debugPrint('Could not load vehicle rating: $e');
    }
  }

  void _openVehicleRatings() {
    final brand = _vehicle?['brand']?.toString().trim() ?? '';
    final model = _vehicle?['model']?.toString().trim() ?? '';
    final year = _vehicle?['year']?.toString().trim() ?? '';
    final vehicleName = [brand, model, year]
        .where((p) => p.isNotEmpty)
        .join(' ');
    final headerTitle = vehicleName.isNotEmpty
        ? '$vehicleName - Reviews & Ratings'
        : 'Vehicle Reviews & Ratings';
    final ownerId = _vehicle?['owner_id']?.toString() ??
        _vehicle?['operator_id']?.toString() ??
        '';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RatingsReviewsScreen(
          userId: ownerId,
          vehicleId: widget.vehicleId,
          title: headerTitle,
        ),
      ),
    );
  }

  Future<void> _loadMyBookings() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      _myBookings = await BookingService().getRenterBookings(user.id);
    } catch (e) {
      debugPrint('Could not load renter bookings for calendar: $e');
      _myBookings = [];
    }
  }

  Future<void> _loadEmergencyContact() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingEmergencyContact = true;
    });

    try {
      _defaultEmergencyContact = await EmergencyContactService()
          .getDefaultContact();
    } catch (e) {
      debugPrint('Could not load emergency contact: $e');
      _defaultEmergencyContact = null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEmergencyContact = false;
        });
      }
    }
  }

  Future<void> _openEmergencyContactScreen() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmergencyContactScreen(
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );

    if (saved == true) {
      await _loadEmergencyContact();
    }
  }

  Future<void> _pickBookingEvidencePhoto({
    required bool isSelfie,
    bool isCoTraveler = false,
  }) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: isSelfie ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() {
      if (isCoTraveler && isSelfie) {
        _coTravelerSelfiePhoto = file;
      } else if (isCoTraveler) {
        _coTravelerValidIdPhoto = file;
      } else if (isSelfie) {
        _selfiePhoto = file;
      } else {
        _validIdPhoto = file;
      }
    });
  }

  Future<void> _openSignatureCapture({required bool coTraveler}) async {
    final currentBytes = coTraveler
        ? _coTravelerSignatureBytes
        : _signatureBytes;
    final result = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => SignatureCaptureScreen(
          title: coTraveler ? 'Co-traveler Signature' : 'Renter Signature',
          initialSignature: currentBytes,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (coTraveler) {
        _coTravelerSignatureBytes = result;
      } else {
        _signatureBytes = result;
      }
    });
  }

  bool _isValidPhilippinePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^09\d{9}$').hasMatch(digits) ||
        RegExp(r'^639\d{9}$').hasMatch(digits);
  }

  Future<void> _loadFavoriteState() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    final isFavorite = await FavoriteVehicleService().isFavorite(
      userId: user.id,
      vehicleId: widget.vehicleId,
    );
    if (!mounted) return;
    setState(() => _isFavorite = isFavorite);
  }

  Future<void> _toggleFavorite() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() => _isFavorite = !_isFavorite);
    try {
      final nowFavorite = await FavoriteVehicleService().toggleFavorite(
        userId: user.id,
        vehicleId: widget.vehicleId,
      );
      if (!mounted) return;
      setState(() => _isFavorite = nowFavorite);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update favorites: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _selectDates() async {
    if (!await _ensureVehicleBookable()) return;

    final isHourly = _bookingMode == BookingMode.hourly;
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final initialDate = _clampToBookableDate(
      _selectedStartDate ?? firstDate.add(const Duration(days: 1)),
    );
    var initialEnd = _clampToBookableDate(_selectedEndDate ?? initialDate);
    if (initialEnd.isBefore(initialDate)) initialEnd = initialDate;

    // Hourly bookings span at most 2 calendar days (e.g. 10pm day 1 → 2am day 2).
    // Clamp the end date to start+1 when in hourly mode.
    if (isHourly && initialEnd.isAfter(initialDate.add(const Duration(days: 1)))) {
      initialEnd = initialDate.add(const Duration(days: 1));
    }

    final DateTime hourlyLastDate = firstDate.add(const Duration(days: 365));
    final DateTimeRange? picked = await _showBookingCalendarDialog(
      firstDate: firstDate,
      lastDate: hourlyLastDate,
      initialStart: _selectedStartDate ?? initialDate,
      initialEnd: _selectedEndDate ?? initialEnd,
      isHourly: isHourly,
    );

    if (picked == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
        _startTime = null;
        _returnTime = null;
        _availableStartSlots = [];
        _availableReturnSlots = [];
      });
      await _loadStartTimeSlots();
    }
  }

  void _showDateLimitModal(BuildContext dialogContext, String message) {
    showDialog(
      context: dialogContext,
      builder: (modalContext) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text(
              'Date Selection Limit',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(modalContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Got it',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTimeRange?> _showBookingCalendarDialog({
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime initialStart,
    required DateTime initialEnd,
    bool isHourly = false,
  }) {
    var focusedDay = initialStart;
    DateTime? rangeStart = initialStart;
    DateTime? rangeEnd = initialEnd;
    final bookedDays = _unavailableDates.map(_dateOnly).toSet();
    final myBookedDetails = _bookingDetailsByDay(_myBookings);
    final myBookedDays = myBookedDetails.keys.toSet();

    return showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasInvalidRange =
                rangeStart != null &&
                rangeEnd != null &&
                _rangeContainsBlockedDate(rangeStart!, rangeEnd!, bookedDays);

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
                          const Expanded(
                            child: Text(
                              'Select Booking Dates',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
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
                      if (isHourly) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withAlpha(80),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Hourly bookings: select 1 or 2 consecutive dates only.',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: const [
                          _CalendarLegendDot(
                            color: AppColors.primary,
                            label: 'Selected',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.error,
                            label: 'Unavailable',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.warning,
                            label: 'Your booking',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.success,
                            label: 'Available',
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
                        enabledDayPredicate: (day) =>
                            !bookedDays.contains(_dateOnly(day)) &&
                            !_dateOnly(day).isBefore(_dateOnly(firstDate)),
                        onRangeSelected: (start, end, focused) {
                          final startDay = start == null
                              ? null
                              : _dateOnly(start);
                          final endDay = end == null ? null : _dateOnly(end);
                          if ((startDay != null &&
                                  bookedDays.contains(startDay)) ||
                              (endDay != null && bookedDays.contains(endDay))) {
                            _showDateLimitModal(
                              dialogContext,
                              'That date is unavailable.',
                            );
                            return;
                          }
                          if (start != null &&
                              end != null &&
                              _rangeContainsBlockedDate(
                                start,
                                end,
                                bookedDays,
                              )) {
                            _showDateLimitModal(
                              dialogContext,
                              'Selected range includes unavailable dates.',
                            );
                            return;
                          }
                          // Hourly mode: max 2 calendar days
                          if (isHourly &&
                              start != null &&
                              end != null &&
                              _dateOnly(end)
                                  .difference(_dateOnly(start))
                                  .inDays >
                                  1) {
                            _showDateLimitModal(
                              dialogContext,
                              'Hourly bookings can span at most 2 days (1 to 2 consecutive dates only).',
                            );
                            return;
                          }

                          setDialogState(() {
                            rangeStart = start;
                            rangeEnd = end ?? start;
                            focusedDay = focused;
                          });
                        },
                        onDaySelected: (selectedDay, focused) {
                          final selectedDate = _dateOnly(selectedDay);
                          if (bookedDays.contains(selectedDate)) {
                            _showDateLimitModal(
                              dialogContext,
                              'That date is unavailable.',
                            );
                            return;
                          }

                          setDialogState(() {
                            if (rangeStart == null ||
                                (rangeStart != null && rangeEnd != null)) {
                              rangeStart = selectedDay;
                              rangeEnd = null;
                            } else if (selectedDay.isBefore(rangeStart!)) {
                              // Hourly: also check the flipped range
                              if (isHourly &&
                                  _dateOnly(rangeStart!)
                                      .difference(_dateOnly(selectedDay))
                                      .inDays >
                                      1) {
                                _showDateLimitModal(
                                  dialogContext,
                                  'Hourly bookings can span at most 2 days (1 to 2 consecutive dates only).',
                                );
                                return;
                              }
                              rangeEnd = rangeStart;
                              rangeStart = selectedDay;
                            } else {
                              if (_rangeContainsBlockedDate(
                                rangeStart!,
                                selectedDay,
                                bookedDays,
                              )) {
                                _showDateLimitModal(
                                  dialogContext,
                                  'Selected range includes unavailable dates.',
                                );
                                return;
                              }
                              // Hourly: max 2 days
                              if (isHourly &&
                                  _dateOnly(selectedDay)
                                      .difference(_dateOnly(rangeStart!))
                                      .inDays >
                                      1) {
                                _showDateLimitModal(
                                  dialogContext,
                                  'Hourly bookings can span at most 2 days (1 to 2 consecutive dates only).',
                                );
                                return;
                              }
                              rangeEnd = selectedDay;
                            }
                            focusedDay = focused;
                          });
                        },
                        onDayLongPressed: (selectedDay, focused) async {
                          final selectedDate = _dateOnly(selectedDay);
                          await _showDateAvailability(
                            selectedDate,
                            fullyUnavailable: bookedDays.contains(selectedDate),
                          );
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
                            color: AppColors.primary,
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right,
                            color: AppColors.primary,
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
                          defaultTextStyle: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          weekendTextStyle: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          disabledTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          todayDecoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          rangeHighlightColor: AppColors.primary.withAlpha(55),
                          selectedDecoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                          rangeStartDecoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          rangeEndDecoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          withinRangeTextStyle: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            final date = _dateOnly(day);
                            if (bookedDays.contains(date)) {
                              return _buildCalendarDayCell(
                                day: day,
                                backgroundColor: AppColors.error,
                                textColor: Colors.white,
                                strikethrough: true,
                              );
                            }
                            if (myBookedDays.contains(date)) {
                              return _buildCalendarDayCell(
                                day: day,
                                backgroundColor: AppColors.warning,
                                textColor: Colors.black,
                              );
                            }
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: AppColors.success.withAlpha(45),
                              borderColor: AppColors.success,
                              textColor: AppColors.textPrimary,
                            );
                          },
                          selectedBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: AppColors.primary,
                              textColor: Colors.black,
                            );
                          },
                          rangeStartBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: AppColors.primary,
                              textColor: Colors.black,
                            );
                          },
                          rangeEndBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: AppColors.primary,
                              textColor: Colors.black,
                            );
                          },
                          markerBuilder: (context, day, events) {
                            return null;
                          },
                          disabledBuilder: (context, day, focusedDay) {
                            final date = _dateOnly(day);
                            if (bookedDays.contains(date)) {
                              return _buildCalendarDayCell(
                                day: day,
                                backgroundColor: AppColors.error,
                                textColor: Colors.white,
                                strikethrough: true,
                              );
                            }
                            if (myBookedDays.contains(date)) {
                              return _buildCalendarDayCell(
                                day: day,
                                backgroundColor: AppColors.warning,
                                textColor: Colors.black,
                              );
                            }
                            return null;
                          },
                          todayBuilder: (context, day, focusedDay) {
                            final date = _dateOnly(day);
                            if (bookedDays.contains(date)) {
                              return _buildCalendarDayCell(
                                day: day,
                                backgroundColor: AppColors.error,
                                textColor: Colors.white,
                                strikethrough: true,
                              );
                            }
                            if (myBookedDays.contains(date)) {
                              return _buildCalendarDayCell(
                                day: day,
                                backgroundColor: AppColors.warning,
                                borderColor: AppColors.primary,
                                textColor: Colors.black,
                              );
                            }
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: AppColors.success.withAlpha(45),
                              borderColor: AppColors.primary,
                              textColor: AppColors.primary,
                            );
                          },
                        ),
                      ),
                      if (hasInvalidRange) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Selected range includes unavailable dates.',
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
                              onPressed:
                                  rangeStart == null ||
                                      rangeEnd == null ||
                                      hasInvalidRange
                                  ? null
                                  : () => Navigator.pop(
                                      dialogContext,
                                      DateTimeRange(
                                        start: rangeStart!,
                                        end: rangeEnd!,
                                      ),
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Apply'),
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

  DateTime _clampToBookableDate(DateTime preferred) {
    final lowerBound = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    var candidate = DateTime(preferred.year, preferred.month, preferred.day);
    if (candidate.isBefore(lowerBound)) candidate = lowerBound;
    final upperBound = lowerBound.add(const Duration(days: 365));
    if (candidate.isAfter(upperBound)) candidate = upperBound;
    final blocked = _unavailableDates.map(_dateOnly).toSet();
    while (blocked.contains(candidate) && candidate.isBefore(upperBound)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _rangeContainsBlockedDate(
    DateTime start,
    DateTime end,
    Set<DateTime> blockedDays,
  ) {
    final startDay = _dateOnly(start);
    final endDay = _dateOnly(end);
    final orderedStart = startDay.isAfter(endDay) ? endDay : startDay;
    final orderedEnd = startDay.isAfter(endDay) ? startDay : endDay;

    for (
      var day = orderedStart;
      !day.isAfter(orderedEnd);
      day = day.add(const Duration(days: 1))
    ) {
      if (blockedDays.contains(day)) return true;
    }

    return false;
  }

  Map<DateTime, List<Map<String, dynamic>>> _bookingDetailsByDay(
    List<Map<String, dynamic>> bookings,
  ) {
    final details = <DateTime, List<Map<String, dynamic>>>{};
    for (final booking in bookings) {
      if (!_bookingBelongsToCurrentVehicle(booking)) continue;

      final status =
          (booking['rawStatus'] ?? booking['status'])
              ?.toString()
              .toLowerCase() ??
          '';
      if (!{'pending', 'approved', 'confirmed', 'active'}.contains(status)) {
        continue;
      }

      final start = _parseBookingCalendarDate(
        booking['start_at'] ??
            booking['start_date_raw'] ??
            booking['start_date'] ??
            booking['startDate'],
      );
      final end = _parseBookingCalendarDate(
        booking['end_at'] ??
            booking['end_date_raw'] ??
            booking['end_date'] ??
            booking['endDate'],
      );
      if (start == null || end == null) continue;

      var current = _dateOnly(start);
      final last = _dateOnly(end);
      while (!current.isAfter(last)) {
        details.putIfAbsent(current, () => []).add(booking);
        current = current.add(const Duration(days: 1));
      }
    }
    return details;
  }

  bool _bookingBelongsToCurrentVehicle(Map<String, dynamic> booking) {
    final directVehicleId = booking['vehicle_id']?.toString();
    if (directVehicleId == widget.vehicleId) return true;

    final vehicle = booking['vehicles'];
    if (vehicle is Map) {
      return vehicle['id']?.toString() == widget.vehicleId;
    }

    return false;
  }

  DateTime? _parseBookingCalendarDate(Object? value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty || raw == 'N/A') return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toLocal();

    final parts = raw.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;

    final day = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
    if (day == null) return null;

    final monthLookup = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final monthText = parts[1].toLowerCase();
    if (monthText.length < 3) return null;
    final monthKey = monthText.substring(0, 3);
    final month = monthLookup[monthKey];
    if (month == null) return null;

    final year = parts.length >= 3
        ? int.tryParse(parts[2])
        : DateTime.now().year;
    if (year == null) return null;

    return DateTime(year, month, day);
  }

  String _bookingVehicleTitle(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'];
    if (vehicle is Map<String, dynamic>) {
      final vehicleName = vehicle['vehicle_name']?.toString().trim() ?? '';
      if (vehicleName.isNotEmpty) return vehicleName;
      final brand = vehicle['brand']?.toString().trim() ?? '';
      final model = vehicle['model']?.toString().trim() ?? '';
      final title = [brand, model].where((part) => part.isNotEmpty).join(' ');
      if (title.isNotEmpty) return title;
    }
    return 'Booked vehicle';
  }

  void _showBookedDateDetails(
    DateTime date,
    Map<DateTime, List<Map<String, dynamic>>> detailsByDay,
  ) {
    final bookings = detailsByDay[_dateOnly(date)] ?? [];
    if (bookings.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your booking on ${_formatDate(date)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...bookings.map((booking) {
                  final status = booking['status']?.toString() ?? 'pending';
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgTertiary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.directions_car,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _bookingVehicleTitle(booking),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarDayCell({
    required DateTime day,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    bool strikethrough = false,
  }) {
    return Container(
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
          decorationColor: textColor,
          decorationThickness: 2,
        ),
      ),
    );
  }

  DateTime? get _startAtLocal {
    final d = _selectedStartDate;
    final time = _startTime;
    if (d == null || time == null) return null;
    return DateTime(d.year, d.month, d.day, time.hour, time.minute);
  }

  DateTime? get _endAtLocal {
    final d = _selectedEndDate;
    final time = _returnTime ?? _startTime;
    if (d == null || time == null) return null;
    return DateTime(d.year, d.month, d.day, time.hour, time.minute);
  }

  Duration get _rentalDuration {
    final start = _startAtLocal;
    final end = _endAtLocal;
    if (start == null || end == null) return Duration.zero;
    final diff = end.difference(start);
    return diff.isNegative ? Duration.zero : diff;
  }

  int get _billableHours {
    final minutes = _rentalDuration.inMinutes;
    if (minutes <= 0) return 0;
    return (minutes / 60).ceil();
  }

  double get _rentalSubtotal {
    final pricePerDay = (_vehicle?['price_per_day'] as num?)?.toDouble() ?? 0.0;
    final pricePerHour = (_vehicle?['price_per_hour'] as num?)?.toDouble() ?? 0.0;

    if (_bookingMode == BookingMode.hourly) {
      final hours = _billableHours;
      if (pricePerHour > 0) {
        return pricePerHour * hours;
      } else if (pricePerDay > 0) {
        return (pricePerDay / 24.0) * hours;
      }
      return 0.0;
    }

    // ── DAILY BOOKING MODE ──
    final start = _startAtLocal;
    final end = _endAtLocal;
    if (start == null || end == null) {
      final days = _selectedStartDate == null || _selectedEndDate == null
          ? 0
          : _selectedEndDate!.difference(_selectedStartDate!).inDays + 1;
      return pricePerDay * (days < 0 ? 0 : days);
    }

    final duration = end.difference(start);
    final totalMinutes = duration.inMinutes;
    if (totalMinutes <= 0) return 0.0;

    final totalHours = (totalMinutes / 60.0).ceil();

    // 24 hours = 1 full day
    int fullDays = totalHours ~/ 24;
    int excessHours = totalHours % 24;

    // Minimum 1 day for daily mode
    if (fullDays == 0) {
      fullDays = 1;
      excessHours = 0;
    }

    final dayCost = fullDays * pricePerDay;

    double excessCost = 0.0;
    if (excessHours > 0) {
      final hourlyRate = pricePerHour > 0 ? pricePerHour : (pricePerDay / 24.0);
      excessCost = excessHours * hourlyRate;
      // Cap excess cost at 1 full day rate
      if (pricePerDay > 0 && excessCost > pricePerDay) {
        excessCost = pricePerDay;
      }
    }

    return dayCost + excessCost;
  }

  String _getFormattedDurationString() {
    if (_bookingMode == BookingMode.hourly) {
      final hours = _billableHours;
      return '$hours hour${hours == 1 ? '' : 's'}';
    }

    final start = _startAtLocal;
    final end = _endAtLocal;
    if (start == null || end == null) {
      final days = _selectedStartDate == null || _selectedEndDate == null
          ? 0
          : _selectedEndDate!.difference(_selectedStartDate!).inDays + 1;
      return '$days day${days == 1 ? '' : 's'}';
    }

    final totalMinutes = end.difference(start).inMinutes;
    if (totalMinutes <= 0) return '0 days';

    final totalHours = (totalMinutes / 60.0).ceil();
    int fullDays = totalHours ~/ 24;
    int excessHours = totalHours % 24;

    if (fullDays == 0) {
      fullDays = 1;
      excessHours = 0;
    }

    final startFmt = _format12Hour(_startTime?.hour ?? 9, _startTime?.minute ?? 0);
    final returnFmt = _format12Hour((_returnTime ?? _startTime)?.hour ?? 9, (_returnTime ?? _startTime)?.minute ?? 0);

    if (excessHours == 0) {
      return '$fullDays day${fullDays == 1 ? '' : 's'} ($startFmt - $returnFmt)';
    } else {
      return '$fullDays day${fullDays == 1 ? '' : 's'} + $excessHours excess hr${excessHours == 1 ? '' : 's'} ($startFmt - $returnFmt)';
    }
  }

  double get _deliveryFee {
    if (!_requiresPickupMap || _deliveryDistanceKm == null) return 0;
    return _deliveryDistanceKm! * PricingPolicy.deliveryRatePerKm;
  }

  bool get _requiresPickupMap => _withDriver || _vehicleDelivery;

  LoyaltyRewardState? _loyaltyRewardState;
  LoyaltyVoucher? _selectedVoucher;

  Future<void> _loadLoyaltyVouchers() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      final rewardState = await LoyaltyRewardService().load(user.id);
      if (!mounted) return;
      setState(() {
        _loyaltyRewardState = rewardState;
      });
    } catch (e) {
      debugPrint('Error loading loyalty vouchers: $e');
    }
  }

  double get _discountAmount {
    if (_selectedVoucher == null) return 0.0;
    final subtotal = _rentalSubtotal;
    if (subtotal <= 0) return 0.0;
    final v = _selectedVoucher!;
    double discount = 0.0;
    if (v.isPercent) {
      discount = subtotal * (v.discountPercent / 100.0);
    } else {
      discount = v.discountAmount;
    }
    return discount > subtotal ? subtotal : discount;
  }

  double get _totalPrice {
    final rawTotal = _rentalSubtotal + _deliveryFee - _discountAmount;
    return rawTotal < 0 ? 0.0 : rawTotal;
  }

  int get _billableDays {
    final minutes = _rentalDuration.inMinutes;
    if (minutes <= 0) return 0;
    return (minutes / Duration.minutesPerDay).ceil();
  }

  bool get _requiresLongBookingReservation =>
      _billableDays > PricingPolicy.longBookingReservationThresholdDays;

  double get _reservationFeeAmount => _requiresLongBookingReservation
      ? _totalPrice * PricingPolicy.longBookingReservationRate
      : 0;

  double get _remainingBalance {
    final balance = _totalPrice - _reservationFeeAmount;
    return balance < 0 ? 0 : balance;
  }

  Future<void> _loadStartTimeSlots() async {
    final date = _selectedStartDate;
    if (date == null) return;

    setState(() {
      _isLoadingTimeSlots = true;
      _availableStartSlots = [];
      _availableReturnSlots = [];
    });
    try {
      final slots = await VehicleService().getAvailableTimeSlots(
        vehicleId: widget.vehicleId,
        date: date,
      );
      if (!mounted || !DateUtils.isSameDay(date, _selectedStartDate)) return;
      setState(() => _availableStartSlots = slots);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load available times: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingTimeSlots = false);
    }
  }

  Future<void> _selectStartSlot(DateTime slot) async {
    setState(() {
      _startTime = TimeOfDay.fromDateTime(slot);
      if (_bookingMode == BookingMode.daily) {
        _returnTime = TimeOfDay.fromDateTime(slot);
        _availableReturnSlots = [];
      } else {
        _returnTime = null;
        _availableReturnSlots = [];
      }
      _isLoadingTimeSlots = true;
    });

    if (_bookingMode == BookingMode.daily) {
      if (mounted) setState(() => _isLoadingTimeSlots = false);
      return;
    }

    final endDate = _selectedEndDate;
    final rentalStart = _startAtLocal;
    if (endDate == null || rentalStart == null) {
      setState(() => _isLoadingTimeSlots = false);
      return;
    }

    try {
      final slots = await VehicleService().getAvailableTimeSlots(
        vehicleId: widget.vehicleId,
        date: endDate,
        rentalStart: rentalStart,
        selectingEnd: true,
      );
      if (!mounted || rentalStart != _startAtLocal) return;
      setState(() => _availableReturnSlots = slots);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load return times: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingTimeSlots = false);
    }
  }

  Future<void> _showDateAvailability(
    DateTime date, {
    required bool fullyUnavailable,
  }) async {
    List<DateTime> available = const [];
    Object? loadError;
    if (!fullyUnavailable) {
      try {
        available = await VehicleService().getAvailableTimeSlots(
          vehicleId: widget.vehicleId,
          date: date,
        );
      } catch (error) {
        loadError = error;
      }
    }
    if (!mounted) return;

    final availableHours = available.map((slot) => slot.hour).toSet();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Availability for ${_formatDate(date)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                loadError != null
                    ? 'Availability could not be loaded.'
                    : 'Unavailable hours remain visible but cannot be selected.',
                style: TextStyle(
                  color: loadError != null
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildReadOnlySlotGrid(
                    date: date,
                    availableHours: fullyUnavailable
                        ? const <int>{}
                        : availableHours,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshDeliveryEstimate() async {
    if (!_requiresPickupMap) {
      setState(() {
        _deliveryDistanceKm = null;
      });
      return;
    }

    final pickup = _getPickupLocation();
    final dropoff = _getDropoffLocation();
    if (pickup.trim().isEmpty || dropoff.trim().isEmpty) return;

    setState(() {
      _isCalculatingDeliveryFee = true;
    });

    try {
      final pickupPosition =
          _pickupMapPin ??
          await _resolveLocationPin(
            address: pickup,
            fallbackLabel: 'Pickup location',
          );
      final dropoffPosition =
          _dropoffMapPin ??
          await _resolveLocationPin(
            address: dropoff,
            fallbackLabel: 'Trip destination',
          );
      final meters = Geolocator.distanceBetween(
        pickupPosition.latitude,
        pickupPosition.longitude,
        dropoffPosition.latitude,
        dropoffPosition.longitude,
      );

      if (!mounted) return;
      setState(() {
        _deliveryDistanceKm = meters <= 0 ? 0 : meters / 1000;
      });
    } catch (e) {
      debugPrint('Delivery fee estimate failed: $e');
      if (!mounted) return;
      setState(() {
        _deliveryDistanceKm = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingDeliveryFee = false;
        });
      }
    }
  }

  Future<void> _handleBooking() async {
    if (!await _ensureVehicleBookable(refreshVehicle: true)) return;

    final authService = AuthService();
    final user = authService.currentUser;

    if (user == null) {
      _showErrorDialog('Error', 'Please log in first');
      return;
    }

    // Get user role from database
    try {
      final verificationState =
          await VerificationService.getUserVerificationState(user.id);
      final userRole = verificationState['role']?.toString() ?? 'renter';
      final isVerified = verificationState['is_verified'] as bool? ?? false;

      // ✅ Skip verification requirement for drivers
      if (userRole == 'driver') {
        debugPrint('✅ Driver detected - skipping verification requirement');
        // Proceed with booking for drivers
        await _proceedWithBooking(requireTermsAgreement: false);
        return;
      }

      // For renters, require verification
      if (!isVerified) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.darkBgSecondary,
              title: const Text(
                'Verification Required',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              content: const Text(
                'You need to verify your identity before you can book a vehicle. Would you like to complete verification now?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Later',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushNamed('/id-verification');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Verify Now'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Renter is verified, proceed with booking
      await _proceedWithBooking(requireTermsAgreement: true);
    } catch (e) {
      debugPrint('Error checking verification: $e');
      _showErrorDialog(
        'Error',
        'Unable to verify user status. Please try again.',
      );
    }
  }

  Future<bool> _ensureVehicleBookable({bool refreshVehicle = false}) async {
    final isBookable = await VehicleService().isVehicleBookable(
      widget.vehicleId,
    );
    if (!mounted) return false;

    Map<String, dynamic>? freshVehicle;
    if (isBookable && refreshVehicle) {
      freshVehicle = await VehicleService().getVehicleById(widget.vehicleId);
      if (!mounted) return false;
    }

    setState(() {
      _isVehicleBookable = isBookable;
      if (freshVehicle != null) _vehicle = freshVehicle;
    });
    if (isBookable) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This vehicle is pending approval, rejected, or no longer listed.',
        ),
        backgroundColor: AppColors.warning,
      ),
    );
    return false;
  }

  Future<void> _proceedWithBooking({bool requireTermsAgreement = true}) async {
    final authService = AuthService();
    ReservationPaymentProof? reservationPaymentProof;

    if (_selectedStartDate == null || _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select rental dates'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final startAtLocal = _startAtLocal;
    final endAtLocal = _endAtLocal;
    if (startAtLocal == null || endAtLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select booking times'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!endAtLocal.isAfter(startAtLocal)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return time must be after start time'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!startAtLocal.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rental start time must be in the future'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    late final bool scheduleIsAvailable;
    try {
      scheduleIsAvailable = await VehicleService().isTimeRangeAvailable(
        vehicleId: widget.vehicleId,
        startAt: startAtLocal,
        endAt: endAtLocal,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not validate the selected schedule: $error'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!mounted) return;
    if (!scheduleIsAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That schedule overlaps an unavailable period or another booking. Choose different dates or times.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_dropoffMapPin == null &&
        _dropoffFreetextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or pin the trip destination.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_requiresPickupMap &&
        _pickupMapPin == null &&
        _pickupFreetextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or pin the delivery location.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_requiresPickupMap && _deliveryDistanceKm == null) {
      await _refreshDeliveryEstimate();
      if (_deliveryDistanceKm == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please pin the delivery location and estimate the fee before booking.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    if (_defaultEmergencyContact == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one emergency contact before booking.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      await _openEmergencyContactScreen();
      return;
    }

    if (_signatureBytes == null || _signatureBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please draw your digital signature.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final coTravelerName = toTitleCaseName(_coTravelerNameController.text);
    final coTravelerPhone = normalizePhilippineMobile(
      _coTravelerPhoneController.text,
    );
    final coTravelerLicense = _coTravelerLicenseController.text.trim();
    if (coTravelerName.isEmpty ||
        coTravelerPhone.isEmpty ||
        coTravelerLicense.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Co-traveler name, phone number, and license number are required.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_isValidPhilippinePhone(coTravelerPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Co-traveler phone must be 11 digits, e.g. 09171234567.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!RegExp(r'^[A-Za-z0-9-]{6,13}$').hasMatch(coTravelerLicense)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Driver's License Number must be 6-13 letters/numbers and may include hyphens.",
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_coTravelerSignatureBytes == null ||
        _coTravelerSignatureBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please draw the co-traveler digital signature.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_validIdPhoto == null || _selfiePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload a valid ID photo and capture a clear selfie before booking.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_coTravelerValidIdPhoto == null || _coTravelerSelfiePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload the co-traveler valid ID and capture their selfie.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (requireTermsAgreement) {
      setState(() {
        _isBooking = true;
      });

      final acceptedTermsSnapshot = await _showTermsAgreementDialog();

      if (!mounted) return;

      setState(() {
        _isBooking = false;
      });

      if (acceptedTermsSnapshot == null) {
        return;
      }

      _acceptedTermsSnapshot = acceptedTermsSnapshot;

      final currentUser = authService.currentUser;
      if (currentUser == null) {
        _showErrorDialog('Error', 'You need to log in before booking.');
        return;
      }

      final detailsConfirmed = await _showBookingDetailsReviewDialog(
        startAt: startAtLocal,
        endAt: endAtLocal,
        coTravelerName: coTravelerName,
        coTravelerPhone: coTravelerPhone,
        coTravelerLicense: coTravelerLicense,
      );

      if (!mounted || !detailsConfirmed) return;

      final mpinAuthorized =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const MpinVerificationDialog(),
          ) ??
          false;

      if (!mounted || !mpinAuthorized) return;

      reservationPaymentProof = await _showReservationPaymentDialog(
        userId: currentUser.id,
      );

      if (!mounted) return;
      if (reservationPaymentProof == null) {
        return;
      }
    }

    setState(() {
      _isBooking = true;
    });

    try {
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw Exception('You need to log in before booking.');
      }

      final error = await showDialog<dynamic>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return BookingStatusDialog(
            billableHours: _billableHours,
            totalPrice: _totalPrice,
            withDriver: _withDriver,
            onProcess: () async {
              final evidenceService = BookingEvidenceService();
              final signatureUrl = await evidenceService.uploadEvidenceBytes(
                userId: currentUser.id,
                bytes: _signatureBytes!,
                evidenceType: 'signature',
              );
              final coTravelerSignatureUrl = await evidenceService.uploadEvidenceBytes(
                userId: currentUser.id,
                bytes: _coTravelerSignatureBytes!,
                evidenceType: 'co_traveler_signature',
              );
              final validIdUrl = await evidenceService.uploadEvidenceFile(
                userId: currentUser.id,
                file: _validIdPhoto!,
                evidenceType: 'valid_id',
              );
              final selfieUrl = await evidenceService.uploadEvidenceFile(
                userId: currentUser.id,
                file: _selfiePhoto!,
                evidenceType: 'selfie',
              );
              final coTravelerValidIdUrl = await evidenceService.uploadEvidenceFile(
                userId: currentUser.id,
                file: _coTravelerValidIdPhoto!,
                evidenceType: 'co_traveler_valid_id',
              );
              final coTravelerSelfieUrl = await evidenceService.uploadEvidenceFile(
                userId: currentUser.id,
                file: _coTravelerSelfiePhoto!,
                evidenceType: 'co_traveler_selfie',
              );

              final createdBooking = await BookingService().createBooking(
                renterId: currentUser.id,
                vehicleId: widget.vehicleId,
                startAt: startAtLocal.toUtc(),
                endAt: endAtLocal.toUtc(),
                totalPrice: _totalPrice,
                rentalSubtotal: _rentalSubtotal,
                discountAmount: _discountAmount,
                appliedVoucher: _selectedVoucher?.code ?? _selectedVoucher?.title,
                deliveryDistanceKm: _deliveryDistanceKm,
                deliveryRatePerKm: PricingPolicy.deliveryRatePerKm,
                deliveryFee: _deliveryFee,
                withDriver: _withDriver,
                pickupLocation: _getPickupLocation(),
                dropoffLocation: _getDropoffLocation(),
                pickupLatitude: _pickupMapPin?.latitude,
                pickupLongitude: _pickupMapPin?.longitude,
                dropoffLatitude: _dropoffMapPin?.latitude,
                dropoffLongitude: _dropoffMapPin?.longitude,
                rentalTermsAcceptedAt: requireTermsAgreement ? DateTime.now() : null,
                rentalTermsSnapshot: requireTermsAgreement
                    ? _acceptedTermsSnapshot
                    : null,
                reservationFeeAmount: reservationPaymentProof?.amount,
                reservationPaymentReference: reservationPaymentProof?.referenceNumber,
                reservationPaymentProofUrl: reservationPaymentProof?.proofUrl,
                reservationPaymentMethod: reservationPaymentProof?.method,
                reservationPaymentType: reservationPaymentProof?.paymentType,
                emergencyContactName: _defaultEmergencyContact?['full_name']
                    ?.toString(),
                emergencyContactPhone: _defaultEmergencyContact?['phone_number']
                    ?.toString(),
                emergencyContactRelationship: _defaultEmergencyContact?['relationship']
                    ?.toString(),
                renterSignatureText: 'Digital signature captured',
                renterSignatureUrl: signatureUrl,
                renterValidIdUrl: validIdUrl,
                renterSelfieUrl: selfieUrl,
                coTravelerName: coTravelerName,
                coTravelerPhone: coTravelerPhone,
                coTravelerLicense: coTravelerLicense,
                coTravelerSignatureText: 'Co-traveler digital signature captured',
                coTravelerSignatureUrl: coTravelerSignatureUrl,
                coTravelerValidIdUrl: coTravelerValidIdUrl,
                coTravelerSelfieUrl: coTravelerSelfieUrl,
              );

              if (reservationPaymentProof != null) {
                final bookingId = createdBooking['id']?.toString();
                if (bookingId != null && bookingId.isNotEmpty) {
                  unawaited(
                    ReservationPaymentService()
                        .createReceiptRecord(
                          bookingId: bookingId,
                          renterId: currentUser.id,
                          proof: reservationPaymentProof,
                        )
                        .timeout(const Duration(seconds: 6))
                        .catchError((e) {
                          debugPrint(
                            'Booking created but receipt audit insert timed out/failed: $e',
                          );
                        }),
                  );
                }
              }
            },
            onDone: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          );
        },
      );

      if (error != null) {
        throw error;
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().toLowerCase().contains('unavailable')
            ? 'Selected dates are unavailable for bookings'
            : 'Error creating booking: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  Future<String?> _showTermsAgreementDialog() async {
    final terms = await TermsService().getRentalTerms();
    if (!mounted) return null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    var accepted = false;

    final acceptedTerms =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              title: Text(
                'Rental Terms & Agreement',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxHeight: 320),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBgSecondary
                            : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderColor
                              : AppColors.lightBorderColor,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          terms,
                          style: TextStyle(
                            height: 1.45,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: accepted,
                          activeColor: AppColors.primary,
                          checkColor: Colors.black,
                          onChanged: (value) {
                            setDialogState(() {
                              accepted = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'I have read and agree to the rental terms, payment rules, and car rental policies.',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: accepted
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text(
                    'Agree & Continue',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;

    return acceptedTerms ? terms : null;
  }

  Future<bool> _showBookingDetailsReviewDialog({
    required DateTime startAt,
    required DateTime endAt,
    required String coTravelerName,
    required String coTravelerPhone,
    required String coTravelerLicense,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicle = _vehicle ?? widget.vehicleData ?? const <String, dynamic>{};
    final vehicleName = [
      vehicle['brand']?.toString().trim() ?? '',
      vehicle['model']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
    final emergencyName =
        _defaultEmergencyContact?['full_name']?.toString().trim() ?? '';
    final emergencyPhone =
        _defaultEmergencyContact?['phone_number']?.toString().trim() ?? '';
    final pickup = _getPickupLocation().trim();
    final destination = _getDropoffLocation().trim();
    final service = _withDriver
        ? 'Professional driver'
        : _vehicleDelivery
        ? 'Self-drive with vehicle delivery'
        : 'Self-pickup';

    String formatDateTime(DateTime value) {
      final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
      final minute = value.minute.toString().padLeft(2, '0');
      final period = value.hour < 12 ? 'AM' : 'PM';
      final time = '$hour:$minute $period';
      return '${_formatDate(value)}, ${value.year} at $time';
    }

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => Dialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.fact_check_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Review Booking Details',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textPrimary
                                      : AppColors.lightTextPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Double-check every detail before payment.',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          icon: const Icon(Icons.close_rounded),
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderColor
                        : AppColors.lightBorderColor,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildBookingReviewSection(
                            context,
                            title: 'Trip Details',
                            icon: Icons.directions_car_filled_outlined,
                            rows: [
                              MapEntry(
                                'Vehicle',
                                vehicleName.isEmpty
                                    ? 'Selected vehicle'
                                    : vehicleName,
                              ),
                              MapEntry('Start', formatDateTime(startAt)),
                              MapEntry('Return', formatDateTime(endAt)),
                              MapEntry('Service', service),
                              MapEntry(
                                'Pickup',
                                PhilippineLocations.normalizePsdcGarageLabel(
                                  pickup,
                                ),
                              ),
                              MapEntry(
                                'Destination',
                                destination.isEmpty
                                    ? 'Not provided'
                                    : destination,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildBookingReviewSection(
                            context,
                            title: 'Safety Information',
                            icon: Icons.health_and_safety_outlined,
                            rows: [
                              MapEntry(
                                'Emergency contact',
                                [emergencyName, emergencyPhone]
                                    .where((value) => value.isNotEmpty)
                                    .join(' • '),
                              ),
                              MapEntry('Co-traveler', coTravelerName),
                              MapEntry('Co-traveler phone', coTravelerPhone),
                              MapEntry('Driver license', coTravelerLicense),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildBookingReviewSection(
                            context,
                            title: 'Price Breakdown',
                            icon: Icons.receipt_long_outlined,
                            rows: [
                              MapEntry(
                                'Rental subtotal',
                                'PHP ${formatAmount(_rentalSubtotal)}',
                              ),
                              if (_requiresPickupMap)
                                MapEntry(
                                  'Delivery fee',
                                  'PHP ${formatAmount(_deliveryFee)}',
                                ),
                              MapEntry(
                                'Total',
                                'PHP ${formatAmount(_totalPrice)}',
                              ),
                            ],
                            emphasizeLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderColor
                        : AppColors.lightBorderColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.lightTextPrimary,
                              side: BorderSide(
                                color: isDark
                                    ? AppColors.borderColor
                                    : AppColors.lightBorderColor,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Back & Edit'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Proceed to Payment',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Widget _buildBookingReviewSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<MapEntry<String, String>> rows,
    bool emphasizeLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgTertiary : AppColors.lightBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 19),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      rows[index].key,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rows[index].value.isEmpty
                          ? 'Not provided'
                          : rows[index].value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: emphasizeLast && index == rows.length - 1
                            ? AppColors.primary
                            : isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                        fontSize: emphasizeLast && index == rows.length - 1
                            ? 14
                            : 12,
                        fontWeight: emphasizeLast && index == rows.length - 1
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
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

  Future<ReservationPaymentProof?> _showReservationPaymentDialog({
    required String userId,
  }) async {
    final service = ReservationPaymentService();
    final settings = await service.getSettings();
    if (!mounted) return null;

    final referenceController = TextEditingController();
    XFile? receiptFile;
    bool isUploading = false;
    bool payFullAmount = false;
    String? errorText;

    try {
      return await showDialog<ReservationPaymentProof>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final vehicle = _vehicle ?? widget.vehicleData ?? {};
              final isPartnerVehicle =
                  vehicle['source']?.toString().toLowerCase() == 'partner' ||
                  vehicle['is_partner_vehicle'] == true ||
                  vehicle['partner_vehicle_id'] != null ||
                  vehicle['partner_name'] != null;
              final rentalTotal = _totalPrice;
              final partnerCommission = isPartnerVehicle
                  ? rentalTotal * 0.10
                  : 0.0;
              final reservationOnlyAmount = _requiresLongBookingReservation
                  ? _reservationFeeAmount
                  : settings.amount;
              final payableAmount = payFullAmount
                  ? rentalTotal + partnerCommission
                  : reservationOnlyAmount;
              Future<void> pickReceipt() async {
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (picked == null) return;
                setDialogState(() {
                  receiptFile = picked;
                  errorText = null;
                });
              }

              Future<void> confirmPayment() async {
                final reference = referenceController.text.trim();
                final payableAmount = payFullAmount
                    ? rentalTotal + partnerCommission
                    : reservationOnlyAmount;
                if (settings.qrUrl.trim().isEmpty) {
                  setDialogState(() {
                    errorText =
                        'Payment QR is not configured yet. Please contact support.';
                  });
                  return;
                }
                if (!RegExp(r'^\d{6,13}$').hasMatch(reference)) {
                  setDialogState(() {
                    errorText =
                        'Enter 6 to 13-digit transaction reference number.';
                  });
                  return;
                }
                if (receiptFile == null) {
                  setDialogState(() {
                    errorText = 'Upload the payment screenshot first.';
                  });
                  return;
                }

                setDialogState(() {
                  isUploading = true;
                  errorText = null;
                });

                try {
                  final receiptUpload = await service.uploadReceiptProof(
                    userId: userId,
                    file: receiptFile!,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(
                    dialogContext,
                    ReservationPaymentProof(
                      amount: payableAmount,
                      method: 'psdc_qr_payment',
                      paymentType: payFullAmount
                          ? 'full_payment'
                          : 'reservation_only',
                      referenceNumber: reference,
                      proofUrl: receiptUpload.publicUrl,
                      proofStoragePath: receiptUpload.storagePath,
                    ),
                  );
                } catch (e) {
                  setDialogState(() {
                    isUploading = false;
                    errorText = 'Could not upload receipt: $e';
                  });
                }
              }

              return AlertDialog(
                backgroundColor: AppColors.darkBgSecondary,
                title: const Text(
                  'Reservation Payment',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payFullAmount
                            ? 'Pay full rental amount now'
                            : _requiresLongBookingReservation
                            ? 'Pay 20% reservation fee'
                            : 'Pay refundable reservation fee',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PHP ${formatAmount(payableAmount, decimalDigits: 0)} to ${settings.accountName}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                            const Text(
                              'Computation & Total Breakdown',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildPaymentBreakdownRow(
                              'Rental subtotal',
                              _rentalSubtotal,
                            ),
                            if (_deliveryFee > 0) ...[
                              const SizedBox(height: 6),
                              _buildPaymentBreakdownRow(
                                'Delivery fee',
                                _deliveryFee,
                              ),
                            ],
                            if (_discountAmount > 0) ...[
                              const SizedBox(height: 6),
                              _buildPaymentBreakdownRow(
                                'Voucher / Loyalty discount',
                                _discountAmount,
                                isDiscount: true,
                              ),
                            ],
                            if (isPartnerVehicle && partnerCommission > 0) ...[
                              const SizedBox(height: 6),
                              _buildPaymentBreakdownRow(
                                'Partner commission (10%)',
                                partnerCommission,
                              ),
                            ],
                            const Divider(
                              height: 18,
                              color: AppColors.borderColor,
                            ),
                            _buildPaymentBreakdownRow(
                              'Total booking cost',
                              payFullAmount && isPartnerVehicle
                                  ? (rentalTotal + partnerCommission)
                                  : rentalTotal,
                              isTotal: true,
                            ),
                            const SizedBox(height: 6),
                            _buildPaymentBreakdownRow(
                              payFullAmount
                                  ? 'Payable now (Full payment)'
                                  : _requiresLongBookingReservation
                                  ? 'Payable now (20% Reservation)'
                                  : 'Payable now (Refundable Reservation)',
                              payableAmount,
                              isTotal: true,
                            ),
                            if (!payFullAmount &&
                                (rentalTotal + (isPartnerVehicle ? partnerCommission : 0.0) - payableAmount) > 0) ...[
                              const SizedBox(height: 6),
                              _buildPaymentBreakdownRow(
                                'Remaining balance (Due upon pickup)',
                                ((rentalTotal + (isPartnerVehicle ? partnerCommission : 0.0)) - payableAmount)
                                    .clamp(0.0, double.infinity),
                              ),
                            ],
                            if (isPartnerVehicle) ...[
                              const SizedBox(height: 6),
                              Text(
                                payFullAmount
                                    ? 'Partner vehicle: 10% commission is included in full payment.'
                                    : 'Partner vehicle: 10% commission will be included in the final rental settlement.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Company-owned vehicle: no extra commission added.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.payments_outlined,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pay full rental amount',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Optional. Leave off to pay reservation only.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: payFullAmount,
                              activeColor: AppColors.primary,
                              onChanged: isUploading
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        payFullAmount = value;
                                        errorText = null;
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        payFullAmount
                            ? '${settings.instructions}\n\nYou selected full payment, so your proof should match the total payable shown above.'
                            : settings.instructions,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: settings.qrUrl.isEmpty
                            ? const Column(
                                children: [
                                  Icon(
                                    Icons.qr_code_2,
                                    color: AppColors.textTertiary,
                                    size: 72,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Payment QR is not configured yet. Please contact support.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: OptimizedNetworkImage(
                                      imageUrl: settings.qrUrl,
                                      height: 220,
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
                                  TextButton.icon(
                                    onPressed: isUploading
                                        ? null
                                        : () => _downloadReservationQr(
                                            settings.qrUrl,
                                          ),
                                    icon: const Icon(Icons.download),
                                    label: const Text('Download QR'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Screenshot or scan this QR, then upload your payment proof below.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: referenceController,
                        keyboardType: TextInputType.number,
                        maxLength: 13,
                        enabled: !isUploading,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Reference number (6 to 13 digits)',
                          counterText: '',
                          labelStyle: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: AppColors.darkBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: isUploading ? null : pickReceipt,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          receiptFile == null
                              ? 'Upload payment screenshot'
                              : 'Receipt selected',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isUploading
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isUploading ? null : confirmPayment,
                    icon: isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(isUploading ? 'Uploading...' : 'Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      referenceController.dispose();
    }
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

  Widget _buildPaymentBreakdownRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: isDiscount
                  ? AppColors.success
                  : isTotal
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${isDiscount ? '-' : ''}PHP ${formatAmount(amount, decimalDigits: 0)}',
          style: TextStyle(
            color: isDiscount
                ? AppColors.success
                : isTotal
                ? AppColors.primary
                : AppColors.textPrimary,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }



  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (_vehicle == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            'Vehicle not found',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final brand = _vehicle!['brand'] ?? 'Unknown';
    final model = _vehicle!['model'] ?? 'Model';
    final year = _vehicle!['year']?.toString() ?? '';
    final category = _vehicle!['category'] ?? 'Standard';
    final pricePerDay = (_vehicle!['price_per_day'] as num?)?.toDouble() ?? 0.0;
    final pricePerHour =
        (_vehicle!['price_per_hour'] as num?)?.toDouble() ?? 0.0;
    final vehicleType = _vehicle!['vehicle_type'] ?? 'Standard';
    final color = _vehicle!['color'] ?? 'Unknown';
    final seats = _vehicle!['seats'] ?? 5;
    final transmission = _vehicle!['transmission'] ?? 'Manual';
    final plateNumber = _vehicle!['plate_number'] ?? 'N/A';
    final fuelType = _vehicle!['fuel_type'] ?? 'Gasoline';
    final description = _vehicle!['description'] ?? 'No description available.';
    final isPartnerVehicle =
        _vehicle!['source']?.toString().toLowerCase() == 'partner' ||
        _vehicle!['is_partner_vehicle'] == true ||
        _vehicle!['owner_role']?.toString().toLowerCase() == 'partner' ||
        _vehicle!['partner_vehicle_id'] != null ||
        _vehicle!['partner_name'] != null;
    final vehicleRating = (_vehicle!['rating'] as num?)?.toDouble() ?? 0.0;
    final vehicleRatingCount =
        (_vehicle!['rating_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          // Image header with back button
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.darkBg,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: _toggleFavorite,
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: VehicleImageCarousel(
                key: ValueKey('vehicle-detail-${widget.vehicleId}'),
                vehicle: _vehicle!,
                height: 280,
                isThumbnail: false,
                backgroundColor: AppColors.darkBgTertiary,
                iconColor: AppColors.textTertiary,
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _VehicleSourceBadge(
                            label: isPartnerVehicle ? 'PSDC PARTNER' : 'PSDC',
                            emphasized: true,
                          ),
                          _VehicleSourceBadge(
                            label: category.toString().toUpperCase(),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _openVehicleRatings,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                vehicleRating > 0
                                    ? '${vehicleRating.toStringAsFixed(1)} ($vehicleRatingCount)'
                                    : 'See ratings',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title and year
                  Text(
                    '$brand $model',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (year.isNotEmpty)
                    Text(
                      year,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Price
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          AppColors.primary.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pricePerHour > 0 ? 'Price per hour' : 'Price per day',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '₱${formatAmount(pricePerHour > 0 ? pricePerHour : pricePerDay)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Specs grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecCard(
                          Icons.directions_car,
                          'Type',
                          vehicleType.toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSpecCard(
                          Icons.palette_outlined,
                          'Color',
                          color.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecCard(
                          Icons.airline_seat_recline_normal,
                          'Seats',
                          seats.toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSpecCard(
                          Icons.settings_outlined,
                          'Transmission',
                          transmission.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecCard(
                          Icons.confirmation_number_outlined,
                          'Plate No.',
                          plateNumber.toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSpecCard(
                          Icons.local_gas_station_outlined,
                          'Fuel Type',
                          fuelType.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Rental Mode Toggle (Daily vs Hourly)
                  const Text(
                    'Rental Mode',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _bookingMode = BookingMode.daily;
                                if (_startTime != null) {
                                  _returnTime = _startTime;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _bookingMode == BookingMode.daily
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: _bookingMode == BookingMode.daily
                                        ? Colors.black
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Daily Rental',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _bookingMode == BookingMode.daily
                                          ? Colors.black
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _bookingMode = BookingMode.hourly;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _bookingMode == BookingMode.hourly
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 16,
                                    color: _bookingMode == BookingMode.hourly
                                        ? Colors.black
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Hourly Rental',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _bookingMode == BookingMode.hourly
                                          ? Colors.black
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date selection
                  const Text(
                    'Select Dates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _selectDates,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.darkBgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedStartDate != null
                                      ? '${_formatDate(_selectedStartDate!)} - ${_formatDate(_selectedEndDate!)}'
                                      : 'Choose rental period',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _selectedStartDate != null
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                if (_selectedStartDate != null)
                                  Text(
                                    '$_billableHours hour${_billableHours == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Unavailable dates notice
                  if (_unavailableDates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_unavailableDates.length} date${_unavailableDates.length > 1 ? 's' : ''} unavailable',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  if (_selectedStartDate != null &&
                      _selectedEndDate != null) ...[
                    _buildTimeAvailabilitySection(),
                    const SizedBox(height: 18),
                  ],

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _withDriver
                              ? Icons.person_pin_circle
                              : Icons.drive_eta,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need a Driver?',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Enable if you want operator to assign an available driver.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _withDriver,
                          activeColor: AppColors.primary,
                          onChanged: (value) {
                            setState(() {
                              _withDriver = value;
                              if (value) _vehicleDelivery = false;
                              // Reset location selections when toggling driver
                              if (!value) {
                                _pickupProvince = null;
                                _pickupCity = null;
                                _pickupBarangay = null;
                                _pickupFreetext = null;
                                _pickupMapPin = null;
                                _pickupFreetextController.clear();
                                _deliveryDistanceKm = null;
                              }
                            });
                            if (value) _refreshDeliveryEstimate();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Driver delivery requires a pickup. Every rental still
                  // records its own trip destination below.
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vehicle Delivery',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Have the vehicle delivered without hiring a driver.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _vehicleDelivery,
                          activeThumbColor: AppColors.primary,
                          onChanged: _withDriver
                              ? null
                              : (value) {
                                  setState(() {
                                    _vehicleDelivery = value;
                                    if (!value) {
                                      _pickupProvince = null;
                                      _pickupCity = null;
                                      _pickupBarangay = null;
                                      _pickupFreetext = null;
                                      _pickupMapPin = null;
                                      _pickupFreetextController.clear();
                                      _deliveryDistanceKm = null;
                                    }
                                  });
                                  if (value) _refreshDeliveryEstimate();
                                },
                        ),
                      ],
                    ),
                  ),

                  if (_requiresPickupMap) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Delivery / Pick-up Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMapLocationField(
                      label: 'Exact delivery / pickup address',
                      hint: 'Search or pin the pickup location',
                      controller: _pickupFreetextController,
                      pin: _pickupMapPin,
                      onChanged: (value) {
                        setState(() {
                          _pickupFreetext = value.trim().isEmpty ? null : value;
                          _pickupMapPin = null;
                          _deliveryDistanceKm = null;
                        });
                      },
                      onMapTap: () => _openLocationPicker(isPickup: true),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Text(
                    'Trip Destination',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Required for route planning and trip records.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMapLocationField(
                    label: 'Trip destination',
                    hint: 'Enter an address or place a map pin',
                    controller: _dropoffFreetextController,
                    pin: _dropoffMapPin,
                    onChanged: (value) {
                      setState(() {
                        _dropoffFreetext = value.trim().isEmpty ? null : value;
                        _dropoffMapPin = null;
                        _deliveryDistanceKm = null;
                      });
                    },
                    onMapTap: () => _openLocationPicker(isPickup: false),
                  ),

                  if (_requiresPickupMap) ...[
                    const SizedBox(height: 24),
                    _buildDeliverySafetyNote(),
                  ],
                  const SizedBox(height: 24),
                  _buildEmergencyContactCard(),
                  const SizedBox(height: 24),
                  _buildBookingEvidenceCard(),
                  const SizedBox(height: 24),

                  // Cost breakdown & Voucher Selection (if dates selected)
                  if (_selectedStartDate != null && _selectedEndDate != null) ...[
                    _buildVoucherSelectionCard(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.darkBgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            'Rental mode',
                            _bookingMode == BookingMode.hourly ? 'Hourly rate' : 'Daily rate',
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Rate',
                            _bookingMode == BookingMode.hourly
                                ? '₱${formatAmount(((_vehicle?['price_per_hour'] as num?)?.toDouble() ?? 0.0))}/hr'
                                : '₱${formatAmount(pricePerDay)}/day',
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Duration',
                            _getFormattedDurationString(),
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Rental subtotal',
                            'PHP ${formatAmount(_rentalSubtotal)}',
                          ),
                          if (_requiresPickupMap) ...[
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Delivery fee',
                              'PHP ${formatAmount(_deliveryFee)}',
                            ),
                          ],
                          if (_discountAmount > 0) ...[
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Voucher / Loyalty Discount',
                              '- PHP ${formatAmount(_discountAmount)}',
                              isDiscount: true,
                            ),
                          ],
                          const Divider(
                            color: AppColors.borderColor,
                            height: 24,
                          ),
                          if (_requiresLongBookingReservation) ...[
                            _buildSummaryRow(
                              'Reservation fee',
                              '20% = PHP ${formatAmount(_reservationFeeAmount)}',
                            ),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Remaining balance',
                              'PHP ${formatAmount(_remainingBalance)}',
                            ),
                            const SizedBox(height: 8),
                          ],
                          _buildSummaryRow(
                            'Total',
                            '₱${formatAmount(_totalPrice)}',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          border: Border(
            top: BorderSide(color: AppColors.borderColor.withOpacity(0.5)),
          ),
        ),
        child: SafeArea(
          child: CustomButton(
            label: !_isVehicleBookable
                ? 'Vehicle Not Available'
                : _selectedStartDate != null &&
                      _startTime != null &&
                      _returnTime != null
                ? 'Book for ₱${formatAmount(_totalPrice)}'
                : _selectedStartDate == null
                ? 'Select Dates to Book'
                : 'Select Available Times',
            onPressed:
                _selectedStartDate != null &&
                    _startTime != null &&
                    _returnTime != null &&
                    _isVehicleBookable
                ? _handleBooking
                : null,
            isLoading: _isBooking,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: isDiscount
                ? AppColors.success
                : isTotal
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isDiscount
                ? AppColors.success
                : isTotal
                ? AppColors.primary
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildVoucherSelectionCard() {
    final hasVoucher = _selectedVoucher != null;
    final discount = _discountAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasVoucher ? AppColors.success : AppColors.borderColor,
          width: hasVoucher ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (hasVoucher ? AppColors.success : AppColors.primary)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.confirmation_number_outlined,
              color: hasVoucher ? AppColors.success : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasVoucher
                      ? '${_selectedVoucher!.title} Applied'
                      : 'Vouchers & Loyalty Rewards',
                  style: TextStyle(
                    color: hasVoucher ? AppColors.success : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasVoucher
                      ? 'Saved ₱${formatAmount(discount)} on this trip!'
                      : 'Tap to apply promo code or loyalty reward',
                  style: TextStyle(
                    color: hasVoucher
                        ? AppColors.success.withOpacity(0.85)
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (hasVoucher)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
              onPressed: () => setState(() => _selectedVoucher = null),
            )
          else
            TextButton(
              onPressed: _showVoucherPickerModalSheet,
              child: const Text(
                'Apply',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showVoucherPickerModalSheet() {
    final customCodeController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final availableVouchers = _getAvailableVouchersList();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Apply Voucher & Rewards',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customCodeController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Enter Promo Code',
                            hintStyle: const TextStyle(color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.darkBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borderColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () {
                          final code = customCodeController.text.trim().toUpperCase();
                          if (code.isEmpty) return;
                          final match = availableVouchers.firstWhere(
                            (v) => v.code.toUpperCase() == code,
                            orElse: () => LoyaltyVoucher(
                              code: code,
                              title: '$code Voucher',
                              description: 'Custom Promo Code',
                              discountPercent: 0.0,
                              discountAmount: 100.0,
                              isPercent: false,
                              minTripsRequired: 0,
                            ),
                          );
                          setState(() => _selectedVoucher = match);
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Available Discounts & Rewards',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (availableVouchers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No active vouchers available.',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: availableVouchers.map((v) {
                            final isSelected = _selectedVoucher?.code == v.code;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppColors.darkBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.borderColor,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.local_offer_outlined,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                title: Text(
                                  v.title,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight:
                                        isSelected ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  v.description,
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: AppColors.primary,
                                      )
                                    : OutlinedButton(
                                        onPressed: () {
                                          setState(() => _selectedVoucher = v);
                                          Navigator.pop(context);
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(color: AppColors.primary),
                                        ),
                                        child: const Text('Select'),
                                      ),
                                onTap: () {
                                  setState(() => _selectedVoucher = v);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }).toList(),
                        ),
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

  List<LoyaltyVoucher> _getAvailableVouchersList() {
    final list = <LoyaltyVoucher>[];
    if (_loyaltyRewardState != null) {
      // Prioritize redeemed milestones from loyalty card, falling back to unlocked milestones
      final stamps = _loyaltyRewardState!.redeemedMilestones.isNotEmpty
          ? _loyaltyRewardState!.redeemedMilestones
          : _loyaltyRewardState!.unlockedMilestones.map((m) => m.stamp).toSet();

      for (final stamp in stamps) {
        if (stamp == 3) {
          list.add(
            const LoyaltyVoucher(
              code: 'LOYALTY50',
              title: '₱50 OFF Loyalty Reward',
              description: 'Redeemed from PSDC Loyalty Reward Card (3 trips)',
              discountPercent: 0.0,
              discountAmount: 50.0,
              isPercent: false,
              minTripsRequired: 3,
            ),
          );
        } else if (stamp == 6) {
          list.add(
            const LoyaltyVoucher(
              code: 'LOYALTY200',
              title: '₱200 OFF Loyalty Reward',
              description: 'Redeemed from PSDC Loyalty Reward Card (6 trips)',
              discountPercent: 0.0,
              discountAmount: 200.0,
              isPercent: false,
              minTripsRequired: 6,
            ),
          );
        } else if (stamp == 12) {
          list.add(
            const LoyaltyVoucher(
              code: 'LOYALTY300',
              title: '₱300 OFF Loyalty Reward',
              description: 'Redeemed from PSDC Loyalty Reward Card (12 trips)',
              discountPercent: 0.0,
              discountAmount: 300.0,
              isPercent: false,
              minTripsRequired: 12,
            ),
          );
        } else if (stamp == 15) {
          final pricePerDay =
              (_vehicle?['price_per_day'] as num?)?.toDouble() ?? 0.0;
          final pricePerHour =
              (_vehicle?['price_per_hour'] as num?)?.toDouble() ?? 0.0;
          final hourlyRate =
              pricePerHour > 0 ? pricePerHour : (pricePerDay / 24.0);
          list.add(
            LoyaltyVoucher(
              code: 'LOYALTY_FREE3H',
              title: 'Free 3 Hours Rental Reward',
              description: 'Redeemed from PSDC Loyalty Reward Card (15 trips)',
              discountPercent: 0.0,
              discountAmount: hourlyRate * 3,
              isPercent: false,
              minTripsRequired: 15,
            ),
          );
        } else if (stamp == 18) {
          final pricePerDay =
              (_vehicle?['price_per_day'] as num?)?.toDouble() ?? 0.0;
          list.add(
            LoyaltyVoucher(
              code: 'LOYALTY_FREE24H',
              title: 'Free 24 Hours Rental Reward',
              description: 'Redeemed from PSDC Loyalty Reward Card (18 trips)',
              discountPercent: 0.0,
              discountAmount: pricePerDay,
              isPercent: false,
              minTripsRequired: 18,
            ),
          );
        }
      }
    }

    final completedTrips = _loyaltyRewardState?.successfulTrips ?? 0;
    for (final sysVoucher in LoyaltyService.systemVouchers) {
      if (completedTrips >= sysVoucher.minTripsRequired) {
        if (!list.any((v) => v.code == sysVoucher.code)) {
          list.add(sysVoucher);
        }
      }
    }

    return list;
  }

  String _format12Hour(int hour, [int minute = 0]) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Widget _buildReadOnlySlotGrid({
    required DateTime date,
    required Set<int> availableHours,
  }) {
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(date, now);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 340 ? 3 : 4;
        const spacing = 8.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var hour = 0; hour <= 23; hour++)
              SizedBox(
                width: width,
                child: _TimeSlotTile(
                  label: _format12Hour(hour),
                  isAvailable: availableHours.contains(hour) &&
                      (!isToday || hour > now.hour),
                  isSelected: false,
                  onTap: null,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSelectableSlotGrid({
    required DateTime date,
    required List<DateTime> availableSlots,
    required TimeOfDay? selectedTime,
    required ValueChanged<DateTime> onSelected,
  }) {
    final availableByHour = <int, DateTime>{
      for (final slot in availableSlots) slot.hour: slot,
    };
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(date, now);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 340 ? 3 : 4;
        const spacing = 8.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var hour = 0; hour <= 23; hour++)
              SizedBox(
                width: width,
                child: _TimeSlotTile(
                  label: _format12Hour(hour),
                  isAvailable: availableByHour.containsKey(hour) &&
                      (!isToday || hour > now.hour),
                  isSelected: selectedTime?.hour == hour,
                  onTap: (availableByHour[hour] == null || (isToday && hour <= now.hour))
                      ? null
                      : () => onSelected(availableByHour[hour]!),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTimeAvailabilitySection() {
    final startDate = _selectedStartDate;
    final endDate = _selectedEndDate;
    if (startDate == null || endDate == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Select available times',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Unavailable times are shown but disabled. Changing dates resets both selections.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          if (_isLoadingTimeSlots) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.darkBgTertiary,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Pickup Time - ${_formatDate(startDate)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildSelectableSlotGrid(
            date: startDate,
            availableSlots: _availableStartSlots,
            selectedTime: _startTime,
            onSelected: _selectStartSlot,
          ),
          if (_bookingMode == BookingMode.hourly) ...[
            const SizedBox(height: 18),
            Text(
              'Return Time - ${_formatDate(endDate)}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (_startTime == null)
              const Text(
                'Select a pickup time first.',
                style: TextStyle(color: AppColors.warning, fontSize: 11),
              ),
            const SizedBox(height: 8),
            _buildSelectableSlotGrid(
              date: endDate,
              availableSlots: _startTime == null
                  ? const <DateTime>[]
                  : _availableReturnSlots,
              selectedTime: _returnTime,
              onSelected: (slot) {
                setState(() => _returnTime = TimeOfDay.fromDateTime(slot));
              },
            ),
          ] else if (_startTime != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daily Mode: Return time is automatically set to ${_format12Hour(_startTime!.hour, _startTime!.minute)} on ${_formatDate(endDate)}.',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildDeliverySafetyNote() {
    final distance = _deliveryDistanceKm;
    final fee = _deliveryFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Note',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Doorstep delivery is PHP ${formatAmount(PricingPolicy.deliveryRatePerKm, decimalDigits: 0)} per kilometer.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (_requiresPickupMap) ...[
                  const SizedBox(height: 12),
                  if (_isCalculatingDeliveryFee)
                    const LinearProgressIndicator(color: AppColors.primary)
                  else if (distance != null)
                    Column(
                      children: [
                        _buildSummaryRow(
                          'Delivery distance',
                          '${distance.toStringAsFixed(2)} km',
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Rate per kilometer',
                          'PHP ${formatAmount(PricingPolicy.deliveryRatePerKm)}',
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Delivery fee',
                          'PHP ${formatAmount(fee)}',
                        ),
                      ],
                    )
                  else
                    TextButton.icon(
                      onPressed: _refreshDeliveryEstimate,
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('Estimate delivery fee'),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactCard() {
    final contact = _defaultEmergencyContact;
    final hasContact = contact != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasContact ? AppColors.borderColor : AppColors.warning,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Emergency Contact',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasContact
                      ? AppColors.success.withOpacity(0.15)
                      : AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasContact ? 'Saved' : 'Required',
                  style: TextStyle(
                    color: hasContact ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This helps PSDC contact someone quickly if the renter or driver is involved in an accident or emergency.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (_isLoadingEmergencyContact)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (hasContact) ...[
            _buildEmergencyContactRow(
              Icons.person_outline,
              contact['full_name']?.toString() ?? 'Unknown',
            ),
            const SizedBox(height: 10),
            _buildEmergencyContactRow(
              Icons.family_restroom_outlined,
              contact['relationship']?.toString() ?? 'Relationship not set',
            ),
            const SizedBox(height: 10),
            _buildEmergencyContactRow(
              Icons.phone_outlined,
              contact['phone_number']?.toString() ?? 'Phone not set',
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Add at least one emergency contact before submitting this booking.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openEmergencyContactScreen,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                hasContact ? 'Edit Emergency Contact' : 'Add Emergency Contact',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingEvidenceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Booking Identity & Safety',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Required before booking so PSDC, the operator, and the partner can verify the renter tied to this trip.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildSignatureCaptureButton(
            signatureBytes: _signatureBytes,
            label: 'Digital signature *',
            onTap: () => _openSignatureCapture(coTraveler: false),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEvidenceButton(
                  label: _validIdPhoto == null ? 'Upload valid ID' : 'ID ready',
                  icon: Icons.badge_outlined,
                  isReady: _validIdPhoto != null,
                  onTap: () => _pickBookingEvidencePhoto(isSelfie: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildEvidenceButton(
                  label: _selfiePhoto == null ? 'Take selfie' : 'Selfie ready',
                  icon: Icons.face_retouching_natural_outlined,
                  isReady: _selfiePhoto != null,
                  onTap: () => _pickBookingEvidencePhoto(isSelfie: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderColor),
          const SizedBox(height: 12),
          const Text(
            'Co-traveler information (required)',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildBookingEvidenceField(
            controller: _coTravelerNameController,
            label: 'Full name',
            hint: 'Co-traveler legal name',
            icon: Icons.person_add_alt_1_outlined,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _buildBookingEvidenceField(
            controller: _coTravelerPhoneController,
            label: 'Phone',
            hint: '09171234567',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: philippineMobileInputFormatters,
          ),
          const SizedBox(height: 12),
          _buildBookingEvidenceField(
            controller: _coTravelerLicenseController,
            label: "Driver's License Number",
            hint: 'e.g. N01-23-456789',
            icon: Icons.credit_card_outlined,
            maxLength: 13,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
              LengthLimitingTextInputFormatter(13),
            ],
          ),
          const SizedBox(height: 12),
          _buildSignatureCaptureButton(
            signatureBytes: _coTravelerSignatureBytes,
            label: 'Co-traveler digital signature *',
            onTap: () => _openSignatureCapture(coTraveler: true),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEvidenceButton(
                  label: _coTravelerValidIdPhoto == null
                      ? 'Co-traveler ID'
                      : 'Co-traveler ID ready',
                  icon: Icons.badge_outlined,
                  isReady: _coTravelerValidIdPhoto != null,
                  onTap: () => _pickBookingEvidencePhoto(
                    isSelfie: false,
                    isCoTraveler: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildEvidenceButton(
                  label: _coTravelerSelfiePhoto == null
                      ? 'Co-traveler selfie'
                      : 'Selfie ready',
                  icon: Icons.face_retouching_natural_outlined,
                  isReady: _coTravelerSelfiePhoto != null,
                  onTap: () => _pickBookingEvidencePhoto(
                    isSelfie: true,
                    isCoTraveler: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCaptureButton({
    required Uint8List? signatureBytes,
    required String label,
    required VoidCallback onTap,
  }) {
    final hasSignature = signatureBytes != null && signatureBytes.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkBgTertiary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasSignature ? AppColors.success : AppColors.borderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: hasSignature ? Colors.white : AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasSignature
                  ? Image.memory(signatureBytes, fit: BoxFit.contain)
                  : const Icon(Icons.draw_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasSignature
                        ? 'Signature saved. Tap to edit.'
                        : 'Tap to open the full-screen signature page.',
                    style: TextStyle(
                      color: hasSignature
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasSignature ? Icons.edit_outlined : Icons.chevron_right,
              color: hasSignature ? AppColors.success : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceButton({
    required String label,
    required IconData icon,
    required bool isReady,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: isReady ? AppColors.success : AppColors.primary,
        side: BorderSide(
          color: isReady ? AppColors.success : AppColors.primary,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildBookingEvidenceField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      onChanged: (_) {
        _touchedEvidenceFields.add(controller);
        setState(() {});
      },
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        errorText: _bookingEvidenceFieldError(controller),
        filled: true,
        fillColor: AppColors.darkBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  String? _bookingEvidenceFieldError(TextEditingController controller) {
    if (!_touchedEvidenceFields.contains(controller)) return null;
    if (identical(controller, _coTravelerNameController)) {
      return validatePersonName(controller.text, fieldName: 'Co-traveler name');
    }
    if (identical(controller, _coTravelerPhoneController)) {
      return validatePhilippineMobile(controller.text);
    }
    if (identical(controller, _coTravelerLicenseController)) {
      final requiredError = validateRequiredText(
        controller.text,
        fieldName: "Driver's license number",
        minLength: 6,
      );
      if (requiredError != null) return requiredError;
      if (!RegExp(r'^[A-Za-z0-9-]{6,13}$').hasMatch(controller.text.trim())) {
        return 'Use 6-13 letters, numbers, or hyphens.';
      }
    }
    return null;
  }

  Widget _buildSpecCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${months[date.month - 1]} ${date.day}';
  }

  String _getPickupLocation() {
    if (!_requiresPickupMap) {
      return PhilippineLocations.psdc_garage;
    }
    if (_pickupMapPin != null) {
      return _pickupMapPin!.address;
    }
    if (_pickupBarangay != null &&
        _pickupCity != null &&
        _pickupProvince != null) {
      final selectedLocation = PhilippineLocations.formatLocation(
        _pickupBarangay!,
        _pickupCity!,
        _pickupProvince!,
      );
      return _appendLandmark(_pickupFreetext, selectedLocation);
    }
    return _pickupFreetext ?? PhilippineLocations.psdc_garage;
  }

  String _getDropoffLocation() {
    if (_dropoffMapPin != null) {
      return _dropoffMapPin!.address;
    }
    if (_dropoffBarangay != null &&
        _dropoffCity != null &&
        _dropoffProvince != null) {
      final selectedLocation = PhilippineLocations.formatLocation(
        _dropoffBarangay!,
        _dropoffCity!,
        _dropoffProvince!,
      );
      return _appendLandmark(_dropoffFreetext, selectedLocation);
    }
    return _dropoffFreetext ?? PhilippineLocations.psdc_garage;
  }

  String _appendLandmark(String? landmark, String selectedLocation) {
    final cleanLandmark = landmark?.trim();
    if (cleanLandmark == null || cleanLandmark.isEmpty) {
      return selectedLocation;
    }
    return '$cleanLandmark, $selectedLocation';
  }

  Future<_BookingLocationPin> _resolveLocationPin({
    required String address,
    required String fallbackLabel,
  }) async {
    final places = await locationFromAddress(address);
    if (places.isEmpty) {
      throw Exception('$fallbackLabel could not be resolved');
    }
    final place = places.first;
    final resolvedAddress = await _resolveCompleteAddress(
      place.latitude,
      place.longitude,
      fallbackAddress: address,
    );
    return _BookingLocationPin(
      address: resolvedAddress,
      latitude: place.latitude,
      longitude: place.longitude,
    );
  }

  Future<String> _resolveCompleteAddress(
    double latitude,
    double longitude, {
    required String fallbackAddress,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return fallbackAddress;
      final place = placemarks.first;
      final candidates = [
        place.street,
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
        place.postalCode,
        place.country,
      ];
      final parts = <String>[];
      for (final candidate in candidates.whereType<String>()) {
        final part = candidate.trim();
        if (part.isEmpty) continue;
        final normalized = part.toLowerCase();
        final isDuplicate = parts.any((existing) {
          final existingNormalized = existing.toLowerCase();
          return existingNormalized == normalized ||
              existingNormalized.contains(normalized) ||
              normalized.contains(existingNormalized);
        });
        if (!isDuplicate) parts.add(part);
      }
      final address = parts.join(', ');
      return address.isEmpty ? fallbackAddress : address;
    } catch (_) {
      return fallbackAddress;
    }
  }

  Future<void> _openLocationPicker({required bool isPickup}) async {
    final initialAddress = isPickup
        ? _getPickupLocation()
        : _getDropoffLocation();
    final initialPin = isPickup ? _pickupMapPin : _dropoffMapPin;
    final selectedPin = await showModalBottomSheet<_BookingLocationPin>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _LocationPinPickerSheet(
        title: isPickup ? 'Pin delivery pickup' : 'Pin trip destination',
        initialAddress: initialAddress,
        initialPin: initialPin,
        resolveFromAddress: (address) => _resolveLocationPin(
          address: address,
          fallbackLabel: isPickup ? 'Pickup location' : 'Trip destination',
        ),
        resolveAddress: _resolveCompleteAddress,
      ),
    );

    if (selectedPin == null || !mounted) return;
    _ResolvedPickupLocation? resolvedLocation;
    try {
      final placemarks = await placemarkFromCoordinates(
        selectedPin.latitude,
        selectedPin.longitude,
      );
      if (placemarks.isNotEmpty) {
        resolvedLocation = _matchPlacemarkToServiceArea(placemarks.first);
      }
    } catch (_) {
      resolvedLocation = null;
    }
    if (!mounted) return;
    setState(() {
      if (isPickup) {
        _pickupMapPin = selectedPin;
        _pickupFreetext = selectedPin.address;
        _pickupFreetextController.text = selectedPin.address;
        _pickupProvince = resolvedLocation?.province;
        _pickupCity = resolvedLocation?.city;
        _pickupBarangay = resolvedLocation?.barangay;
      } else {
        _dropoffMapPin = selectedPin;
        _dropoffFreetext = selectedPin.address;
        _dropoffFreetextController.text = selectedPin.address;
        _dropoffProvince = resolvedLocation?.province;
        _dropoffCity = resolvedLocation?.city;
        _dropoffBarangay = resolvedLocation?.barangay;
      }
      _deliveryDistanceKm = null;
    });
    await _refreshDeliveryEstimate();
  }

  Widget _buildLocationMapCard({
    required String title,
    required _BookingLocationPin? pin,
    required String fallbackAddress,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    final cleanAddress = pin?.address.trim().isNotEmpty == true
        ? pin!.address
        : fallbackAddress;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pin == null ? AppColors.borderColor : AppColors.primary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pin != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: MobilisLeafletMap(
                  interactive: false,
                  initialZoom: 15,
                  markers: [
                    MobilisMapMarker(
                      latitude: pin.latitude,
                      longitude: pin.longitude,
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              width: double.infinity,
              child: _buildMapPreviewFallback(
                hasPin: pin != null,
                compact: true,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pin == null ? 'No exact map pin selected yet.' : cleanAddress,
                  style: TextStyle(
                    color: pin == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (pin != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(actionLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreviewFallback({
    required bool hasPin,
    bool compact = false,
  }) {
    return ColoredBox(
      color: AppColors.darkBgTertiary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasPin ? Icons.location_pin : Icons.add_location_alt_outlined,
                color: AppColors.primary,
                size: compact ? 34 : 42,
              ),
              const SizedBox(height: 6),
              Text(
                hasPin
                    ? 'Map preview unavailable. Your pin and address are still saved.'
                    : 'Search or use your location to place a pin.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _useCurrentPickupLocation() async {
    if (_isLocatingPickup) return;

    setState(() => _isLocatingPickup = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please turn on location services first.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission is required to use this.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        throw Exception('Could not read your current address.');
      }

      final match = _matchPlacemarkToServiceArea(placemarks.first);
      if (match == null) {
        throw Exception(
          'Current location is outside the supported Luzon pickup list.',
        );
      }

      if (!mounted) return;
      final fullAddress = await _resolveCompleteAddress(
        position.latitude,
        position.longitude,
        fallbackAddress: PhilippineLocations.formatLocation(
          match.barangay,
          match.city,
          match.province,
        ),
      );
      if (!mounted) return;
      setState(() {
        _pickupProvince = match.province;
        _pickupCity = match.city;
        _pickupBarangay = match.barangay;
        _pickupMapPin = _BookingLocationPin(
          address: fullAddress,
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _pickupFreetext = fullAddress;
        _pickupFreetextController.text = fullAddress;
        _deliveryDistanceKm = null;
      });
      await _refreshDeliveryEstimate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pickup set to ${PhilippineLocations.formatLocation(match.barangay, match.city, match.province)}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLocatingPickup = false);
      }
    }
  }

  _ResolvedPickupLocation? _matchPlacemarkToServiceArea(Placemark placemark) {
    final province = _findProvinceMatch([
      placemark.administrativeArea,
      placemark.subAdministrativeArea,
    ]);
    if (province == null) return null;

    final city = _findCityMatch(province, [
      placemark.locality,
      placemark.subLocality,
      placemark.subAdministrativeArea,
    ]);
    if (city == null) return null;

    final barangay = _findBarangayMatch(city, [
      placemark.subLocality,
      placemark.thoroughfare,
      placemark.street,
      placemark.name,
    ]);
    if (barangay == null) return null;

    return _ResolvedPickupLocation(
      province: province,
      city: city,
      barangay: barangay,
    );
  }

  String? _findProvinceMatch(List<String?> candidates) {
    return _findBestLocationMatch(
      candidates,
      PhilippineLocations.getAllProvinces(),
    );
  }

  String? _findCityMatch(String province, List<String?> candidates) {
    return _findBestLocationMatch(
      candidates,
      PhilippineLocations.getCitiesForProvince(province),
    );
  }

  String? _findBarangayMatch(String city, List<String?> candidates) {
    return _findBestLocationMatch(
      candidates,
      PhilippineLocations.getBarangaysForCity(city),
    );
  }

  String? _findBestLocationMatch(
    List<String?> candidates,
    List<String> options,
  ) {
    for (final candidate in candidates) {
      final normalizedCandidate = _normalizeLocationText(candidate);
      if (normalizedCandidate.isEmpty) continue;

      for (final option in options) {
        final normalizedOption = _normalizeLocationText(option);
        if (normalizedCandidate == normalizedOption ||
            normalizedCandidate.contains(normalizedOption) ||
            normalizedOption.contains(normalizedCandidate)) {
          return option;
        }
      }
    }
    return null;
  }

  String _normalizeLocationText(String? value) {
    return (value ?? '')
        .toLowerCase()
        .replaceAll(
          RegExp(r'\b(province|city|municipality|barangay|brgy)\b'),
          '',
        )
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  Widget _buildMapLocationField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required _BookingLocationPin? pin,
    required ValueChanged<String> onChanged,
    required VoidCallback onMapTap,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: 2,
      minLines: 1,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        prefixIcon: Icon(
          pin == null ? Icons.location_on_outlined : Icons.location_on,
          color: pin == null ? AppColors.textSecondary : AppColors.success,
        ),
        suffixIcon: IconButton(
          tooltip: pin == null ? 'Open map' : 'Change map pin',
          onPressed: onMapTap,
          icon: const Icon(Icons.map_outlined),
          color: AppColors.primary,
        ),
        filled: true,
        fillColor: AppColors.darkBgSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: pin == null ? AppColors.borderColor : AppColors.success,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildUseCurrentLocationButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLocatingPickup ? null : _useCurrentPickupLocation,
        icon: _isLocatingPickup
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(Icons.my_location, size: 18),
        label: Text(
          _isLocatingPickup ? 'Locating...' : 'Use my current location',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildLocationDropdowns({
    required bool isPickup,
    required String? province,
    required String? city,
    required String? barangay,
    required String? freetext,
    required TextEditingController freetextController,
    required Function(String?) onProvinceChanged,
    required Function(String?) onCityChanged,
    required Function(String?) onBarangayChanged,
    required Function(String?) onFreetextChanged,
  }) {
    final allProvinces = PhilippineLocations.getAllProvinces();
    final cities = province != null
        ? PhilippineLocations.getCitiesForProvince(province)
        : [];
    final barangays = city != null
        ? PhilippineLocations.getBarangaysForCity(city)
        : [];
    if (freetextController.text != (freetext ?? '')) {
      freetextController.value = TextEditingValue(
        text: freetext ?? '',
        selection: TextSelection.collapsed(offset: (freetext ?? '').length),
      );
    }

    return Column(
      children: [
        // Province dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.darkBgTertiary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text(
              'Select Province',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            value: province,
            items: allProvinces.map((p) {
              return DropdownMenuItem<String>(
                value: p,
                child: Text(
                  p,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: onProvinceChanged,
            dropdownColor: AppColors.darkBgSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // City dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.darkBgTertiary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text(
              'Select City/Municipality',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            value: city,
            disabledHint: const Text(
              'Select Province first',
              style: TextStyle(color: AppColors.textTertiary),
            ),
            items: cities.map((c) {
              return DropdownMenuItem<String>(
                value: c,
                child: Text(
                  c,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: province != null ? onCityChanged : null,
            dropdownColor: AppColors.darkBgSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Barangay dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.darkBgTertiary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text(
              'Select Barangay',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            value: barangay,
            disabledHint: const Text(
              'Select City first',
              style: TextStyle(color: AppColors.textTertiary),
            ),
            items: barangays.map((b) {
              return DropdownMenuItem<String>(
                value: b,
                child: Text(
                  b,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: city != null ? onBarangayChanged : null,
            dropdownColor: AppColors.darkBgSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Free text input (landmark or specific address)
        TextField(
          controller: freetextController,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
          decoration: InputDecoration(
            hintText: 'Enter landmark or specific address (optional)',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.darkBgTertiary,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: (value) {
            onFreetextChanged(value);
          },
        ),
      ],
    );
  }
}

class _ResolvedPickupLocation {
  final String province;
  final String city;
  final String barangay;

  const _ResolvedPickupLocation({
    required this.province,
    required this.city,
    required this.barangay,
  });
}

class _VehicleSourceBadge extends StatelessWidget {
  final String label;
  final bool emphasized;

  const _VehicleSourceBadge({required this.label, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.primary
            : AppColors.primary.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: emphasized ? Colors.black : AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TimeSlotTile extends StatelessWidget {
  final String label;
  final bool isAvailable;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TimeSlotTile({
    required this.label,
    required this.isAvailable,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = isSelected
        ? AppColors.primary
        : isAvailable
        ? AppColors.darkBgTertiary
        : AppColors.error.withOpacity(0.08);
    final foreground = isSelected
        ? Colors.black
        : isAvailable
        ? AppColors.textPrimary
        : AppColors.textTertiary;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : isAvailable
                  ? AppColors.borderColor
                  : AppColors.error.withOpacity(0.25),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              decoration: isAvailable ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingLocationPin {
  final String address;
  final double latitude;
  final double longitude;

  const _BookingLocationPin({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class _LocationPinPickerSheet extends StatefulWidget {
  final String title;
  final String initialAddress;
  final _BookingLocationPin? initialPin;
  final Future<_BookingLocationPin> Function(String address) resolveFromAddress;
  final Future<String> Function(
    double latitude,
    double longitude, {
    required String fallbackAddress,
  })
  resolveAddress;

  const _LocationPinPickerSheet({
    required this.title,
    required this.initialAddress,
    required this.initialPin,
    required this.resolveFromAddress,
    required this.resolveAddress,
  });

  @override
  State<_LocationPinPickerSheet> createState() =>
      _LocationPinPickerSheetState();
}

class _LocationPinPickerSheetState extends State<_LocationPinPickerSheet> {
  late final TextEditingController _searchController;
  final MapController _mapController = MapController();
  _BookingLocationPin? _selectedPin;
  bool _isResolving = false;
  String? _errorMessage;

  static const _fallbackCenter = LatLng(15.9758, 120.5719);

  LatLng get _mapCenter => _selectedPin == null
      ? _fallbackCenter
      : LatLng(_selectedPin!.latitude, _selectedPin!.longitude);

  void _moveMap(_BookingLocationPin pin) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(LatLng(pin.latitude, pin.longitude), 16);
    });
  }

  Future<void> _openExpandedMap() async {
    final pin = await Navigator.of(context).push<_BookingLocationPin>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _ExpandedLocationMapScreen(
          title: widget.title,
          initialPin: _selectedPin,
          fallbackCenter: _mapCenter,
          resolveAddress: widget.resolveAddress,
        ),
      ),
    );
    if (pin == null || !mounted) return;
    setState(() {
      _selectedPin = pin;
      _searchController.text = pin.address;
      _errorMessage = null;
    });
    _moveMap(pin);
  }

  @override
  void initState() {
    super.initState();
    _selectedPin = widget.initialPin;
    _searchController = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _isResolving) return;
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });
    try {
      final pin = await widget.resolveFromAddress(query);
      if (!mounted) return;
      setState(() {
        _selectedPin = pin;
        _searchController.text = pin.address;
      });
      _moveMap(pin);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isResolving) return;
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please turn on location services first.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission is required to pin this.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );
      final address = await widget.resolveAddress(
        position.latitude,
        position.longitude,
        fallbackAddress: 'Pinned location',
      );
      final pin = _BookingLocationPin(
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _selectedPin = pin;
        _searchController.text = address;
      });
      _moveMap(pin);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  Future<void> _selectMapPoint(LatLng point) async {
    if (_isResolving) return;
    setState(() {
      _isResolving = true;
      _errorMessage = null;
      _selectedPin = _BookingLocationPin(
        address: 'Resolving pinned address...',
        latitude: point.latitude,
        longitude: point.longitude,
      );
    });
    try {
      final address = await widget.resolveAddress(
        point.latitude,
        point.longitude,
        fallbackAddress: 'Pinned location',
      );
      final pin = _BookingLocationPin(
        address: address,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted) return;
      setState(() {
        _selectedPin = pin;
        _searchController.text = address;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = (screenHeight * 0.9 - bottomInset)
        .clamp(420.0, screenHeight * 0.9)
        .toDouble();

    return SizedBox(
      height: sheetHeight,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Search an address or use your current location to set the exact pin.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchAddress(),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search complete address',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _isResolving ? null : _searchAddress,
                    icon: _isResolving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_outlined),
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: AppColors.darkBgTertiary,
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
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isResolving ? null : _useCurrentLocation,
                  icon: const Icon(Icons.gps_fixed_outlined, size: 18),
                  label: const Text('Use current location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 230,
                  width: double.infinity,
                  color: AppColors.darkBgTertiary,
                  child: Stack(
                    children: [
                      MobilisLeafletMap(
                        mapController: _mapController,
                        fallbackLatitude: _mapCenter.latitude,
                        fallbackLongitude: _mapCenter.longitude,
                        initialZoom: _selectedPin == null ? 12 : 16,
                        onTap: (latitude, longitude) =>
                            _selectMapPoint(LatLng(latitude, longitude)),
                        markers: _selectedPin == null
                            ? const []
                            : [
                                MobilisMapMarker(
                                  latitude: _selectedPin!.latitude,
                                  longitude: _selectedPin!.longitude,
                                  size: 46,
                                ),
                              ],
                      ),
                      const Positioned(
                        left: 10,
                        bottom: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xDD111827),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            child: Text(
                              'Tap the map to place the pin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: const Color(0xDD111827),
                          borderRadius: BorderRadius.circular(10),
                          child: IconButton(
                            tooltip: 'Expand map',
                            onPressed: _openExpandedMap,
                            icon: const Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (_isResolving)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x33000000),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_selectedPin != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPin!.address,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedPin!.latitude.toStringAsFixed(5)}, ${_selectedPin!.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedPin == null
                      ? null
                      : () => Navigator.pop(context, _selectedPin),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Use this location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.darkBg,
                    disabledBackgroundColor: AppColors.darkBgTertiary,
                    disabledForegroundColor: AppColors.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedLocationMapScreen extends StatefulWidget {
  final String title;
  final _BookingLocationPin? initialPin;
  final LatLng fallbackCenter;
  final Future<String> Function(
    double latitude,
    double longitude, {
    required String fallbackAddress,
  })
  resolveAddress;

  const _ExpandedLocationMapScreen({
    required this.title,
    required this.initialPin,
    required this.fallbackCenter,
    required this.resolveAddress,
  });

  @override
  State<_ExpandedLocationMapScreen> createState() =>
      _ExpandedLocationMapScreenState();
}

class _ExpandedLocationMapScreenState
    extends State<_ExpandedLocationMapScreen> {
  final MapController _mapController = MapController();
  _BookingLocationPin? _selectedPin;
  bool _isResolving = false;

  LatLng get _center => _selectedPin == null
      ? widget.fallbackCenter
      : LatLng(_selectedPin!.latitude, _selectedPin!.longitude);

  @override
  void initState() {
    super.initState();
    _selectedPin = widget.initialPin;
  }

  Future<void> _selectPoint(LatLng point) async {
    if (_isResolving) return;
    setState(() {
      _isResolving = true;
      _selectedPin = _BookingLocationPin(
        address: 'Resolving pinned address...',
        latitude: point.latitude,
        longitude: point.longitude,
      );
    });
    try {
      final address = await widget.resolveAddress(
        point.latitude,
        point.longitude,
        fallbackAddress: 'Pinned location',
      );
      if (!mounted) return;
      setState(() {
        _selectedPin = _BookingLocationPin(
          address: address,
          latitude: point.latitude,
          longitude: point.longitude,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isResolving) return;
    setState(() => _isResolving = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please turn on location services first.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission is required to pin this.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );
      final address = await widget.resolveAddress(
        position.latitude,
        position.longitude,
        fallbackAddress: 'Current location',
      );
      final pin = _BookingLocationPin(
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() => _selectedPin = pin);
      _mapController.move(LatLng(position.latitude, position.longitude), 17);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.darkBg,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Use current location',
            onPressed: _isResolving ? null : _useCurrentLocation,
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobilisLeafletMap(
              mapController: _mapController,
              fallbackLatitude: _center.latitude,
              fallbackLongitude: _center.longitude,
              initialZoom: _selectedPin == null ? 12 : 16,
              onTap: (latitude, longitude) =>
                  _selectPoint(LatLng(latitude, longitude)),
              markers: _selectedPin == null
                  ? const []
                  : [
                      MobilisMapMarker(
                        latitude: _selectedPin!.latitude,
                        longitude: _selectedPin!.longitude,
                        size: 54,
                      ),
                    ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.darkBgSecondary.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderColor),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 18),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _selectedPin?.address ??
                                'Tap the map to place a pin.',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectedPin == null || _isResolving
                            ? null
                            : () => Navigator.pop(context, _selectedPin),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.darkBg,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isResolving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.darkBg,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          _isResolving
                              ? 'Resolving address...'
                              : 'Use this location',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isResolving)
            const Positioned(
              top: 16,
              left: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xDD111827),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Getting accurate address...',
                        style: TextStyle(color: Colors.white, fontSize: 11),
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
