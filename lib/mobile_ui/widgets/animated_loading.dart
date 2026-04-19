import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedLoadingWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String gifPath;
  final String logoPath;

  const AnimatedLoadingWidget({
    super.key,
    this.title = 'Mobilis by PSDC',
    this.subtitle = 'Professional Car Rental Solutions',
    this.gifPath = 'assets/loading.gif',
    this.logoPath = 'assets/icon/logo1.png',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated loading GIF
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(gifPath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 32),
            // App name
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            // Tagline
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),
            // Loading text
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
