import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../services/verification_service.dart';
import '../../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class DocumentVerificationScreen extends StatefulWidget {
  final VoidCallback? onVerificationComplete;
  final bool isDarkMode;

  const DocumentVerificationScreen({
    super.key,
    this.onVerificationComplete,
    this.isDarkMode = true,
  });

  @override
  State<DocumentVerificationScreen> createState() =>
      _DocumentVerificationScreenState();
}

class _DocumentVerificationScreenState
    extends State<DocumentVerificationScreen> {
  // Files
  File? _idFrontFile;
  File? _idBackFile;
  File? _facePhotoFile;

  // UI State
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _verificationStatus;
  String? _rejectionReason;
  int _currentStep = 0; // 0: ID Front, 1: ID Back, 2: Face, 3: Review

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
          _currentStep = 4;
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

  Future<void> _captureFacePhoto() async {
    final file = await VerificationService.pickImage(
      source: ImageSource.camera,
    );
    if (file != null) {
      setState(() {
        _facePhotoFile = file;
        _errorMessage = null;
      });
    }
  }

  Future<void> _uploadFacePhoto() async {
    final file = await VerificationService.pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      setState(() {
        _facePhotoFile = file;
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitVerification() async {
    if (_idFrontFile == null || _idBackFile == null || _facePhotoFile == null) {
      setState(() {
        _errorMessage = 'Please upload all required documents';
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

      final result = await VerificationService.submitVerification(
        userId: userId,
        idFrontFile: _idFrontFile!,
        idBackFile: _idBackFile!,
        facePhotoFile: _facePhotoFile!,
      );

      if (result['success']) {
        setState(() {
          _successMessage = result['message'];
          _isLoading = false;
          _currentStep = 4; // Completion step
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
    if (_currentStep == 4) {
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
          'Document Verification',
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
              _buildFacePhotoStep(isDark, cardColor, textColor),
            if (_currentStep == 3)
              _buildReviewStep(isDark, cardColor, textColor),

            const SizedBox(height: 24),

            // Navigation buttons
            if (_currentStep < 3)
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
    final steps = ['ID Front', 'ID Back', 'Face Photo', 'Review'];
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
              color: isDark ? AppColors.borderColor : Colors.blue[200]!,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ensure your ID is clear, well-lit, and covers the entire card with all text visible.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : Colors.blue[900],
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
      ],
    );
  }

  Widget _buildFacePhotoStep(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Text(
          'Take a selfie for face verification',
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
          image: _facePhotoFile,
          onCameraPress: _captureFacePhoto,
          onGalleryPress: _uploadFacePhoto,
          label: 'Face Photo',
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
              color: isDark ? AppColors.borderColor : Colors.blue[200]!,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Look directly at the camera with good lighting and a neutral expression.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : Colors.blue[900],
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
          'Review your documents',
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 20),
        _buildDocumentReview(
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          label: 'ID Front',
          image: _idFrontFile,
        ),
        const SizedBox(height: 12),
        _buildDocumentReview(
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          label: 'ID Back',
          image: _idBackFile,
        ),
        const SizedBox(height: 12),
        _buildDocumentReview(
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          label: 'Face Photo',
          image: _facePhotoFile,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBgSecondary.withOpacity(0.5)
                : Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.borderColor : AppColors.success,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your documents look good. Click Submit to send for admin verification.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : Colors.green[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
        title: Text(
          'Verification Rejected',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your recent verification was rejected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _rejectionReason ??
                        'No rejection reason was provided by admin.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? AppColors.textSecondary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please correct the issue and submit again.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondary : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildProgressIndicator(isDark),
            const SizedBox(height: 20),
            if (_currentStep == 0)
              _buildIdFrontStep(isDark, AppColors.darkBgSecondary, textColor)
            else if (_currentStep == 1)
              _buildIdBackStep(isDark, AppColors.darkBgSecondary, textColor)
            else if (_currentStep == 2)
              _buildFacePhotoStep(isDark, AppColors.darkBgSecondary, textColor)
            else
              _buildReviewStep(isDark, AppColors.darkBgSecondary, textColor),
            const SizedBox(height: 24),
            Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: CustomButton(
                      label: 'Previous',
                      onPressed: () => setState(() => _currentStep--),
                      backgroundColor: isDark
                          ? AppColors.darkBgSecondary
                          : Colors.grey[200],
                      textColor: isDark ? AppColors.textPrimary : Colors.black,
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    label: _isLoading ? 'Re-submitting...' : 'Submit Again',
                    onPressed: _isLoading ? null : _submitVerification,
                    backgroundColor: AppColors.primary,
                    textColor: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: image == null
          ? Column(
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBgSecondary
                        : Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 48,
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Upload $label',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onCameraPress,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onGalleryPress,
                              icon: const Icon(Icons.image),
                              label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? AppColors.textPrimary
                                    : Colors.black,
                                side: BorderSide(
                                  color: isDark
                                      ? AppColors.borderColor
                                      : AppColors.lightBorderColor,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                image,
                fit: BoxFit.cover,
                height: 250,
                width: double.infinity,
              ),
            ),
    );
  }

  Widget _buildDocumentReview({
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required String label,
    required File? image,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Row(
        children: [
          if (image != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Image.file(
                image,
                fit: BoxFit.cover,
                width: 80,
                height: 80,
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                      const SizedBox(height: 4),
                      Text(
                        image != null ? 'Uploaded' : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: image != null
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    image != null ? Icons.check_circle : Icons.pending,
                    color: image != null
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen(bool isDark, Color bgColor, Color textColor) {
    return Scaffold(
      backgroundColor: bgColor,
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
                  color: AppColors.success.withOpacity(0.1),
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
              ),
              const SizedBox(height: 12),
              Text(
                'Your documents have been submitted for verification.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'An admin will review your documents shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textTertiary
                      : AppColors.lightTextTertiary,
                ),
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
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verification In Progress',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your documents are being verified by an admin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You will receive a notification once verification is complete.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Return',
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

  bool _isNextDisabled() {
    if (_currentStep == 0) return _idFrontFile == null;
    if (_currentStep == 1) return _idBackFile == null;
    if (_currentStep == 2) return _facePhotoFile == null;
    return false;
  }

  void _handleNextStep() {
    if (!_isNextDisabled()) {
      setState(() => _currentStep++);
    }
  }
}
