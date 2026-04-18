import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../theme/app_colors.dart';

class VerificationOptionsScreen extends StatefulWidget {
  const VerificationOptionsScreen({super.key});

  @override
  State<VerificationOptionsScreen> createState() =>
      _VerificationOptionsScreenState();
}

class _VerificationOptionsScreenState extends State<VerificationOptionsScreen> {
  bool isCreatingBasicAccount = false;
  late Future<String?> roleFuture;

  @override
  void initState() {
    super.initState();
    final authService = AuthService();
    roleFuture = authService.getUserRole();
  }

  void _handleSkipVerification() async {
    setState(() {
      isCreatingBasicAccount = true;
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
          isCreatingBasicAccount = false;
        });
      }
    }
  }

  void _handleRenterVerification() {
    Navigator.of(context).pushReplacementNamed('/id-verification');
  }

  Future<void> _handlePartnerVerification() async {
    final authService = AuthService();
    await authService.updateUserApplicationStatus(status: 'pending');
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/owner-verification');
  }

  Future<void> _handleDriverVerification() async {
    final authService = AuthService();
    await authService.updateUserApplicationStatus(status: 'pending');
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/driver-license-upload');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: FutureBuilder<String?>(
        future: roleFuture,
        builder: (context, snapshot) {
          final userRole = snapshot.data;

          return SingleChildScrollView(
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

                  // Title
                  Text(
                    userRole == 'driver'
                        ? 'Driver Verification'
                        : userRole == 'partner'
                        ? 'Partner Verification'
                        : 'Verify Your Identity',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userRole == 'driver'
                        ? 'Upload your documents to apply as a driver. Admin approval is required before you can go on-call.'
                        : userRole == 'partner'
                        ? 'Complete the basic security check first, then submit your partner application for admin approval.'
                        : 'Verification unlocks full access to rent cars. Browse without verification.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Conditional verification options
                  if (userRole == 'driver')
                    _buildDriverVerificationOptions()
                  else if (userRole == 'partner')
                    _buildPartnerVerificationOptions()
                  else
                    _buildRenterVerificationOptions(),

                  const SizedBox(height: 32),

                  // Info box
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
                        Text(
                          userRole == 'driver' ? 'Why Verify?' : 'Why Verify?',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userRole == 'driver'
                              ? 'Verification takes a few minutes and ensures our platform remains safe and trustworthy. You\'ll be able to accept driving jobs and start earning.'
                              : 'Verification takes 2 minutes and keeps our community safe. You\'ll be able to rent amazing cars and enjoy exclusive benefits.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDriverVerificationOptions() {
    return Column(
      children: [
        // Full Verification Option (Recommended)
        GestureDetector(
          onTap: _handleDriverVerification,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        color: AppColors.success,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Full Verification',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFeature('✓ Accept driving jobs immediately'),
                _buildFeature('✓ Start earning as a driver'),
                _buildFeature('✓ Build your driver rating'),
                _buildFeature('✓ Access all premium features'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Basic Account Option
        GestureDetector(
          onTap: _handleSkipVerification,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textTertiary.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.warning,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Basic Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Skip for now',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFeature('• Browse the app'),
                _buildFeature('• Cannot accept driving jobs'),
                _buildFeature('• Limited features'),
                _buildFeature('• Verify anytime from settings'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerVerificationOptions() {
    return Column(
      children: [
        GestureDetector(
          onTap: _handlePartnerVerification,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront,
                        color: AppColors.success,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Partner Application',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Admin approval required',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFeature('✓ Complete basic security verification'),
                _buildFeature('✓ Submit business / vehicle documents'),
                _buildFeature('✓ Wait for admin approval'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRenterVerificationOptions() {
    return Column(
      children: [
        // Verified Account Option
        GestureDetector(
          onTap: _handleRenterVerification,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        color: AppColors.success,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verified Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFeature('✓ Rent cars immediately'),
                _buildFeature('✓ Full access to all vehicles'),
                _buildFeature('✓ Premium booking priority'),
                _buildFeature('✓ Higher booking limits'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Basic Account Option
        GestureDetector(
          onTap: _handleSkipVerification,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textTertiary.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.warning,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Basic Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Skip for now',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFeature('• Browse all available cars'),
                _buildFeature('• View listings and details'),
                _buildFeature('• Cannot rent until verified'),
                _buildFeature('• Verify anytime from settings'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}
