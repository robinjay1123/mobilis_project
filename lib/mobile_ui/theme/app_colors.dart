import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFFFFD700); // Mobilis Gold / Yellow
  static const Color primaryDark = Color(0xFFFFC700);
  static const Color primaryLight = Color(0xFFFFF9C4);

  // Dark Theme Background colors
  static const Color darkBg = Color(0xFF0F172A); // Midnight Slate
  static const Color darkBgSecondary = Color(0xFF1E293B); // Slate 800
  static const Color darkBgTertiary = Color(0xFF334155); // Slate 700
  static const Color darkCard = Color(0xFF1E293B);

  // Light Theme Background colors
  static const Color lightBg = Color(0xFFF8FAFC); // Clean Slate 50
  static const Color lightBgSecondary = Color(0xFFFFFFFF); // Pure White
  static const Color lightBgTertiary = Color(0xFFF1F5F9); // Slate 100
  static const Color lightCard = Color(0xFFFFFFFF);

  // Dark Theme Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color textTertiary = Color(0xFF64748B); // Slate 500

  // Light Theme Text colors
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600
  static const Color lightTextTertiary = Color(0xFF64748B); // Slate 500

  // Border and divider colors
  static const Color borderColor = Color(0xFF334155); // Dark mode border (Slate 700)
  static const Color lightBorderColor = Color(0xFFCBD5E1); // Light mode border (Slate 300)
  static const Color lightBorderSubtle = Color(0xFFE2E8F0); // Light mode subtle border (Slate 200)

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Rating colors
  static const Color ratingGold = Color(0xFFFFD700);

  // Theme-aware Context Helpers
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color textPrimaryOf(BuildContext context) {
    return isDarkMode(context) ? textPrimary : lightTextPrimary;
  }

  static Color textSecondaryOf(BuildContext context) {
    return isDarkMode(context) ? textSecondary : lightTextSecondary;
  }

  static Color textTertiaryOf(BuildContext context) {
    return isDarkMode(context) ? textTertiary : lightTextTertiary;
  }

  static Color bgOf(BuildContext context) {
    return isDarkMode(context) ? darkBg : lightBg;
  }

  static Color cardOf(BuildContext context) {
    return isDarkMode(context) ? darkCard : lightCard;
  }

  static Color surfaceOf(BuildContext context) {
    return isDarkMode(context) ? darkBgSecondary : lightBgSecondary;
  }

  static Color borderOf(BuildContext context) {
    return isDarkMode(context)
        ? borderColor.withValues(alpha: 0.7)
        : lightBorderColor;
  }

  static Color subtleBorderOf(BuildContext context) {
    return isDarkMode(context)
        ? borderColor.withValues(alpha: 0.45)
        : lightBorderSubtle;
  }

  static Color cardBorderOf(BuildContext context) {
    return isDarkMode(context)
        ? const Color(0xFF334155).withValues(alpha: 0.6)
        : const Color(0xFFE2E8F0);
  }

  static Color chipBgOf(BuildContext context) {
    return isDarkMode(context)
        ? const Color(0xFF1E293B)
        : const Color(0xFFF1F5F9);
  }

  static Color chipBorderOf(BuildContext context) {
    return isDarkMode(context)
        ? const Color(0xFF334155).withValues(alpha: 0.6)
        : const Color(0xFFE2E8F0);
  }

  static Color modalBgOf(BuildContext context) {
    return isDarkMode(context) ? const Color(0xFF1E293B) : Colors.white;
  }

  static Color modalBorderOf(BuildContext context) {
    return isDarkMode(context)
        ? const Color(0xFF334155).withValues(alpha: 0.7)
        : const Color(0xFFE2E8F0);
  }

  static Color inputFillOf(BuildContext context) {
    return isDarkMode(context)
        ? const Color(0xFF0F172A).withValues(alpha: 0.8)
        : const Color(0xFFF8FAFC);
  }

  static Color inputBorderOf(BuildContext context) {
    return isDarkMode(context)
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);
  }

  static List<BoxShadow> cardShadowOf(BuildContext context) {
    if (isDarkMode(context)) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];
  }

  // Legacy helper methods
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

