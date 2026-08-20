import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedLoadingWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final String logoPath;
  final String? gifPath;

  const AnimatedLoadingWidget({
    super.key,
    this.title = 'Mobilis',
    this.subtitle = 'Professional Car Rental Solutions',
    this.logoPath = 'assets/icon/logo1.png',
    this.gifPath,
  });

  @override
  State<AnimatedLoadingWidget> createState() => _AnimatedLoadingWidgetState();
}

class _AnimatedLoadingWidgetState extends State<AnimatedLoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _glow = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return ScaleTransition(
                      scale: _pulse,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardBg,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: _glow.value * 0.75),
                              blurRadius: 36,
                              spreadRadius: 6,
                            ),
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.8),
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            widget.logoPath,
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/icon/logo-black.png',
                              width: 52,
                              height: 52,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.directions_car_rounded,
                                color: AppColors.primary,
                                size: 44,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryTextColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: 140,
                  height: 3.5,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
