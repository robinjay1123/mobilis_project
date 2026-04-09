import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class VehicleRegistrationUploadScreen extends StatefulWidget {
  const VehicleRegistrationUploadScreen({super.key});

  @override
  State<VehicleRegistrationUploadScreen> createState() =>
      _VehicleRegistrationUploadScreenState();
}

class _VehicleRegistrationUploadScreenState
    extends State<VehicleRegistrationUploadScreen> {
  String? orImagePath;
  String? crImagePath;
  bool isUploading = false;

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
          'Vehicle Registration',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Upload Documents',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To complete your registration, please provide high-quality photos of your vehicle\'s official documents',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Official Receipt (OR) Upload
            _buildDocumentUploadSection(
              title: 'Official Receipt (OR)',
              description: 'Latest LTO Official Receipt',
              imagePath: orImagePath,
              onUpload: () => _handleUpload('or'),
              onRemove: () => setState(() => orImagePath = null),
            ),
            const SizedBox(height: 20),

            // Certificate of Registration (CR) Upload
            _buildDocumentUploadSection(
              title: 'Certificate of Registration (CR)',
              description: 'Valid Certificate of Registration',
              imagePath: crImagePath,
              onUpload: () => _handleUpload('cr'),
              onRemove: () => setState(() => crImagePath = null),
            ),
            const SizedBox(height: 32),

            // Photo Quality Checklist
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
                  const Row(
                    children: [
                      Icon(Icons.checklist, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Photo Quality Checklist',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildChecklistItem('All four corners visible'),
                  _buildChecklistItem('Sharp and legible text'),
                  _buildChecklistItem('No glare from flash'),
                  _buildChecklistItem('Plain, contrasting background'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed:
                    (orImagePath != null && crImagePath != null && !isUploading)
                    ? _handleSubmit
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.primary.withAlpha(100),
                  disabledForegroundColor: Colors.black54,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: isUploading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black,
                          ),
                        ),
                      )
                    : const Text(
                        'Submit for Verification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Note
            Center(
              child: Text(
                'Verification usually takes 24-48 hours',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUploadSection({
    required String title,
    required String description,
    required String? imagePath,
    required VoidCallback onUpload,
    required VoidCallback onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: imagePath == null ? onUpload : null,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: imagePath != null
                    ? AppColors.success
                    : AppColors.borderColor,
                width: imagePath != null ? 2 : 1,
              ),
            ),
            child: imagePath != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(
                          imagePath,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildUploadedPlaceholder();
                          },
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Uploaded',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkBgTertiary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          color: AppColors.textSecondary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tap to upload',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, PNG or PDF (max 5MB)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadedPlaceholder() {
    return Container(
      color: AppColors.darkBgTertiary,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, color: AppColors.success, size: 40),
            SizedBox(height: 8),
            Text(
              'Document Uploaded',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.check, color: AppColors.success, size: 14),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpload(String type) async {
    // TODO: Implement actual image picker
    // For now, simulate upload
    setState(() {
      if (type == 'or') {
        orImagePath = 'uploaded';
      } else {
        crImagePath = 'uploaded';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Image upload functionality will be implemented with image_picker',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _handleSubmit() async {
    setState(() => isUploading = true);

    // Simulate submission
    await Future.delayed(const Duration(seconds: 2));

    setState(() => isUploading = false);

    if (mounted) {
      // Navigate to success screen
      Navigator.pushReplacementNamed(context, '/verification-success');
    }
  }
}
