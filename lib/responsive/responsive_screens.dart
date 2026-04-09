import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../mobile_ui/screens/operator/operator_home_screen.dart';
import '../mobile_ui/screens/admin/admin_home_screen.dart';
import '../mobile_ui/screens/auth/login_screen.dart';
import '../web_ui/screens/operator/operator_web_screen.dart';
import '../web_ui/screens/admin/admin_web_screen.dart';
import '../web_ui/screens/auth/login_web_screen.dart';

class ResponsiveOperatorScreen extends StatelessWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const ResponsiveOperatorScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Use web layout for web platform or large screens (> 900px)
    if (kIsWeb || screenWidth > 900) {
      return OperatorWebScreen(
        onThemeToggle: onThemeToggle,
        isDarkMode: isDarkMode,
      );
    }

    // Use mobile layout for mobile platforms or small screens
    return OperatorHomeScreen(
      onThemeToggle: onThemeToggle,
      isDarkMode: isDarkMode,
    );
  }
}

class ResponsiveAdminScreen extends StatelessWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const ResponsiveAdminScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Use web layout for web platform or large screens (> 900px)
    if (kIsWeb || screenWidth > 900) {
      return AdminWebScreen(
        onThemeToggle: onThemeToggle,
        isDarkMode: isDarkMode,
      );
    }

    // Use mobile layout for mobile platforms or small screens
    return AdminHomeScreen(
      onThemeToggle: onThemeToggle,
      isDarkMode: isDarkMode,
    );
  }
}

// Preview widgets - Force specific layouts for testing
class PreviewOperatorWeb extends StatelessWidget {
  const PreviewOperatorWeb({super.key});

  @override
  Widget build(BuildContext context) {
    // Always show web layout
    return const OperatorWebScreen();
  }
}

class PreviewOperatorMobile extends StatelessWidget {
  const PreviewOperatorMobile({super.key});

  @override
  Widget build(BuildContext context) {
    // Always show mobile layout
    return const OperatorHomeScreen();
  }
}

class PreviewAdminWeb extends StatelessWidget {
  const PreviewAdminWeb({super.key});

  @override
  Widget build(BuildContext context) {
    // Always show web layout
    return const AdminWebScreen();
  }
}

class PreviewAdminMobile extends StatelessWidget {
  const PreviewAdminMobile({super.key});

  @override
  Widget build(BuildContext context) {
    // Always show mobile layout
    return const AdminHomeScreen();
  }
}

// Responsive Login Screen
class ResponsiveLoginScreen extends StatelessWidget {
  const ResponsiveLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Use web layout for web platform or large screens (> 900px)
    if (kIsWeb || screenWidth > 900) {
      return const LoginWebScreen();
    }

    // Use mobile layout for mobile platforms or small screens
    return const LoginScreen();
  }
}

// Preview Login widgets
class PreviewLoginWeb extends StatelessWidget {
  const PreviewLoginWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginWebScreen();
  }
}

class PreviewLoginMobile extends StatelessWidget {
  const PreviewLoginMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
