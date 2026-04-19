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
    this.logoPath = 'assets/icon/logo-wtext.png',
    this.actions,
    this.showLogo = true,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Back button or logo
              if (onBackPressed != null)
                GestureDetector(
                  onTap: onBackPressed,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                )
              else if (showLogo)
                Container(
                  height: 50,
                  width: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(logoPath, fit: BoxFit.contain),
                ),
              if (actions != null) const Spacer(),
              // Actions
              if (actions != null) ...actions! else const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
