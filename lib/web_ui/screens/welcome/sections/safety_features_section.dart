import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';

class SafetyFeaturesSection extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;
  final double width;

  const SafetyFeaturesSection({
    super.key,
    required this.isDesktop,
    required this.isTablet,
    required this.width,
  });

  Widget _buildFeatureHighlightCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isDesktop,
    required double width,
  }) {
    final cardWidth = isDesktop ? 280.0 : (width < 640 ? double.infinity : 300.0);

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1838),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1AFFFFFF)),
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
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = width < 768;

    return Container(
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
                'SAFE & RELIABLE JOURNEYS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Why Renters in Pangasinan Choose Mobilis',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 36),

              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _buildFeatureHighlightCard(
                    icon: Icons.gps_fixed_rounded,
                    title: '24/7 Satellite GPS Safety',
                    description: 'Every vehicle is paired with live real-time GPS tracking for passenger and fleet security.',
                    isDesktop: isDesktop,
                    width: width,
                  ),
                  _buildFeatureHighlightCard(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Digital Pre/Post Inspection',
                    description: 'Full damage checklist and timestamped photo verification protects you against disputed charges.',
                    isDesktop: isDesktop,
                    width: width,
                  ),
                  _buildFeatureHighlightCard(
                    icon: Icons.price_check_rounded,
                    title: 'Fixed Transparent Rates',
                    description: 'No hidden surge pricing. Clear hourly half-day and daily rates across all vehicle categories.',
                    isDesktop: isDesktop,
                    width: width,
                  ),
                  _buildFeatureHighlightCard(
                    icon: Icons.shield_rounded,
                    title: 'Verified Drivers & Renters',
                    description: 'Strict identity, valid government ID & driver license screenings ensure safe travels.',
                    isDesktop: isDesktop,
                    width: width,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
