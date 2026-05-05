import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class OwnerVerificationScreen extends StatefulWidget {
  const OwnerVerificationScreen({super.key});

  @override
  State<OwnerVerificationScreen> createState() =>
      _OwnerVerificationScreenState();
}

class _OwnerVerificationScreenState extends State<OwnerVerificationScreen> {
  // Verification status for each item
  Map<String, String> verificationStatus = {
    'national_id': 'not_started',
    'drivers_license': 'not_started',
    'vehicle_registration': 'not_started',
    'face_scan': 'not_started',
    'profile_picture': 'not_started',
  };

  double get overallProgress {
    int completed = verificationStatus.values
        .where((s) => s == 'completed')
        .length;
    return completed / verificationStatus.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'MOBILIS BY PSDC',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Verification',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Owner Verification',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete these requirements to start listing your vehicles and earning with Mobilis',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Overall Progress
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Overall Progress',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${(overallProgress * 100).toInt()}% Complete',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: overallProgress == 1.0
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: overallProgress,
                      minHeight: 8,
                      backgroundColor: AppColors.darkBgTertiary,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        overallProgress == 1.0
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Verification Items
            _buildVerificationItem(
              icon: Icons.badge_outlined,
              title: 'National ID',
              subtitle: 'Front & Back scan required',
              status: verificationStatus['national_id']!,
              onTap: () => _navigateToUpload('national_id', 'National ID'),
            ),
            _buildVerificationItem(
              icon: Icons.credit_card,
              title: "Driver's License",
              subtitle: 'Required for insurance coverage',
              status: verificationStatus['drivers_license']!,
              onTap: () =>
                  _navigateToUpload('drivers_license', "Driver's License"),
            ),
            _buildVerificationItem(
              icon: Icons.description_outlined,
              title: 'Vehicle Registration',
              subtitle: 'OR/CR & Official Papers',
              status: verificationStatus['vehicle_registration']!,
              onTap: () =>
                  Navigator.pushNamed(context, '/vehicle-registration-upload'),
            ),
            _buildVerificationItem(
              icon: Icons.face_outlined,
              title: 'Live Face Scan',
              subtitle: 'Biometric identity verification',
              status: verificationStatus['face_scan']!,
              onTap: () => Navigator.pushNamed(context, '/face-scan'),
            ),
            _buildVerificationItem(
              icon: Icons.account_circle_outlined,
              title: 'Profile Picture',
              subtitle: 'Visible on your owner profile',
              status: verificationStatus['profile_picture']!,
              onTap: () =>
                  Navigator.pushNamed(context, '/profile-picture-upload'),
            ),
            const SizedBox(height: 32),

            // Start Verification Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Start Verification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Help text
            Center(
              child: Text(
                'Need help? Contact our support team',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required VoidCallback onTap,
  }) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = AppColors.success;
        statusText = 'COMPLETED';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = AppColors.warning;
        statusText = 'PENDING';
        statusIcon = Icons.pending;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusText = 'REJECTED';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = AppColors.textTertiary;
        statusText = 'NOT STARTED';
        statusIcon = Icons.circle_outlined;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == 'completed'
                ? AppColors.success.withAlpha(50)
                : AppColors.borderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.darkBgTertiary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 14),
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
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToUpload(String type, String title) {
    Navigator.pushNamed(
      context,
      '/document-upload',
      arguments: {'type': type, 'title': title},
    );
  }

  void _startVerification() {
    // Find the first incomplete verification item and navigate to it
    if (verificationStatus['national_id'] != 'completed') {
      _navigateToUpload('national_id', 'National ID');
    } else if (verificationStatus['drivers_license'] != 'completed') {
      _navigateToUpload('drivers_license', "Driver's License");
    } else if (verificationStatus['vehicle_registration'] != 'completed') {
      Navigator.pushNamed(context, '/vehicle-registration-upload');
    } else if (verificationStatus['face_scan'] != 'completed') {
      Navigator.pushNamed(context, '/face-scan');
    } else if (verificationStatus['profile_picture'] != 'completed') {
      Navigator.pushNamed(context, '/profile-picture-upload');
    }
  }
}
