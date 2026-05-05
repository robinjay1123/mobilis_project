import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../../services/auth_service.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  late int _remainingSeconds;
  bool _isSkipping = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 3;
    _simulateFaceScan();
  }

  Future<void> _simulateFaceScan() async {
    for (int i = 3; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _remainingSeconds = i - 1;
        });
      }
    }
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/license-upload');
    }
  }

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
                'Face Scan',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Position your face in the circle and hold still for 3 seconds',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Face scan circle with timer
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
                        border: Border.all(color: AppColors.primary, width: 3),
                      ),
                    ),
                    // Inner circle with gradient
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        gradient: RadialGradient(
                          colors: [
                            AppColors.darkBgSecondary,
                            AppColors.darkBgTertiary,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          size: 80,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    // Timer badge
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.darkBgSecondary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Text(
                          '${_remainingSeconds.toString().padLeft(2, '0')}:00s',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Checklist items
              _buildChecklistItem(
                icon: Icons.light,
                title: 'Lighting Check',
                description: 'Ensure your face is well lit',
                isChecked: true,
              ),
              const SizedBox(height: 16),
              _buildChecklistItem(
                icon: Icons.face,
                title: 'Alignment',
                description: 'Keep eyes within the center',
                isChecked: false,
              ),
              const SizedBox(height: 48),

              // Manual Capture button
              CustomButton(
                label: 'Manual Capture',
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/license-upload');
                },
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
              const SizedBox(height: 16),
              Center(
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
