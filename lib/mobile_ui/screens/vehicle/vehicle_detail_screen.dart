import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/verification_service.dart';
import '../../../utils/locations.dart';

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
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  List<DateTime> _unavailableDates = [];
  bool _withDriver = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _returnTime = const TimeOfDay(hour: 6, minute: 0);

  // Location selection state
  String? _pickupProvince;
  String? _pickupCity;
  String? _pickupBarangay;
  String? _pickupFreetext;
  String? _dropoffProvince;
  String? _dropoffCity;
  String? _dropoffBarangay;
  String? _dropoffFreetext;

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

  Future<void> _selectDates() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final initialDate = _firstAvailableDate(
      _selectedStartDate ?? now.add(const Duration(days: 1)),
    );
    final initialEnd = _firstAvailableDate(
      _selectedEndDate ?? initialDate.add(const Duration(days: 2)),
      from: initialDate,
    );

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
      initialDateRange: _selectedStartDate != null && _selectedEndDate != null
          ? DateTimeRange(start: _selectedStartDate!, end: _selectedEndDate!)
          : DateTimeRange(start: initialDate, end: initialEnd),
      selectableDayPredicate: (date, selectedStart, selectedEnd) =>
          !_isUnavailableDate(date),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.darkBgSecondary,
              onSurface: AppColors.textPrimary,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppColors.darkBgSecondary,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: AppColors.darkBg,
              headerForegroundColor: AppColors.textPrimary,
              rangePickerBackgroundColor: AppColors.darkBgSecondary,
              rangePickerHeaderBackgroundColor: AppColors.darkBg,
              rangePickerHeaderForegroundColor: AppColors.textPrimary,
              rangePickerSurfaceTintColor: Colors.transparent,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.textTertiary;
                }
                if (states.contains(WidgetState.selected)) {
                  return Colors.black;
                }
                return AppColors.textPrimary;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.all(AppColors.primary),
              todayBorder: const BorderSide(color: AppColors.primary),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.textTertiary;
                }
                if (states.contains(WidgetState.selected)) {
                  return Colors.black;
                }
                return AppColors.textPrimary;
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
            ),
            dialogBackgroundColor: AppColors.darkBgSecondary,
            scaffoldBackgroundColor: AppColors.darkBg,
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: AppColors.textPrimary,
              displayColor: AppColors.textPrimary,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: AppColors.darkBgTertiary,
              labelStyle: TextStyle(color: AppColors.textSecondary),
              hintStyle: TextStyle(color: AppColors.textTertiary),
              helperStyle: TextStyle(color: AppColors.textSecondary),
              errorStyle: TextStyle(color: AppColors.error),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Check if any selected date is unavailable
      bool hasUnavailable = false;
      var currentDate = picked.start;
      while (!currentDate.isAfter(picked.end)) {
        if (_unavailableDates.any(
          (d) =>
              d.year == currentDate.year &&
              d.month == currentDate.month &&
              d.day == currentDate.day,
        )) {
          hasUnavailable = true;
          break;
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      if (hasUnavailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Some selected dates are not available. Please choose different dates.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
      });
    }
  }

  DateTime _firstAvailableDate(DateTime preferred, {DateTime? from}) {
    final lowerBound = from == null
        ? DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          )
        : DateTime(from.year, from.month, from.day);
    var candidate = DateTime(preferred.year, preferred.month, preferred.day);
    if (candidate.isBefore(lowerBound)) candidate = lowerBound;
    for (var i = 0; i < 365; i++) {
      if (!_isUnavailableDate(candidate)) return candidate;
      candidate = candidate.add(const Duration(days: 1));
    }
    return lowerBound;
  }

  bool _isUnavailableDate(DateTime date) {
    return _unavailableDates.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
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
        _proceedWithBooking();
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
      _proceedWithBooking();
    } catch (e) {
      debugPrint('Error checking verification: $e');
      _showErrorDialog(
        'Error',
        'Unable to verify user status. Please try again.',
      );
    }
  }

  Future<void> _proceedWithBooking() async {
    final authService = AuthService();

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

    setState(() {
      _isBooking = true;
    });

    try {
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw Exception('You need to log in before booking.');
      }

      await BookingService().createBooking(
        renterId: currentUser.id,
        vehicleId: widget.vehicleId,
        startAt: startAtLocal.toUtc(),
        endAt: endAtLocal.toUtc(),
        totalPrice: _totalPrice,
        withDriver: _withDriver,
        pickupLocation: _getPickupLocation(),
        dropoffLocation: _getDropoffLocation(),
      );

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
                  'Your booking request has been sent to the owner. You will be notified once they respond.',
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
                                _dropoffProvince = null;
                                _dropoffCity = null;
                                _dropoffBarangay = null;
                                _dropoffFreetext = null;
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
                    _buildLocationDropdowns(
                      isPickup: true,
                      province: _pickupProvince,
                      city: _pickupCity,
                      barangay: _pickupBarangay,
                      freetext: _pickupFreetext,
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
                        setState(() {
                          _pickupFreetext = value;
                        });
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
                        setState(() {
                          _dropoffFreetext = value;
                        });
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
      return PhilippineLocations.formatLocation(
        _pickupBarangay!,
        _pickupCity!,
        _pickupProvince!,
      );
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
      return PhilippineLocations.formatLocation(
        _dropoffBarangay!,
        _dropoffCity!,
        _dropoffProvince!,
      );
    }
    return _dropoffFreetext ?? PhilippineLocations.psdc_garage;
  }

  Widget _buildLocationDropdowns({
    required bool isPickup,
    required String? province,
    required String? city,
    required String? barangay,
    required String? freetext,
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
    final freetextController = TextEditingController(text: freetext ?? '');

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
