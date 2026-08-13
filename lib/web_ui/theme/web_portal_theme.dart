import 'package:flutter/material.dart';

import '../../mobile_ui/theme/app_colors.dart';

class WebPortalTheme {
  const WebPortalTheme._();

  static ThemeData resolve(BuildContext context, {required bool isDark}) {
    final base = Theme.of(context);
    final foreground = isDark ? Colors.white : const Color(0xFF122033);
    final border = isDark ? AppColors.borderColor : const Color(0xFFD8E0EA);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return base.copyWith(
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF07111D)
          : const Color(0xFFEDF1F6),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF102033) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 3,
        shadowColor: isDark
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: isDark ? border : const Color(0xFFCBD5E1)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: buttonPadding,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          disabledBackgroundColor: isDark
              ? const Color(0xFF263648)
              : const Color(0xFFE4E8ED),
          disabledForegroundColor: isDark ? Colors.white38 : Colors.black38,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: buttonShape,
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: buttonPadding,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: buttonPadding,
          foregroundColor: foreground,
          side: BorderSide(color: border, width: 1.2),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(42, 42),
          padding: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: isDark ? const Color(0xFF0B1826) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF102033) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
