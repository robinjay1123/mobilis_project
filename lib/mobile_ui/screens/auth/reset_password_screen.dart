import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/connectivity_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late TextEditingController newPasswordController;
  late TextEditingController confirmPasswordController;
  bool isLoading = false;
  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    newPasswordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
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
    if (!_passwordMeetsRequirements(newPasswordController.text)) {
      setState(() {});
      return;
    }

    if (confirmPasswordController.text.isEmpty) {
      _showErrorSnackBar('Please confirm your password');
      return;
    }

    if (newPasswordController.text != confirmPasswordController.text) {
      setState(() {});
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authService = AuthService();
      debugPrint('🔐 [ResetPasswordScreen] Updating password');

      await authService.updatePassword(newPassword: newPasswordController.text);

      debugPrint('✅ [ResetPasswordScreen] Password updated successfully!');

      if (mounted) {
        _showSuccessSnackBar('Password updated successfully!');

        // Navigate back to login after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ [ResetPasswordScreen] Error updating password: $e');
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _passwordMeetsRequirements(String password) =>
      password.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(password) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(password);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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

              // Title
              const Text(
                'Create New Password',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              const Text(
                'Enter your new password below. Make sure it\'s strong and unique.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // New password field
              CustomTextField(
                label: 'New Password *',
                hintText: '••••••••',
                controller: newPasswordController,
                obscureText: obscureNewPassword,
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureNewPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureNewPassword = !obscureNewPassword;
                    });
                  },
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              _buildRequirement(
                'At least 8 characters',
                newPasswordController.text.length >= 8,
              ),
              const SizedBox(height: 6),
              _buildRequirement(
                'At least 1 special character',
                RegExp(r'[^A-Za-z0-9]').hasMatch(newPasswordController.text),
              ),
              const SizedBox(height: 6),
              _buildRequirement(
                'At least 1 uppercase letter',
                RegExp(r'[A-Z]').hasMatch(newPasswordController.text),
              ),
              const SizedBox(height: 20),

              // Confirm password field
              CustomTextField(
                label: 'Confirm Password *',
                hintText: '••••••••',
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureConfirmPassword = !obscureConfirmPassword;
                    });
                  },
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (confirmPasswordController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildRequirement(
                  'Passwords match',
                  newPasswordController.text == confirmPasswordController.text,
                ),
              ],
              const SizedBox(height: 32),

              // Update password button
              CustomButton(
                label: isLoading ? 'Updating...' : 'Update Password',
                onPressed: isLoading ? null : _handleResetPassword,
                isLoading: isLoading,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    final color = isMet ? AppColors.success : AppColors.textTertiary;
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: color)),
        ),
      ],
    );
  }
}
