import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    _loadCachedCredentials();
  }

  /// Load cached credentials from device
  Future<void> _loadCachedCredentials() async {
    try {
      final prefsService = PreferencesService();
      await prefsService.init();

      final cachedEmail = prefsService.getCachedLoginEmail();
      final cachedPassword = prefsService.getCachedLoginPassword();
      final rememberEnabled = prefsService.isRememberDeviceEnabled();

      if (mounted && cachedEmail != null && cachedPassword != null) {
        setState(() {
          emailController.text = cachedEmail;
          passwordController.text = cachedPassword;
          rememberDevice = rememberEnabled;
        });
        debugPrint('Cached credentials loaded successfully');
      }
    } catch (e) {
      debugPrint('Error loading cached credentials: $e');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    // Check internet connection first
    final connectivityService = ConnectivityService();
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      _showErrorSnackBar(
        'No internet connection. Please check your WiFi or mobile data.',
      );
      return;
    }

    // Validate inputs
    if (emailController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your email address');
      return;
    }

    if (passwordController.text.isEmpty) {
      _showErrorSnackBar('Please enter your password');
      return;
    }

    // Validate email format
    if (!_isValidEmail(emailController.text.trim())) {
      _showErrorSnackBar('Please enter a valid email address');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authService = AuthService();
      debugPrint(
        '🔐 [LoginScreen] Attempting login with: ${emailController.text.trim()}',
      );
      await authService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
        rememberDevice: rememberDevice,
      );

      debugPrint(
        '✅ [LoginScreen] Login successful! AuthWrapper will handle routing.',
      );
      if (mounted) {
        // Clear controllers only on successful login
        emailController.clear();
        passwordController.clear();

        // Fallback: If AuthWrapper doesn't navigate within 3 seconds, manually navigate
        Future.delayed(const Duration(seconds: 3), () async {
          if (mounted) {
            final currentRoute = ModalRoute.of(context)?.settings.name;
            if (currentRoute == '/login') {
              debugPrint(
                '⚠️ [LoginScreen] Still on login after 3s, attempting manual fallback',
              );
              try {
                final authService = AuthService();
                final role = await authService.getUserRole();
                debugPrint(
                  '📍 [LoginScreen Fallback] Manual route resolution: $role',
                );
                if (mounted) {
                  String fallbackRoute = '/dashboard';
                  if (role == 'admin')
                    fallbackRoute = '/admin-home';
                  else if (role == 'operator')
                    fallbackRoute = '/operator-home';
                  else if (role == 'partner')
                    fallbackRoute = '/partner-home';
                  else if (role == 'driver')
                    fallbackRoute = '/driver-home';

                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(fallbackRoute, (route) => false);
                  debugPrint(
                    '🚀 [LoginScreen Fallback] Navigated to: $fallbackRoute',
                  );
                }
              } catch (e) {
                debugPrint('❌ [LoginScreen Fallback] Error: $e');
              }
            }
          }
        });
        // AuthWrapper will handle routing based on auth state change
      }
    } catch (e) {
      debugPrint('❌ [LoginScreen] Login failed with error: $e');
      if (mounted) {
        final authService = AuthService();
        final errorMessage = authService.getErrorMessage(e);

        // If email is not confirmed, still allow access to dashboard
        if (errorMessage.contains('Email not confirmed')) {
          _showErrorSnackBar(
            'Email not confirmed - Check your inbox to verify. You can still access your account.',
          );

          // Clear controllers - AuthWrapper will handle routing
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              emailController.clear();
              passwordController.clear();
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
    // Check internet connection first
    final connectivityService = ConnectivityService();
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
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
        // AuthWrapper listens for signed-in state and routes by role.
        _showInfoSnackBar(
          'Continue in the browser and return to the app to finish sign in.',
        );
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

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Mobilis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Welcome text
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please enter your credentials to\naccess your account.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Email field
              CustomTextField(
                label: 'Email Address',
                hintText: 'name@gmail.com',
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 20),

              // Password field
              CustomTextField(
                label: 'Password',
                hintText: '••••••••',
                controller: passwordController,
                obscureText: obscurePassword,
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textTertiary,
                ),
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
              const SizedBox(height: 16),

              // Remember device checkbox
              Row(
                children: [
                  Checkbox(
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
                  const Expanded(
                    child: Text(
                      'Remember this device for 30 days',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: Navigate to forgot password
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Login button
              CustomButton(
                label: 'Log In',
                onPressed: _handleLogin,
                isLoading: isLoading,
              ),
              const SizedBox(height: 32),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: AppColors.borderColor),
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
                    child: Container(height: 1, color: AppColors.borderColor),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Social login buttons
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _handleGoogleLogin,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.borderColor),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FontAwesomeIcons.google, size: 20),
                      const SizedBox(width: 12),
                      const Text('Continue with Google'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Partnership promotion banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.business,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Become a Partner',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Earn passive income by renting out your vehicle. Join our community of successful partners today!',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to partnership application or info page
                          // For now, navigate to signup with partner flag
                          Navigator.of(context).pushNamed('/signup');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Apply for Partnership',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
          ),
        ),
      ),
    );
  }
}
