import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../services/auth_service.dart';
import '../../../services/partner_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ApplyVehicleScreen extends StatefulWidget {
  const ApplyVehicleScreen({super.key});

  @override
  State<ApplyVehicleScreen> createState() => _ApplyVehicleScreenState();
}

class _ApplyVehicleScreenState extends State<ApplyVehicleScreen> {
  late TextEditingController brandController;
  late TextEditingController modelController;
  late TextEditingController yearController;
  late TextEditingController plateNumberController;
  late TextEditingController pricePerDayController;
  late TextEditingController pricePerHourController;

  int selectedSeats = 5;
  String selectedFuelType = 'Gasoline';
  String selectedTransmission = 'Manual';
  bool isLoading = false;
  bool isCheckingEligibility = true;
  bool hasPendingApplication = false;
  String verificationStatus = 'pending';
  File? _orDocumentFile;
  File? _crDocumentFile;
  File? _vehiclePhotoFile;

  final List<int> seatOptions = [2, 4, 5, 7, 8, 12];
  final List<String> fuelTypeOptions = [
    'Gasoline',
    'Diesel',
    'Hybrid',
    'Electric',
  ];
  final List<String> transmissionOptions = ['Manual', 'Automatic'];

  @override
  void initState() {
    super.initState();
    brandController = TextEditingController();
    modelController = TextEditingController();
    yearController = TextEditingController();
    plateNumberController = TextEditingController();
    pricePerDayController = TextEditingController();
    pricePerHourController = TextEditingController();
    _loadEligibilityState();
  }

  @override
  void dispose() {
    brandController.dispose();
    modelController.dispose();
    yearController.dispose();
    plateNumberController.dispose();
    pricePerDayController.dispose();
    pricePerHourController.dispose();
    super.dispose();
  }

  Future<void> _loadEligibilityState() async {
    try {
      final authService = AuthService();
      final partnerService = PartnerService();
      final user = authService.currentUser;

      if (user != null) {
        final hasPending = await partnerService.hasPendingApplication(user.id);
        final status = _normalizeVerificationStatus(
          await partnerService.getVerificationStatus(user.id),
        );

        if (!mounted) return;
        setState(() {
          hasPendingApplication = hasPending;
          verificationStatus = status;
          isCheckingEligibility = false;
        });
      } else if (mounted) {
        setState(() {
          isCheckingEligibility = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking partner eligibility: $e');
      if (mounted) {
        setState(() {
          isCheckingEligibility = false;
        });
      }
    }
  }

  bool get _isVerifiedPartner =>
      verificationStatus == 'verified' || verificationStatus == 'certified';

  void _goToVerification() {
    Navigator.pushNamed(context, '/identity-verification-form');
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

  bool _validateInputs() {
    if (brandController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter the vehicle brand');
      return false;
    }

    if (modelController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter the vehicle model');
      return false;
    }

    if (yearController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter the vehicle year');
      return false;
    }

    final year = int.tryParse(yearController.text.trim());
    if (year == null || year < 1990 || year > DateTime.now().year + 1) {
      _showErrorSnackBar(
        'Please enter a valid year (1990-${DateTime.now().year + 1})',
      );
      return false;
    }

    if (plateNumberController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter the plate number');
      return false;
    }

    if (pricePerDayController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter the price per day');
      return false;
    }

    final pricePerDay = double.tryParse(pricePerDayController.text.trim());
    if (pricePerDay == null || pricePerDay <= 0) {
      _showErrorSnackBar('Please enter a valid price per day');
      return false;
    }

    if (pricePerHourController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter the price per hour');
      return false;
    }

    final pricePerHour = double.tryParse(pricePerHourController.text.trim());
    if (pricePerHour == null || pricePerHour <= 0) {
      _showErrorSnackBar('Please enter a valid price per hour');
      return false;
    }

    if (_orDocumentFile == null) {
      _showErrorSnackBar('Please upload OR document');
      return false;
    }

    if (_crDocumentFile == null) {
      _showErrorSnackBar('Please upload CR document');
      return false;
    }

    return true;
  }

  Future<void> _pickDocument(String docType) async {
    final file = await VerificationService.pickImage(
      source: ImageSource.gallery,
    );
    if (file == null) return;

    setState(() {
      if (docType == 'or') {
        _orDocumentFile = file;
      } else if (docType == 'cr') {
        _crDocumentFile = file;
      } else {
        _vehiclePhotoFile = file;
      }
    });
  }

  Future<void> _handleSubmit() async {
    // Check internet connection
    final connectivityService = ConnectivityService();
    if (!connectivityService.isOnline) {
      _showErrorSnackBar('No internet connection');
      return;
    }

    if (!_validateInputs()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final authService = AuthService();
      final partnerService = PartnerService();
      final user = authService.currentUser;

      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final partnerId = user.id;

      // Check again for pending application
      final hasPending = await partnerService.hasPendingApplication(partnerId);
      if (hasPending) {
        _showErrorSnackBar('You already have a pending application');
        setState(() {
          hasPendingApplication = true;
          isLoading = false;
        });
        return;
      }

      final latestVerificationStatus = _normalizeVerificationStatus(
        await partnerService.getVerificationStatus(partnerId),
      );
      if (latestVerificationStatus != 'verified') {
        _showErrorSnackBar(
          'Complete your identity verification before applying a vehicle.',
        );
        setState(() {
          verificationStatus = latestVerificationStatus;
          isLoading = false;
        });
        return;
      }

      // Submit application
      final orDocumentUrl = await partnerService.uploadToPartnerDocumentsBucket(
        partnerId: partnerId,
        file: _orDocumentFile!,
        documentType: 'or_document',
      );
      final crDocumentUrl = await partnerService.uploadToPartnerDocumentsBucket(
        partnerId: partnerId,
        file: _crDocumentFile!,
        documentType: 'cr_document',
      );
      String? vehiclePhotoUrl;
      if (_vehiclePhotoFile != null) {
        vehiclePhotoUrl = await partnerService.uploadToPartnerDocumentsBucket(
          partnerId: partnerId,
          file: _vehiclePhotoFile!,
          documentType: 'vehicle_photo',
        );
      }

      await partnerService.submitVehicleApplication(
        partnerId: partnerId,
        brand: brandController.text.trim(),
        model: modelController.text.trim(),
        year: int.parse(yearController.text.trim()),
        plateNumber: plateNumberController.text.trim().toUpperCase(),
        seats: selectedSeats,
        pricePerDay: double.parse(pricePerDayController.text.trim()),
        pricePerHour: double.parse(pricePerHourController.text.trim()),
        orDocumentUrl: orDocumentUrl,
        crDocumentUrl: crDocumentUrl,
        fuelType: selectedFuelType,
        transmission: selectedTransmission,
        vehiclePhotoUrl: vehiclePhotoUrl,
      );

      if (mounted) {
        _showSuccessSnackBar('Application submitted successfully!');
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to submit application: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.darkBgSecondary,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(itemLabel(item)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
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
        title: const Text(
          'Apply Vehicle Unit',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: hasPendingApplication
          ? _buildPendingApplicationWarning()
          : isCheckingEligibility
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : !_isVerifiedPartner
          ? _buildVerificationRequiredWarning()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'List Your Vehicle',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Fill in the details below to apply your vehicle for rental.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Vehicle Details Section
                  const Text(
                    'Vehicle Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Brand
                  CustomTextField(
                    label: 'Brand',
                    hintText: 'e.g., Toyota, Honda, Ford',
                    controller: brandController,
                    prefixIcon: const Icon(
                      Icons.directions_car,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Model
                  CustomTextField(
                    label: 'Model',
                    hintText: 'e.g., Camry, Civic, Mustang',
                    controller: modelController,
                    prefixIcon: const Icon(
                      Icons.drive_eta,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Year and Seats row
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Year',
                          hintText: 'e.g., 2022',
                          controller: yearController,
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(
                            Icons.calendar_today,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Seats',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.darkBgSecondary,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: selectedSeats,
                                  isExpanded: true,
                                  dropdownColor: AppColors.darkBgSecondary,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                  items: seatOptions.map((seats) {
                                    return DropdownMenuItem(
                                      value: seats,
                                      child: Text('$seats seats'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedSeats = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Plate Number
                  CustomTextField(
                    label: 'Plate Number',
                    hintText: 'e.g., ABC 1234',
                    controller: plateNumberController,
                    prefixIcon: const Icon(
                      Icons.confirmation_number,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField<String>(
                          label: 'Transmission',
                          value: selectedTransmission,
                          items: transmissionOptions,
                          itemLabel: (value) => value,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedTransmission = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdownField<String>(
                          label: 'Fuel Type',
                          value: selectedFuelType,
                          items: fuelTypeOptions,
                          itemLabel: (value) => value,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedFuelType = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pricing Section
                  const Text(
                    'Pricing',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price per day
                  CustomTextField(
                    label: 'Price per Day',
                    hintText: 'e.g., 2500',
                    controller: pricePerDayController,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(
                      Icons.attach_money,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price per hour
                  CustomTextField(
                    label: 'Price per Hour',
                    hintText: 'e.g., 150',
                    controller: pricePerHourController,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(
                      Icons.schedule,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Required documents
                  const Text(
                    'Application Documents',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildUploadCard(
                    title: 'OR Document',
                    subtitle: 'Upload Official Receipt image',
                    selectedFile: _orDocumentFile,
                    onTap: () => _pickDocument('or'),
                    requiredDoc: true,
                  ),
                  const SizedBox(height: 12),
                  _buildUploadCard(
                    title: 'CR Document',
                    subtitle: 'Upload Certificate of Registration image',
                    selectedFile: _crDocumentFile,
                    onTap: () => _pickDocument('cr'),
                    requiredDoc: true,
                  ),
                  const SizedBox(height: 12),
                  _buildUploadCard(
                    title: 'Vehicle Photo',
                    subtitle: 'Optional but recommended',
                    selectedFile: _vehiclePhotoFile,
                    onTap: () => _pickDocument('vehicle_photo'),
                    requiredDoc: false,
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  CustomButton(
                    label: 'Submit Application',
                    onPressed: _handleSubmit,
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your application will be reviewed by our team. You will be notified once it is approved or if we need additional information.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildVerificationRequiredWarning() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Verification Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Finish your identity verification before submitting a vehicle application.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                label: 'Go to Verification',
                onPressed: _goToVerification,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApplicationWarning() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pending,
                size: 64,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pending Application',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You already have a pending vehicle application. Please wait for it to be reviewed before submitting a new one.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                label: 'Go Back',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required File? selectedFile,
    required VoidCallback onTap,
    required bool requiredDoc,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload_file, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requiredDoc ? '$title *' : title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedFile != null
                        ? selectedFile.path.split('\\').last
                        : subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selectedFile != null ? Icons.check_circle : Icons.chevron_right,
              color: selectedFile != null
                  ? AppColors.success
                  : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

String _normalizeVerificationStatus(String? status) {
  final value = (status ?? 'pending').toLowerCase();
  if (value == 'approved') return 'verified';
  return value;
}
