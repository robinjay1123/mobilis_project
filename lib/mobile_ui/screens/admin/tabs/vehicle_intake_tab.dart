import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/admin/vehicle_intake_card.dart';

class VehicleIntakeTab extends StatefulWidget {
  final List<Map<String, dynamic>> vehicleApplications;
  final Function(Map<String, dynamic>, String?)? onApprove;
  final Function(Map<String, dynamic>, String?)? onReject;
  final Function(Map<String, dynamic>)? onViewDocuments;

  const VehicleIntakeTab({
    super.key,
    required this.vehicleApplications,
    this.onApprove,
    this.onReject,
    this.onViewDocuments,
  });

  @override
  State<VehicleIntakeTab> createState() => _VehicleIntakeTabState();
}

class _VehicleIntakeTabState extends State<VehicleIntakeTab> {
  final Map<String, TextEditingController> _noteControllers = {};
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Sedan', 'SUV', 'Van', 'Luxury'];

  @override
  void dispose() {
    for (var controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String id) {
    if (!_noteControllers.containsKey(id)) {
      _noteControllers[id] = TextEditingController();
    }
    return _noteControllers[id]!;
  }

  List<Map<String, dynamic>> get _filteredVehicles {
    if (_selectedFilter == 'All') return widget.vehicleApplications;
    return widget.vehicleApplications.where((v) {
      final type = (v['vehicle_type'] ?? v['type'] ?? '')
          .toString()
          .toLowerCase();
      return type.contains(_selectedFilter.toLowerCase());
    }).toList();
  }

  int get _todayCount {
    // Mock count - in real app, filter by today's date
    return widget.vehicleApplications.length > 3
        ? 3
        : widget.vehicleApplications.length;
  }

  int _getFilterCount(String filter) {
    if (filter == 'All') return widget.vehicleApplications.length;
    return widget.vehicleApplications.where((v) {
      final type = (v['vehicle_type'] ?? v['type'] ?? '')
          .toString()
          .toLowerCase();
      return type.contains(filter.toLowerCase());
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehicle Intake',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reviewing ${widget.vehicleApplications.length} pending vehicle registrations.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),

        // Quick Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderColor
                          : AppColors.lightBorderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Today',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+$_todayCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'New submissions',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderColor
                          : AppColors.lightBorderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Approval Rate',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '94%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Document Requirements Notice
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Document Requirements',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.blue[200] : Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'All vehicles must have valid OR/CR, LTO registration, and comprehensive insurance.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.blue[200] : Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Filter Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                final count = _getFilterCount(filter);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.borderColor
                                    : AppColors.lightBorderColor),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            filter,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.black
                                  : (isDark
                                        ? AppColors.textSecondary
                                        : AppColors.lightTextSecondary),
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black.withOpacity(0.2)
                                    : (isDark
                                          ? AppColors.darkBgSecondary
                                          : AppColors.lightBgTertiary),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                count.toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.black
                                      : (isDark
                                            ? AppColors.textTertiary
                                            : AppColors.lightTextTertiary),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Vehicle Applications List
        Expanded(
          child: _filteredVehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppColors.success.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All vehicles reviewed!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No pending vehicle registrations',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filteredVehicles.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _filteredVehicles.length) {
                      // End of list indicator
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 1,
                                color: isDark
                                    ? AppColors.borderColor
                                    : AppColors.lightBorderColor,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'End of Queue',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textTertiary
                                      : AppColors.lightTextTertiary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 40,
                                height: 1,
                                color: isDark
                                    ? AppColors.borderColor
                                    : AppColors.lightBorderColor,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final vehicle = _filteredVehicles[index];
                    final vehicleId =
                        vehicle['id']?.toString() ?? index.toString();

                    return VehicleIntakeCard(
                      brand: vehicle['brand'] ?? 'Unknown',
                      model: vehicle['model'] ?? 'Model',
                      year: vehicle['year']?.toString() ?? '',
                      imageUrl: vehicle['image_url'],
                      ownerName:
                          vehicle['owner_name'] ??
                          vehicle['owner']?['full_name'] ??
                          'Unknown Owner',
                      submittedTime: _formatSubmittedTime(
                        vehicle['created_at'],
                      ),
                      plateNumber: vehicle['plate_number'] ?? 'N/A',
                      vehicleType:
                          vehicle['vehicle_type'] ?? vehicle['type'] ?? 'Sedan',
                      fuelType: vehicle['fuel_type'] ?? 'Gasoline',
                      seats: vehicle['seats'] ?? 5,
                      transmission: vehicle['transmission'] ?? 'Auto',
                      orCrStatus: vehicle['or_cr_status'] ?? 'Pending Review',
                      orCrExpiry: vehicle['or_cr_expiry'],
                      insuranceStatus:
                          vehicle['insurance_status'] ?? 'Pending Review',
                      insuranceExpiry: vehicle['insurance_expiry'],
                      registrationStatus:
                          vehicle['registration_status'] ?? 'Pending Review',
                      documentUrls: vehicle['document_urls'] != null
                          ? List<String>.from(vehicle['document_urls'])
                          : null,
                      noteController: _getController(vehicleId),
                      onApprove: () {
                        final note = _getController(vehicleId).text;
                        widget.onApprove?.call(
                          vehicle,
                          note.isEmpty ? null : note,
                        );
                      },
                      onReject: () {
                        final note = _getController(vehicleId).text;
                        widget.onReject?.call(
                          vehicle,
                          note.isEmpty ? null : note,
                        );
                      },
                      onViewDocuments: () {
                        widget.onViewDocuments?.call(vehicle);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatSubmittedTime(dynamic createdAt) {
    if (createdAt == null) return '2 hours ago';
    // In a real app, calculate the time difference
    return '2 hours ago';
  }
}
