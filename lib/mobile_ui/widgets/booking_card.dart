import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import '../theme/app_colors.dart';
import 'optimized_network_image.dart';

class BookingCard extends StatelessWidget {
  final String carName;
  final String rentalPartner;
  final String status;
  final int days;
  final String pickupLocation;
  final String dropoffLocation;
  final int totalCost;
  final double rating;
  final VoidCallback onTap;
  final VoidCallback? onViewDetails;
  final VoidCallback? onMessage;
  final VoidCallback? onTrack;
  final VoidCallback? onCancel;
  final bool showMessageButton;
  final bool showTrackButton;
  final bool showCancelButton;
  final bool showRating;
  final bool showRateButton;
  final bool isAlreadyRated;
  final VoidCallback? onRateTrip;
  final String detailsButtonLabel;
  final String trackButtonLabel;
  final bool isActive;
  final String? carImageUrl;
  final Widget? ongoingSummary;

  const BookingCard({
    super.key,
    required this.carName,
    required this.rentalPartner,
    required this.status,
    required this.days,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.totalCost,
    required this.rating,
    required this.onTap,
    this.onViewDetails,
    this.onMessage,
    this.onTrack,
    this.onCancel,
    this.onRateTrip,
    this.showMessageButton = false,
    this.showTrackButton = false,
    this.showCancelButton = false,
    this.showRating = true,
    this.showRateButton = false,
    this.isAlreadyRated = false,
    this.detailsButtonLabel = 'View Details',
    this.trackButtonLabel = 'Track Ongoing Trip',
    this.isActive = false,
    this.carImageUrl,
    this.ongoingSummary,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.toLowerCase();
    final shouldShowRating =
        showRating && normalizedStatus != 'pending' && rating > 0;
    final statusColor =
        normalizedStatus == 'approved' ||
            normalizedStatus == 'active' ||
            normalizedStatus == 'confirmed'
        ? AppColors.success
        : normalizedStatus == 'completed' || normalizedStatus == 'past'
        ? AppColors.primary
        : normalizedStatus == 'declined' ||
              normalizedStatus == 'rejected' ||
              normalizedStatus == 'cancelled' ||
              normalizedStatus == 'canceled'
        ? AppColors.error
        : AppColors.warning;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.borderColor,
            width: isActive ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Car name and status
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.darkBgTertiary,
                    borderRadius: BorderRadius.circular(8),
                    image: carImageUrl != null
                        ? DecorationImage(
                            image: OptimizedNetworkImageProvider(carImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: carImageUrl == null
                      ? const Icon(
                          Icons.directions_car,
                          size: 20,
                          color: AppColors.textSecondary,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        carName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        rentalPartner,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Duration
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$days days',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Pickup location
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pickupLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Dropoff location
            Row(
              children: [
                const Icon(
                  Icons.arrow_forward,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dropoffLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Cost and rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      '₱${formatAmount(totalCost, decimalDigits: 0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (shouldShowRating) ...[
                        const Icon(
                          Icons.star,
                          size: 12,
                          color: AppColors.ratingGold,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (showTrackButton) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onTrack,
                  icon: const Icon(Icons.near_me_outlined, size: 16),
                  label: Text(trackButtonLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (ongoingSummary != null) ...[
              ongoingSummary!,
              const SizedBox(height: 10),
            ],
            if (showRateButton) ...[
              SizedBox(
                width: double.infinity,
                child: isAlreadyRated
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.star_rounded, color: AppColors.ratingGold, size: 18),
                        label: const Text(
                          'Rating Submitted',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: onRateTrip,
                        icon: const Icon(Icons.star_rounded, color: Colors.black, size: 18),
                        label: const Text(
                          'Rate Trip',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                if (showCancelButton) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails ?? onTap,
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: Text(detailsButtonLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (showMessageButton) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onMessage,
                      icon: const Icon(Icons.message, size: 16),
                      label: const Text('Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
