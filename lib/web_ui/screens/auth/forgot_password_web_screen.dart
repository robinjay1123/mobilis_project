import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../mobile_ui/theme/app_colors.dart';
import '../../../mobile_ui/widgets/custom_button.dart';
import '../../../mobile_ui/widgets/custom_text_field.dart';

class ForgotPasswordWebScreen extends StatefulWidget {
  const ForgotPasswordWebScreen({super.key});

  @override
  State<ForgotPasswordWebScreen> createState() =>
      _ForgotPasswordWebScreenState();
}

class _ForgotPasswordWebScreenState extends State<ForgotPasswordWebScreen> {
  late TextEditingController emailController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  bool emailSent = false;

  void _handleResetPassword() async {
    final connectivityService = ConnectivityService();
    if (!connectivityService.isOnline) {
      _showErrorSnackBar(
        'No internet connection. Please check your WiFi or mobile data.',
      );
      return;
    }

    final rawInput = emailController.text.trim();
    if (rawInput.isEmpty) {
      _showErrorSnackBar('Please enter your email or mobile number');
      return;
    }

    if (rawInput.contains('@')) {
      final isValidEmail = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      ).hasMatch(rawInput);
      if (!isValidEmail) {
        _showErrorSnackBar('Please enter a valid email address');
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authService = AuthService();
      debugPrint(
        '🔐 [ForgotPasswordWebScreen] Requesting reset for: $rawInput',
      );

      final resetEmail = await authService.resolvePasswordResetEmail(rawInput);
      await authService.resetPassword(
        email: resetEmail,
        redirectTo: '${Uri.base.origin}/#/reset-password',
      );

      debugPrint('✅ [ForgotPasswordWebScreen] Reset request completed');
    } catch (e) {
      debugPrint('❌ [ForgotPasswordWebScreen] Error during reset request: $e');
      if (mounted && e.toString().contains('rate limit')) {
        final authService = AuthService();
        _showErrorSnackBar(authService.getErrorMessage(e));
        setState(() {
          isLoading = false;
        });
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          emailSent = true;
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 1200.0 ? 1200.0 : screenWidth;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: maxWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: Row(
                children: [
                  // Left side - Branding
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            color: Colors.black,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Mobilis',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Forgot Your Password?',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Enter your email address or mobile number. The reset link will be sent to your registered email.',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 60),

                  // Right side - Form
                  Expanded(
                    child: emailSent
                        ? Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.success.withOpacity(0.4),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.mark_email_read_outlined,
                                      size: 56,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Password Reset Link Sent',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'If an account exists with this email, a password reset link has been sent. Check your inbox for instructions.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              CustomButton(
                                label: 'Back to Login',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              CustomTextField(
                                label: 'Email or Mobile Number',
                                hintText: 'name@gmail.com or 09XXXXXXXXX',
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: const Icon(
                                  Icons.contact_mail_outlined,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 40),
                              CustomButton(
                                label: isLoading ? 'Sending...' : 'Send Reset Link',
                                onPressed: isLoading ? null : _handleResetPassword,
                                isLoading: isLoading,
                              ),
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Back to Login',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'The reset link is sent to the registered email, even when a mobile number is used.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
