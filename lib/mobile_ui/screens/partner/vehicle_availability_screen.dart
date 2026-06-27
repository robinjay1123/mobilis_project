import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:io';
import '../../../services/auth_service.dart';
import '../../../services/partner_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../utils/pricing_policy.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class VehicleAvailabilityScreen extends StatefulWidget {
  const VehicleAvailabilityScreen({super.key});

  @override
  State<VehicleAvailabilityScreen> createState() =>
      _VehicleAvailabilityScreenState();
}

class _VehicleAvailabilityScreenState extends State<VehicleAvailabilityScreen> {
  static const List<int> _seatOptions = [2, 4, 5, 7, 8, 12];
  static const List<String> _fuelTypeOptions = [
    'Gasoline',
    'Diesel',
    'Hybrid',
    'Electric',
  ];
  static const List<String> _transmissionOptions = ['Manual', 'Automatic'];

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

  List<Map<String, dynamic>> _availabilityVehiclesFromApplications(
    List<Map<String, dynamic>> appList,
  ) {
    final merged = <String, Map<String, dynamic>>{};

    for (final application in appList) {
      final status = _applicationStatus(application);
      if (status != 'approved') continue;

      final vehicleId =
          application['created_vehicle_id']?.toString().trim() ??
          application['partner_vehicle_id']?.toString().trim() ??
          '';
      if (vehicleId.isEmpty) continue;

      merged[vehicleId] = {
        'id': vehicleId,
        'brand': application['brand']?.toString() ?? 'Vehicle',
        'model': application['model']?.toString() ?? '',
        'plate_number': application['plate_number']?.toString() ?? '',
        'year': application['year'],
        'source': 'approved_application',
      };
    }

    return merged.values.toList();
  }

  List<Map<String, dynamic>> _mergeAvailabilityVehicles({
    required List<Map<String, dynamic>> directVehicles,
    required List<Map<String, dynamic>> appList,
  }) {
    final merged = <String, Map<String, dynamic>>{};

    for (final vehicle in directVehicles) {
      final id = vehicle['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      merged[id] = Map<String, dynamic>.from(vehicle);
    }

    for (final vehicle in _availabilityVehiclesFromApplications(appList)) {
      final id = vehicle['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      merged.putIfAbsent(id, () => vehicle);
    }

    final results = merged.values.toList();
    results.sort((a, b) {
      final aBrand = '${a['brand'] ?? ''} ${a['model'] ?? ''}'.trim();
      final bBrand = '${b['brand'] ?? ''} ${b['model'] ?? ''}'.trim();
      return aBrand.toLowerCase().compareTo(bBrand.toLowerCase());
    });
    return results;
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
        final vehicleService = VehicleService();
        final vehicleList = await vehicleService.getPartnerVehicles(user.id);
        final availabilityVehicles = _mergeAvailabilityVehicles(
          directVehicles: vehicleList,
          appList: appList,
        );
        final stillValidSelectedVehicleId =
            selectedVehicleId != null &&
            availabilityVehicles.any(
              (vehicle) => vehicle['id']?.toString() == selectedVehicleId,
            );

        setState(() {
          vehicles = availabilityVehicles;
          applications = appList;
          applicationCounts = counts;
          if (!stillValidSelectedVehicleId) {
            selectedVehicleId = null;
            unavailableDates.clear();
            selectedDates.clear();
          }
          isLoading = false;
        });
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
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadVehicles,
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: _buildApplicationOverview(),
                            ),

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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.darkBgSecondary,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.borderColor,
                                      ),
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
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                              dropdownColor:
                                                  AppColors.darkBgSecondary,
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 14,
                                              ),
                                              items: vehicles.map((vehicle) {
                                                return DropdownMenuItem(
                                                  value:
                                                      vehicle['id'] as String,
                                                  child: Text(
                                                    '${vehicle['brand']} ${vehicle['model']} - ${vehicle['plate_number']}',
                                                    overflow:
                                                        TextOverflow.ellipsis,
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

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 18,
                                runSpacing: 8,
                                children: [
                                  _buildLegendItem(
                                    AppColors.error,
                                    'Unavailable',
                                  ),
                                  _buildLegendItem(
                                    AppColors.primary,
                                    'Selected',
                                  ),
                                  _buildLegendItem(
                                    AppColors.darkBgSecondary,
                                    'Available',
                                    outlined: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (selectedVehicleId == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 40,
                                  horizontal: 24,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.calendar_month,
                                      size: 64,
                                      color: AppColors.textTertiary,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Pull down to refresh fleet status, then select a vehicle to manage availability.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: TableCalendar(
                                  firstDay: DateTime.now(),
                                  lastDay: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                  focusedDay: focusedDay,
                                  calendarFormat: calendarFormat,
                                  selectedDayPredicate: (day) =>
                                      _isSelected(day),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (selectedVehicleId != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        16 + MediaQuery.of(context).padding.bottom,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
            ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool outlined = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            shape: BoxShape.circle,
            border: outlined ? Border.all(color: AppColors.borderColor) : null,
          ),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showApplicationDetailsDialog(application),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: Text(
                status == 'approved'
                    ? 'View vehicle details'
                    : 'View application details',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (status == 'approved') ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderColor, height: 1),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showEditApprovedVehicleDialog(application),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit vehicle details'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
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
      _loadVehicles();
    } catch (e) {
      _showErrorSnackBar('Failed to update vehicle settings');
    }
  }

  Future<void> _showEditApprovedVehicleDialog(
    Map<String, dynamic> application,
  ) async {
    final currentUserId = AuthService().currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    final brandController = TextEditingController(
      text: application['brand']?.toString() ?? '',
    );
    final modelController = TextEditingController(
      text: application['model']?.toString() ?? '',
    );
    final yearController = TextEditingController(
      text: application['year']?.toString() ?? '',
    );
    final plateController = TextEditingController(
      text: application['plate_number']?.toString() ?? '',
    );

    int selectedSeats =
        int.tryParse(application['seats']?.toString() ?? '') ?? 5;
    if (!_seatOptions.contains(selectedSeats)) {
      selectedSeats = _seatOptions.first;
    }

    String selectedFuelType =
        application['fuel_type']?.toString().trim().isNotEmpty == true
        ? application['fuel_type'].toString().trim()
        : _fuelTypeOptions.first;
    if (!_fuelTypeOptions.contains(selectedFuelType)) {
      selectedFuelType = _fuelTypeOptions.first;
    }

    String selectedTransmission =
        application['transmission']?.toString().trim().isNotEmpty == true
        ? application['transmission'].toString().trim()
        : _transmissionOptions.first;
    if (!_transmissionOptions.contains(selectedTransmission)) {
      selectedTransmission = _transmissionOptions.first;
    }

    final existingPhotoUrls = List<String>.from(
      await _loadApplicationPhotoUrls(application),
    );
    final List<XFile> newPhotoFiles = [];

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.92,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    20 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Edit Vehicle Details',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Review the current photos and update the vehicle info below. Once saved, this vehicle returns to pending review.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (existingPhotoUrls.isEmpty && newPhotoFiles.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.darkBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No vehicle images were attached to this application yet.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Car Images',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 148,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ...existingPhotoUrls.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final url = entry.value;
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right:
                                            index ==
                                                    existingPhotoUrls.length -
                                                        1 &&
                                                newPhotoFiles.isEmpty
                                            ? 0
                                            : 12,
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              width: 220,
                                              color: AppColors.darkBg,
                                              child: Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      color: AppColors.darkBg,
                                                      alignment:
                                                          Alignment.center,
                                                      child: const Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () => setDialogState(
                                                () => existingPhotoUrls
                                                    .removeAt(index),
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black87,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  ...newPhotoFiles.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final file = entry.value;
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: index == newPhotoFiles.length - 1
                                            ? 0
                                            : 12,
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              width: 220,
                                              color: AppColors.darkBg,
                                              child: Image.file(
                                                File(file.path),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () => setDialogState(
                                                () => newPhotoFiles.removeAt(
                                                  index,
                                                ),
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black87,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await ImagePicker()
                                    .pickMultiImage(imageQuality: 85);
                                if (picked.isEmpty) return;
                                setDialogState(() {
                                  final existingPaths = newPhotoFiles
                                      .map((file) => file.path)
                                      .toSet();
                                  for (final file in picked) {
                                    if (!existingPaths.contains(file.path)) {
                                      newPhotoFiles.add(file);
                                    }
                                  }
                                });
                              },
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: const Text('Add more images'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: SingleChildScrollView(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final useTwoColumns = constraints.maxWidth >= 620;
                              if (useTwoColumns) {
                                return Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildEditField(
                                            brandController,
                                            'Brand',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildEditField(
                                            modelController,
                                            'Model',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildEditField(
                                            yearController,
                                            'Year',
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildEditField(
                                            plateController,
                                            'Plate Number',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildEditDropdown<int>(
                                            label: 'Seats',
                                            value: selectedSeats,
                                            items: _seatOptions,
                                            labelBuilder: (value) =>
                                                '$value seats',
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setDialogState(
                                                () => selectedSeats = value,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildEditDropdown<String>(
                                            label: 'Fuel Type',
                                            value: selectedFuelType,
                                            items: _fuelTypeOptions,
                                            labelBuilder: (value) => value,
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setDialogState(
                                                () => selectedFuelType = value,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildEditDropdown<String>(
                                      label: 'Transmission',
                                      value: selectedTransmission,
                                      items: _transmissionOptions,
                                      labelBuilder: (value) => value,
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setDialogState(
                                          () => selectedTransmission = value,
                                        );
                                      },
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildEditField(brandController, 'Brand'),
                                  const SizedBox(height: 12),
                                  _buildEditField(modelController, 'Model'),
                                  const SizedBox(height: 12),
                                  _buildEditField(
                                    yearController,
                                    'Year',
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEditField(
                                    plateController,
                                    'Plate Number',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEditDropdown<int>(
                                    label: 'Seats',
                                    value: selectedSeats,
                                    items: _seatOptions,
                                    labelBuilder: (value) => '$value seats',
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setDialogState(
                                        () => selectedSeats = value,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEditDropdown<String>(
                                    label: 'Fuel Type',
                                    value: selectedFuelType,
                                    items: _fuelTypeOptions,
                                    labelBuilder: (value) => value,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setDialogState(
                                        () => selectedFuelType = value,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEditDropdown<String>(
                                    label: 'Transmission',
                                    value: selectedTransmission,
                                    items: _transmissionOptions,
                                    labelBuilder: (value) => value,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setDialogState(
                                        () => selectedTransmission = value,
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: const Text(
                          'Pricing stays locked here. Contact admin if the rental price needs to change.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(dialogContext, false);
                            await _showPriceChangeRequestDialog(application);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            side: const BorderSide(color: AppColors.warning),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.support_agent_outlined),
                          label: const Text(
                            'Request Price Change From Admin',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
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

    if (shouldSave != true) {
      brandController.dispose();
      modelController.dispose();
      yearController.dispose();
      plateController.dispose();
      return;
    }

    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final year = int.tryParse(yearController.text.trim());
    final plateNumber = plateController.text.trim();

    brandController.dispose();
    modelController.dispose();
    yearController.dispose();
    plateController.dispose();

    if (brand.isEmpty || model.isEmpty || plateNumber.isEmpty || year == null) {
      _showErrorSnackBar('Please complete all vehicle details correctly');
      return;
    }

    final applicationId = application['id']?.toString();
    final partnerVehicleId = application['partner_vehicle_id']?.toString();
    final vehicleId = application['created_vehicle_id']?.toString();
    final mergedPhotoUrls = <String>[...existingPhotoUrls];

    if (applicationId == null ||
        applicationId.isEmpty ||
        partnerVehicleId == null ||
        partnerVehicleId.isEmpty) {
      _showErrorSnackBar('Approved vehicle link is missing');
      return;
    }

    try {
      for (var i = 0; i < newPhotoFiles.length; i++) {
        final url = await PartnerService().uploadToPartnerDocumentsBucket(
          partnerId: currentUserId,
          file: File(newPhotoFiles[i].path),
          documentType: 'vehicle_photo_edit_${i + 1}',
        );
        if (url.trim().isNotEmpty) {
          mergedPhotoUrls.add(url.trim());
        }
      }

      await PartnerService().updateApprovedVehicleDetails(
        applicationId: applicationId,
        partnerVehicleId: partnerVehicleId,
        vehicleId: vehicleId,
        brand: brand,
        model: model,
        year: year,
        plateNumber: plateNumber,
        seats: selectedSeats,
        fuelType: selectedFuelType,
        transmission: selectedTransmission,
        photoUrls: mergedPhotoUrls,
      );

      _showSuccessSnackBar(
        'Vehicle changes submitted. This car is pending review again.',
      );
      _loadVehicles();
    } catch (e) {
      _showErrorSnackBar('Failed to update vehicle details');
    }
  }

  Widget _buildEditField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
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

  Widget _buildEditDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T value) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: AppColors.darkBgSecondary,
          isExpanded: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(labelBuilder(item)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
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

  void _showApplicationDetailsDialog(Map<String, dynamic> application) {
    final status = _applicationStatus(application);
    final applicationId = application['id']?.toString() ?? '';
    final detailRows = <MapEntry<String, String>>[
      MapEntry('Brand', application['brand']?.toString() ?? 'N/A'),
      MapEntry('Model', application['model']?.toString() ?? 'N/A'),
      MapEntry('Year', application['year']?.toString() ?? 'N/A'),
      MapEntry(
        'Plate Number',
        application['plate_number']?.toString() ?? 'N/A',
      ),
      MapEntry('Seats', application['seats']?.toString() ?? 'N/A'),
      MapEntry('Fuel Type', application['fuel_type']?.toString() ?? 'N/A'),
      MapEntry(
        'Transmission',
        application['transmission']?.toString() ?? 'N/A',
      ),
      MapEntry(
        'Driver Setup',
        _truthy(application['owner_is_driver'])
            ? 'Owner will drive'
            : 'Vehicle only',
      ),
      MapEntry(
        'Availability',
        _truthy(application['is_available']) ? 'Available' : 'Unavailable',
      ),
      MapEntry(
        'Submitted',
        application['created_at']?.toString().isNotEmpty == true
            ? _formatDate(application['created_at'].toString())
            : 'N/A',
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status == 'approved'
                          ? 'Approved Vehicle Details'
                          : 'Pending Application Details',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildStatusChip(status.toUpperCase(), _statusColor(status)),
              if (status != 'approved') ...[
                const SizedBox(height: 8),
                const Text(
                  'Details are visible here, but editing stays locked until approval.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              if (status == 'approved') ...[
                const SizedBox(height: 8),
                const Text(
                  'If you confirm an edit, this vehicle returns to pending review until admin approves it again.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FutureBuilder<List<String>>(
                future: _loadApplicationPhotoUrls(application),
                builder: (context, snapshot) {
                  final photoUrls = snapshot.data ?? const <String>[];
                  if (photoUrls.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehicle Photos',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 148,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: photoUrls.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 210,
                                color: AppColors.darkBg,
                                child: Image.network(
                                  photoUrls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.darkBg,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final useTwoColumns = constraints.maxWidth >= 640;
                  final itemWidth = useTwoColumns
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: detailRows
                        .map(
                          (detail) => SizedBox(
                            width: itemWidth,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.darkBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detail.key,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    detail.value,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              if (status == 'rejected' &&
                  application['rejection_reason']
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    'Reason: ${application['rejection_reason']}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
      case 'declined':
      case 'cancelled':
      case 'canceled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Future<List<String>> _loadApplicationPhotoUrls(
    Map<String, dynamic> application,
  ) async {
    final urls = <String>{};
    final primaryUrl = application['vehicle_photo_url']?.toString().trim();
    if (primaryUrl != null && primaryUrl.isNotEmpty) {
      urls.add(primaryUrl);
    }

    final applicationId = application['id']?.toString().trim() ?? '';
    final partnerVehicleId =
        application['partner_vehicle_id']?.toString().trim() ?? '';
    final createdVehicleId =
        application['created_vehicle_id']?.toString().trim() ?? '';

    try {
      if (applicationId.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('partner_vehicle_documents')
            .select('file_url')
            .eq('partner_vehicle_application_id', applicationId)
            .eq('document_type', 'vehicle_photo');

        for (final row in List<Map<String, dynamic>>.from(rows)) {
          final url = row['file_url']?.toString().trim();
          if (url != null && url.isNotEmpty) {
            urls.add(url);
          }
        }
      }

      if (partnerVehicleId.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('vehicle_images')
            .select('image_url')
            .eq('partner_vehicle_id', partnerVehicleId);
        for (final row in List<Map<String, dynamic>>.from(rows)) {
          final url = row['image_url']?.toString().trim();
          if (url != null && url.isNotEmpty) {
            urls.add(url);
          }
        }
      }

      if (createdVehicleId.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('vehicle_images')
            .select('image_url')
            .eq('vehicle_id', createdVehicleId);
        for (final row in List<Map<String, dynamic>>.from(rows)) {
          final url = row['image_url']?.toString().trim();
          if (url != null && url.isNotEmpty) {
            urls.add(url);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading partner application photos: $e');
    }

    return urls.toList();
  }

  Future<void> _showPriceChangeRequestDialog(
    Map<String, dynamic> application,
  ) async {
    final currentUserId = AuthService().currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    final dayController = TextEditingController(
      text: (application['price_per_day'] ?? 0).toString(),
    );
    final hourController = TextEditingController(
      text: (application['price_per_hour'] ?? 0).toString(),
    );
    final noteController = TextEditingController();

    final shouldSubmit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Request Price Change',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Send your requested daily and hourly price to admin. Admin will review it and coordinate with the operator for the final price update.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.darkBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildPriceSummaryTile(
                        title: 'Current / Day',
                        value: 'PHP ${(application['price_per_day'] ?? 0)}',
                      ),
                      _buildPriceSummaryTile(
                        title: 'Current / Hour',
                        value: 'PHP ${(application['price_per_hour'] ?? 0)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  dayController,
                  'Requested Price per Day',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                _buildEditField(
                  hourController,
                  'Requested Price per Hour',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  minLines: 4,
                  maxLines: 5,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Reason / Note',
                    hintText: 'Explain why the price should be updated.',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.darkBg,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Send to Admin',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (shouldSubmit != true) {
      dayController.dispose();
      hourController.dispose();
      noteController.dispose();
      return;
    }

    final requestedDay = double.tryParse(dayController.text.trim());
    final requestedHour = double.tryParse(hourController.text.trim());
    final note = noteController.text.trim();
    final currentDay =
        (application['price_per_day'] as num?)?.toDouble() ?? 0.0;
    final currentHour =
        (application['price_per_hour'] as num?)?.toDouble() ?? 0.0;

    dayController.dispose();
    hourController.dispose();
    noteController.dispose();

    if (requestedDay == null || requestedHour == null) {
      _showErrorSnackBar('Please enter valid requested prices');
      return;
    }

    final dayPriceError = PricingPolicy.validateDailyRentalPrice(requestedDay);
    if (dayPriceError != null) {
      _showErrorSnackBar(dayPriceError);
      return;
    }

    final hourPriceError = PricingPolicy.validateHourlyRentalPrice(
      requestedHour,
    );
    if (hourPriceError != null) {
      _showErrorSnackBar(hourPriceError);
      return;
    }

    try {
      final count = await PartnerService().requestVehiclePriceChange(
        partnerId: currentUserId,
        applicationId: application['id']?.toString() ?? '',
        partnerVehicleId: application['partner_vehicle_id']?.toString() ?? '',
        vehicleId: application['created_vehicle_id']?.toString(),
        vehicleTitle:
            '${application['brand'] ?? ''} ${application['model'] ?? ''}'
                .trim(),
        currentPricePerDay: currentDay,
        currentPricePerHour: currentHour,
        requestedPricePerDay: requestedDay,
        requestedPricePerHour: requestedHour,
        note: note,
      );
      _showSuccessSnackBar(
        'Price change request sent to $count admin account(s).',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to send price change request');
    }
  }

  Widget _buildPriceSummaryTile({
    required String title,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
