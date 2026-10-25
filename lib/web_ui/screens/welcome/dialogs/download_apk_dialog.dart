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
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
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
                  vehicleName != null ? 'Book in the Mobilis App' : 'Download Mobilis for Android',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  vehicleName != null
                      ? 'Download the official Mobilis app to complete real-time reservation, license verification, and digital payment.'
                      : 'Official release for Renters, Drivers, and Vehicle Partners in Pangasinan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.45),
                ),
                const SizedBox(height: 20),

                // Direct Download Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      WelcomeWebConstants.openUrl(WelcomeWebConstants.apkDownloadUrl);
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Direct Download (.apk)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF030A18),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // GitHub Releases Link
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      WelcomeWebConstants.openUrl(WelcomeWebConstants.githubReleasesUrl);
                    },
                    icon: const Icon(Icons.code_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'View on GitHub Releases',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Installation Tips
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF030A18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 15),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'If prompted "File might be harmful", tap "Download anyway" -> Open file -> Tap "Install".',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.4),
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
