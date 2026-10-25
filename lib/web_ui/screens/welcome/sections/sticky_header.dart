import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../mobile_ui/theme/app_colors.dart';

class StickyHeader extends StatelessWidget {
  final bool isDesktop;
  final double width;
  final VoidCallback onScrollToVehicles;
  final VoidCallback onScrollToModes;
  final VoidCallback onScrollToHub;
  final VoidCallback onScrollToEstimator;
  final VoidCallback onScrollToFaq;
  final VoidCallback onScrollToContact;
  final VoidCallback onShowDownloadApk;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  const StickyHeader({
    super.key,
    required this.isDesktop,
    required this.width,
    required this.onScrollToVehicles,
    required this.onScrollToModes,
    required this.onScrollToHub,
    required this.onScrollToEstimator,
    required this.onScrollToFaq,
    required this.onScrollToContact,
    required this.onShowDownloadApk,
    required this.onLogin,
    required this.onSignup,
  });

  void _showMobileNavSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF07142E),
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                _buildMobileNavItem('🚗  Vehicles', () {
                  Navigator.of(context).pop();
                  onScrollToVehicles();
                }),
                _buildMobileNavItem('🔄  3-in-1 Platform (Renter, Driver, Partner)', () {
                  Navigator.of(context).pop();
                  onScrollToModes();
                }),
                _buildMobileNavItem('📍  Pangasinan Hub & Coverage', () {
                  Navigator.of(context).pop();
                  onScrollToHub();
                }),
                _buildMobileNavItem('💰  Rental Cost Estimator', () {
                  Navigator.of(context).pop();
                  onScrollToEstimator();
                }),
                _buildMobileNavItem('❓  FAQ', () {
                  Navigator.of(context).pop();
                  onScrollToFaq();
                }),
                _buildMobileNavItem('📞  Contact & Support', () {
                  Navigator.of(context).pop();
                  onScrollToContact();
                }),
                const Divider(color: Color(0x1AFFFFFF), height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onShowDownloadApk();
                    },
                    icon: const Icon(Icons.android_rounded, size: 18),
                    label: const Text('Download Android APK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF030A18),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onLogin();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Admin & Operator Portal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileNavItem(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderNavLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = width < 768;

    return Container(
      width: double.infinity,
      height: isMobile ? 68 : 84,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: const Color(0xE6030A18),
        border: const Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand Logo
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://mobilis.autos'),
                  webOnlyWindowName: '_self',
                ),
                child: Row(
                  children: [
                    Container(
                      width: isMobile ? 38 : 44,
                      height: isMobile ? 38 : 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD740), Color(0xFFFFB300)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(5),
                      child: Image.asset('assets/icon/logo-black.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'MOBILIS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PSDC',
                                style: TextStyle(
                                  color: Color(0xFF030A18),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isMobile)
                          const Text(
                            'PANGASINAN CAR RENTAL HUB',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Navigation links (Desktop)
              if (isDesktop)
                Row(
                  children: [
                    _buildHeaderNavLink('Vehicles', onScrollToVehicles),
                    _buildHeaderNavLink('3-in-1 Platform', onScrollToModes),
                    _buildHeaderNavLink('Pangasinan Hub', onScrollToHub),
                    _buildHeaderNavLink('Cost Estimator', onScrollToEstimator),
                    _buildHeaderNavLink('FAQ', onScrollToFaq),
                    _buildHeaderNavLink('Contact', onScrollToContact),
                  ],
                ),

              // Desktop Header Actions
              if (isDesktop)
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onShowDownloadApk,
                      icon: const Icon(Icons.android_rounded, size: 16, color: AppColors.primary),
                      label: const Text('Download APK', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x44FFD740)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: onLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x33FFFFFF)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: onSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF030A18),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        children: [
                          Text('Register', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                )
              else
                // Mobile & Tablet Header Actions
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: onLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x44FFFFFF)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showMobileNavSheet(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1F42),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                      ),
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
