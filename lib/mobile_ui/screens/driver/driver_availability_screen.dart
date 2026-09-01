import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_service.dart';
import '../../../services/connectivity_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class DriverAvailabilityScreen extends StatefulWidget {
  const DriverAvailabilityScreen({super.key});

  @override
  State<DriverAvailabilityScreen> createState() =>
      _DriverAvailabilityScreenState();
}

class _DriverAvailabilityScreenState extends State<DriverAvailabilityScreen> {
  late TextEditingController preferredAreasController;
  late TextEditingController workStartTimeController;
  late TextEditingController workEndTimeController;

  // Availability settings
  bool isAvailable = false;
  Set<String> selectedDays = {};
  Set<DateTime> selectedDates = {};
  List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  List<String> dayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    preferredAreasController = TextEditingController();
    workStartTimeController = TextEditingController();
    workEndTimeController = TextEditingController();

    selectedDays = {};
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _formatDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _timeForDatabase(String value, String fallback) {
    final raw = value.trim();
    if (raw.isEmpty) return fallback;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return raw;
    var hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final period = match.group(3)!.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  @override
  void dispose() {
    preferredAreasController.dispose();
    workStartTimeController.dispose();
    workEndTimeController.dispose();
    super.dispose();
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

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        controller.text = pickedTime.format(context);
      });
    }
  }

  Future<void> _pickAvailabilityDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = firstDate.add(const Duration(days: 180));
    final pickedDates = await showDialog<Set<DateTime>>(
      context: context,
      builder: (dialogContext) {
        var focusedDay = selectedDates.isNotEmpty ? selectedDates.last : now;
        final tempDates = selectedDates.map(_dateOnly).toSet();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1826),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pick Available Dates',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${tempDates.length} selected',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF07111D),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: TableCalendar(
                              firstDay: firstDate,
                              lastDay: lastDate,
                              focusedDay: focusedDay,
                              calendarFormat: CalendarFormat.month,
                              rowHeight: 44,
                              availableCalendarFormats: const {
                                CalendarFormat.month: 'Month',
                              },
                              selectedDayPredicate: (day) =>
                                  tempDates.contains(_dateOnly(day)),
                              onDaySelected: (selectedDay, newFocusedDay) {
                                final normalized = _dateOnly(selectedDay);
                                setDialogState(() {
                                  focusedDay = newFocusedDay;
                                  if (tempDates.contains(normalized)) {
                                    tempDates.remove(normalized);
                                  } else {
                                    tempDates.add(normalized);
                                  }
                                });
                              },
                              onPageChanged: (newFocusedDay) {
                                focusedDay = newFocusedDay;
                              },
                              headerStyle: const HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                                titleTextStyle: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
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
                                  fontWeight: FontWeight.w700,
                                ),
                                weekendStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              calendarStyle: CalendarStyle(
                                cellMargin: const EdgeInsets.all(5),
                                defaultTextStyle: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                weekendTextStyle: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                outsideTextStyle: TextStyle(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                todayDecoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  border: Border.all(color: AppColors.primary),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                todayTextStyle: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                                selectedDecoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                selectedTextStyle: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setDialogState(tempDates.clear),
                            child: const Text('Clear'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, tempDates),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                              child: Text('Apply (${tempDates.length})'),
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
    if (pickedDates == null) return;
    setState(() {
      selectedDates
        ..clear()
        ..addAll(pickedDates);
    });
  }

  void _removeAvailabilityDate(DateTime date) {
    setState(() => selectedDates.remove(_dateOnly(date)));
  }

  bool _validateInputs() {
    if (selectedDays.isEmpty) {
      _showErrorSnackBar('Please select at least one preferred working day');
      return false;
    }

    if (preferredAreasController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your preferred areas');
      return false;
    }

    if (isAvailable && selectedDates.isEmpty) {
      _showErrorSnackBar('Please select at least one available work date');
      return false;
    }

    return true;
  }

  Future<void> _saveAvailability() async {
    // Check internet
    final connectivityService = ConnectivityService();
    if (!connectivityService.isOnline) {
      _showErrorSnackBar(
        'No internet connection. Please check your WiFi or mobile data.',
      );
      return;
    }

    if (!_validateInputs()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authService = AuthService();
      final driverService = DriverService();
      final user = authService.currentUser;

      if (user != null) {
        // Get driver profile
        var driverProfile = await driverService.getDriverProfile(user.id);

        if (driverProfile != null) {
          // Set availability status
          await driverService.setAvailability(user.id, isAvailable);

          // Prepare schedule data
          final daysData = selectedDays.join(',');

          // Update driver profile with availability info
          await driverService.updateDriverProfile(driverProfile['id'], {
            'preferred_days':
                daysData, // Store as comma-separated values or JSON
            'preferred_areas': preferredAreasController.text.trim(),
          });

          await driverService.replaceDateSchedule(
            driverId: user.id,
            dates: selectedDates,
            startTime: _timeForDatabase(workStartTimeController.text, '08:00'),
            endTime: _timeForDatabase(workEndTimeController.text, '20:00'),
            isAvailable: isAvailable,
          );

          // Add schedule entries for each selected day
          for (String day in selectedDays) {
            await driverService.addScheduleEntry(
              driverId: user.id,
              dayOfWeek: day,
              startTime: _timeForDatabase(
                workStartTimeController.text,
                '08:00',
              ),
              endTime: _timeForDatabase(workEndTimeController.text, '20:00'),
            );
          }

          if (mounted) {
            _showSuccessSnackBar('Availability settings saved successfully!');
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/driver-home');
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error saving availability: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/icon/logo1.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Mobilis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Title
            Text(
              'Set Your Availability',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Let us know when you\'re ready to accept driving jobs',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Availability Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isAvailable ? Icons.check_circle : Icons.pause_circle,
                      color: isAvailable
                          ? AppColors.success
                          : AppColors.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Availability Status',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          isAvailable
                              ? 'You are set to receive job offers'
                              : 'You are currently unavailable',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isAvailable,
                    onChanged: (value) {
                      setState(() {
                        isAvailable = value;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preferred Days Section
            Text(
              'Preferred Working Days',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),

            // Day Selection Buttons
            Wrap(
              spacing: 10,
              children: List.generate(daysOfWeek.length, (index) {
                final day = daysOfWeek[index];
                final isSelected = selectedDays.contains(day);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedDays.remove(day);
                      } else {
                        selectedDays.add(day);
                      }
                    });
                  },
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : isDark
                          ? AppColors.darkCard
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        dayInitials[index],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.black
                              : isDark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Exact Available Dates
            Text(
              'Work Schedule Dates',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick the exact dates you want to be available. You will only show as available on those dates.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : _pickAvailabilityDate,
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Pick Available Dates'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (selectedDates.isEmpty)
                    const Center(
                      child: Text(
                        'No dates selected yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (selectedDates.toList()..sort())
                          .map(
                            (date) => InputChip(
                              label: Text(_formatDate(date)),
                              onDeleted: isLoading
                                  ? null
                                  : () => _removeAvailabilityDate(date),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              backgroundColor: AppColors.primary.withOpacity(
                                0.16,
                              ),
                              labelStyle: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              side: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Preferred Areas
            Text(
              'Preferred Areas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: preferredAreasController,
              label: 'Areas',
              hintText:
                  'e.g., Metro Manila, Quezon City, Makati, Pasig (comma separated)',
              maxLines: 2,
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            const SizedBox(height: 24),

            // Work Hours Section
            Text(
              'Work Hours (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectTime(workStartTimeController),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Time',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            workStartTimeController.text.isEmpty
                                ? '08:00 AM'
                                : workStartTimeController.text,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black,
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
                    onTap: () => _selectTime(workEndTimeController),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Time',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            workEndTimeController.text.isEmpty
                                ? '08:00 PM'
                                : workEndTimeController.text,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 Tips',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can change your availability anytime. Toggle OFF to pause job offers, or adjust your schedule as needed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            CustomButton(
              label: isLoading ? 'Saving...' : 'Complete Setup',
              onPressed: isLoading ? null : _saveAvailability,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
