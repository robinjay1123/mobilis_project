import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../widgets/optimized_network_image.dart';

class PartnerSafetyReviewScreen extends StatelessWidget {
  const PartnerSafetyReviewScreen({
    super.key,
    required this.booking,
  });

  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['users'] as Map<String, dynamic>?;
    final vehicleTitle = vehicle != null
        ? '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
        : 'Vehicle';
    final renterName = renter?['full_name']?.toString() ??
        renter?['name']?.toString() ??
        booking['renter_name']?.toString() ??
        'Renter';

    final renterSignatureUrl =
        booking['renter_signature_url']?.toString().trim() ?? '';
    final renterValidIdUrl =
        booking['renter_valid_id_url']?.toString().trim() ?? '';
    final renterSelfieUrl =
        booking['renter_selfie_url']?.toString().trim() ?? '';

    final coTravelerName = booking['co_traveler_name']?.toString().trim() ?? '';
    final coTravelerPhone =
        booking['co_traveler_phone']?.toString().trim() ?? '';
    final coTravelerLicense =
        booking['co_traveler_license']?.toString().trim() ?? '';
    final coTravelerSignatureText =
        booking['co_traveler_signature_text']?.toString().trim() ?? '';
    final coTravelerSignatureUrl =
        booking['co_traveler_signature_url']?.toString().trim() ?? '';
    final coTravelerValidIdUrl =
        booking['co_traveler_valid_id_url']?.toString().trim() ?? '';
    final coTravelerSelfieUrl =
        booking['co_traveler_selfie_url']?.toString().trim() ?? '';

    final hasCoTraveler = coTravelerName.isNotEmpty ||
        coTravelerLicense.isNotEmpty ||
        coTravelerValidIdUrl.isNotEmpty ||
        coTravelerSignatureUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Renter Safety Review',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          // Header Card: Summary of Booking & Renter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBgSecondary
                  : AppColors.lightBgSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        renterName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        vehicleTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 1: Primary Renter Safety Info & Signature
          _buildSectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'Primary Renter Verification',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBgSecondary
                  : AppColors.lightBgSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  label: 'Digital signature text',
                  value: booking['renter_signature_text']?.toString(),
                  icon: Icons.draw_outlined,
                  isDark: isDark,
                ),
                const Divider(height: 20),
                _buildDetailRow(
                  label: 'Emergency contact',
                  value: [
                    booking['emergency_contact_name']?.toString(),
                    booking['emergency_contact_relationship']?.toString(),
                    booking['emergency_contact_phone']?.toString(),
                  ]
                      .where((part) => part != null && part.trim().isNotEmpty)
                      .join(' - '),
                  icon: Icons.contact_emergency_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                Text(
                  'Submitted Documents',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                _buildDocumentTile(
                  context: context,
                  title: 'Signature image',
                  imageUrl: renterSignatureUrl,
                  icon: Icons.draw_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildDocumentTile(
                  context: context,
                  title: 'Valid Government ID',
                  imageUrl: renterValidIdUrl,
                  icon: Icons.badge_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildDocumentTile(
                  context: context,
                  title: 'Selfie Verification',
                  imageUrl: renterSelfieUrl,
                  icon: Icons.face_rounded,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECTION 2: Co-Traveler / Authorized Second Driver
          _buildSectionHeader(
            icon: Icons.people_outline_rounded,
            title: 'Co-Traveler / Authorized Second Driver',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBgSecondary
                  : AppColors.lightBgSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
              ),
            ),
            child: hasCoTraveler
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        label: 'Co-traveler Name & Phone',
                        value: [
                          coTravelerName,
                          coTravelerPhone,
                        ]
                            .where((part) => part.trim().isNotEmpty)
                            .join(' - '),
                        icon: Icons.person_add_alt_1_outlined,
                        isDark: isDark,
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        label: 'Co-traveler Driver\'s License',
                        value: coTravelerLicense,
                        icon: Icons.credit_card_outlined,
                        isDark: isDark,
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        label: 'Co-traveler Digital Signature',
                        value: coTravelerSignatureText,
                        icon: Icons.draw_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Co-Traveler Documents',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDocumentTile(
                        context: context,
                        title: 'Co-traveler signature image',
                        imageUrl: coTravelerSignatureUrl,
                        icon: Icons.draw_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _buildDocumentTile(
                        context: context,
                        title: 'Co-traveler Valid ID',
                        imageUrl: coTravelerValidIdUrl,
                        icon: Icons.badge_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _buildDocumentTile(
                        context: context,
                        title: 'Co-traveler Selfie',
                        imageUrl: coTravelerSelfieUrl,
                        icon: Icons.face_rounded,
                        isDark: isDark,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: isDark
                            ? AppColors.textTertiary
                            : AppColors.lightTextTertiary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No co-traveler / second driver specified for this booking.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String? value,
    required IconData icon,
    required bool isDark,
  }) {
    final clean = value?.trim();
    final hasValue = clean != null && clean.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasValue ? clean : 'Not provided',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: hasValue
                      ? (isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary)
                      : (isDark
                          ? AppColors.textTertiary
                          : AppColors.lightTextTertiary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentTile({
    required BuildContext context,
    required String title,
    required String imageUrl,
    required IconData icon,
    required bool isDark,
  }) {
    final hasImage = imageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openImageModal(
            context: context,
            title: title,
            imageUrl: imageUrl,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Thumbnail or placeholder icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasImage
                        ? Colors.black12
                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderColor
                          : AppColors.lightBorderColor,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasImage
                      ? OptimizedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          errorWidget: Icon(
                            icon,
                            color: isDark
                                ? AppColors.textTertiary
                                : AppColors.lightTextTertiary,
                            size: 20,
                          ),
                        )
                      : Icon(
                          icon,
                          color: isDark
                              ? AppColors.textTertiary
                              : AppColors.lightTextTertiary,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasImage ? 'Tap to view full image' : 'No image submitted',
                        style: TextStyle(
                          fontSize: 11,
                          color: hasImage
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.textTertiary
                                  : AppColors.lightTextTertiary),
                          fontWeight:
                              hasImage ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasImage
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasImage
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.borderColor
                              : AppColors.lightBorderColor),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasImage
                            ? Icons.visibility_outlined
                            : Icons.block_outlined,
                        size: 14,
                        color: hasImage
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.textTertiary
                                : AppColors.lightTextTertiary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasImage ? 'View' : 'None',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasImage
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.textTertiary
                                  : AppColors.lightTextTertiary),
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
    );
  }

  void _openImageModal({
    required BuildContext context,
    required String title,
    required String imageUrl,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        final hasImage = imageUrl.isNotEmpty;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgSecondary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        icon: const Icon(Icons.close_rounded),
                        color: isDark ? Colors.white70 : Colors.black87,
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Image Viewer Container
                Flexible(
                  child: hasImage
                      ? Container(
                          width: double.infinity,
                          color: Colors.black,
                          child: InteractiveViewer(
                            panEnabled: true,
                            boundaryMargin: const EdgeInsets.all(20),
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Center(
                              child: OptimizedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                isThumbnail: false,
                                placeholder: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                ),
                                errorWidget: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white60,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Unable to load image preview',
                                        style: TextStyle(
                                          color: isDark
                                              ? AppColors.textSecondary
                                              : AppColors.lightTextSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 40,
                            horizontal: 20,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: 54,
                                color: isDark
                                    ? AppColors.textTertiary
                                    : AppColors.lightTextTertiary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No image attached',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.textPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The renter has not provided an image for this requirement.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                const Divider(height: 1),

                // Footer Actions
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      if (hasImage) ...[
                        OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(imageUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Full Size / Browser'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const Spacer(),
                      ] else
                        const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
