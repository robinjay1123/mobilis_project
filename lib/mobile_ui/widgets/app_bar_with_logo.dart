import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBarWithLogo extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String logoPath;
  final List<Widget>? actions;
  final bool showLogo;
  final VoidCallback? onBackPressed;

  const AppBarWithLogo({
    super.key,
    this.title = 'Mobilis',
    this.logoPath = 'assets/icon/logo-wtext-nobg.png',
    this.actions,
    this.showLogo = true,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button or logo
              if (onBackPressed != null)
                GestureDetector(
                  onTap: onBackPressed,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                )
              else if (showLogo)
                Container(
                  height: 60,
                  width: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    logoPath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              // Spacer to push actions to the right
              if (actions != null && actions!.isNotEmpty) ...[
                const Spacer(),
                // Actions container with better styling
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkCard.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(
                        actions!.length,
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: actions![index],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
