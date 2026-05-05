import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFFFFD700); // Yellow
  static const Color primaryDark = Color(0xFFFFC700);

  // Dark Theme Background colors
  static const Color darkBg = Color(0xFF1A1F2E);
  static const Color darkBgSecondary = Color(0xFF2D3748);
  static const Color darkBgTertiary = Color(0xFF374151);
  static const Color darkCard = Color(0xFF252D3D);

  // Light Theme Background colors
  static const Color lightBg = Color(0xFFF5F5F5);
  static const Color lightBgSecondary = Color(0xFFFFFFFF);
  static const Color lightBgTertiary = Color(0xFFF0F0F0);

  // Dark Theme Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);

  // Light Theme Text colors
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF666666);
  static const Color lightTextTertiary = Color(0xFF999999);

  // Dark Theme Border and divider colors
  static const Color borderColor = Color(0xFF374151);

  // Light Theme Border and divider colors
  static const Color lightBorderColor = Color(0xFFE0E0E0);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Rating colors
  static const Color ratingGold = Color(0xFFFFD700);

  // Helper method to get theme-aware colors
  static Color getBgColor(
    BuildContext context, {
    required Color darkColor,
    required Color lightColor,
  }) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkColor
        : lightColor;
  }

  static Color getTextColor(
    BuildContext context, {
    required Color darkColor,
    required Color lightColor,
  }) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkColor
        : lightColor;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? borderColor
        : lightBorderColor;
  }
}
