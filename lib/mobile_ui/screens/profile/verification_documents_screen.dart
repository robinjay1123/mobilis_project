import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_service.dart';
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/optimized_network_image.dart';

class VerificationDocumentsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool isDarkMode;

  const VerificationDocumentsScreen({
    super.key,
    this.onBack,
    this.isDarkMode = true,
  });

  @override
  State<VerificationDocumentsScreen> createState() =>
      _VerificationDocumentsScreenState();
}

class _VerificationDocumentsScreenState
    extends State<VerificationDocumentsScreen> {
  bool _isLoading = true;
  bool _isVerified = false;
  bool _hasSubmittedVerification = false;
  String _verificationStatus = 'required';
  String _rejectionReason = '';
  Map<String, dynamic> _verificationRecord = {};

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final authService = AuthService();
      final userId = authService.currentUser?.id;
      final verification = userId == null
          ? null
          : await VerificationService.getUserVerification(userId);
      final isVerified = await authService.isUserVerified();
      final rawStatus = verification?['verification_status']
          ?.toString()
          .toLowerCase();
      final status =
          verification == null || rawStatus == null || rawStatus.isEmpty
          ? 'required'
          : rawStatus;
      final Map<String, dynamic> combinedRecord = Map<String, dynamic>.from(verification ?? {});
      if (userId != null) {
        final driverProfile = await DriverService().getDriverProfile(userId);
        if (driverProfile != null) {
          combinedRecord.addAll(driverProfile);
        }
      }
      final meta = authService.currentUser?.userMetadata;
      if (meta != null) {
        combinedRecord.addAll(Map<String, dynamic>.from(meta));
      }

      if (!mounted) return;
      setState(() {
        _verificationRecord = combinedRecord;
        _isVerified =
            isVerified ||
            (verification?['verification_status']?.toString().toLowerCase() ==
                'verified');
        _hasSubmittedVerification = verification != null;
        _verificationStatus = status;
        _rejectionReason = (verification?['rejection_reason'] ?? '')
            .toString()
            .trim();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isVerified = false;
        _hasSubmittedVerification = false;
        _verificationStatus = 'required';
      });
    }
  }

  void _openVerificationFlow() {
    Navigator.of(context).pushNamed('/id-verification');
  }

  List<Map<String, dynamic>> get documents {
    if (_isVerified) {
      return [
        {
          'title': 'Identity Verification',
          'status': 'Verified',
          'date': 'Your account is verified',
          'icon': Icons.verified_user,
          'statusColor': AppColors.success,
        },
      ];
    }

    return [
      {
        'title': 'Identity Verification',
        'status': _verificationStatus == 'rejected'
            ? 'Rejected'
            : _hasSubmittedVerification
            ? 'Pending'
            : 'Required',
        'date': _verificationStatus == 'rejected'
            ? (_rejectionReason.isNotEmpty
                  ? 'Rejected: $_rejectionReason'
                  : 'Rejected by admin')
            : _hasSubmittedVerification
            ? 'Submitted for admin review'
            : 'Verification required',
        'icon': Icons.verified_user,
        'statusColor': _verificationStatus == 'rejected'
            ? AppColors.error
            : _hasSubmittedVerification
            ? AppColors.warning
            : AppColors.primary,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    return Container(
      color: isDark ? AppColors.darkBg : AppColors.lightBg,
      child: Column(
        children: [
          // Header
          Container(
            color: isDark
                ? AppColors.darkBgSecondary
                : AppColors.lightBgSecondary,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 12,
              16,
              12,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2837) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Verification Docs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isVerified
                                ? 'Verification Status: Complete'
                                : _verificationStatus == 'rejected'
                                ? 'Verification Status: Rejected'
                                : _hasSubmittedVerification
                                ? 'Verification Status: Pending Review'
                                : 'Verification Status: Required',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _isVerified ? 1.0 : 0.3,
                              minHeight: 8,
                              backgroundColor: isDark
                                  ? AppColors.darkBgSecondary
                                  : AppColors.lightBgSecondary,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: _buildSubmittedDocumentPhotoCards(
                          context: context,
                          record: _verificationRecord,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_isVerified)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verification Notes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _verificationStatus == 'rejected'
                                    ? AppColors.error.withOpacity(0.12)
                                    : isDark
                                    ? AppColors.darkBgSecondary
                                    : AppColors.lightBgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _verificationStatus == 'rejected'
                                      ? AppColors.error.withOpacity(0.35)
                                      : isDark
                                      ? AppColors.borderColor
                                      : AppColors.lightBorderColor,
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
                                          color:
                                              (_verificationStatus == 'rejected'
                                                      ? AppColors.error
                                                      : AppColors.warning)
                                                  .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          _verificationStatus == 'rejected'
                                              ? Icons.cancel_outlined
                                              : Icons.info,
                                          color:
                                              _verificationStatus == 'rejected'
                                              ? AppColors.error
                                              : AppColors.warning,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _verificationStatus == 'rejected'
                                                  ? 'Rejected'
                                                  : _hasSubmittedVerification
                                                  ? 'Under Review'
                                                  : 'Action Required',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? AppColors.textPrimary
                                                    : AppColors.lightTextPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _verificationStatus == 'rejected'
                                                  ? (_rejectionReason.isNotEmpty
                                                        ? _rejectionReason
                                                        : 'No reason was provided by admin.')
                                                  : _hasSubmittedVerification
                                                  ? 'Your verification request has been submitted and is waiting for admin approval.'
                                                  : 'Identity verification is required before you can book a vehicle.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppColors.textSecondary
                                                    : AppColors.lightTextSecondary,
                                              ),
                                            ),
                                            if (_verificationStatus ==
                                                'rejected')
                                              const SizedBox(height: 4),
                                            if (_verificationStatus ==
                                                'rejected')
                                              Text(
                                                'You can correct the issue and reapply.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? AppColors.textSecondary
                                                      : AppColors.lightTextSecondary,
                                                ),
                                              ),
                                             if (!_isVerified) ...[
                                               const SizedBox(height: 12),
                                               SizedBox(
                                                 width: double.infinity,
                                                 child: ElevatedButton.icon(
                                                   onPressed: _openVerificationFlow,
                                                   icon: const Icon(Icons.edit_document, size: 16),
                                                   label: Text(
                                                     _verificationStatus == 'rejected'
                                                         ? 'Reapply Verification'
                                                         : 'Update / Submit Verification',
                                                     style: const TextStyle(fontWeight: FontWeight.bold),
                                                   ),
                                                   style: ElevatedButton.styleFrom(
                                                     backgroundColor: AppColors.primary,
                                                     foregroundColor: Colors.black,
                                                     shape: RoundedRectangleBorder(
                                                       borderRadius: BorderRadius.circular(10),
                                                     ),
                                                   ),
                                                 ),
                                               ),
                                             ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePreviewDialog(BuildContext context, String title, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: OptimizedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSubmittedDocumentPhotoCards({
    required BuildContext context,
    required Map<String, dynamic> record,
    required bool isDark,
  }) {
    String? clean(dynamic v) {
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty && (s.startsWith('http') || s.startsWith('data:image') || s.contains('/storage/')))
          ? s
          : null;
    }

    final idFrontUrl = clean(record['id_front_url'] ?? record['id_document_url'] ?? record['id_photo_url']);
    final idBackUrl = clean(record['id_back_url']);
    final faceSelfieUrl = clean(record['face_selfie_url'] ?? record['profile_picture_url'] ?? record['avatar_url']);
    final selfieWithIdUrl = clean(record['selfie_with_id_url'] ?? record['selfie_holding_id_url']);
    final licensePhotoUrl = clean(record['driver_license_photo_url'] ?? record['license_photo_url'] ?? record['license_url']);
    final nbiFileUrl = clean(record['driver_nbi_url'] ?? record['nbi_file_url'] ?? record['nbi_url']);
    final signatureUrl = clean(record['driver_signature_url'] ?? record['signature_url']);

    final defaultStatus = _isVerified ? 'Verified' : (_hasSubmittedVerification ? 'Submitted' : 'Pending');
    final defaultStatusColor = _isVerified ? AppColors.success : (_hasSubmittedVerification ? AppColors.primary : AppColors.warning);

    final items = [
      {
        'title': 'Government ID (Front)',
        'subtitle': record['id_type'] != null ? 'Type: ${record['id_type']}' : 'Government identity photo',
        'icon': Icons.badge_outlined,
        'url': idFrontUrl,
        'status': idFrontUrl != null ? defaultStatus : (_isVerified ? 'Verified' : 'Pending'),
        'statusColor': idFrontUrl != null ? defaultStatusColor : (_isVerified ? AppColors.success : AppColors.warning),
      },
      {
        'title': 'Government ID (Back)',
        'subtitle': 'Rear side photo of ID card',
        'icon': Icons.credit_card_outlined,
        'url': idBackUrl,
        'status': idBackUrl != null ? defaultStatus : (_isVerified ? 'Verified' : 'Pending'),
        'statusColor': idBackUrl != null ? defaultStatusColor : (_isVerified ? AppColors.success : AppColors.warning),
      },
      {
        'title': 'Biometric Face Selfie',
        'subtitle': 'Liveness & identity selfie check',
        'icon': Icons.face_retouching_natural,
        'url': faceSelfieUrl,
        'status': faceSelfieUrl != null ? defaultStatus : (_isVerified ? 'Verified' : 'Pending'),
        'statusColor': faceSelfieUrl != null ? defaultStatusColor : (_isVerified ? AppColors.success : AppColors.warning),
      },
      {
        'title': 'Selfie Holding ID',
        'subtitle': 'Authenticated photo holding government ID',
        'icon': Icons.co_present_outlined,
        'url': selfieWithIdUrl,
        'status': selfieWithIdUrl != null ? defaultStatus : (_isVerified ? 'Verified' : 'Pending'),
        'statusColor': selfieWithIdUrl != null ? defaultStatusColor : (_isVerified ? AppColors.success : AppColors.warning),
      },
      if (licensePhotoUrl != null)
        {
          'title': 'Driver\'s License Document',
          'subtitle': 'Valid driver\'s license document photo',
          'icon': Icons.card_membership_outlined,
          'url': licensePhotoUrl,
          'status': defaultStatus,
          'statusColor': defaultStatusColor,
        },
      if (nbiFileUrl != null)
        {
          'title': 'NBI / Police Clearance',
          'subtitle': 'Official clearance certificate photo',
          'icon': Icons.verified_user_outlined,
          'url': nbiFileUrl,
          'status': defaultStatus,
          'statusColor': defaultStatusColor,
        },
      if (signatureUrl != null)
        {
          'title': 'Digital Signature',
          'subtitle': 'Authenticated digital signature',
          'icon': Icons.draw_outlined,
          'url': signatureUrl,
          'status': defaultStatus,
          'statusColor': defaultStatusColor,
        },
    ];

    return items.map((item) {
      final title = item['title'] as String;
      final subtitle = item['subtitle'] as String;
      final icon = item['icon'] as IconData;
      final url = item['url'] as String?;
      final status = item['status'] as String;
      final statusColor = item['statusColor'] as Color;

      final hasImage = url != null && url.isNotEmpty;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (hasImage) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showImagePreviewDialog(context, title, url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 145,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        OptimizedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'View Photo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                    SizedBox(width: 6),
                    Text(
                      'Document authenticated on file',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }
}
