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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final imageBg = isDark ? AppColors.darkBgTertiary : const Color(0xFFE2E8F0);
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;
    final cardBorder = isActive
        ? AppColors.primary
        : (isDark ? AppColors.borderColor : AppColors.lightBorderColor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cardBorder,
            width: isActive ? 2 : 1.2,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Car name and status
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: imageBg,
                    borderRadius: BorderRadius.circular(10),
                    image: carImageUrl != null
                        ? DecorationImage(
                            image: OptimizedNetworkImageProvider(carImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: carImageUrl == null
                      ? Icon(
                          Icons.directions_car,
                          size: 22,
                          color: secondaryText,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        carName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rentalPartner,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: tertiaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Duration
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: tertiaryText,
                ),
                const SizedBox(width: 6),
                Text(
                  '$days days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Pickup location
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: tertiaryText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pickupLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: secondaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Dropoff location
            Row(
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: tertiaryText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dropoffLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: secondaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Cost and rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Cost',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tertiaryText,
                      ),
                    ),
                    Text(
                      '₱${formatAmount(totalCost, decimalDigits: 0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.primary : const Color(0xFFD97706),
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
                          Icons.star_rounded,
                          size: 15,
                          color: AppColors.ratingGold,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryText,
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
                      borderRadius: BorderRadius.circular(10),
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
                        onPressed: onRateTrip,
                        icon: const Icon(Icons.star_rounded, color: AppColors.ratingGold, size: 18),
                        label: Text(
                          'Rating Submitted • View / Edit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: secondaryText,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? AppColors.borderColor : AppColors.lightBorderColor),
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
                          borderRadius: BorderRadius.circular(10),
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
                      foregroundColor: isDark ? AppColors.primary : const Color(0xFFB45309),
                      side: BorderSide(color: isDark ? AppColors.primary : const Color(0xFFB45309)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                          borderRadius: BorderRadius.circular(10),
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
