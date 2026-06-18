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
  bool ownerIsDriver = false;
  bool isLoading = false;
  bool isCheckingEligibility = true;
  bool hasPendingApplication = false;
  String verificationStatus = 'pending';
  int _currentStep = 0;
  File? _orDocumentFile;
  File? _crDocumentFile;
  final List<File> _vehiclePhotoFiles = [];

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

    if (_vehiclePhotoFiles.isEmpty) {
      _showErrorSnackBar('Please upload at least one vehicle photo');
      return false;
    }

    return true;
  }

  bool _validateVehicleStep() {
    if (brandController.text.trim().isEmpty ||
        modelController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter the vehicle model/name');
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

    final pricePerDay = double.tryParse(pricePerDayController.text.trim());
    if (pricePerDay == null || pricePerDay <= 0) {
      _showErrorSnackBar('Please enter a valid target daily rental price');
      return false;
    }

    if (_vehiclePhotoFiles.isEmpty) {
      _showErrorSnackBar('Please upload a vehicle photo');
      return false;
    }

    return true;
  }

  void _continueApplication() {
    if (_currentStep == 0) {
      setState(() => _currentStep = 1);
      return;
    }

    if (_currentStep == 1) {
      if (!_validateVehicleStep()) return;
      setState(() => _currentStep = 2);
      return;
    }

    _handleSubmit();
  }

  Future<void> _pickDocument(String docType) async {
    if (docType == 'vehicle_photo') {
      await _pickVehiclePhotos();
      return;
    }

    final file = await VerificationService.pickImage(
      source: ImageSource.gallery,
    );
    if (file == null) return;

    setState(() {
      if (docType == 'or') {
        _orDocumentFile = file;
      } else if (docType == 'cr') {
        _crDocumentFile = file;
      }
    });
  }

  Future<void> _pickVehiclePhotos() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 85);
    if (pickedFiles.isEmpty) return;

    final existingPaths = _vehiclePhotoFiles.map((file) => file.path).toSet();
    final newFiles = pickedFiles
        .where((file) => !existingPaths.contains(file.path))
        .map((file) => File(file.path))
        .toList();

    if (newFiles.isEmpty) return;

    setState(() {
      _vehiclePhotoFiles.addAll(newFiles);
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
      final vehiclePhotoUrls = <String>[];
      for (var i = 0; i < _vehiclePhotoFiles.length; i++) {
        final url = await partnerService.uploadToPartnerDocumentsBucket(
          partnerId: partnerId,
          file: _vehiclePhotoFiles[i],
          documentType: 'vehicle_photo_${i + 1}',
        );
        vehiclePhotoUrls.add(url);
      }
      final vehiclePhotoUrl = vehiclePhotoUrls.isEmpty
          ? null
          : vehiclePhotoUrls.first;

      final application = await partnerService.submitVehicleApplication(
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
        ownerIsDriver: ownerIsDriver,
      );
      final applicationId = application['id']?.toString();
      if (applicationId != null && applicationId.isNotEmpty) {
        await partnerService.addVehicleApplicationPhotos(
          applicationId: applicationId,
          photoUrls: vehiclePhotoUrls,
        );
      }

      if (mounted) {
        setState(() {
          hasPendingApplication = true;
          _currentStep = 3;
        });
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
          'Mobilis Partners',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(
              Icons.account_circle_outlined,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: hasPendingApplication
          ? _buildStatusTracker()
          : isCheckingEligibility
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : !_isVerifiedPartner
          ? _buildVerificationRequiredWarning()
          : _currentStep == 0
          ? _buildIntroStep()
          : _buildApplicationFlow(),
    );
  }

  Widget _buildIntroStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroPanel(
            title: 'Partner',
            subtitle:
                'Join our trusted network of car owners and start earning with our premium rental platform.',
          ),
          const SizedBox(height: 30),
          _buildStepHeader(step: 'STEP 1 OF 3', label: 'Profile Verification'),
          const SizedBox(height: 34),
          const Text(
            'Application Requirements',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please prepare the following documents to complete your partnership request.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          _buildRequirementTile(
            icon: Icons.description_outlined,
            title: 'Business Permit',
            subtitle: "Current year Mayor's Permit",
          ),
          _buildRequirementTile(
            icon: Icons.business_outlined,
            title: 'DTI / SEC Registration',
            subtitle: 'Certificate of Registration',
          ),
          _buildRequirementTile(
            icon: Icons.badge_outlined,
            title: 'Valid ID',
            subtitle: 'Government issued Identification',
          ),
          _buildRequirementTile(
            icon: Icons.directions_car_outlined,
            title: 'Proof of Ownership',
            subtitle: 'OR/CR for all listed vehicles',
          ),
          const SizedBox(height: 34),
          CustomButton(
            label: 'Apply for Partnership ->',
            onPressed: _continueApplication,
          ),
          const SizedBox(height: 14),
          _buildTermsText(),
        ],
      ),
    );
  }

  Widget _buildApplicationFlow() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroPanel(
            title: _currentStep == 1
                ? 'List Your Vehicle'
                : 'Business Documents',
            subtitle: _currentStep == 1
                ? 'Provide your vehicle details and high-quality photos to start earning today.'
                : 'Upload your registration documents so our team can verify ownership.',
          ),
          const SizedBox(height: 30),
          _buildStepHeader(
            step: _currentStep == 1 ? 'STEP 1 OF 4' : 'STEP 2 OF 4',
            label: _currentStep == 1 ? 'Vehicle Details' : 'Documents',
          ),
          const SizedBox(height: 34),
          if (_currentStep == 1) _buildVehicleDetailsStep(),
          if (_currentStep == 2) _buildDocumentStep(),
          const SizedBox(height: 34),
          CustomButton(
            label: _currentStep == 1
                ? 'Apply for Partnership ->'
                : 'Submit for Review ->',
            onPressed: _continueApplication,
            isLoading: isLoading,
          ),
          const SizedBox(height: 14),
          _buildTermsText(),
          const SizedBox(height: 28),
          _buildNextStepNote(),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Photos',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 18),
        _buildPhotoPreviewGrid(),
        const SizedBox(height: 28),
        const Text(
          'Vehicle Information',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Provide the essential details about your vehicle.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 22),
        CustomTextField(
          label: 'Car Model / Name',
          hintText: 'e.g. Toyota Fortuner 2023',
          controller: modelController,
          prefixIcon: const Icon(
            Icons.directions_car,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 14),
        CustomTextField(
          label: 'Brand',
          hintText: 'e.g. Toyota',
          controller: brandController,
          prefixIcon: const Icon(Icons.sell, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Engine / Fuel Type',
                value: selectedFuelType,
                items: fuelTypeOptions,
                itemLabel: (value) => value,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedFuelType = value);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdownField<int>(
                label: 'Seats',
                value: selectedSeats,
                items: seatOptions,
                itemLabel: (value) => '$value',
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedSeats = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                label: 'Year',
                hintText: '2023',
                controller: yearController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                label: 'Plate Number',
                hintText: 'ABC 1234',
                controller: plateNumberController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDropdownField<String>(
          label: 'Transmission',
          value: selectedTransmission,
          items: transmissionOptions,
          itemLabel: (value) => value,
          onChanged: (value) {
            if (value == null) return;
            setState(() => selectedTransmission = value);
          },
        ),
        const SizedBox(height: 14),
        CustomTextField(
          label: 'Target Daily Rental Price',
          hintText: '2,500',
          controller: pricePerDayController,
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.currency_yen, color: AppColors.primary),
        ),
        const SizedBox(height: 14),
        CustomTextField(
          label: 'Target Hourly Rental Price',
          hintText: '400',
          controller: pricePerHourController,
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.schedule, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 16),
        _buildOwnerDriverToggle(),
      ],
    );
  }

  Widget _buildOwnerDriverToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_pin_circle_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'With me',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Turn this on if you, the owner, will also drive this vehicle.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: ownerIsDriver,
            activeThumbColor: AppColors.primary,
            onChanged: (value) => setState(() => ownerIsDriver = value),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registered Documents',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Upload clear photos of the documents for this vehicle.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
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
      ],
    );
  }

  Widget _buildStatusTracker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primary),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 14, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'UNDER REVIEW',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Almost There!',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your application is currently being processed by our team.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 36),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: const Column(
              children: [
                _StatusStep(
                  icon: Icons.check,
                  title: 'Application Submitted',
                  subtitle: 'Completed just now',
                  active: true,
                  complete: true,
                ),
                _StatusStep(
                  icon: Icons.hourglass_bottom,
                  title: 'Admin Review',
                  subtitle: 'In Progress',
                  active: true,
                ),
                _StatusStep(
                  icon: Icons.lock_outline,
                  title: 'Final Approval',
                  subtitle: 'Pending review completion',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildInfoBox(
            'Our team is currently verifying your documents. This usually takes 24-48 hours. You will receive a notification once approved.',
          ),
          const SizedBox(height: 28),
          CustomButton(
            label: 'Refresh Status',
            onPressed: _loadEligibilityState,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact Support'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPanel({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF06223A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF123755)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader({required String step, required String label}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                step,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _currentStep == 0
                ? 0.33
                : _currentStep == 1
                ? 0.25
                : 0.5,
            minHeight: 7,
            backgroundColor: AppColors.darkBgTertiary,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.info_outline, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildPhotoPreviewGrid() {
    final photoCount = _vehiclePhotoFiles.length;
    final itemCount = photoCount < 4 ? 4 : photoCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.62,
          ),
          itemBuilder: (context, index) {
            final hasPhoto = index < photoCount;
            final photo = hasPhoto ? _vehiclePhotoFiles[index] : null;
            return GestureDetector(
              onTap: () => _pickDocument('vehicle_photo'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppColors.darkBgSecondary,
                      child: hasPhoto
                          ? Image.file(photo!, fit: BoxFit.cover)
                          : const Center(
                              child: Icon(
                                Icons.add_a_photo_outlined,
                                color: AppColors.textTertiary,
                              ),
                            ),
                    ),
                    if (hasPhoto)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: AppColors.primary,
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    if (hasPhoto)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              setState(() {
                                _vehiclePhotoFiles.removeAt(index);
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                photoCount > 0
                    ? '$photoCount photo${photoCount == 1 ? '' : 's'} selected. You can upload 4 or more at once.'
                    : 'Upload at least 1 vehicle photo. You can select 4 or more at once.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickDocument('vehicle_photo'),
              icon: const Icon(Icons.add_a_photo, size: 16),
              label: const Text('Add More'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTermsText() {
    return const Center(
      child: Text.rich(
        TextSpan(
          text: 'By proceeding, you agree to the ',
          children: [
            TextSpan(
              text: 'Partner Terms of Service.',
              style: TextStyle(color: AppColors.primary),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildNextStepNote() {
    return _buildInfoBox(
      'Next Step: Business Documents\nYou will be asked to upload your Business Permit and DTI/SEC registration in the next section.',
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF123755)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
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

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final bool complete;

  const _StatusStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.active = false,
    this.complete = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? AppColors.success
        : active
        ? AppColors.primary
        : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: active ? 1 : 0.16),
            child: Icon(
              icon,
              size: 18,
              color: active ? Colors.black : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? color : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _normalizeVerificationStatus(String? status) {
  final value = (status ?? 'pending').toLowerCase();
  if (value == 'approved') return 'verified';
  return value;
}
