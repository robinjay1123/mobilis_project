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
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _spinController;
  late final Animation<double> _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _glow = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _processAuthFlow());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
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
        Future<void>.delayed(const Duration(milliseconds: 700)),
      ]);
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _processLoginRouting() async {
    try {
      final authService = AuthService();
      if (!authService.isAuthenticated) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      final roleFuture = authService.getUserRole();
      final minDelayFuture = Future<void>.delayed(const Duration(milliseconds: 700));

      final results = await Future.wait([roleFuture, minDelayFuture]);
      final role = results[0] as String?;

      final applicationApproved = role == 'partner' || role == 'driver'
          ? await authService.isApplicationApproved()
          : true;
      final route = _routeForRole(role, applicationApproved);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } catch (e) {
      debugPrint('Auth processing error: $e');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLogout = widget.mode == AuthProcessingMode.logout;
    final title = isLogout ? 'Signing you out' : 'Welcome back';
    final subtitle = isLogout
        ? 'Closing your secure session safely...'
        : 'Preparing your personalized dashboard...';

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final trackBg = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return ScaleTransition(
                      scale: _pulse,
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardBg,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: _glow.value * 0.7),
                              blurRadius: 36,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.8),
                            width: 2.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            RotationTransition(
                              turns: _spinController,
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            Image.asset(
                              'assets/icon/logo1.png',
                              width: 52,
                              height: 52,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/icon/logo-black.png',
                                width: 50,
                                height: 50,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.directions_car_rounded,
                                  color: AppColors.primary,
                                  size: 42,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 38),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 36),
                Container(
                  width: 190,
                  height: 4,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: trackBg,
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
