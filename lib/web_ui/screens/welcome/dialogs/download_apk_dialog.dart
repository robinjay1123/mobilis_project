import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';
import '../welcome_web_constants.dart';

void showDownloadApkDialog(BuildContext context, {Map<String, dynamic>? selectedVehicle}) {
  final vehicleName = selectedVehicle != null
      ? '${selectedVehicle['brand'] ?? ''} ${selectedVehicle['model'] ?? ''}'.trim()
      : null;
  final priceDay = (selectedVehicle?['price_per_day'] as num?)?.toDouble();

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: const Color(0xFF07142E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x33FFD740)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (vehicleName != null && vehicleName.isNotEmpty) ...[
                  // Selected Vehicle Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F2656), Color(0xFF081836)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicleName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                priceDay != null
                                    ? '₱${priceDay.toStringAsFixed(0)} / day  •  PSDC Verified'
                                    : 'PSDC Pangasinan Fleet',
                                style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: const Icon(Icons.android_rounded, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(height: 14),
                ],

                Text(
                  vehicleName != null ? 'Book in the Mobilis App' : 'Get Mobilis for Android',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  vehicleName != null
                      ? 'Install the official Mobilis app to complete real-time reservation, license verification, and digital payment.'
                      : 'Available on Google Play Store and direct package download for Renters, Drivers, and Partners in Pangasinan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.45),
                ),
                const SizedBox(height: 20),

                // Option 1: Google Play Store (Featured / Recommended)
                _buildDownloadOption(
                  context: context,
                  isPrimary: true,
                  badge: 'Official',
                  badgeColor: const Color(0xFF10B981),
                  icon: Icons.shop_two_rounded,
                  title: 'Get it on Google Play',
                  subtitle: 'Official Google Play Store release • Auto-updates',
                  onTap: () {
                    Navigator.of(context).pop();
                    WelcomeWebConstants.openUrl(WelcomeWebConstants.playStoreUrl);
                  },
                ),
                const SizedBox(height: 10),

                // Option 2: Direct APK Download
                _buildDownloadOption(
                  context: context,
                  isPrimary: false,
                  badge: 'v1.3.3',
                  badgeColor: AppColors.primary,
                  icon: Icons.download_rounded,
                  title: 'Direct Download (.apk)',
                  subtitle: 'Direct installation package for Android devices',
                  onTap: () {
                    Navigator.of(context).pop();
                    WelcomeWebConstants.openUrl(WelcomeWebConstants.apkDownloadUrl);
                  },
                ),
                const SizedBox(height: 10),

                // Option 3: GitHub Releases
                _buildDownloadOption(
                  context: context,
                  isPrimary: false,
                  isOutlined: true,
                  icon: Icons.code_rounded,
                  title: 'GitHub Releases',
                  subtitle: 'View all releases, change logs & source assets',
                  onTap: () {
                    Navigator.of(context).pop();
                    WelcomeWebConstants.openUrl(WelcomeWebConstants.githubReleasesUrl);
                  },
                ),
                const SizedBox(height: 16),

                // Installation Tips
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF030A18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'For instant installation, tap "Get it on Google Play". If downloading .apk directly, select "Download anyway" -> Open file -> Tap "Install".',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildDownloadOption({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  bool isPrimary = false,
  bool isOutlined = false,
  String? badge,
  Color? badgeColor,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.primary
            : (isOutlined ? const Color(0xFF0A1C3E) : const Color(0xFF0F2656)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary
              ? AppColors.primary
              : (isOutlined ? const Color(0x33FFFFFF) : AppColors.primary.withValues(alpha: 0.3)),
          width: isPrimary ? 1.5 : 1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPrimary
                  ? Colors.black.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isPrimary ? const Color(0xFF030A18) : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isPrimary ? const Color(0xFF030A18) : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? const Color(0xFF030A18)
                              : (badgeColor ?? AppColors.primary).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPrimary
                                ? Colors.transparent
                                : (badgeColor ?? AppColors.primary).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: isPrimary ? Colors.white : (badgeColor ?? AppColors.primary),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isPrimary
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: isPrimary ? const Color(0xFF030A18) : const Color(0xFF64748B),
            size: 20,
          ),
        ],
      ),
    ),
  );
}
