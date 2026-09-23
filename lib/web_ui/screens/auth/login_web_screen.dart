import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../mobile_ui/theme/app_colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'forgot_password_web_screen.dart';

class LoginWebScreen extends StatefulWidget {
  const LoginWebScreen({super.key});

  @override
  State<LoginWebScreen> createState() => _LoginWebScreenState();
}

class _LoginWebScreenState extends State<LoginWebScreen> {
  late TextEditingController emailController;
  late TextEditingController passwordController;
  bool rememberDevice = false;
  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (isLoading) return;

    final connectivityService = ConnectivityService();
    if (!connectivityService.isOnline) {
      _showErrorSnackBar(
        'No internet connection. Please check your WiFi or mobile data.',
      );
      return;
    }

    if (emailController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your email address');
      return;
    }

    if (passwordController.text.isEmpty) {
      _showErrorSnackBar('Please enter your password');
      return;
    }

    if (!_isValidEmail(emailController.text.trim())) {
      _showErrorSnackBar('Please enter a valid email address');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authService = AuthService();
      await authService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (mounted) {
        emailController.clear();
        passwordController.clear();
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/auth-processing',
          (route) => false,
          arguments: {'mode': 'login'},
        );

        // Fallback: If AuthWrapper doesn't navigate within 3 seconds, manually navigate
        Future.delayed(const Duration(seconds: 3), () async {
          if (mounted) {
            final currentRoute = ModalRoute.of(context)?.settings.name;
            if (currentRoute == '/login' || currentRoute == null) {
              debugPrint(
                '⚠️ [LoginWebScreen] Still on login after 3s, attempting manual fallback',
              );
              try {
                final authService = AuthService();
                final role = await authService.getUserRole();
                debugPrint(
                  '📍 [LoginWebScreen Fallback] Manual route resolution: $role',
                );
                if (mounted) {
                  String fallbackRoute = '/dashboard';
                  if (role == 'admin') {
                    fallbackRoute = '/admin-home';
                  } else if (role == 'operator') {
                    fallbackRoute = '/operator-home';
                  } else if (role == 'partner') {
                    fallbackRoute = '/partner-home';
                  } else if (role == 'driver') {
                    fallbackRoute = '/driver-home';
                  }

                  Navigator.of(context).pushReplacementNamed(fallbackRoute);
                  debugPrint(
                    '🚀 [LoginWebScreen Fallback] Navigated to: $fallbackRoute',
                  );
                }
              } catch (e) {
                debugPrint('❌ [LoginWebScreen Fallback] Error: $e');
              }
            }
          }
        });
        // AuthWrapper will handle routing based on auth state change
      }
    } catch (e) {
      if (mounted) {
        final authService = AuthService();
        final errorMessage = authService.getErrorMessage(e);

        if (errorMessage.contains('Email not confirmed')) {
          _showErrorSnackBar(
            'Email not confirmed - Check your inbox to verify.',
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              emailController.clear();
              passwordController.clear();
              // AuthWrapper will handle routing
            }
          });
        } else {
          _showErrorSnackBar(errorMessage);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _handleGoogleLogin() async {
    if (isLoading) return;

    final connectivityService = ConnectivityService();
    if (!connectivityService.isOnline) {
      _showErrorSnackBar(
        'No internet connection. Please check your WiFi or mobile data.',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authService = AuthService();
      await authService.signInWithGoogle();

      if (mounted) {
        // AuthWrapper will handle routing based on auth state change
      }
    } catch (e) {
      if (mounted) {
        final authService = AuthService();
        final errorMessage = authService.getErrorMessage(e);
        _showErrorSnackBar(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;
          final isTablet =
              constraints.maxWidth >= 600 && constraints.maxWidth < 960;

          if (isDesktop) {
            return _buildDesktopLayout(constraints);
          } else {
            return _buildCompactLayout(constraints, isTablet);
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    return Row(
      children: [
        // Left side - Branding panel
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.darkBg,
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse('https://mobilis.autos'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/icon/logo-black.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Mobilis',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your trusted car rental platform',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Feature highlights
                    _buildFeatureItem(
                      Icons.verified_user,
                      'Verified Partners',
                      'All partners undergo strict verification',
                    ),
                    const SizedBox(height: 24),
                    _buildFeatureItem(
                      Icons.security,
                      'Secure Payments',
                      'Protected transactions & insurance',
                    ),
                    const SizedBox(height: 24),
                    _buildFeatureItem(
                      Icons.support_agent,
                      '24/7 Support',
                      'Always here when you need us',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Right side - Login form
        Expanded(
          flex: 1,
          child: Container(
            color: AppColors.darkBg,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: _buildLoginForm(isCompact: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints, bool isTablet) {
    final isMobile = !isTablet;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.darkBg,
            AppColors.darkBg,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 36,
              vertical: isMobile ? 24 : 40,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Compact Branding Header
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isMobile ? 56 : 68,
                          height: isMobile ? 56 : 68,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/icon/logo-black.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Mobilis',
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your trusted car rental platform',
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (isTablet) ...[
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _buildFeatureChip(
                                Icons.verified_user,
                                'Verified Partners',
                              ),
                              _buildFeatureChip(
                                Icons.security,
                                'Secure Payments',
                              ),
                              _buildFeatureChip(
                                Icons.support_agent,
                                '24/7 Support',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 24 : 32),

                  // Form Container (card wrapper on tablet, clean flat on mobile)
                  if (isTablet)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.borderColor,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _buildLoginForm(isCompact: true),
                    )
                  else
                    _buildLoginForm(isCompact: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm({required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: isCompact ? 28 : 36,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please enter your credentials to access your account.',
          style: TextStyle(
            fontSize: isCompact ? 14 : 16,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        SizedBox(height: isCompact ? 26 : 40),

        // Email field
        _buildLabel('Email Address'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: emailController,
          hintText: 'name@gmail.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 20),

        // Password field
        _buildLabel('Password'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: passwordController,
          hintText: '••••••••',
          prefixIcon: Icons.lock_outline,
          obscureText: obscurePassword,
          onSubmitted: (_) => _handleLogin(),
          suffixIcon: IconButton(
            icon: Icon(
              obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textTertiary,
            ),
            onPressed: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
          ),
        ),
        const SizedBox(height: 14),

        // Remember device & Forgot password (Responsive Wrap to prevent overflow)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: rememberDevice,
                    onChanged: (value) {
                      setState(() {
                        rememberDevice = value ?? false;
                      });
                    },
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary;
                      }
                      return Colors.transparent;
                    }),
                    side: const BorderSide(color: AppColors.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember for 30 days',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordWebScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 24 : 32),

        // Login button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Text(
                    'Log In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        SizedBox(height: isCompact ? 24 : 32),

        // Divider
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.borderColor,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR CONTINUE WITH',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.borderColor,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 20 : 24),

        // Google login
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _handleGoogleLogin,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.borderColor),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(FontAwesomeIcons.google, size: 20),
                SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isCompact ? 24 : 32),

        // Sign up link
        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed('/signup');
            },
            child: RichText(
              text: const TextSpan(
                text: "Don't have an account? ",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: 'Create an account',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        prefixIcon: Icon(prefixIcon, color: AppColors.textTertiary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
