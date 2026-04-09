import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../../services/auth_service.dart';

class ProfilePictureUploadScreen extends StatefulWidget {
  const ProfilePictureUploadScreen({super.key});

  @override
  State<ProfilePictureUploadScreen> createState() =>
      _ProfilePictureUploadScreenState();
}

class _ProfilePictureUploadScreenState
    extends State<ProfilePictureUploadScreen> {
  bool _isUploaded = false;
  bool _isSkipping = false;

  Future<void> _handleSkipVerification() async {
    setState(() {
      _isSkipping = true;
    });

    try {
      final authService = AuthService();
      // Mark user as having skipped verification
      await authService.updateUserVerificationStatus(verified: false);

      if (mounted) {
        // Check user role and navigate accordingly
        final role = await authService.getUserRole();
        if (role == 'partner') {
          Navigator.of(context).pushReplacementNamed('/partner-home');
        } else {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSkipping = false;
        });
      }
    }
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
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Progress indicator
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        value: 0.75,
                        minHeight: 4,
                        backgroundColor: AppColors.borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Step 3 of 4',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'Profile Picture',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload a clear photo of your face that matches your ID',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Upload area
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isUploaded = true;
                  });
                },
                child: Container(
                  height: 320,
                  decoration: BoxDecoration(
                    color: AppColors.darkBgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isUploaded
                          ? AppColors.success
                          : AppColors.borderColor,
                      style: BorderStyle.solid,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUploaded)
                        Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(60),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.black,
                                size: 60,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Photo Uploaded',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Clear, frontal photo captured',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                color: AppColors.primary,
                                size: 50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tap to upload photo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Portrait orientation recommended',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tips container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkBgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Photo Tips',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTip('✓ Face must be clearly visible'),
                    _buildTip('✓ Good lighting'),
                    _buildTip('✓ No sunglasses or hat'),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Continue button
              Opacity(
                opacity: _isUploaded ? 1.0 : 0.5,
                child: CustomButton(
                  label: 'Continue',
                  onPressed: () {
                    if (_isUploaded) {
                      Navigator.of(
                        context,
                      ).pushReplacementNamed('/verification-options');
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Skip Verification button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSkipping ? null : _handleSkipVerification,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.borderColor),
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSkipping
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textSecondary,
                            ),
                          ),
                        )
                      : const Text('Skip Verification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}
