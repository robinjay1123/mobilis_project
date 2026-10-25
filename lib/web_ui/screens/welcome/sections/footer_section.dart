import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';
import '../welcome_web_constants.dart';

class FooterSection extends StatelessWidget {
  final Key? contactKey;
  final bool isDesktop;
  final double width;
  final VoidCallback onSignup;
  final VoidCallback onDownloadApk;
  final VoidCallback onLogin;

  const FooterSection({
    super.key,
    this.contactKey,
    required this.isDesktop,
    required this.width,
    required this.onSignup,
    required this.onDownloadApk,
    required this.onLogin,
  });

  Widget _buildPreFooterCta(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 36 : 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 36, vertical: isMobile ? 32 : 48),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF132854), Color(0xFF0A1733)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 40,
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'READY TO HIT THE ROAD?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create Your Mobilis Account Today',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 36 : (isMobile ? 22 : 26),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Instant bookings, GPS protection, and flexible hourly or daily rates throughout Pangasinan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: onSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF030A18),
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Create Free Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    ),
                    ElevatedButton.icon(
                      onPressed: onDownloadApk,
                      icon: const Icon(Icons.android_rounded, size: 18, color: Colors.white),
                      label: const Text('Download Android APK', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F2B5C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0x55FFD740)),
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Admin & Operator Portal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterBrandColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/icon/logo-black.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            const Text(
              'MOBILIS PSDC',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Pangasinan’s premier car rental solutions platform. Verified fleet, accredited drivers, and registered vehicle partners.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => WelcomeWebConstants.openUrl(WelcomeWebConstants.googleMapsLocationUrl),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${WelcomeWebConstants.mainOfficeLocation} (${WelcomeWebConstants.mainOfficePlusCode})',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0x55FFD740),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterContactsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CONTACTS & SUPPORT', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => WelcomeWebConstants.callPhone(WelcomeWebConstants.hotline1),
          child: const Text('📞 ${WelcomeWebConstants.hotline1}', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => WelcomeWebConstants.callPhone(WelcomeWebConstants.hotline2),
          child: const Text('📞 ${WelcomeWebConstants.hotline2}', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => WelcomeWebConstants.openUrl(WelcomeWebConstants.facebookUrl),
          child: const Text('🌐 fb.com/psdc.dagupan', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildFooterQuickLinksColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK ACCESS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => WelcomeWebConstants.openUrl(WelcomeWebConstants.playStoreUrl),
          child: const Text('🛍️ Google Play Store', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        InkWell(onTap: onDownloadApk, child: const Text('📲 Download Android App (.apk)', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(height: 6),
        InkWell(onTap: onLogin, child: const Text('Admin & Operator Portal', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
        const SizedBox(height: 6),
        InkWell(onTap: onDownloadApk, child: const Text('Register via Mobile App', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => Navigator.of(context).pushNamed('/terms-and-privacy'),
          child: const Text('Legal Terms & Privacy Policy', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = width < 768;

    return Column(
      children: [
        _buildPreFooterCta(isMobile),
        Container(
          key: contactKey,
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 40),
          decoration: const BoxDecoration(
            color: Color(0xFF020712),
            border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                children: [
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Brand & Address
                        Expanded(
                          flex: 2,
                          child: _buildFooterBrandColumn(),
                        ),
                        const SizedBox(width: 48),
                        // Contacts
                        Expanded(
                          child: _buildFooterContactsColumn(),
                        ),
                        // Quick Links
                        Expanded(
                          child: _buildFooterQuickLinksColumn(context),
                        ),
                      ],
                    )
                  else
                    // Mobile & Tablet Stacked Footer
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFooterBrandColumn(),
                        const SizedBox(height: 24),
                        _buildFooterContactsColumn(),
                        const SizedBox(height: 24),
                        _buildFooterQuickLinksColumn(context),
                      ],
                    ),
                  const Divider(color: Color(0x1AFFFFFF), height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          '© 2026 Mobilis PSDC. All rights reserved.',
                          style: TextStyle(color: Color(0xFF475569), fontSize: 11),
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Pangasinan, PH',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
