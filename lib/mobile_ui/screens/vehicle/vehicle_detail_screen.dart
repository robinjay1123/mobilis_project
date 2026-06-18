import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/favorite_vehicle_service.dart';
import '../../../services/reservation_payment_service.dart';
import '../../../services/terms_service.dart';
import '../../../services/verification_service.dart';
import '../../../utils/locations.dart';
import '../../../utils/web_html.dart' as html;

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
  Map<String, dynamic>? _vehicle;
  bool _isLoading = true;
  bool _isBooking = false;
  bool _isFavorite = false;
  bool _isLocatingPickup = false;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  List<DateTime> _unavailableDates = [];
  List<Map<String, dynamic>> _myBookings = [];
  bool _withDriver = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _returnTime = const TimeOfDay(hour: 6, minute: 0);
  String? _acceptedTermsSnapshot;

  // Location selection state
  String? _pickupProvince;
  String? _pickupCity;
  String? _pickupBarangay;
  String? _pickupFreetext;
  String? _dropoffProvince;
  String? _dropoffCity;
  String? _dropoffBarangay;
  String? _dropoffFreetext;
  final TextEditingController _pickupFreetextController =
      TextEditingController();
  final TextEditingController _dropoffFreetextController =
      TextEditingController();

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
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vehicleService = VehicleService();

      // Use passed data or fetch from database
      if (widget.vehicleData != null) {
        _vehicle = widget.vehicleData;
      } else {
        _vehicle = await vehicleService.getVehicleById(widget.vehicleId);
      }

      // Get unavailable dates
      _unavailableDates = await vehicleService.getUnavailableDates(
        widget.vehicleId,
      );
      await _loadMyBookings();
      await _loadFavoriteState();
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
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final initialDate = _clampToBookableDate(
      _selectedStartDate ?? firstDate.add(const Duration(days: 1)),
    );
    var initialEnd = _clampToBookableDate(_selectedEndDate ?? initialDate);
    if (initialEnd.isBefore(initialDate)) initialEnd = initialDate;

    final DateTimeRange? picked = await _showBookingCalendarDialog(
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
      initialStart: _selectedStartDate ?? initialDate,
      initialEnd: _selectedEndDate ?? initialEnd,
    );

    if (picked == null) {
      if (!mounted) return;
      if (_selectedStartDate != null || _selectedEndDate != null) {
        setState(() {
          _selectedStartDate = null;
          _selectedEndDate = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
      });
    }
  }

  Future<DateTimeRange?> _showBookingCalendarDialog({
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime initialStart,
    required DateTime initialEnd,
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
                        onRangeSelected: (start, end, focused) {
                          final startDay = start == null
                              ? null
                              : _dateOnly(start);
                          final endDay = end == null ? null : _dateOnly(end);
                          if ((startDay != null &&
                                  bookedDays.contains(startDay)) ||
                              (endDay != null && bookedDays.contains(endDay))) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('That date is unavailable'),
                                backgroundColor: AppColors.error,
                              ),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selected range includes unavailable dates',
                                ),
                                backgroundColor: AppColors.error,
                              ),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('That date is unavailable'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            if (rangeStart == null ||
                                (rangeStart != null && rangeEnd != null)) {
                              rangeStart = selectedDay;
                              rangeEnd = null;
                            } else if (selectedDay.isBefore(rangeStart!)) {
                              rangeEnd = rangeStart;
                              rangeStart = selectedDay;
                            } else {
                              if (_rangeContainsBlockedDate(
                                rangeStart!,
                                selectedDay,
                                bookedDays,
                              )) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Selected range includes unavailable dates',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }
                              rangeEnd = selectedDay;
                            }
                            focusedDay = focused;
                          });
                        },
                        onDayLongPressed: (selectedDay, focused) {
                          final selectedDate = _dateOnly(selectedDay);
                          if (myBookedDays.contains(selectedDate)) {
                            _showBookedDateDetails(
                              selectedDate,
                              myBookedDetails,
                            );
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
    return candidate.isAfter(upperBound) ? upperBound : candidate;
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
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, _startTime.hour, _startTime.minute);
  }

  DateTime? get _endAtLocal {
    final d = _selectedEndDate;
    if (d == null) return null;
    return DateTime(
      d.year,
      d.month,
      d.day,
      _returnTime.hour,
      _returnTime.minute,
    );
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

  double get _totalPrice {
    final pricePerHour =
        (_vehicle?['price_per_hour'] as num?)?.toDouble() ?? 0.0;
    if (pricePerHour > 0) return pricePerHour * _billableHours;

    final pricePerDay = (_vehicle?['price_per_day'] as num?)?.toDouble() ?? 0.0;
    final days = _selectedStartDate == null || _selectedEndDate == null
        ? 0
        : _selectedEndDate!.difference(_selectedStartDate!).inDays + 1;
    return pricePerDay * (days < 0 ? 0 : days);
  }

  Future<void> _selectTime({required bool isStartTime}) async {
    final initial = isStartTime ? _startTime : _returnTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStartTime) {
        _startTime = picked;
      } else {
        _returnTime = picked;
      }
    });
  }

  Future<void> _handleBooking() async {
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

      final createdBooking = await BookingService().createBooking(
        renterId: currentUser.id,
        vehicleId: widget.vehicleId,
        startAt: startAtLocal.toUtc(),
        endAt: endAtLocal.toUtc(),
        totalPrice: _totalPrice,
        withDriver: _withDriver,
        pickupLocation: _getPickupLocation(),
        dropoffLocation: _getDropoffLocation(),
        rentalTermsAcceptedAt: requireTermsAgreement ? DateTime.now() : null,
        rentalTermsSnapshot: requireTermsAgreement
            ? _acceptedTermsSnapshot
            : null,
        reservationFeeAmount: reservationPaymentProof?.amount,
        reservationPaymentReference: reservationPaymentProof?.referenceNumber,
        reservationPaymentProofUrl: reservationPaymentProof?.proofUrl,
        reservationPaymentMethod: reservationPaymentProof?.method,
        reservationPaymentType: reservationPaymentProof?.paymentType,
      );

      if (reservationPaymentProof != null) {
        final bookingId = createdBooking['id']?.toString();
        if (bookingId != null && bookingId.isNotEmpty) {
          try {
            await ReservationPaymentService().createReceiptRecord(
              bookingId: bookingId,
              renterId: currentUser.id,
              proof: reservationPaymentProof,
            );
          } catch (e) {
            debugPrint('Booking created but receipt audit insert failed: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Booking saved, but receipt audit failed: $e'),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
          }
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.darkBgSecondary,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Booking Requested',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your booking request and reservation payment proof have been submitted. You will be notified once the operator and owner respond.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.darkBgTertiary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        'Duration',
                        '$_billableHours hour${_billableHours == 1 ? '' : 's'}',
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Total',
                        '₱${_totalPrice.toStringAsFixed(2)}',
                        isTotal: true,
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Service',
                        _withDriver ? 'With Driver' : 'Self-Drive',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );
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
                  ),
                  child: const Text('Agree & Continue'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    return acceptedTerms ? terms : null;
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
              final payableAmount = payFullAmount
                  ? _totalPrice
                  : settings.amount;
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
                    ? _totalPrice
                    : settings.amount;
                if (settings.qrUrl.trim().isEmpty) {
                  setDialogState(() {
                    errorText =
                        'Payment QR is not configured yet. Please contact support.';
                  });
                  return;
                }
                if (!RegExp(r'^\d{13}$').hasMatch(reference)) {
                  setDialogState(() {
                    errorText =
                        'Enter the 13-digit transaction reference number.';
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
                            : 'Pay refundable reservation fee',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PHP ${payableAmount.toStringAsFixed(0)} to ${settings.accountName}',
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
                            ? '${settings.instructions}\n\nYou selected full payment, so your proof should match the full rental total shown above.'
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
                                    child: Image.network(
                                      settings.qrUrl,
                                      height: 220,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
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
                          labelText: '13-digit reference number',
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

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            fontSize: isTotal ? 16 : 14,
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
    final imageUrl = _vehicle!['image_url'] as String?;

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
              background: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category.toString().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
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
                          '₱${(pricePerHour > 0 ? pricePerHour : pricePerDay).toStringAsFixed(2)}',
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
                              // Reset location selections when toggling driver
                              if (!value) {
                                _pickupProvince = null;
                                _pickupCity = null;
                                _pickupBarangay = null;
                                _pickupFreetext = null;
                                _pickupFreetextController.clear();
                                _dropoffProvince = null;
                                _dropoffCity = null;
                                _dropoffBarangay = null;
                                _dropoffFreetext = null;
                                _dropoffFreetextController.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Location selection (only show if driver is enabled)
                  if (_withDriver) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Pick-up Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildUseCurrentLocationButton(),
                    const SizedBox(height: 12),
                    _buildLocationDropdowns(
                      isPickup: true,
                      province: _pickupProvince,
                      city: _pickupCity,
                      barangay: _pickupBarangay,
                      freetext: _pickupFreetext,
                      freetextController: _pickupFreetextController,
                      onProvinceChanged: (value) {
                        setState(() {
                          _pickupProvince = value;
                          _pickupCity = null;
                          _pickupBarangay = null;
                        });
                      },
                      onCityChanged: (value) {
                        setState(() {
                          _pickupCity = value;
                          _pickupBarangay = null;
                        });
                      },
                      onBarangayChanged: (value) {
                        setState(() {
                          _pickupBarangay = value;
                        });
                      },
                      onFreetextChanged: (value) {
                        final cleanValue = value?.trim();
                        _pickupFreetext =
                            cleanValue == null || cleanValue.isEmpty
                            ? null
                            : value;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Drop-off Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLocationDropdowns(
                      isPickup: false,
                      province: _dropoffProvince,
                      city: _dropoffCity,
                      barangay: _dropoffBarangay,
                      freetext: _dropoffFreetext,
                      freetextController: _dropoffFreetextController,
                      onProvinceChanged: (value) {
                        setState(() {
                          _dropoffProvince = value;
                          _dropoffCity = null;
                          _dropoffBarangay = null;
                        });
                      },
                      onCityChanged: (value) {
                        setState(() {
                          _dropoffCity = value;
                          _dropoffBarangay = null;
                        });
                      },
                      onBarangayChanged: (value) {
                        setState(() {
                          _dropoffBarangay = value;
                        });
                      },
                      onFreetextChanged: (value) {
                        final cleanValue = value?.trim();
                        _dropoffFreetext =
                            cleanValue == null || cleanValue.isEmpty
                            ? null
                            : value;
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (_selectedStartDate != null &&
                      _selectedEndDate != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectTime(isStartTime: true),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.darkBgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderColor,
                                ),
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
                                      Icons.schedule,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Start time',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _startTime.format(context),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectTime(isStartTime: false),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.darkBgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderColor,
                                ),
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
                                      Icons.schedule_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Return time',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _returnTime.format(context),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Cost breakdown (if dates selected)
                  if (_selectedStartDate != null && _selectedEndDate != null)
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
                            ((_vehicle?['price_per_hour'] as num?)
                                            ?.toDouble() ??
                                        0.0) >
                                    0
                                ? 'Hourly rate'
                                : 'Daily rate',
                            ((_vehicle?['price_per_hour'] as num?)
                                            ?.toDouble() ??
                                        0.0) >
                                    0
                                ? '₱${((_vehicle?['price_per_hour'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'
                                : '₱${pricePerDay.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Duration',
                            ((_vehicle?['price_per_hour'] as num?)
                                            ?.toDouble() ??
                                        0.0) >
                                    0
                                ? '$_billableHours hour${_billableHours == 1 ? '' : 's'}'
                                : '${(_selectedEndDate!.difference(_selectedStartDate!).inDays + 1)} day${(_selectedEndDate!.difference(_selectedStartDate!).inDays + 1) == 1 ? '' : 's'}',
                          ),
                          const Divider(
                            color: AppColors.borderColor,
                            height: 24,
                          ),
                          _buildSummaryRow(
                            'Total',
                            '₱${_totalPrice.toStringAsFixed(2)}',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
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
            label: _selectedStartDate != null
                ? 'Book for ₱${_totalPrice.toStringAsFixed(2)}'
                : 'Select Dates to Book',
            onPressed: _selectedStartDate != null ? _handleBooking : null,
            isLoading: _isBooking,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.darkBgSecondary,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car,
              size: 80,
              color: AppColors.textTertiary.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'No image available',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
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
    if (!_withDriver) {
      return PhilippineLocations.psdc_garage;
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
    if (!_withDriver) {
      return PhilippineLocations.psdc_garage;
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
        desiredAccuracy: LocationAccuracy.high,
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
      setState(() {
        _pickupProvince = match.province;
        _pickupCity = match.city;
        _pickupBarangay = match.barangay;
      });
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
