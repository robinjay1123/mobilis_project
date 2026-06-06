import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class DriverNBIUploadScreen extends StatefulWidget {
  const DriverNBIUploadScreen({super.key});

  @override
  State<DriverNBIUploadScreen> createState() => _DriverNBIUploadScreenState();
}

class _DriverNBIUploadScreenState extends State<DriverNBIUploadScreen> {
  late TextEditingController nbiNumberController;
  DateTime? selectedExpiryDate;
  File? nbiDocumentFile;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nbiNumberController = TextEditingController();
  }

  Future<void> _pickNBIDocument() async {
    final file = await VerificationService.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      nbiDocumentFile = file;
    });
  }

  @override
  void dispose() {
    nbiNumberController.dispose();
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
    if (nbiNumberController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your NBI clearance number');
      return false;
    }

    if (selectedExpiryDate == null) {
      _showErrorSnackBar('Please select NBI expiry date');
      return false;
    }

    if (nbiDocumentFile == null) {
      _showErrorSnackBar('Please upload NBI clearance document');
      return false;
    }

    return true;
  }

  Future<void> _uploadNBIClearance() async {
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
        // Get driver profile (should exist from license upload)
        var driverProfile = await driverService.getDriverProfile(user.id);

        if (driverProfile != null) {
          final nbiUrl = await driverService.uploadToDriverDocumentsBucket(
            userId: user.id,
            file: nbiDocumentFile!,
            documentType: 'nbi_clearance',
          );

          // Upload NBI clearance document
          await driverService.uploadDriverDocument(
            driverId: driverProfile['id'],
            documentType: 'nbi_clearance',
            fileUrl: nbiUrl,
            issueDate: DateTime.now().subtract(const Duration(days: 365)),
            expiryDate: selectedExpiryDate!,
          );

          // Update driver profile with NBI info
          await driverService.updateDriverProfile(
            driverProfile['id'],
            {
              'nbi_file_url': nbiUrl,
              'verification_status': 'pending',
            },
          );

          if (mounted) {
            _showSuccessSnackBar('NBI clearance uploaded successfully!');
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/driver-availability');
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error uploading NBI clearance: $e');
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
              'NBI Clearance Verification',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your NBI clearance to complete verification',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // NBI Number
            CustomTextField(
              controller: nbiNumberController,
              label: 'NBI Clearance Number',
              hintText: 'Enter your NBI clearance number',
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
                            'NBI Expiry Date',
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

            // NBI Document Info
            Text(
              'NBI Clearance Document',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Document Upload
            GestureDetector(
              onTap: _pickNBIDocument,
              child: Container(
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
                          Icons.file_present_outlined,
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
                              'NBI Clearance',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'PDF or image of NBI clearance',
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
                      if (nbiDocumentFile != null)
                        const Icon(Icons.check_circle, color: Colors.green)
                      else
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],
              ),
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
                    'Ensure the NBI clearance is valid and the document is clear and readable. No criminal records should be present.',
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
              label: isLoading
                  ? 'Uploading...'
                  : 'Continue to Availability Setup',
              onPressed: isLoading ? null : _uploadNBIClearance,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
