import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../mobile_ui/screens/auth/login_screen.dart';
import '../mobile_ui/screens/auth/signup_screen.dart';
import '../mobile_ui/screens/welcome/welcome_screen.dart';
import '../web_ui/screens/auth/login_web_screen.dart';
import '../web_ui/screens/auth/signup_web_screen.dart';
import '../web_ui/screens/welcome/welcome_web_screen.dart';

// Responsive Welcome Screen
class ResponsiveWelcomeScreen extends StatelessWidget {
  const ResponsiveWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Use web layout for web platform or large screens (> 900px)
    if (kIsWeb || screenWidth > 900) {
      return const WelcomeWebScreen();
    }

    // Use mobile layout for mobile platforms or small screens
    return const WelcomeScreen();
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

// Responsive Signup Screen
class ResponsiveSignupScreen extends StatelessWidget {
  const ResponsiveSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Use web layout for web platform or large screens (> 900px)
    if (kIsWeb || screenWidth > 900) {
      return const SignupWebScreen();
    }

    // Use mobile layout for mobile platforms or small screens
    return const SignupScreen();
  }
}
