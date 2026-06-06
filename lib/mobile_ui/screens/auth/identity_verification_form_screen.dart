import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../services/verification_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class IdentityVerificationFormScreen extends StatefulWidget {
  final VoidCallback? onVerificationComplete;
  final bool isDarkMode;
  final String? userRole;

  const IdentityVerificationFormScreen({
    super.key,
    this.onVerificationComplete,
    this.isDarkMode = true,
    this.userRole = 'renter',
  });

  @override
  State<IdentityVerificationFormScreen> createState() =>
      _IdentityVerificationFormScreenState();
}

class _IdentityVerificationFormScreenState
    extends State<IdentityVerificationFormScreen> {
  // Form fields
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _idNumberController = TextEditingController();
  String _selectedIdType = 'National ID';
  File? _idFrontFile;

  // UI State
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _verificationStatus;

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
    _loadExistingVerification();
  }

  void _handleBackNavigation() {
    if (widget.userRole == 'partner') {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/partner-home',
        (route) => false,
      );
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
      final status = (verification?['verification_status'] ?? '')
          .toString()
          .toLowerCase();

      if (!mounted) return;

      // Populate existing data if available
      if (verification != null) {
        setState(() {
          _nameController.text = verification['full_name'] ?? '';
          _locationController.text = verification['location'] ?? '';
          _idNumberController.text = verification['id_number'] ?? '';
          _selectedIdType = verification['id_type'] ?? 'National ID';
          _verificationStatus = status;
        });

        if (status == 'verified') {
          setState(() {
            _successMessage = 'Your verification has already been approved.';
          });
        } else if (status == 'pending') {
          setState(() {
            _successMessage =
                'Your verification is pending admin review. Please check back soon.';
          });
        }
      }
    }
  }

  Future<void> _captureIdFront() async {
    final file = await VerificationService.pickImage(
      source: ImageSource.camera,
    );
    if (file != null) {
      setState(() {
        _idFrontFile = file;
        _errorMessage = null;
      });
    }
  }

  Future<void> _uploadIdFront() async {
    final file = await VerificationService.pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      setState(() {
        _idFrontFile = file;
        _errorMessage = null;
      });
    }
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
    if (_idNumberController.text.isEmpty) {
      _showError('Please enter your ID number');
      return;
    }
    if (_idFrontFile == null) {
      _showError('Please upload your ID image');
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

      final idImageUrl = await _uploadVerificationImage(userId);

      // Submit verification with all form data
      final result = await VerificationService.submitVerificationWithDetails(
        userId: userId,
        fullName: _nameController.text.trim(),
        location: _locationController.text.trim(),
        idType: _selectedIdType,
        idNumber: _idNumberController.text.trim(),
        idDocumentUrl: idImageUrl,
      );

      if (result['success']) {
        setState(() {
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

  Future<String> _uploadVerificationImage(String userId) async {
    if (widget.userRole == 'driver') {
      return DriverService().uploadToDriverDocumentsBucket(
        userId: userId,
        file: _idFrontFile!,
        documentType: 'identity_verification',
      );
    }

    final uploadResult = await VerificationService.uploadIdentityPhoto(
      userId: userId,
      idPhotoFile: _idFrontFile!,
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
                  'Verification Submitted!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your verification has been submitted for admin review. We\'ll notify you once it\'s complete.',
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
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final inputTextColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final hintTextColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    final inputBorderColor = isDark
        ? AppColors.borderColor
        : Colors.grey[300]!;
    final inputFillColor = isDark ? AppColors.darkCard : Colors.white;

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
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 14),
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
              label: 'ID Number *',
              controller: _idNumberController,
              hint: 'Enter your ID number',
              icon: Icons.badge,
            ),
            const SizedBox(height: 16),

            // === ID IMAGE UPLOAD ===
            Text(
              'ID Image (Front) *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildImageUploadCard(
              isDark,
              inputFillColor,
              textColor,
              hintTextColor,
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
            style: TextStyle(color: inputTextColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: hintTextColor),
              prefixIcon: Icon(
                icon,
                color: AppColors.primary,
              ),
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
                    child: Text(
                      type,
                      style: TextStyle(color: inputTextColor),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedIdType = value ?? 'National ID';
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

  Widget _buildImageUploadCard(
    bool isDark,
    Color cardColor,
    Color textColor,
    Color hintTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(
          color: _idFrontFile != null
              ? AppColors.primary
              : AppColors.borderColor,
          width: _idFrontFile != null ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _idFrontFile != null
          ? Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _idFrontFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _captureIdFront,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Retake'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _uploadIdFront,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Change'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 48,
                  color: hintTextColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'No image selected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _captureIdFront,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _uploadIdFront,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
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
    _locationController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }
}
