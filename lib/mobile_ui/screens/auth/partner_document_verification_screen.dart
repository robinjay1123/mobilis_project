import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../services/verification_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/partner_verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class PartnerDocumentVerificationScreen extends StatefulWidget {
  final VoidCallback? onVerificationComplete;
  final bool isDarkMode;

  const PartnerDocumentVerificationScreen({
    super.key,
    this.onVerificationComplete,
    this.isDarkMode = true,
  });

  @override
  State<PartnerDocumentVerificationScreen> createState() =>
      _PartnerDocumentVerificationScreenState();
}

class _PartnerDocumentVerificationScreenState
    extends State<PartnerDocumentVerificationScreen> {
  // Files
  File? _idFrontFile;
  File? _idBackFile;

  // UI State
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _verificationStatus;
  String? _rejectionReason;
  int _currentStep = 0; // 0: ID Front, 1: ID Back, 2: Review

  @override
  void initState() {
    super.initState();
    _loadExistingVerification();
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
      final rejectionReason = (verification?['rejection_reason'] ?? '')
          .toString()
          .trim();

      if (!mounted) return;

      if (status == 'verified') {
        setState(() {
          _successMessage = 'Your verification has already been approved.';
          _verificationStatus = status;
          _currentStep = 3;
        });
      } else if (verification != null &&
          (status == 'pending' || status.isEmpty)) {
        setState(() {
          _successMessage =
              'Your verification is pending admin review. Please check back soon.';
          _verificationStatus = status;
        });
      } else if (verification != null && status == 'rejected') {
        setState(() {
          _verificationStatus = status;
          _rejectionReason = rejectionReason.isNotEmpty
              ? rejectionReason
              : 'No reason was provided by admin.';
          _errorMessage =
              'Your verification was rejected: $_rejectionReason. You can reapply after correcting it.';
        });
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

  Future<void> _captureIdBack() async {
    final file = await VerificationService.pickImage(
      source: ImageSource.camera,
    );
    if (file != null) {
      setState(() {
        _idBackFile = file;
        _errorMessage = null;
      });
    }
  }

  Future<void> _uploadIdBack() async {
    final file = await VerificationService.pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      setState(() {
        _idBackFile = file;
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitVerification() async {
    if (_idFrontFile == null || _idBackFile == null) {
      setState(() {
        _errorMessage = 'Please upload both ID front and back';
      });
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

      // Upload files
      final idFrontUrl = await VerificationService.uploadIdentityPhoto(
        userId: userId,
        idPhotoFile: _idFrontFile!,
      );

      final idBackUrl = await VerificationService.uploadIdentityPhoto(
        userId: userId,
        idPhotoFile: _idBackFile!,
      );

      // Combine both URLs
      final combinedIdUrl =
          '${idFrontUrl['file_url']}|${idBackUrl['file_url']}';

      // Submit partner verification (ID only, no face photo)
      final partnerVerifyService = PartnerVerificationService();
      final result = await partnerVerifyService.submitPartnerVerification(
        userId: userId,
        idDocumentUrl: combinedIdUrl,
      );

      if (result['success']) {
        setState(() {
          _successMessage = result['message'];
          _isLoading = false;
          _currentStep = 3; // Completion step
        });

        widget.onVerificationComplete?.call();
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;

    // Show completion screen
    if (_currentStep == 3) {
      return _buildCompletionScreen(isDark, bgColor, textColor);
    }

    // Show verification pending screen
    if (_successMessage != null &&
        _successMessage!.contains('pending admin review')) {
      return _buildPendingScreen(isDark, bgColor, textColor);
    }

    if (_errorMessage != null && _verificationStatus == 'rejected') {
      return _buildRejectedScreen(isDark, bgColor, textColor);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Identity Verification',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            _buildProgressIndicator(isDark),
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
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 16),

            // Step content
            if (_currentStep == 0)
              _buildIdFrontStep(isDark, cardColor, textColor),
            if (_currentStep == 1)
              _buildIdBackStep(isDark, cardColor, textColor),
            if (_currentStep == 2)
              _buildReviewStep(isDark, cardColor, textColor),

            const SizedBox(height: 24),

            // Navigation buttons
            if (_currentStep < 2)
              Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: CustomButton(
                        label: 'Previous',
                        onPressed: () {
                          setState(() => _currentStep--);
                        },
                        backgroundColor: isDark
                            ? AppColors.darkBgSecondary
                            : Colors.grey[200],
                        textColor: isDark
                            ? AppColors.textPrimary
                            : Colors.black,
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      label: 'Next',
                      onPressed: _isLoading ? null : _handleNextStep,
                      backgroundColor: _isNextDisabled()
                          ? Colors.grey
                          : AppColors.primary,
                      textColor: Colors.black,
                    ),
                  ),
                ],
              )
            else
              CustomButton(
                label: _isLoading ? 'Submitting...' : 'Submit for Verification',
                onPressed: _isLoading ? null : _submitVerification,
                backgroundColor: AppColors.primary,
                textColor: Colors.black,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    final steps = ['ID Front', 'ID Back', 'Review'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${_currentStep + 1} of ${steps.length}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          steps[_currentStep],
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / steps.length,
            minHeight: 4,
            backgroundColor: isDark
                ? AppColors.borderColor
                : AppColors.lightBorderColor,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildIdFrontStep(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Text(
          'Upload the front side of your ID',
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 20),
        _buildImageUploadCard(
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          image: _idFrontFile,
          onCameraPress: _captureIdFront,
          onGalleryPress: _uploadIdFront,
          label: 'ID Front',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBgSecondary.withOpacity(0.5)
                : Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.blue[300]!,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: isDark ? AppColors.primary : Colors.blue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Make sure the ID is clear and fully visible',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdBackStep(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Text(
          'Upload the back side of your ID',
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 20),
        _buildImageUploadCard(
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          image: _idBackFile,
          onCameraPress: _captureIdBack,
          onGalleryPress: _uploadIdBack,
          label: 'ID Back',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBgSecondary.withOpacity(0.5)
                : Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.blue[300]!,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: isDark ? AppColors.primary : Colors.blue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Make sure the back side is clear and fully visible',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Text(
          'Review Your Documents',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: AppColors.borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildDocumentReviewItem(
                isDark,
                cardColor,
                'ID Front',
                _idFrontFile,
              ),
              const SizedBox(height: 12),
              _buildDocumentReviewItem(
                isDark,
                cardColor,
                'ID Back',
                _idBackFile,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Documents look good! Ready to submit?',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentReviewItem(
    bool isDark,
    Color cardColor,
    String label,
    File? image,
  ) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgSecondary : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(image, fit: BoxFit.cover),
                )
              : const Icon(
                  Icons.image_not_supported,
                  color: AppColors.textSecondary,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                image != null ? 'Ready' : 'Not uploaded',
                style: TextStyle(
                  fontSize: 12,
                  color: image != null ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        Icon(
          image != null ? Icons.check_circle : Icons.error_outline,
          color: image != null ? AppColors.success : AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildImageUploadCard({
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required File? image,
    required VoidCallback onCameraPress,
    required VoidCallback onGalleryPress,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(
          color: image != null ? AppColors.primary : AppColors.borderColor,
          width: image != null ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: image != null
          ? Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    image,
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
                      onPressed: onCameraPress,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Retake'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: onGalleryPress,
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
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
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
                      onPressed: onCameraPress,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: onGalleryPress,
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

  Widget _buildCompletionScreen(bool isDark, Color bgColor, Color textColor) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verification Submitted!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your documents have been submitted for admin review. We\'ll notify you once your verification is complete.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Back to Home',
                onPressed: () => Navigator.pop(context),
                backgroundColor: AppColors.primary,
                textColor: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingScreen(bool isDark, Color bgColor, Color textColor) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  color: AppColors.warning,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verification Pending',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your verification is being reviewed by our admin team. This usually takes 1-2 business days.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Back to Home',
                onPressed: () => Navigator.pop(context),
                backgroundColor: AppColors.primary,
                textColor: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen(bool isDark, Color bgColor, Color textColor) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verification Rejected',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (_rejectionReason != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason:',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _rejectionReason!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Please correct the issue and resubmit.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Resubmit',
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                    _idFrontFile = null;
                    _idBackFile = null;
                    _errorMessage = null;
                  });
                },
                backgroundColor: AppColors.primary,
                textColor: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isNextDisabled() {
    if (_currentStep == 0) return _idFrontFile == null;
    if (_currentStep == 1) return _idBackFile == null;
    return false;
  }

  void _handleNextStep() {
    if (!_isNextDisabled()) {
      setState(() => _currentStep++);
    }
  }
}
