part of '../driver_home_screen.dart';

// AVAILABILITY TAB
class _AvailabilityTab extends StatefulWidget {
  const _AvailabilityTab();

  @override
  State<_AvailabilityTab> createState() => __AvailabilityTabState();
}

class __AvailabilityTabState extends State<_AvailabilityTab> {
  final DriverService _driverService = DriverService();
  bool isAvailable = false;
  bool isLoading = true;
  bool isSaving = false;
  final Set<DateTime> selectedDates = {};
  DateTime _availabilityFocusedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

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

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final userId = AuthService().currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      final stats = await _driverService.getDriverStats(userId);
      final schedule = await _driverService.getSchedule(userId);
      final dates = schedule
          .map((row) => DateTime.tryParse(row['date']?.toString() ?? ''))
          .whereType<DateTime>()
          .map(_dateOnly)
          .toSet();
      if (!mounted) return;
      final sortedDates = dates.toList()..sort();
      setState(() {
        isAvailable = stats['is_available'] == true;
        selectedDates
          ..clear()
          ..addAll(dates);
        if (sortedDates.isNotEmpty) {
          _availabilityFocusedDay = DateTime(
            sortedDates.first.year,
            sortedDates.first.month,
            1,
          );
        }
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    final userId = AuthService().currentUser?.id;
    if (userId == null || isSaving) return;
    if (value && selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one available date first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final previous = isAvailable;
    setState(() {
      isAvailable = value;
      isSaving = true;
    });

    try {
      await _driverService.setAvailability(userId, value);
      if (selectedDates.isNotEmpty) {
        await _driverService.replaceDateSchedule(
          driverId: userId,
          dates: selectedDates,
          isAvailable: value,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'You are now available for driver assignments on your selected dates.'
                : 'You are now unavailable for assignments (Emergency / Off-duty).',
          ),
          backgroundColor: value ? AppColors.success : AppColors.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isAvailable = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update availability: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _saveSelectedDates() async {
    final userId = AuthService().currentUser?.id;
    if (userId == null || isSaving) return;
    if (selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one available date first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
      isAvailable = true;
    });
    try {
      await _driverService.replaceDateSchedule(
        driverId: userId,
        dates: selectedDates,
        isAvailable: true,
      );
      await _driverService.setAvailability(userId, true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability dates saved and activated!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save availability dates: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
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

  String _formatMonthYear(DateTime date) {
    const fullMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${fullMonths[date.month - 1]} ${date.year}';
  }

  void _changeAvailabilityMonth(int offset) {
    setState(() {
      _availabilityFocusedDay = DateTime(
        _availabilityFocusedDay.year,
        _availabilityFocusedDay.month + offset,
        1,
      );
    });
  }

  Future<void> _confirmRemoveAvailabilityDate(DateTime date) async {
    final formatted = _formatDate(date);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Remove Date',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to remove this availability date?',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatted,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _removeAvailabilityDate(date);
    }
  }

  void _removeAvailabilityDate(DateTime date) async {
    final normalized = _dateOnly(date);
    setState(() => selectedDates.remove(normalized));
    final userId = AuthService().currentUser?.id;
    if (userId != null) {
      try {
        await _driverService.replaceDateSchedule(
          driverId: userId,
          dates: selectedDates,
          isAvailable: isAvailable,
        );
        if (selectedDates.isEmpty && isAvailable) {
          setState(() => isAvailable = false);
          await _driverService.setAvailability(userId, false);
        }
      } catch (err) {
        debugPrint('Error syncing removed date: $err');
      }
    }
  }

  Widget _buildAvailableDatesSection(bool isDark) {
    final calendarText = isDark ? Colors.white : Colors.black87;
    final mutedText = isDark ? Colors.white54 : Colors.grey.shade600;
    final sortedDates = selectedDates.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF07111D) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: isSaving
                        ? null
                        : () => _changeAvailabilityMonth(-1),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: isSaving ? mutedText : AppColors.primary,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatMonthYear(_availabilityFocusedDay),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: calendarText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: isSaving
                        ? null
                        : () => _changeAvailabilityMonth(1),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: isSaving ? mutedText : AppColors.primary,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TableCalendar<void>(
                firstDay: DateTime(2000, 1, 1),
                lastDay: DateTime(2100, 12, 31),
                focusedDay: _availabilityFocusedDay,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                headerVisible: false,
                rowHeight: 42,
                daysOfWeekHeight: 24,
                selectedDayPredicate: (day) =>
                    selectedDates.contains(_dateOnly(day)),
                onPageChanged: (focusedDay) {
                  setState(() {
                    _availabilityFocusedDay = DateTime(
                      focusedDay.year,
                      focusedDay.month,
                      1,
                    );
                  });
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  cellMargin: const EdgeInsets.all(4),
                  defaultTextStyle: TextStyle(
                    color: mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  weekendTextStyle: TextStyle(
                    color: mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  todayTextStyle: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  weekendStyle: TextStyle(
                    color: mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                calendarBuilders: CalendarBuilders<void>(
                  defaultBuilder: (context, day, focusedDay) {
                    if (!selectedDates.contains(_dateOnly(day))) return null;
                    return _buildAvailableCalendarDay(
                      day,
                      isDark,
                      isToday: false,
                    );
                  },
                  todayBuilder: (context, day, focusedDay) {
                    if (selectedDates.contains(_dateOnly(day))) {
                      return _buildAvailableCalendarDay(
                        day,
                        isDark,
                        isToday: true,
                      );
                    }
                    return _buildCalendarDay(day, isDark, isToday: true);
                  },
                  selectedBuilder: (context, day, focusedDay) =>
                      _buildAvailableCalendarDay(
                        day,
                        isDark,
                        isToday: DateUtils.isSameDay(day, DateTime.now()),
                      ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildCalendarLegend(
                    color: AppColors.primary,
                    label: 'Available',
                    isDark: isDark,
                  ),
                  _buildCalendarLegend(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    label: 'Not selected',
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (sortedDates.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'No dates selected yet. Use Pick Dates to add availability.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedText, fontSize: 12.5),
            ),
          )
        else ...[
          Text(
            '${sortedDates.length} available date${sortedDates.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: calendarText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedDates.map((date) {
              return InputChip(
                avatar: const Icon(
                  Icons.event_available_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text(_formatDate(date)),
                onDeleted: isSaving
                    ? null
                    : () => _confirmRemoveAvailabilityDate(date),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  color: calendarText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAvailableCalendarDay(
    DateTime day,
    bool isDark, {
    required bool isToday,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(
                color: isDark ? Colors.white : Colors.black87,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildCalendarDay(DateTime day, bool isDark, {required bool isToday}) {
    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.12)
            : (isDark ? Colors.white.withValues(alpha: 0.035) : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday
              ? AppColors.primary
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: isToday
              ? AppColors.primary
              : (isDark ? Colors.white54 : Colors.grey.shade600),
          fontSize: 13,
          fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCalendarLegend({
    required Color color,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Availability Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
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
                    color: isAvailable ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are ${isAvailable ? 'Available' : 'Unavailable'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        isAvailable
                            ? 'Receiving job offers'
                            : 'Not receiving jobs',
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
                  onChanged: isLoading || isSaving
                      ? null
                      : (value) => _toggleAvailability(value),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ),
          if (isLoading || isSaving) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  isLoading
                      ? 'Loading availability...'
                      : 'Saving availability...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Work Schedule',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Available Dates',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: isSaving ? null : _pickAvailabilityDate,
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('Pick Dates'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isAvailable
                      ? 'You will only show as available on the selected dates.'
                      : 'Pick dates first, then turn availability on.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
                _buildAvailableDatesSection(isDark),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : _saveSelectedDates,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Selected Dates'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
}

