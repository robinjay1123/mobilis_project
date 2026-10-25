import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';
import '../welcome_web_constants.dart';

class PangasinanHubSection extends StatelessWidget {
  final Key? sectionKey;
  final bool isDesktop;
  final bool isTablet;
  final double width;

  const PangasinanHubSection({
    super.key,
    this.sectionKey,
    required this.isDesktop,
    required this.isTablet,
    required this.width,
  });

  Widget _buildHubDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtext,
    required bool isDesktop,
    required double width,
    VoidCallback? onTap,
  }) {
    final cardWidth = isDesktop ? 360.0 : (width < 420 ? double.infinity : 340.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1838),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtext, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = width < 768;

    return Container(
      key: sectionKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              const Text(
                'LOCAL COVERAGE & HEADQUARTERS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Exclusively Serving Pangasinan & Nearby Places',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Headquartered in Urdaneta City with coverage spanning all major towns and cities across Pangasinan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 36),

              // Hub Info Cards
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _buildHubDetailCard(
                    icon: Icons.location_on_rounded,
                    title: 'Main Office (Tap for Maps 📍)',
                    value: '${WelcomeWebConstants.mainOfficeLocation}\n(${WelcomeWebConstants.mainOfficePlusCode})',
                    subtext: 'Tap to view exact GPS location & directions on Google Maps',
                    onTap: () => WelcomeWebConstants.openUrl(WelcomeWebConstants.googleMapsLocationUrl),
                    isDesktop: isDesktop,
                    width: width,
                  ),
                  _buildHubDetailCard(
                    icon: Icons.phone_in_talk_rounded,
                    title: 'Available Hotlines',
                    value: '${WelcomeWebConstants.hotline1}\n${WelcomeWebConstants.hotline2}',
                    subtext: 'Call or SMS for reservations & roadside assistance',
                    onTap: () => WelcomeWebConstants.callPhone(WelcomeWebConstants.hotline1),
                    isDesktop: isDesktop,
                    width: width,
                  ),
                  _buildHubDetailCard(
                    icon: Icons.facebook_rounded,
                    title: 'Official Facebook',
                    value: 'fb.com/psdc.dagupan',
                    subtext: 'Follow us for promos, announcements & updates',
                    onTap: () => WelcomeWebConstants.openUrl(WelcomeWebConstants.facebookUrl),
                    isDesktop: isDesktop,
                    width: width,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Pangasinan Towns Badges
              Container(
                padding: EdgeInsets.all(isMobile ? 18 : 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF071533),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ACTIVE SERVICE COVERAGE TOWNS',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        'Urdaneta City (HQ)',
                        'Dagupan City',
                        'San Carlos City',
                        'Lingayen',
                        'Manaoag',
                        'Rosales',
                        'Alaminos City (Hundred Islands)',
                        'Calasiao',
                        'Malasiqui',
                        'Villasis',
                        'Binalonan',
                        'Tayug',
                        'Mangaldan',
                        'Nearby Provinces (La Union / Tarlac / Baguio transit)',
                      ].map((town) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D224E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: Text(
                          town,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
