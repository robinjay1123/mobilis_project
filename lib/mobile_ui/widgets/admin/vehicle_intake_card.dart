import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class VehicleIntakeCard extends StatelessWidget {
  final String brand;
  final String model;
  final String year;
  final String? imageUrl;
  final String ownerName;
  final String submittedTime;
  final String plateNumber;
  final String vehicleType;
  final String fuelType;
  final int seats;
  final String transmission;
  final String orCrStatus;
  final String? orCrExpiry;
  final String insuranceStatus;
  final String? insuranceExpiry;
  final String registrationStatus;
  final List<String>? documentUrls;
  final TextEditingController? noteController;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onViewDocuments;

  const VehicleIntakeCard({
    super.key,
    required this.brand,
    required this.model,
    required this.year,
    this.imageUrl,
    required this.ownerName,
    required this.submittedTime,
    required this.plateNumber,
    required this.vehicleType,
    required this.fuelType,
    required this.seats,
    required this.transmission,
    required this.orCrStatus,
    this.orCrExpiry,
    required this.insuranceStatus,
    this.insuranceExpiry,
    required this.registrationStatus,
    this.documentUrls,
    this.noteController,
    this.onApprove,
    this.onReject,
    this.onViewDocuments,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'valid':
      case 'complete':
        return AppColors.success;
      case 'pending':
      case 'pending review':
      case 'under review':
        return AppColors.warning;
      case 'expired':
      case 'missing':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getVehicleTypeColor() {
    switch (vehicleType.toLowerCase()) {
      case 'sedan':
        return Colors.blue;
      case 'suv':
        return Colors.purple;
      case 'van':
        return Colors.orange;
      case 'luxury':
        return AppColors.primary;
      case 'economy':
        return Colors.teal;
      case 'electric':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle type badge and image
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 100,
                  height: 72,
                  color: isDark
                      ? AppColors.darkBgSecondary
                      : AppColors.lightBgTertiary,
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildVehiclePlaceholder(isDark);
                          },
                        )
                      : _buildVehiclePlaceholder(isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _getVehicleTypeColor().withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        vehicleType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _getVehicleTypeColor(),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Vehicle name
                    Text(
                      '$brand $model',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$year • $plateNumber',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: isDark
                              ? AppColors.textTertiary
                              : AppColors.lightTextTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ownerName,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• $submittedTime',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Vehicle specs row
          Row(
            children: [
              _buildSpecChip(Icons.people_outline, '$seats Seats', isDark),
              const SizedBox(width: 8),
              _buildSpecChip(
                Icons.local_gas_station_outlined,
                fuelType,
                isDark,
              ),
              const SizedBox(width: 8),
              _buildSpecChip(Icons.settings_outlined, transmission, isDark),
            ],
          ),

          const SizedBox(height: 16),

          // Document statuses
          _buildDocumentRow(
            context,
            Icons.description_outlined,
            'OR / CR Certificate',
            orCrStatus,
            orCrExpiry != null ? 'Exp: $orCrExpiry' : null,
            isDark,
          ),

          const SizedBox(height: 10),

          _buildDocumentRow(
            context,
            Icons.verified_user_outlined,
            'Insurance Policy',
            insuranceStatus,
            insuranceExpiry != null ? 'Exp: $insuranceExpiry' : null,
            isDark,
          ),

          const SizedBox(height: 10),

          _buildDocumentRow(
            context,
            Icons.car_rental_outlined,
            'LTO Registration',
            registrationStatus,
            null,
            isDark,
          ),

          // Document thumbnails
          if (documentUrls != null && documentUrls!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: documentUrls!.length > 4 ? 4 : documentUrls!.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 3 && documentUrls!.length > 4) {
                    return GestureDetector(
                      onTap: onViewDocuments,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBgSecondary
                              : AppColors.lightBgTertiary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderColor
                                : AppColors.lightBorderColor,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+${documentUrls!.length - 3}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return GestureDetector(
                    onTap: onViewDocuments,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 60,
                        height: 60,
                        color: isDark
                            ? AppColors.darkBgSecondary
                            : AppColors.lightBgTertiary,
                        child: Image.network(
                          documentUrls![index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_outlined,
                              color: AppColors.textTertiary,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Note field
          TextField(
            controller: noteController,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Note for decision reason (optional)',
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textTertiary
                    : AppColors.lightTextTertiary,
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkBgSecondary
                  : AppColors.lightBgTertiary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclePlaceholder(bool isDark) {
    return Center(
      child: Icon(
        Icons.directions_car_outlined,
        size: 32,
        color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
      ),
    );
  }

  Widget _buildSpecChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : AppColors.lightBgTertiary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(
    BuildContext context,
    IconData icon,
    String title,
    String status,
    String? subtitle,
    bool isDark,
  ) {
    final statusColor = _getStatusColor(status);

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}
