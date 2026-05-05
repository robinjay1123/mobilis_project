import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../services/auth_service.dart';
import '../../../services/partner_service.dart';
import '../../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class VehicleAvailabilityScreen extends StatefulWidget {
  const VehicleAvailabilityScreen({super.key});

  @override
  State<VehicleAvailabilityScreen> createState() =>
      _VehicleAvailabilityScreenState();
}

class _VehicleAvailabilityScreenState extends State<VehicleAvailabilityScreen> {
  String? selectedVehicleId;
  List<Map<String, dynamic>> vehicles = [];
  Set<DateTime> unavailableDates = {};
  Set<DateTime> selectedDates = {};
  DateTime focusedDay = DateTime.now();
  CalendarFormat calendarFormat = CalendarFormat.month;

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final authService = AuthService();
      final partnerService = PartnerService();
      final user = authService.currentUser;

      if (user != null) {
        final profile = await partnerService.getPartnerProfile(user.id);
        if (profile != null) {
          final vehicleService = VehicleService();
          final vehicleList = await vehicleService.getPartnerVehicles(
            profile['id'] as String,
          );

          setState(() {
            vehicles = vehicleList;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadAvailability(String vehicleId) async {
    try {
      final vehicleService = VehicleService();
      final dates = await vehicleService.getUnavailableDates(vehicleId);

      setState(() {
        unavailableDates = dates.map((d) => _normalizeDate(d)).toSet();
        selectedDates.clear();
      });
    } catch (e) {
      debugPrint('Error loading availability: $e');
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isUnavailable(DateTime day) {
    return unavailableDates.contains(_normalizeDate(day));
  }

  bool _isSelected(DateTime day) {
    return selectedDates.contains(_normalizeDate(day));
  }

  void _toggleDateSelection(DateTime day) {
    final normalizedDay = _normalizeDate(day);

    setState(() {
      if (selectedDates.contains(normalizedDay)) {
        selectedDates.remove(normalizedDay);
      } else {
        selectedDates.add(normalizedDay);
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _markAsUnavailable() async {
    if (selectedVehicleId == null) {
      _showErrorSnackBar('Please select a vehicle first');
      return;
    }

    if (selectedDates.isEmpty) {
      _showErrorSnackBar('Please select dates to mark as unavailable');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final vehicleService = VehicleService();

      for (final date in selectedDates) {
        await vehicleService.setAvailability(
          vehicleId: selectedVehicleId!,
          date: date,
          isAvailable: false,
        );
      }

      setState(() {
        unavailableDates.addAll(selectedDates);
        selectedDates.clear();
      });

      _showSuccessSnackBar('Dates marked as unavailable');
    } catch (e) {
      _showErrorSnackBar('Failed to update availability');
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _markAsAvailable() async {
    if (selectedVehicleId == null) {
      _showErrorSnackBar('Please select a vehicle first');
      return;
    }

    if (selectedDates.isEmpty) {
      _showErrorSnackBar('Please select dates to mark as available');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final vehicleService = VehicleService();

      for (final date in selectedDates) {
        await vehicleService.clearAvailability(
          vehicleId: selectedVehicleId!,
          date: date,
        );
      }

      setState(() {
        for (final date in selectedDates) {
          unavailableDates.remove(date);
        }
        selectedDates.clear();
      });

      _showSuccessSnackBar('Dates marked as available');
    } catch (e) {
      _showErrorSnackBar('Failed to update availability');
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Vehicle Availability',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Column(
              children: [
                // Vehicle selector
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Vehicle',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.darkBgSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: vehicles.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No approved vehicles found',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedVehicleId,
                                  isExpanded: true,
                                  hint: const Text(
                                    'Choose a vehicle',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  dropdownColor: AppColors.darkBgSecondary,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                  items: vehicles.map((vehicle) {
                                    return DropdownMenuItem(
                                      value: vehicle['id'] as String,
                                      child: Text(
                                        '${vehicle['brand']} ${vehicle['model']} - ${vehicle['plate_number']}',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedVehicleId = value;
                                      });
                                      _loadAvailability(value);
                                    }
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // Legend
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(AppColors.error, 'Unavailable'),
                      const SizedBox(width: 24),
                      _buildLegendItem(AppColors.primary, 'Selected'),
                      const SizedBox(width: 24),
                      _buildLegendItem(AppColors.darkBgSecondary, 'Available'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Calendar
                Expanded(
                  child: selectedVehicleId == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.calendar_month,
                                size: 64,
                                color: AppColors.textTertiary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Select a vehicle to manage availability',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TableCalendar(
                            firstDay: DateTime.now(),
                            lastDay: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            focusedDay: focusedDay,
                            calendarFormat: calendarFormat,
                            selectedDayPredicate: (day) => _isSelected(day),
                            onDaySelected: (selectedDay, focusedDay) {
                              _toggleDateSelection(selectedDay);
                              setState(() {
                                this.focusedDay = focusedDay;
                              });
                            },
                            onFormatChanged: (format) {
                              setState(() {
                                calendarFormat = format;
                              });
                            },
                            onPageChanged: (focusedDay) {
                              this.focusedDay = focusedDay;
                            },
                            calendarStyle: CalendarStyle(
                              defaultTextStyle: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              weekendTextStyle: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              outsideTextStyle: const TextStyle(
                                color: AppColors.textTertiary,
                              ),
                              todayDecoration: BoxDecoration(
                                color: AppColors.darkBgTertiary,
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              selectedDecoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              selectedTextStyle: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, day, focusedDay) {
                                if (_isUnavailable(day)) {
                                  return Container(
                                    margin: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${day.day}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return null;
                              },
                            ),
                            headerStyle: const HeaderStyle(
                              titleTextStyle: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              formatButtonTextStyle: TextStyle(
                                color: AppColors.primary,
                              ),
                              formatButtonDecoration: BoxDecoration(
                                border: Border.fromBorderSide(
                                  BorderSide(color: AppColors.primary),
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              leftChevronIcon: Icon(
                                Icons.chevron_left,
                                color: AppColors.textPrimary,
                              ),
                              rightChevronIcon: Icon(
                                Icons.chevron_right,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            daysOfWeekStyle: const DaysOfWeekStyle(
                              weekdayStyle: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                              weekendStyle: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                ),

                // Action buttons
                if (selectedVehicleId != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (selectedDates.isNotEmpty)
                          Text(
                            '${selectedDates.length} date(s) selected',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSaving ? null : _markAsAvailable,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.success,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Mark Available',
                                  style: TextStyle(color: AppColors.success),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomButton(
                                label: 'Mark Unavailable',
                                onPressed: _markAsUnavailable,
                                isLoading: isSaving,
                                backgroundColor: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
