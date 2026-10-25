import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';
import '../welcome_web_constants.dart';

class TopAnnouncementBar extends StatelessWidget {
  final bool isDesktop;
  final double width;

  const TopAnnouncementBar({
    super.key,
    required this.isDesktop,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = width < 640;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF06142E),
        border: Border(bottom: BorderSide(color: Color(0x20FFD740))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            isMobile ? 'PANGASINAN SERVICE' : 'PANGASINAN & NEARBY PROVINCES ONLY',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => WelcomeWebConstants.openUrl(WelcomeWebConstants.googleMapsLocationUrl),
                        child: const Text(
                          '•   Main Office: Urdaneta City (${WelcomeWebConstants.mainOfficePlusCode})   •   PSDC Fleet',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              InkWell(
                onTap: () => WelcomeWebConstants.callPhone(WelcomeWebConstants.hotline1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      WelcomeWebConstants.hotline1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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
