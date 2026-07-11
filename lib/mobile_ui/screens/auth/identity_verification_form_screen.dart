import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/verification_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../vehicle/signature_capture_screen.dart';

class IdentityVerificationFormScreen extends StatefulWidget {
  final VoidCallback? onVerificationComplete;
  final bool isDarkMode;
  final String? userRole;
  final String? driverMode;

  const IdentityVerificationFormScreen({
    super.key,
    this.onVerificationComplete,
    this.isDarkMode = true,
    this.userRole = 'renter',
    this.driverMode,
  });

  @override
  State<IdentityVerificationFormScreen> createState() =>
      _IdentityVerificationFormScreenState();
}

class _IdentityVerificationFormScreenState
    extends State<IdentityVerificationFormScreen> {
  // Form fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _previousCompaniesController = TextEditingController();
  String _selectedIdType = 'National ID';
  String _selectedYearsExperience = '0';
  DateTime? _driverLicenseExpiryDate;
  File? _idFrontFile;
  File? _idBackFile;
  File? _faceSelfieFile;
  File? _selfieWithIdFile;
  File? _nbiClearanceFile;
  Uint8List? _driverSignatureBytes;

  // UI State
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _verificationStatus;
  String _driverApplicationStatus = 'basic';
  bool _showDriverApplicationForm = false;
  bool _showDriverApplicationReview = false;
  bool _isInitialLoading = true;

  // ID types dropdown
  final List<String> _idTypes = [
    'National ID',
    'Passport',
    "Driver's License",
    'TIN ID',
    'Senior Citizen ID',
    'PWD ID',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _showDriverApplicationForm = widget.driverMode == 'renewal';
    _prefillUserDetails();
    _loadExistingVerification();
  }

  void _prefillUserDetails() {
    final user = AuthService().currentUser;
    final metadata = user?.userMetadata ?? {};
    _emailController.text = user?.email ?? '';
    _phoneController.text = metadata['phone']?.toString() ?? '';
    _nameController.text = metadata['full_name']?.toString() ?? '';
    _locationController.text = metadata['location']?.toString() ?? '';

    if (widget.userRole == 'driver') {
      _selectedIdType = "Driver's License";
    }
  }

  void _handleBackNavigation() {
    if (widget.userRole == 'partner') {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/partner-home', (route) => false);
      return;
    }

    if (widget.userRole == 'driver') {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/driver-home', (route) => false);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
  }

  Future<void> _loadExistingVerification() async {
    final authService = AuthService();
    final userId = authService.currentUser?.id;

    if (userId != null) {
      final verification = await VerificationService.getUserVerification(
        userId,
      );
      final verificationState =
          await VerificationService.getUserVerificationState(userId);
      final status = verificationState['is_verified'] == true
          ? 'verified'
          : (verification?['verification_status'] ?? '')
                .toString()
                .toLowerCase();

      final driverApplicationStatus = widget.userRole == 'driver'
          ? _normalizeDriverApplicationStatus(
              await DriverService().getCertificationApplicationStatus(userId),
            )
          : null;

      if (!mounted) return;

      // Populate existing data if available
      if (verification != null) {
        setState(() {
          _nameController.text = verification['full_name'] ?? '';
          _locationController.text = verification['location'] ?? '';
          _idNumberController.text = verification['id_number'] ?? '';
          _selectedIdType = verification['id_type'] ?? 'National ID';
          final expiryRaw = verification['driver_license_expiry']?.toString();
          if (expiryRaw != null && expiryRaw.isNotEmpty) {
            _driverLicenseExpiryDate = DateTime.tryParse(expiryRaw);
          }
          final years = verification['driver_years_experience']?.toString();
          if (years != null && years.isNotEmpty) {
            _selectedYearsExperience = years;
          }
          _previousCompaniesController.text =
              verification['driver_previous_companies']?.toString() ?? '';
          if (widget.userRole == 'driver') {
            _driverApplicationStatus = driverApplicationStatus ?? 'basic';
            _verificationStatus = _driverScreenStatusForApplication(
              _driverApplicationStatus,
            );
          } else {
            _verificationStatus = status;
          }
        });

        if (widget.userRole == 'driver') {
          if (_driverApplicationStatus == 'certified') {
            setState(() {
              _successMessage =
                  'Your certified driver application has been approved.';
            });
          } else if (_driverApplicationStatus == 'pending') {
            setState(() {
              _successMessage =
                  'Your driver application is pending admin review. Please check back soon.';
            });
          } else if (_driverApplicationStatus == 'rejected') {
            setState(() {
              _successMessage = null;
              _errorMessage =
                  'Your previous driver application was rejected. You may update your details and submit again.';
            });
          } else {
            setState(() {
              _successMessage = null;
              _errorMessage = null;
            });
          }
        } else if (status == 'verified') {
          setState(() {
            _successMessage =
                'Your account has been verified. You can continue using Mobilis.';
          });
        } else if (status == 'pending') {
          setState(() {
            _successMessage =
                'Your verification is pending admin review. Please check back soon.';
          });
        }
      } else if (widget.userRole == 'driver') {
        setState(() {
          _driverApplicationStatus = driverApplicationStatus ?? 'basic';
          _verificationStatus = _driverScreenStatusForApplication(
            _driverApplicationStatus,
          );
        });
      } else if (status == 'verified') {
        setState(() {
          _verificationStatus = status;
          _successMessage =
              'Your account has been verified. You can continue using Mobilis.';
        });
      }
    }

    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  String _normalizeDriverApplicationStatus(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';
    if (status.isEmpty ||
        status == 'null' ||
        status == 'basic' ||
        status == 'skipped') {
      return 'basic';
    }
    if (status == 'approved' || status == 'verified' || status == 'certified') {
      return 'certified';
    }
    if (status == 'pending' ||
        status == 'submitted' ||
        status == 'in_review' ||
        status == 'under_review') {
      return 'pending';
    }
    if (status == 'rejected' || status == 'declined') {
      return 'rejected';
    }
    return status;
  }

  String? _driverScreenStatusForApplication(String status) {
    if (status == 'certified') return 'verified';
    if (status == 'pending') return 'pending';
    if (status == 'rejected') return 'rejected';
    return null;
  }

  bool get _driverLicenseNeedsRenewal {
    final expiry = _driverLicenseExpiryDate;
    if (expiry == null) return false;
    final renewalWindow = DateTime.now().add(const Duration(days: 90));
    return !expiry.isAfter(renewalWindow);
  }

  Future<void> _pickVerificationPhoto(
    String photoType,
    ImageSource source,
  ) async {
    final file = await VerificationService.pickImage(source: source);
    if (file == null || !mounted) return;
    setState(() {
      switch (photoType) {
        case 'id_back':
          _idBackFile = file;
          break;
        case 'face_selfie':
          _faceSelfieFile = file;
          break;
        case 'selfie_with_id':
          _selfieWithIdFile = file;
          break;
        case 'nbi_clearance':
          _nbiClearanceFile = file;
          break;
        default:
          _idFrontFile = file;
      }
      _errorMessage = null;
    });
  }

  Future<void> _openDriverSignatureDialog() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => SignatureCaptureScreen(
          title: 'Driver Signature',
          initialSignature: _driverSignatureBytes,
        ),
      ),
    );
    if (bytes == null || !mounted) return;
    setState(() => _driverSignatureBytes = bytes);
  }

  Future<void> _submitVerification() async {
    // Validate form
    if (_nameController.text.isEmpty) {
      _showError('Please enter your full name');
      return;
    }
    if (_locationController.text.isEmpty) {
      _showError('Please enter your location/address');
      return;
    }
    if (_idNumberController.text.trim().isEmpty) {
      _showError('Please enter your ID number');
      return;
    }
    final idNumberError = _validateIdNumber(
      _selectedIdType,
      _idNumberController.text,
    );
    if (idNumberError != null) {
      _showError(idNumberError);
      return;
    }
    if (widget.userRole == 'driver' && _driverLicenseExpiryDate == null) {
      _showError("Please select your driver's license expiration date");
      return;
    }
    if (widget.userRole == 'driver' &&
        !_driverLicenseExpiryDate!.isAfter(DateTime.now())) {
      _showError("Driver's license expiration date must be in the future");
      return;
    }
    if (_idFrontFile == null) {
      _showError('Please capture or upload the front of your ID');
      return;
    }
    if (_idBackFile == null) {
      _showError('Please capture or upload the back of your ID');
      return;
    }
    if (_faceSelfieFile == null) {
      _showError('Please take a clear face-only selfie');
      return;
    }
    if (_selfieWithIdFile == null) {
      _showError('Please take a selfie while holding your ID');
      return;
    }
    if (widget.userRole == 'driver' && _nbiClearanceFile == null) {
      _showError('Please upload or capture your NBI clearance');
      return;
    }
    if (widget.userRole == 'driver' && _driverSignatureBytes == null) {
      _showError('Please add your digital signature');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final userId = authService.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final idFrontUrl = await _uploadVerificationImage(
        userId,
        _idFrontFile!,
        'id_front',
      );
      final idBackUrl = await _uploadVerificationImage(
        userId,
        _idBackFile!,
        'id_back',
      );
      final faceSelfieUrl = await _uploadVerificationImage(
        userId,
        _faceSelfieFile!,
        'face_selfie',
      );
      final selfieWithIdUrl = await _uploadVerificationImage(
        userId,
        _selfieWithIdFile!,
        'selfie_with_id',
      );
      if (widget.userRole == 'driver') {
        await DriverService().markDriverApplicationSubmitted(userId);
        final driverProfile = await DriverService().getDriverProfile(userId);
        if (driverProfile == null) {
          throw Exception('Driver profile could not be created');
        }
        await DriverService()
            .updateDriverProfile(driverProfile['id'].toString(), {
              'license_number': _idNumberController.text.trim(),
              'license_expiry': _driverLicenseExpiryDate!
                  .toIso8601String()
                  .split('T')
                  .first,
            });
        final signatureUrl = await DriverService()
            .uploadBytesToDriverDocumentsBucket(
              userId: userId,
              bytes: _driverSignatureBytes!,
              documentType: 'digital_signature',
            );
        await DriverService().uploadDriverDocument(
          driverId: driverProfile['id'].toString(),
          documentType: 'digital_signature',
          fileUrl: signatureUrl,
          issueDate: DateTime.now(),
          expiryDate: DateTime.now().add(const Duration(days: 3650)),
        );
        final nbiUrl = await _uploadVerificationImage(
          userId,
          _nbiClearanceFile!,
          'nbi_clearance',
        );
        await DriverService().uploadDriverDocument(
          driverId: driverProfile['id'].toString(),
          documentType: 'nbi_clearance',
          fileUrl: nbiUrl,
          issueDate: DateTime.now(),
          expiryDate: DateTime.now().add(const Duration(days: 365)),
        );
      }

      // Submit verification with all form data
      final result = await VerificationService.submitVerificationWithDetails(
        userId: userId,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
        idType: _selectedIdType,
        idNumber: _idNumberController.text.trim(),
        idDocumentUrl: '$idFrontUrl|$idBackUrl',
        idFrontUrl: idFrontUrl,
        idBackUrl: idBackUrl,
        faceSelfieUrl: faceSelfieUrl,
        selfieWithIdUrl: selfieWithIdUrl,
        driverYearsExperience: widget.userRole == 'driver'
            ? _selectedYearsExperience
            : null,
        driverPreviousCompanies: widget.userRole == 'driver'
            ? _previousCompaniesController.text.trim()
            : null,
        driverLicenseExpiry: widget.userRole == 'driver'
            ? _driverLicenseExpiryDate
            : null,
      );

      if (result['success']) {
        setState(() {
          if (widget.userRole == 'driver') {
            _driverApplicationStatus = 'pending';
            _verificationStatus = 'pending';
          }
          _successMessage = result['message'];
          _isLoading = false;
        });

        widget.onVerificationComplete?.call();

        // Show completion dialog
        if (mounted) {
          _showCompletionDialog();
        }
      } else {
        setState(() {
          _errorMessage = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<String> _uploadVerificationImage(
    String userId,
    File file,
    String photoType,
  ) async {
    if (widget.userRole == 'driver') {
      return DriverService().uploadToDriverDocumentsBucket(
        userId: userId,
        file: file,
        documentType: 'identity_verification_$photoType',
      );
    }

    final uploadResult = await VerificationService.uploadIdentityPhoto(
      userId: userId,
      idPhotoFile: file,
      photoType: photoType,
    );

    if (uploadResult['success'] != true) {
      throw Exception('Failed to upload ID image');
    }

    final url = uploadResult['file_url']?.toString() ?? '';
    if (url.isEmpty) {
      throw Exception('Failed to upload ID image');
    }

    return url;
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  String? _validateIdNumber(String idType, String rawValue) {
    final value = rawValue.trim();
    final normalizedType = idType.toLowerCase();
    if (normalizedType.contains('driver')) {
      if (!RegExp(r'^[A-Za-z0-9-]{6,13}$').hasMatch(value)) {
        return "Driver's License Number must be 6-13 letters/numbers and may include hyphens";
      }
      return null;
    }

    if (normalizedType.contains('national')) {
      final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.length != 12) {
        return 'National ID number must contain exactly 12 digits';
      }
      return null;
    }

    if (normalizedType.contains('passport')) {
      if (!RegExp(r'^[A-Za-z0-9]{7,9}$').hasMatch(value)) {
        return 'Passport number must be 7-9 letters/numbers';
      }
      return null;
    }

    if (normalizedType.contains('tin')) {
      final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.length != 9 && digitsOnly.length != 12) {
        return 'TIN must contain 9 or 12 digits';
      }
      return null;
    }

    if (normalizedType.contains('senior') || normalizedType.contains('pwd')) {
      if (!RegExp(r'^[A-Za-z0-9-]{6,20}$').hasMatch(value)) {
        return 'ID number must be 6-20 letters/numbers and may include hyphens';
      }
      return null;
    }

    if (value.length < 5 || value.length > 40) {
      return 'ID number must be between 5 and 40 characters';
    }
    return null;
  }

  String _formatDriverLicenseExpiry() {
    final date = _driverLicenseExpiryDate;
    if (date == null) return "Select driver's license expiration date";
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _pickDriverLicenseExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _driverLicenseExpiryDate ?? now.add(const Duration(days: 365)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 15, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.darkBgSecondary,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.darkBgSecondary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _driverLicenseExpiryDate = picked);
  }

  Widget _buildDriverLicenseExpiryField({
    required Color textColor,
    required Color inputFillColor,
    required Color inputBorderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Driver's License Expiration Date *",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDriverLicenseExpiry,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: inputFillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: inputBorderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatDriverLicenseExpiry(),
                    style: TextStyle(
                      color: _driverLicenseExpiryDate == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontWeight: _driverLicenseExpiryDate == null
                          ? FontWeight.w500
                          : FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'We use this to notify you and the admin when renewal is needed.',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDark = widget.isDarkMode;
        final bgColor = isDark ? AppColors.darkBgSecondary : Colors.white;
        final textColor = isDark
            ? AppColors.textPrimary
            : AppColors.lightTextPrimary;

        return Dialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.userRole == 'driver'
                      ? 'Application Submitted!'
                      : 'Verification Submitted!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.userRole == 'driver'
                      ? 'Your driver application has been submitted for admin review. We\'ll notify you once it\'s complete.'
                      : 'Your verification has been submitted for admin review. We\'ll notify you once it\'s complete.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'Back to Home',
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      _handleBackNavigation();
                    },
                    backgroundColor: AppColors.primary,
                    textColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final inputTextColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final hintTextColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    final inputBorderColor = isDark ? AppColors.borderColor : Colors.grey[300]!;
    final inputFillColor = isDark ? AppColors.darkCard : Colors.white;

    if (widget.userRole == 'driver') {
      if (_isInitialLoading) {
        return const Scaffold(
          backgroundColor: AppColors.darkBg,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      if (_showDriverApplicationForm) {
        return _buildDriverApplicationScaffold(
          isDark: isDark,
          bgColor: bgColor,
          textColor: textColor,
          inputTextColor: inputTextColor,
          hintTextColor: hintTextColor,
          inputBorderColor: inputBorderColor,
          inputFillColor: inputFillColor,
        );
      }

      if (_showDriverApplicationReview) {
        return _buildDriverApplicationReviewScaffold();
      }

      if (_verificationStatus == 'verified') {
        return _buildDriverStatusScaffold(
          title: 'Documents Verified',
          subtitle:
              'Excellent. Your identity and supporting documents have been processed and confirmed.',
          status: 'verified',
        );
      }

      if (_verificationStatus == 'pending') {
        return _buildDriverStatusScaffold(
          title: 'Application Under Review',
          subtitle:
              'Your driver application documents were submitted. Our team is reviewing them now.',
          status: 'pending',
        );
      }

      return _buildDriverApplicationScaffold(
        isDark: isDark,
        bgColor: bgColor,
        textColor: textColor,
        inputTextColor: inputTextColor,
        hintTextColor: hintTextColor,
        inputBorderColor: inputBorderColor,
        inputFillColor: inputFillColor,
      );
    }

    // Show if already verified
    if (_verificationStatus == 'verified') {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: _handleBackNavigation,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Already Verified',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your identity has already been verified.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: _handleBackNavigation,
        ),
        title: Text(
          widget.userRole == 'driver'
              ? 'Driver Verification'
              : 'Identity Verification',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              widget.userRole == 'driver'
                  ? 'Driver Identity Verification'
                  : 'Complete Your Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userRole == 'driver'
                  ? 'Please provide your identity details and ID image'
                  : 'Please provide your details and ID information',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      (_verificationStatus == 'rejected'
                              ? AppColors.warning
                              : AppColors.error)
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _verificationStatus == 'rejected'
                        ? AppColors.warning
                        : AppColors.error,
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: _verificationStatus == 'rejected'
                        ? AppColors.warning
                        : AppColors.error,
                    fontSize: 14,
                  ),
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 16),

            // Success message
            if (_successMessage != null && _verificationStatus == 'pending')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_successMessage != null && _verificationStatus == 'pending')
              const SizedBox(height: 16),

            // === NAME FIELD ===
            _buildFormField(
              isDark,
              inputFillColor,
              textColor,
              inputTextColor: inputTextColor,
              hintTextColor: hintTextColor,
              borderColor: inputBorderColor,
              label: 'Full Name *',
              controller: _nameController,
              hint: 'Enter your full name',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),

            // === LOCATION FIELD ===
            _buildFormField(
              isDark,
              inputFillColor,
              textColor,
              inputTextColor: inputTextColor,
              hintTextColor: hintTextColor,
              borderColor: inputBorderColor,
              label: 'Location / Address *',
              controller: _locationController,
              hint: 'Enter your address',
              icon: Icons.location_on,
            ),
            const SizedBox(height: 16),

            // === ID TYPE DROPDOWN ===
            _buildIdTypeDropdown(
              isDark,
              inputFillColor,
              textColor,
              inputTextColor,
              hintTextColor,
              inputBorderColor,
            ),
            const SizedBox(height: 16),

            // === ID NUMBER FIELD ===
            _buildFormField(
              isDark,
              inputFillColor,
              textColor,
              inputTextColor: inputTextColor,
              hintTextColor: hintTextColor,
              borderColor: inputBorderColor,
              label: _idNumberLabel,
              controller: _idNumberController,
              hint: _idNumberHint,
              icon: Icons.badge,
              inputFormatters: _idNumberInputFormatters,
            ),
            const SizedBox(height: 16),

            _buildVerificationPhotoSection(
              title: '1. ID Front *',
              description:
                  'Capture the front of the ID. Keep all text and corners visible.',
              file: _idFrontFile,
              photoType: 'id_front',
              icon: Icons.badge_outlined,
              cardColor: inputFillColor,
              textColor: textColor,
              hintTextColor: hintTextColor,
            ),
            const SizedBox(height: 16),
            _buildVerificationPhotoSection(
              title: '2. ID Back *',
              description:
                  'Turn the same ID over and capture its complete back side.',
              file: _idBackFile,
              photoType: 'id_back',
              icon: Icons.flip_to_back_outlined,
              cardColor: inputFillColor,
              textColor: textColor,
              hintTextColor: hintTextColor,
            ),
            const SizedBox(height: 16),
            _buildVerificationPhotoSection(
              title: '3. Face Selfie *',
              description:
                  'Take a face-only selfie in good lighting. No mask, ID, or other person should appear.',
              file: _faceSelfieFile,
              photoType: 'face_selfie',
              icon: Icons.face_retouching_natural,
              cardColor: inputFillColor,
              textColor: textColor,
              hintTextColor: hintTextColor,
              cameraOnly: true,
            ),
            const SizedBox(height: 16),
            _buildVerificationPhotoSection(
              title: '4. Selfie Holding ID *',
              description:
                  'Hold the front of your ID beside your face. Your face and ID must both be clear.',
              file: _selfieWithIdFile,
              photoType: 'selfie_with_id',
              icon: Icons.co_present_outlined,
              cardColor: inputFillColor,
              textColor: textColor,
              hintTextColor: hintTextColor,
              cameraOnly: true,
            ),
            const SizedBox(height: 32),

            // === SUBMIT BUTTON ===
            CustomButton(
              label: _isLoading ? 'Submitting...' : 'Submit Verification',
              onPressed: _isLoading ? null : _submitVerification,
              backgroundColor: AppColors.primary,
              textColor: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverApplicationScaffold({
    required bool isDark,
    required Color bgColor,
    required Color textColor,
    required Color inputTextColor,
    required Color hintTextColor,
    required Color inputBorderColor,
    required Color inputFillColor,
  }) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: _handleBackNavigation,
        ),
        title: const Text(
          'Driver Partnership',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDriverProgressCard(),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              _buildDriverNotice(
                message: _errorMessage!,
                color: AppColors.error,
                icon: Icons.error_outline,
              ),
              const SizedBox(height: 16),
            ],
            if (_driverLicenseNeedsRenewal ||
                widget.driverMode == 'renewal') ...[
              _buildDriverNotice(
                message:
                    "Your driver's license is expired or nearing expiry. Please renew your details and re-submit your driver application.",
                color: AppColors.primary,
                icon: Icons.update_outlined,
              ),
              const SizedBox(height: 16),
            ],
            _buildDriverStepSection(
              step: 1,
              title: 'Basic Information',
              icon: Icons.person_outline,
              children: [
                _buildFormField(
                  isDark,
                  inputFillColor,
                  textColor,
                  inputTextColor: inputTextColor,
                  hintTextColor: hintTextColor,
                  borderColor: inputBorderColor,
                  label: 'Full Name *',
                  controller: _nameController,
                  hint: 'Enter your full legal name',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 14),
                _buildFormField(
                  isDark,
                  inputFillColor,
                  textColor,
                  inputTextColor: inputTextColor,
                  hintTextColor: hintTextColor,
                  borderColor: inputBorderColor,
                  label: 'Email Address',
                  controller: _emailController,
                  hint: 'name@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  readOnly: true,
                ),
                const SizedBox(height: 14),
                _buildFormField(
                  isDark,
                  inputFillColor,
                  textColor,
                  inputTextColor: inputTextColor,
                  hintTextColor: hintTextColor,
                  borderColor: inputBorderColor,
                  label: 'Phone Number',
                  controller: _phoneController,
                  hint: '+63 900 000 0000',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _buildFormField(
                  isDark,
                  inputFillColor,
                  textColor,
                  inputTextColor: inputTextColor,
                  hintTextColor: hintTextColor,
                  borderColor: inputBorderColor,
                  label: 'Location / Address *',
                  controller: _locationController,
                  hint: 'Enter your address',
                  icon: Icons.location_on_outlined,
                ),
              ],
            ),
            const SizedBox(height: 26),
            _buildDriverStepSection(
              step: 2,
              title: 'Professional Experience',
              icon: Icons.work_outline,
              children: [
                _buildYearsExperienceDropdown(
                  isDark,
                  inputFillColor,
                  textColor,
                  inputTextColor: inputTextColor,
                  hintTextColor: hintTextColor,
                  borderColor: inputBorderColor,
                ),
                const SizedBox(height: 14),
                _buildFormField(
                  isDark,
                  inputFillColor,
                  textColor,
                  inputTextColor: inputTextColor,
                  hintTextColor: hintTextColor,
                  borderColor: inputBorderColor,
                  label: 'Previous Companies / Platforms',
                  controller: _previousCompaniesController,
                  hint: 'Type N/A if no previous experience',
                  icon: Icons.business_center_outlined,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: If you have no transport company/platform experience, put N/A.',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            _buildDriverStepSection(
              step: 3,
              title: 'Required Documents',
              icon: Icons.upload_file_outlined,
              children: [
                _buildIdTypeDropdown(
                  isDark,
                  inputFillColor,
                  textColor,
                  inputTextColor,
                  hintTextColor,
                  inputBorderColor,
                ),
                const SizedBox(height: 14),
                _buildFormField(
                  isDark,
                  inputFillColor,
                  textColor,
                  inputTextColor: inputTextColor,
                  hintTextColor: hintTextColor,
                  borderColor: inputBorderColor,
                  label: _idNumberLabel,
                  controller: _idNumberController,
                  hint: _idNumberHint,
                  icon: Icons.credit_card_outlined,
                  inputFormatters: _idNumberInputFormatters,
                ),
                const SizedBox(height: 14),
                _buildDriverLicenseExpiryField(
                  textColor: textColor,
                  inputFillColor: inputFillColor,
                  inputBorderColor: inputBorderColor,
                ),
                const SizedBox(height: 14),
                _buildVerificationPhotoSection(
                  title: 'ID Front *',
                  description:
                      'Capture the front of your valid ID. Keep text and corners visible.',
                  file: _idFrontFile,
                  photoType: 'id_front',
                  icon: Icons.badge_outlined,
                  cardColor: inputFillColor,
                  textColor: textColor,
                  hintTextColor: hintTextColor,
                ),
                const SizedBox(height: 14),
                _buildVerificationPhotoSection(
                  title: 'ID Back *',
                  description: 'Capture the back of the same ID clearly.',
                  file: _idBackFile,
                  photoType: 'id_back',
                  icon: Icons.flip_to_back_outlined,
                  cardColor: inputFillColor,
                  textColor: textColor,
                  hintTextColor: hintTextColor,
                ),
                const SizedBox(height: 14),
                _buildVerificationPhotoSection(
                  title: 'Face Selfie *',
                  description:
                      'Take a face-only selfie in good lighting for liveness review.',
                  file: _faceSelfieFile,
                  photoType: 'face_selfie',
                  icon: Icons.face_retouching_natural,
                  cardColor: inputFillColor,
                  textColor: textColor,
                  hintTextColor: hintTextColor,
                  cameraOnly: true,
                ),
                const SizedBox(height: 14),
                _buildVerificationPhotoSection(
                  title: 'Selfie Holding ID *',
                  description:
                      'Hold your ID beside your face. Both your face and ID must be readable.',
                  file: _selfieWithIdFile,
                  photoType: 'selfie_with_id',
                  icon: Icons.co_present_outlined,
                  cardColor: inputFillColor,
                  textColor: textColor,
                  hintTextColor: hintTextColor,
                  cameraOnly: true,
                ),
                const SizedBox(height: 14),
                _buildVerificationPhotoSection(
                  title: 'NBI Clearance *',
                  description:
                      'Upload or capture a clear photo of your NBI clearance document.',
                  file: _nbiClearanceFile,
                  photoType: 'nbi_clearance',
                  icon: Icons.assignment_ind_outlined,
                  cardColor: inputFillColor,
                  textColor: textColor,
                  hintTextColor: hintTextColor,
                ),
                const SizedBox(height: 14),
                _buildDriverSignatureButton(),
              ],
            ),
            const SizedBox(height: 28),
            CustomButton(
              label: _isLoading ? 'Submitting...' : 'Submit Application',
              onPressed: _isLoading ? null : _submitVerification,
              backgroundColor: AppColors.primary,
              textColor: Colors.black,
            ),
            const SizedBox(height: 16),
            const Text(
              'By submitting, you agree to Mobilis by PSDC driver screening and partnership review.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Application Progress',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Step 1 of 3',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: 1 / 3,
              minHeight: 10,
              backgroundColor: AppColors.borderColor,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverStepSection({
    required int step,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Step $step: $title',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }

  Widget _buildYearsExperienceDropdown(
    bool isDark,
    Color inputFillColor,
    Color textColor, {
    required Color inputTextColor,
    required Color hintTextColor,
    required Color borderColor,
  }) {
    const options = ['0', '1', '2', '3', '4', '5', '6-9', '10+'];

    String labelForYears(String years) {
      if (years == '0') return 'No professional driving experience yet';
      if (years == '1') return '1 year';
      return '$years years';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Years of Driving Experience',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: inputFillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedYearsExperience,
            items: options
                .map(
                  (years) => DropdownMenuItem(
                    value: years,
                    child: Text(labelForYears(years)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedYearsExperience = value);
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.timeline_outlined,
                color: AppColors.primary,
              ),
              hintText: 'Select years of experience',
              hintStyle: TextStyle(color: hintTextColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            style: TextStyle(color: inputTextColor),
            dropdownColor: inputFillColor,
            iconEnabledColor: inputTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverNotice({
    required String message,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverApplicationReviewScaffold() {
    final licenseExpiry = _driverLicenseExpiryDate == null
        ? 'Not provided'
        : _formatDriverLicenseExpiry();
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            setState(() => _showDriverApplicationReview = false);
          },
        ),
        title: const Text(
          'Application Review',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_outlined, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'View-only approved application',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildReviewSection(
              title: 'Basic Information',
              children: [
                _buildReviewRow('Full Name', _nameController.text),
                _buildReviewRow('Email', _emailController.text),
                _buildReviewRow('Phone', _phoneController.text),
                _buildReviewRow('Location', _locationController.text),
              ],
            ),
            const SizedBox(height: 16),
            _buildReviewSection(
              title: 'Professional Experience',
              children: [
                _buildReviewRow(
                  'Years of Experience',
                  _selectedYearsExperience == '1'
                      ? '1 year'
                      : '$_selectedYearsExperience years',
                ),
                _buildReviewRow(
                  'Previous Companies',
                  _previousCompaniesController.text.trim().isEmpty
                      ? 'N/A'
                      : _previousCompaniesController.text.trim(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildReviewSection(
              title: 'License Details',
              children: [
                _buildReviewRow('ID Type', _selectedIdType),
                _buildReviewRow('ID Number', _idNumberController.text),
                _buildReviewRow('License Expiry', licenseExpiry),
              ],
            ),
            const SizedBox(height: 22),
            CustomButton(
              label: 'Back to Status',
              onPressed: () {
                setState(() => _showDriverApplicationReview = false);
              },
              backgroundColor: AppColors.primary,
              textColor: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    final cleanValue = value.trim().isEmpty ? 'Not provided' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              cleanValue,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverStatusScaffold({
    required String title,
    required String subtitle,
    required String status,
  }) {
    final isVerified = status == 'verified';
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _handleBackNavigation,
        ),
        title: Text(
          isVerified ? 'Application Status' : 'Partnership',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: (isVerified ? AppColors.success : AppColors.primary)
                    .withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVerified
                    ? Icons.verified_outlined
                    : Icons.hourglass_top_rounded,
                color: isVerified ? AppColors.success : AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 34),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'VERIFIED RECORDS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildDriverStatusRecord(
              icon: Icons.badge_outlined,
              title: 'Government ID',
              subtitle: isVerified ? 'Verified' : 'Submitted for review',
              complete: isVerified,
            ),
            _buildDriverStatusRecord(
              icon: Icons.face_retouching_natural,
              title: 'Biometric Face Selfie',
              subtitle: isVerified ? 'Liveness check completed' : 'Pending',
              complete: isVerified,
            ),
            _buildDriverStatusRecord(
              icon: Icons.co_present_outlined,
              title: 'Selfie Holding ID',
              subtitle: isVerified ? 'Authenticated' : 'Pending',
              complete: isVerified,
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: 'Review your application',
              onPressed: () {
                setState(() => _showDriverApplicationReview = true);
              },
              backgroundColor: AppColors.darkBgSecondary,
              textColor: AppColors.primary,
            ),
            const SizedBox(height: 14),
            CustomButton(
              label: isVerified ? 'Continue to Dashboard' : 'Back to Dashboard',
              onPressed: _handleBackNavigation,
              backgroundColor: AppColors.primary,
              textColor: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverStatusRecord({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool complete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            complete ? Icons.check_circle_outline : Icons.radio_button_checked,
            color: complete ? AppColors.success : AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(
    bool isDark,
    Color cardColor,
    Color textColor, {
    required Color inputTextColor,
    required Color hintTextColor,
    required Color borderColor,
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            inputFormatters: inputFormatters,
            style: TextStyle(color: inputTextColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: hintTextColor),
              prefixIcon: Icon(icon, color: AppColors.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _idNumberLabel {
    final type = _selectedIdType.toLowerCase();
    if (type.contains('driver')) return "Driver's License Number *";
    if (type.contains('national')) return 'National ID Number *';
    return 'ID Number *';
  }

  String get _idNumberHint {
    final type = _selectedIdType.toLowerCase();
    if (type.contains('driver')) {
      return 'e.g. A12-34-567890';
    }
    if (type.contains('national')) return '12-digit PhilSys number';
    if (type.contains('passport')) return '7-9 character passport number';
    if (type.contains('tin')) return '9 or 12 digit TIN';
    return 'Enter your ID number';
  }

  List<TextInputFormatter> get _idNumberInputFormatters {
    final type = _selectedIdType.toLowerCase();
    if (type.contains('driver')) {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
        LengthLimitingTextInputFormatter(13),
      ];
    }
    if (type.contains('national')) {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(14),
      ];
    }
    if (type.contains('passport')) {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        LengthLimitingTextInputFormatter(9),
      ];
    }
    if (type.contains('tin')) {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(15),
      ];
    }
    if (type.contains('senior') || type.contains('pwd')) {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
        LengthLimitingTextInputFormatter(20),
      ];
    }
    return [LengthLimitingTextInputFormatter(40)];
  }

  Widget _buildDriverSignatureButton() {
    final hasSignature = _driverSignatureBytes != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasSignature ? AppColors.success : AppColors.borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (hasSignature ? AppColors.success : AppColors.primary)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasSignature ? Icons.check_rounded : Icons.draw_outlined,
              color: hasSignature ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSignature
                      ? 'Digital signature added'
                      : 'Digital signature *',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Tap the button to open the signature board.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _openDriverSignatureDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(hasSignature ? 'Edit' : 'Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildIdTypeDropdown(
    bool isDark,
    Color cardColor,
    Color textColor,
    Color inputTextColor,
    Color hintTextColor,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type of ID *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedIdType,
            items: _idTypes
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type, style: TextStyle(color: inputTextColor)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedIdType = value ?? 'National ID';
                _idNumberController.clear();
              });
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.card_membership,
                color: AppColors.primary,
              ),
              hintStyle: TextStyle(color: hintTextColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            style: TextStyle(color: inputTextColor),
            dropdownColor: cardColor,
            iconEnabledColor: inputTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationPhotoSection({
    required String title,
    required String description,
    required File? file,
    required String photoType,
    required IconData icon,
    required Color cardColor,
    required Color textColor,
    required Color hintTextColor,
    bool cameraOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(
          color: file != null ? AppColors.primary : AppColors.borderColor,
          width: file != null ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: file != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(description, style: TextStyle(color: hintTextColor)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    file,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          _pickVerificationPhoto(photoType, ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text(
                        'Retake',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                    if (!cameraOnly)
                      ElevatedButton.icon(
                        onPressed: () => _pickVerificationPhoto(
                          photoType,
                          ImageSource.gallery,
                        ),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Change'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                Icon(icon, size: 48, color: hintTextColor),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: hintTextColor),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          _pickVerificationPhoto(photoType, ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                    if (!cameraOnly)
                      ElevatedButton.icon(
                        onPressed: () => _pickVerificationPhoto(
                          photoType,
                          ImageSource.gallery,
                        ),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Upload'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _idNumberController.dispose();
    _previousCompaniesController.dispose();
    super.dispose();
  }
}
