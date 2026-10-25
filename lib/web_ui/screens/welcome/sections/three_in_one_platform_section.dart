import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';

class ThreeInOnePlatformSection extends StatefulWidget {
  final Key? sectionKey;
  final bool isDesktop;
  final bool isTablet;
  final double width;
  final VoidCallback onSignup;

  const ThreeInOnePlatformSection({
    super.key,
    this.sectionKey,
    required this.isDesktop,
    required this.isTablet,
    required this.width,
    required this.onSignup,
  });

  @override
  State<ThreeInOnePlatformSection> createState() => _ThreeInOnePlatformSectionState();
}

class _ThreeInOnePlatformSectionState extends State<ThreeInOnePlatformSection> {
  int _activeRoleTab = 0; // 0: Renter, 1: Driver, 2: Partner

  Widget _buildRoleTabButton(int index, String label) {
    final isSelected = _activeRoleTab == index;
    return InkWell(
      onTap: () => setState(() => _activeRoleTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF030A18) : const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRoleContent(bool isDesktop, bool isMobile) {
    if (_activeRoleTab == 0) {
      // Renter
      return _buildRoleCardLayout(
        badge: 'FOR RENTERS',
        title: 'Seamless Car Rental with Zero Headaches',
        description:
            'Book verified cars in Pangasinan for business, family outings, tourism, or emergencies. Choose between flexible 12-hour minimum hourly rentals or full daily rentals. Opt for self-drive or relax with a certified professional driver.',
        features: [
          'Hourly (12h min) & Daily rental flexibility',
          'Doorstep delivery anywhere in Pangasinan',
          'Self-drive or with professional driver options',
          '100% digital contract, MPIN & electronic signatures',
        ],
        ctaText: 'Sign Up as Renter',
        onCta: widget.onSignup,
        icon: Icons.key_rounded,
        isMobile: isMobile,
      );
    } else if (_activeRoleTab == 1) {
      // Driver
      return _buildRoleCardLayout(
        badge: 'FOR PROFESSIONAL DRIVERS',
        title: 'Earn Transparent Daily Driver Fees in Pangasinan',
        description:
            'Join our elite pool of accredited drivers. Receive assigned rental trips across Pangasinan and neighboring regions with clear route waypoints, guaranteed daily driver rates, and transparent payout settlements.',
        features: [
          'Fixed PHP 1,500.00 / day driver fee guaranteed',
          'Digital itinerary & GPS route guidance in-app',
          'Protected by Mobilis verification & safety guidelines',
          'Instant driver settlement & trip rating records',
        ],
        ctaText: 'Apply as Driver',
        onCta: widget.onSignup,
        icon: Icons.airline_seat_recline_extra_rounded,
        isMobile: isMobile,
      );
    } else {
      // Partner
      return _buildRoleCardLayout(
        badge: 'FOR VEHICLE OWNERS (PARTNERS)',
        title: 'Turn Your Vehicle Into a High-Earning Asset',
        description:
            'List your car with Mobilis PSDC. We handle verified renter screenings, digital contracts, and vehicle tracking. Monitor your vehicle’s live GPS location 24/7 with our integrated AIKA / Traccar GPS system.',
        features: [
          'Earn high monthly passive income per vehicle',
          'Real-time GPS tracker connection & monitoring',
          'Full digital pre-trip and post-trip condition logs',
          'Operator-backed fleet management and security',
        ],
        ctaText: 'List Your Vehicle',
        onCta: widget.onSignup,
        icon: Icons.handshake_rounded,
        isMobile: isMobile,
      );
    }
  }

  Widget _buildRoleCardLayout({
    required String badge,
    required String title,
    required String description,
    required List<String> features,
    required String ctaText,
    required VoidCallback onCta,
    required IconData icon,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 36),
      decoration: BoxDecoration(
        color: const Color(0xFF091636),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: features.map((f) => SizedBox(
              width: isMobile ? double.infinity : 320,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: isMobile ? double.infinity : null,
            child: ElevatedButton.icon(
              onPressed: onCta,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(ctaText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: const Color(0xFF030A18),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.width < 768;

    return Container(
      key: widget.sectionKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: widget.isDesktop ? 80 : 48,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF061229),
        border: Border.symmetric(horizontal: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              const Text(
                'A UNIFIED ECOSYSTEM',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'One Platform For Renters, Drivers & Partners',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.isDesktop ? 36 : (widget.isTablet ? 28 : 24),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Whether you want to rent a car, drive professionally, or earn passive income with your vehicle—Mobilis PSDC connects everything seamlessly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Role Tabs Switcher (Scrollable horizontally on mobile)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF030A18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRoleTabButton(0, '🔑 Rent a Car (Renter)'),
                      _buildRoleTabButton(1, '🧑‍✈️ Drive as Driver'),
                      _buildRoleTabButton(2, '🤝 List Your Vehicle (Partner)'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Active Role Tab Details Card
              _buildActiveRoleContent(widget.isDesktop, isMobile),
            ],
          ),
        ),
      ),
    );
  }
}
