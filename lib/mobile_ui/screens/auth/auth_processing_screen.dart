import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../theme/app_colors.dart';

enum AuthProcessingMode { login, logout }

class AuthProcessingScreen extends StatefulWidget {
  final AuthProcessingMode mode;

  const AuthProcessingScreen({super.key, this.mode = AuthProcessingMode.login});

  static AuthProcessingMode modeFromArguments(Object? arguments) {
    if (arguments is Map && arguments['mode']?.toString() == 'logout') {
      return AuthProcessingMode.logout;
    }
    return AuthProcessingMode.login;
  }

  @override
  State<AuthProcessingScreen> createState() => _AuthProcessingScreenState();
}

class _AuthProcessingScreenState extends State<AuthProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _processAuthFlow());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processAuthFlow() async {
    if (widget.mode == AuthProcessingMode.logout) {
      await _processLogout();
      return;
    }
    await _processLoginRouting();
  }

  Future<void> _processLogout() async {
    try {
      await Future.wait([
        AuthService().signOut(),
        Future<void>.delayed(const Duration(milliseconds: 850)),
      ]);
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _processLoginRouting() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 850));
      final authService = AuthService();
      if (!authService.isAuthenticated) {
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      final role = await authService.getUserRole();
      final applicationApproved = role == 'partner' || role == 'driver'
          ? await authService.isApplicationApproved()
          : true;
      final route = _routeForRole(role, applicationApproved);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  String _routeForRole(String? role, bool applicationApproved) {
    switch (role) {
      case 'admin':
        return '/admin-home';
      case 'operator':
        return '/operator-home';
      case 'partner':
        return applicationApproved
            ? '/partner-home'
            : '/identity-verification-form';
      case 'driver':
        return applicationApproved
            ? '/driver-home'
            : '/driver-identity-verification';
      case 'renter':
        return '/dashboard';
      default:
        return '/login';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogout = widget.mode == AuthProcessingMode.logout;
    final title = isLogout ? 'Signing you out' : 'Signing you in';
    final subtitle = isLogout
        ? 'Closing your secure session...'
        : 'Checking your account and preparing your dashboard...';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.32),
                        blurRadius: 34,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(
                        width: 76,
                        height: 76,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black,
                          ),
                        ),
                      ),
                      Image.asset(
                        'assets/icon/logo-black.png',
                        width: 46,
                        height: 46,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.directions_car,
                          color: Colors.black,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              const LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: AppColors.darkBgSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
