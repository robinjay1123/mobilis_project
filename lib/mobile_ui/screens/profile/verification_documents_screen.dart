import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';

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
  String _verificationStatus = 'pending';
  String _rejectionReason = '';

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    final authService = AuthService();
    final userId = authService.currentUser?.id;
    final verification = userId == null
        ? null
        : await VerificationService.getUserVerification(userId);
    final isVerified = await authService.isUserVerified();
    final status = (verification?['verification_status'] ?? 'pending')
        .toString()
        .toLowerCase();
    if (!mounted) return;
    setState(() {
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
  }

  Future<void> _uploadDocument(String documentType) async {
    try {
      final authService = AuthService();

      final userId = authService.supabase.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
        return;
      }

      // Show a dialog for file path input (in a real app, use image_picker)
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Upload $documentType'),
          content: const Text(
            'In a production app, this would open a file picker',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Document upload feature will be available in next release',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
        'status': _verificationStatus == 'rejected' ? 'Rejected' : 'Pending',
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
            : AppColors.warning,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          color: Theme.of(context).brightness == Brightness.dark
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
              GestureDetector(
                onTap: widget.onBack,
                child: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Verification Docs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
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
                              : 'Verification Status: Pending',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
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
                      children: List.generate(
                        documents.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: documents[index]['status'] == 'Pending'
                                ? () =>
                                      _uploadDocument(documents[index]['title'])
                                : null,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.darkBgSecondary
                                    : AppColors.lightBgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.borderColor
                                      : AppColors.lightBorderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: documents[index]['statusColor']
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      documents[index]['icon'],
                                      color: documents[index]['statusColor'],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              documents[index]['title'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.dark
                                                    ? AppColors.textPrimary
                                                    : AppColors
                                                          .lightTextPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    documents[index]['statusColor']
                                                        .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                documents[index]['status'],
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      documents[index]['statusColor'],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          documents[index]['date'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? AppColors.textSecondary
                                                : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (documents[index]['status'] == 'Pending')
                                    Icon(
                                      Icons.upload,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.textSecondary
                                          : AppColors.lightTextSecondary,
                                      size: 20,
                                    )
                                  else
                                    Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
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
                                  : Theme.of(context).brightness ==
                                        Brightness.dark
                                  ? AppColors.darkBgSecondary
                                  : AppColors.lightBgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _verificationStatus == 'rejected'
                                    ? AppColors.error.withOpacity(0.35)
                                    : Theme.of(context).brightness ==
                                          Brightness.dark
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
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _verificationStatus == 'rejected'
                                            ? Icons.cancel_outlined
                                            : Icons.info,
                                        color: _verificationStatus == 'rejected'
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
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
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
                                                : 'Please upload your address proof to complete verification',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? AppColors.textSecondary
                                                  : AppColors
                                                        .lightTextSecondary,
                                            ),
                                          ),
                                          if (_verificationStatus == 'rejected')
                                            const SizedBox(height: 4),
                                          if (_verificationStatus == 'rejected')
                                            Text(
                                              'You can correct the issue and reapply.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.dark
                                                    ? AppColors.textSecondary
                                                    : AppColors
                                                          .lightTextSecondary,
                                              ),
                                            ),
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
    );
  }
}
