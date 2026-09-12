import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../../services/auth_service.dart';
import '../../../services/verification_service.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  File? _capturedFaceFile;
  bool _isSkipping = false;
  bool _isCapturing = false;

  Future<void> _captureFacePhoto() async {
    setState(() => _isCapturing = true);
    try {
      final file = await VerificationService.pickImage(
        source: ImageSource.camera,
      );
      if (file != null && mounted) {
        setState(() {
          _capturedFaceFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _proceedToLicenseUpload() {
    if (_capturedFaceFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture a face selfie photo first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacementNamed('/license-upload');
  }

  Future<void> _handleSkipVerification() async {
    setState(() {
      _isSkipping = true;
    });

    try {
      final authService = AuthService();
      await authService.updateUserVerificationStatus(verified: false);

      if (mounted) {
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

              // Title
              const Text(
                'Identity Verification',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),

              // Face Scan Title
              const Text(
                'Live Face Capture',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _capturedFaceFile != null
                    ? 'Face photo captured successfully. Review below or retake if needed.'
                    : 'Position your face clearly in camera frame and take a selfie.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Face scan preview circle
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer circle
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(110),
                        border: Border.all(
                          color: _capturedFaceFile != null
                              ? AppColors.success
                              : AppColors.primary,
                          width: 3,
                        ),
                      ),
                    ),
                    // Inner circle
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.darkBgSecondary,
                          gradient: _capturedFaceFile == null
                              ? const RadialGradient(
                                  colors: [
                                    AppColors.darkBgSecondary,
                                    AppColors.darkBgTertiary,
                                  ],
                                )
                              : null,
                        ),
                        child: _capturedFaceFile != null
                            ? Image.file(
                                _capturedFaceFile!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: _isCapturing
                                    ? const CircularProgressIndicator(
                                        color: AppColors.primary,
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 80,
                                        color: AppColors.textSecondary,
                                      ),
                              ),
                      ),
                    ),
                    // Status badge
                    if (_capturedFaceFile != null)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 16, color: Colors.black),
                              SizedBox(width: 4),
                              Text(
                                'Captured',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Checklist items
              _buildChecklistItem(
                icon: Icons.light,
                title: 'Good Lighting',
                description: 'Ensure your face is evenly illuminated',
                isChecked: _capturedFaceFile != null,
              ),
              const SizedBox(height: 16),
              _buildChecklistItem(
                icon: Icons.face,
                title: 'Clear & Centered',
                description: 'Look directly at camera without hat or mask',
                isChecked: _capturedFaceFile != null,
              ),
              const SizedBox(height: 36),

              // Action buttons
              if (_capturedFaceFile == null)
                CustomButton(
                  label: _isCapturing ? 'Opening Camera...' : 'Take Face Photo',
                  onPressed: _isCapturing ? null : _captureFacePhoto,
                )
              else ...[
                CustomButton(
                  label: 'Continue to License Upload',
                  onPressed: _proceedToLicenseUpload,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isCapturing ? null : _captureFacePhoto,
                    icon: const Icon(Icons.refresh, color: AppColors.primary),
                    label: const Text(
                      'Retake Photo',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
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
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'MOBILIS SECURITY SYSTEM',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isChecked,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (isChecked)
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
      ],
    );
  }
}
