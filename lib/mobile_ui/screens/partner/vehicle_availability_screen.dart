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
  int selectedApplicationStatusTab = 0;
  List<Map<String, dynamic>> vehicles = [];
  List<Map<String, dynamic>> applications = [];
  Map<String, int> applicationCounts = {
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'total': 0,
  };
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
        final appList = await partnerService.getVehicleApplications(user.id);
        final counts = await partnerService.getApplicationCounts(user.id);
        if (profile != null) {
          final vehicleService = VehicleService();
          final vehicleList = await vehicleService.getPartnerVehicles(
            profile['id'] as String,
          );

          setState(() {
            vehicles = vehicleList;
            applications = appList;
            applicationCounts = counts;
            isLoading = false;
          });
        } else {
          setState(() {
            applications = appList;
            applicationCounts = counts;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildApplicationOverview(),
                ),

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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildApplicationOverview() {
    final filteredApplications = _filteredApplicationsForSelectedStatus();
    final selectedStatusTitle = switch (selectedApplicationStatusTab) {
      0 => 'Pending Applications',
      1 => 'Approved Applications',
      _ => 'Declined Applications',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                'Manage Fleet Applications',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.darkBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Row(
                  children: [
                    _buildApplicationStatusTab(
                      label: 'Pending',
                      count: _countApplicationsByStatus({'pending'}),
                      index: 0,
                      color: AppColors.warning,
                    ),
                    _buildApplicationStatusTab(
                      label: 'Approved',
                      count: _countApplicationsByStatus({'approved'}),
                      index: 1,
                      color: AppColors.success,
                    ),
                    _buildApplicationStatusTab(
                      label: 'Declined',
                      count: _countApplicationsByStatus({
                        'rejected',
                        'declined',
                        'cancelled',
                        'canceled',
                      }),
                      index: 2,
                      color: AppColors.error,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _selectedApplicationStatusColor(),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedStatusTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredApplications.isEmpty)
                Text(
                  'No ${selectedStatusTitle.toLowerCase()} yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                ...filteredApplications.map(_buildApplicationCard),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationStatusTab({
    required String label,
    required int count,
    required int index,
    required Color color,
  }) {
    final isSelected = selectedApplicationStatusTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedApplicationStatusTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? color : AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? color : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final status =
        (application['application_status'] ??
                application['status'] ??
                'pending')
            .toString()
            .toLowerCase();
    final brand = application['brand']?.toString() ?? 'Vehicle';
    final model = application['model']?.toString() ?? '';
    final plateNumber = application['plate_number']?.toString() ?? '';
    final createdAt = application['created_at']?.toString();
    final ownerIsDriver = _truthy(application['owner_is_driver']);
    final isAvailable = _truthy(application['is_available']);

    Color statusColor = AppColors.warning;
    if (status == 'approved') {
      statusColor = AppColors.success;
    } else if (status == 'rejected') {
      statusColor = AppColors.error;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$brand $model'.trim(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              _buildStatusChip(status.toUpperCase(), statusColor),
            ],
          ),
          if (plateNumber.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Plate: $plateNumber',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (createdAt != null && createdAt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Submitted: ${_formatDate(createdAt)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (status == 'rejected' &&
              application['rejection_reason'] != null &&
              application['rejection_reason'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${application['rejection_reason']}',
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          if (status == 'approved') ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderColor, height: 1),
            const SizedBox(height: 10),
            _buildApprovedApplicationToggle(
              icon: Icons.person_pin_circle_outlined,
              title: 'With me',
              subtitle: 'Owner will also drive this vehicle',
              value: ownerIsDriver,
              onChanged: (value) => _updateApprovedApplicationSettings(
                application,
                ownerIsDriver: value,
                isAvailable: isAvailable,
              ),
            ),
            _buildApprovedApplicationToggle(
              icon: Icons.event_available_outlined,
              title: 'Available',
              subtitle: 'Vehicle can be shown as available for booking',
              value: isAvailable,
              onChanged: (value) => _updateApprovedApplicationSettings(
                application,
                ownerIsDriver: ownerIsDriver,
                isAvailable: value,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApprovedApplicationToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _updateApprovedApplicationSettings(
    Map<String, dynamic> application, {
    required bool ownerIsDriver,
    required bool isAvailable,
  }) async {
    final applicationId = application['id']?.toString();
    final partnerVehicleId = application['partner_vehicle_id']?.toString();
    final vehicleId = application['created_vehicle_id']?.toString();

    if (applicationId == null ||
        applicationId.isEmpty ||
        partnerVehicleId == null ||
        partnerVehicleId.isEmpty) {
      _showErrorSnackBar('Approved vehicle link is missing');
      return;
    }

    try {
      final partnerService = PartnerService();
      await partnerService.updateApprovedVehicleSettings(
        applicationId: applicationId,
        partnerVehicleId: partnerVehicleId,
        vehicleId: vehicleId,
        ownerIsDriver: ownerIsDriver,
        isAvailable: isAvailable,
      );

      setState(() {
        application['owner_is_driver'] = ownerIsDriver;
        application['is_available'] = isAvailable;
      });
      _showSuccessSnackBar('Vehicle settings updated');
    } catch (e) {
      _showErrorSnackBar('Failed to update vehicle settings');
    }
  }

  List<Map<String, dynamic>> _filteredApplicationsForSelectedStatus() {
    final statuses = switch (selectedApplicationStatusTab) {
      0 => {'pending'},
      1 => {'approved'},
      _ => {'rejected', 'declined', 'cancelled', 'canceled'},
    };

    return applications
        .where(
          (application) => statuses.contains(_applicationStatus(application)),
        )
        .toList();
  }

  int _countApplicationsByStatus(Set<String> statuses) {
    return applications
        .where(
          (application) => statuses.contains(_applicationStatus(application)),
        )
        .length;
  }

  String _applicationStatus(Map<String, dynamic> application) {
    return (application['application_status'] ??
            application['status'] ??
            'pending')
        .toString()
        .toLowerCase();
  }

  Color _selectedApplicationStatusColor() {
    return switch (selectedApplicationStatusTab) {
      0 => AppColors.warning,
      1 => AppColors.success,
      _ => AppColors.error,
    };
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == 'yes' ||
          normalized == '1' ||
          normalized == 'available';
    }
    return false;
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value);
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$day';
    } catch (_) {
      return value;
    }
  }
}
