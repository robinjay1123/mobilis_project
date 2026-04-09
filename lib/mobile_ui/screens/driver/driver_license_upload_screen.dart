import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_service.dart';
import '../../../services/connectivity_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class DriverLicenseUploadScreen extends StatefulWidget {
  const DriverLicenseUploadScreen({super.key});

  @override
  State<DriverLicenseUploadScreen> createState() =>
      _DriverLicenseUploadScreenState();
}

class _DriverLicenseUploadScreenState extends State<DriverLicenseUploadScreen> {
  late TextEditingController licenseNumberController;
  DateTime? selectedExpiryDate;
  String? licenseImageFront;
  String? licenseImageBack;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    licenseNumberController = TextEditingController();
  }

  @override
  void dispose() {
    licenseNumberController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectExpiryDate() async {
    final future = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (future != null) {
      setState(() {
        selectedExpiryDate = future;
      });
    }
  }

  bool _validateInputs() {
    if (licenseNumberController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your license number');
      return false;
    }

    if (selectedExpiryDate == null) {
      _showErrorSnackBar('Please select license expiry date');
      return false;
    }

    if (licenseImageFront == null) {
      _showErrorSnackBar('Please upload license front photo');
      return false;
    }

    if (licenseImageBack == null) {
      _showErrorSnackBar('Please upload license back photo');
      return false;
    }

    return true;
  }

  Future<void> _uploadLicense() async {
    // Check internet
    final connectivityService = ConnectivityService();
    if (!connectivityService.isOnline) {
      _showErrorSnackBar(
        'No internet connection. Please check your WiFi or mobile data.',
      );
      return;
    }

    if (!_validateInputs()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authService = AuthService();
      final driverService = DriverService();
      final user = authService.currentUser;

      if (user != null) {
        // Get or create driver profile
        var driverProfile = await driverService.getDriverProfile(user.id);

        if (driverProfile == null) {
          // Create driver profile with initial license info
          driverProfile = await driverService.createDriverProfile(
            userId: user.id,
            licenseNumber: licenseNumberController.text.trim(),
            licenseExpiry: selectedExpiryDate!,
            nbiClearanceNumber: 'PENDING', // Set temporarily
            nbiExpiry: DateTime.now().add(const Duration(days: 365)),
          );
        }

        // Upload license document
        await driverService.uploadDriverDocument(
          driverId: driverProfile['id'],
          documentType: 'license',
          fileUrl:
              'license_${user.id}_front.png', // In production, upload to storage
          issueDate: DateTime.now().subtract(const Duration(days: 365)),
          expiryDate: selectedExpiryDate!,
        );

        if (mounted) {
          _showSuccessSnackBar('License uploaded successfully!');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/driver-nbi-upload');
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error uploading license: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.black),
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
              'Driver License Verification',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your driver\'s license to verify your identity',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // License Number
            CustomTextField(
              controller: licenseNumberController,
              label: 'License Number',
              hintText: 'Enter your license number',
              prefixIcon: const Icon(Icons.badge),
            ),
            const SizedBox(height: 20),

            // Expiry Date
            GestureDetector(
              onTap: _selectExpiryDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderColor
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'License Expiry Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedExpiryDate != null
                                ? '${selectedExpiryDate!.year}-${selectedExpiryDate!.month.toString().padLeft(2, '0')}-${selectedExpiryDate!.day.toString().padLeft(2, '0')}'
                                : 'Select expiry date',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // License Photos Info
            Text(
              'License Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Front Photo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'License Front',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'Clear photo of license front',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (licenseImageFront != null)
                        const Icon(Icons.check_circle, color: Colors.green)
                      else
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Back Photo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'License Back',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'Clear photo of license back',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (licenseImageBack != null)
                        const Icon(Icons.check_circle, color: Colors.green)
                      else
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Info Box
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
                    '📌 Important',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ensure the license is not expired and photos are clear and readable.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Upload Button
            CustomButton(
              label: isLoading ? 'Uploading...' : 'Continue to NBI Clearance',
              onPressed: isLoading ? null : _uploadLicense,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
