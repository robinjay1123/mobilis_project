import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';

class HeroSection extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;
  final double width;
  final VoidCallback onBrowseVehicles;
  final VoidCallback onDownloadApk;
  final VoidCallback onUrdanetaHub;

  const HeroSection({
    super.key,
    required this.isDesktop,
    required this.isTablet,
    required this.width,
    required this.onBrowseVehicles,
    required this.onDownloadApk,
    required this.onUrdanetaHub,
  });

  Widget _buildHeroStat(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStatDivider() {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0x22FFFFFF),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = width < 768;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 24,
        vertical: isDesktop ? 70 : (isTablet ? 48 : 36),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 7),
                    Text(
                      isMobile ? 'PANGASINAN PREMIER CAR RENTAL' : 'PANGASINAN’S PREMIER 100% CAR RENTAL SERVICE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: isMobile ? 10.5 : 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Catchy Title
              Text(
                'Rent a Car & Enjoy the Journey\nExclusively in Pangasinan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 52 : (isTablet ? 38 : 28),
                  fontWeight: FontWeight.w900,
                  height: 1.18,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Description
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Text(
                  'Explore Pangasinan with ease. Flexible Hourly (12 hrs minimum) & Daily rentals for Sedans, SUVs, MPVs, and 15-Seat Tour Vans. Choose self-drive or hire a professional driver with 24/7 active GPS tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF94A3B8),
                    fontSize: isDesktop ? 16 : 14,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onBrowseVehicles,
                    icon: const Icon(Icons.directions_car_rounded, size: 18),
                    label: const Text('Browse Vehicles', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF030A18),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                      shadowColor: AppColors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onDownloadApk,
                    icon: const Icon(Icons.android_rounded, size: 18, color: Colors.white),
                    label: const Text('Download Android APK', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2B5C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0x55FFD740)),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onUrdanetaHub,
                    icon: const Icon(Icons.location_city_rounded, size: 18, color: AppColors.primary),
                    label: const Text('Urdaneta Hub', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Key Trust Metric Cards
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : 16,
                    vertical: isDesktop ? 20 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1733),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: isDesktop
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildHeroStat('Urdaneta HQ', 'Central Pangasinan Office'),
                            _buildHeroStatDivider(),
                            _buildHeroStat('100% GPS', 'Active Satellite Tracking'),
                            _buildHeroStatDivider(),
                            _buildHeroStat('Self-Drive / Driver', 'Flexible Rental Options'),
                            _buildHeroStatDivider(),
                            _buildHeroStat('12h to Multi-Day', 'Half-day & Daily Rates'),
                          ],
                        )
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.spaceAround,
                          children: [
                            SizedBox(
                              width: width < 400 ? (width - 70) / 2 : 140,
                              child: _buildHeroStat('Urdaneta HQ', 'Central Hub'),
                            ),
                            SizedBox(
                              width: width < 400 ? (width - 70) / 2 : 140,
                              child: _buildHeroStat('100% GPS', 'Satellite Tracking'),
                            ),
                            SizedBox(
                              width: width < 400 ? (width - 70) / 2 : 140,
                              child: _buildHeroStat('Self-Drive/Driver', 'Flexible Options'),
                            ),
                            SizedBox(
                              width: width < 400 ? (width - 70) / 2 : 140,
                              child: _buildHeroStat('12h to Daily', 'Transparent Rates'),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
