import 'package:flutter/material.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/auth_service.dart';
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  late TextEditingController fullNameController;
  late TextEditingController idNumberController;
  late TextEditingController locationController;
  late TextEditingController phoneController;
  String? selectedIdType = 'Passport';
  bool isLoading = false;
  File? idPhotoFile;

  @override
  void initState() {
    super.initState();
    fullNameController = TextEditingController();
    idNumberController = TextEditingController();
    locationController = TextEditingController();
    phoneController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    idNumberController.dispose();
    locationController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authService = AuthService();
    final user = authService.currentUser;

    if (user != null) {
      setState(() {
        fullNameController.text = user.userMetadata?['name'] ?? '';        locationController.text = user.userMetadata?['location'] ?? '';
        phoneController.text = user.userMetadata?['phone'] ?? '';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final location =
            '${place.locality}, ${place.administrativeArea}, ${place.country}';
        setState(() {
          locationController.text = location;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleVerification() async {
    // Validate inputs
    if (fullNameController.text.trim().isEmpty) {
      _showError('Please enter your full name');
      return;
    }

    if (idNumberController.text.trim().isEmpty) {
      _showError('Please enter your ID number');
      return;
    }

    if (locationController.text.trim().isEmpty) {
      _showError('Please enter your location');
      return;
    }

    if (phoneController.text.trim().isEmpty) {
      _showError('Please enter your phone number');
      return;
    }

    if (idPhotoFile == null) {
      _showError('Please attach or capture a photo of your ID');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authService = AuthService();
      final user = authService.currentUser;

      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      final uploadResult = await VerificationService.uploadIdentityPhoto(
        userId: user.id,
        idPhotoFile: idPhotoFile!,
      );

      if (uploadResult['success'] != true) {
        _showError(uploadResult['message']?.toString() ?? 'Failed to upload ID photo');
        return;
      }

      final idDocumentUrl =
          (uploadResult['data'] as Map<String, dynamic>)['id_photo_url']
              ?.toString();

      // Update user profile with verification data
      await authService.updateUserVerification(
        fullName: fullNameController.text.trim(),
        idType: selectedIdType ?? 'Passport',
        idNumber: idNumberController.text.trim(),
        location: locationController.text.trim(),
        phone: phoneController.text.trim(),
        idDocumentUrl: idDocumentUrl,
      );

      if (mounted) {
        // Show success dialog
        _showSuccessDialog();
      }
    } catch (e) {
      _showError('Error during verification: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ID Verification Complete!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your identity has been verified\nYou can now start renting',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed('/dashboard');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Go to Dashboard',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
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

  Future<void> _pickIdPhoto(ImageSource source) async {
    final file = await VerificationService.pickImage(source: source);
    if (file == null) return;
    setState(() {
      idPhotoFile = file;
    });
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
              // Logo
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        'assets/icon/logo-black.png',
                        fit: BoxFit.contain,
                      ),
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
                'Verify Your Identity',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete ID verification to start\nrenting cars on Mobilis',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Full Name
              CustomTextField(
                label: 'Full Name',
                hintText: 'Enter your full name',
                controller: fullNameController,
                prefixIcon: const Icon(
                  Icons.person_outline,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 20),

              // ID Type
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ID Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedIdType,
                        icon: const Icon(
                          Icons.expand_more,
                          color: AppColors.textTertiary,
                        ),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        items: ['Passport', 'Driver License', 'National ID']
                            .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            })
                            .toList(),
                        onChanged: (String? value) {
                          setState(() {
                            selectedIdType = value;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ID Number
              CustomTextField(
                label: 'ID Number',
                hintText: 'Enter your ID number',
                controller: idNumberController,
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 20),

              // Phone
              CustomTextField(
                label: 'Phone Number',
                hintText: '+1(555) 000-0000',
                controller: phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 20),

              // Location with auto-detect
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: TextField(
                      controller: locationController,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'City, Country',
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.textTertiary,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.location_searching,
                            color: AppColors.primary,
                          ),
                          onPressed: _getCurrentLocation,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ID photo capture/upload section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ID Photo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Column(
                      children: [
                        if (idPhotoFile != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              idPhotoFile!,
                              width: double.infinity,
                              height: 170,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.darkBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderColor),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  color: AppColors.textTertiary,
                                  size: 28,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Attach or capture your ID photo',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (idPhotoFile != null) ...[
                          const SizedBox(height: 8),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'ID photo selected',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickIdPhoto(ImageSource.camera),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Capture',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickIdPhoto(ImageSource.gallery),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(
                                    color: AppColors.borderColor,
                                  ),
                                  backgroundColor: AppColors.darkBgTertiary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Attach',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Submit Button
              CustomButton(
                label: 'Complete Verification',
                onPressed: _handleVerification,
                isLoading: isLoading,
              ),
              const SizedBox(height: 24),

              // Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkBgSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: const Text(
                  '✓ Your information is secure and encrypted. We only use it to verify your identity and prevent fraud.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
