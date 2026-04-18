import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../../services/auth_service.dart';

class LicenseUploadScreen extends StatefulWidget {
  final int step;

  const LicenseUploadScreen({super.key, this.step = 1});

  @override
  State<LicenseUploadScreen> createState() => _LicenseUploadScreenState();
}

class _LicenseUploadScreenState extends State<LicenseUploadScreen> {
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
          Navigator.of(context).pushReplacementNamed('/owner-verification');
        } else if (role == 'driver') {
          Navigator.of(context).pushReplacementNamed('/driver-license-upload');
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
    final isFrontSide = widget.step == 1;

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
                      child: LinearProgressIndicator(
                        value: isFrontSide ? 0.25 : 0.5,
                        minHeight: 4,
                        backgroundColor: AppColors.borderColor,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Step ${widget.step} of 4',
                    style: const TextStyle(
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
                "Driver's License ID Upload",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFrontSide
                    ? 'Scan or upload the front side of your driver\'s license'
                    : 'Scan or upload the back side of your driver\'s license',
                style: const TextStyle(
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
                  height: 280,
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
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Upload Successful',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isFrontSide
                                  ? 'Front side captured'
                                  : 'Back side captured',
                              style: const TextStyle(
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
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: const Icon(
                                Icons.document_scanner_outlined,
                                color: AppColors.primary,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tap to scan or upload',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Make sure document is clear and readable',
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
              const SizedBox(height: 48),

              // Continue button
              Opacity(
                opacity: _isUploaded ? 1.0 : 0.5,
                child: CustomButton(
                  label: 'Continue',
                  onPressed: () {
                    if (_isUploaded) {
                      if (isFrontSide) {
                        Navigator.of(context).pushReplacementNamed(
                          '/license-upload',
                          arguments: {'step': 2},
                        );
                      } else {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed('/profile-picture-upload');
                      }
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
}
