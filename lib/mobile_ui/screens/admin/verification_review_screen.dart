import 'package:flutter/material.dart';
import '../../../services/verification_service.dart';
import '../../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class AdminVerificationHubScreen extends StatefulWidget {
  final bool isDarkMode;

  const AdminVerificationHubScreen({super.key, this.isDarkMode = true});

  @override
  State<AdminVerificationHubScreen> createState() =>
      _AdminVerificationHubScreenState();
}

class _AdminVerificationHubScreenState
    extends State<AdminVerificationHubScreen> {
  late Future<List<Map<String, dynamic>>> _verificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadVerifications();
  }

  void _loadVerifications() {
    _verificationsFuture = VerificationService.getPendingVerifications();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Verification Hub',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _verificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading verifications: ${snapshot.error}',
                style: TextStyle(color: textColor),
              ),
            );
          }

          final verifications = snapshot.data ?? [];

          if (verifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text(
                    'All verifications complete!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No pending verifications',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: verifications.length,
            itemBuilder: (context, index) {
              final verification = verifications[index];
              return _buildVerificationCard(
                context,
                verification,
                isDark,
                textColor,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVerificationCard(
    BuildContext context,
    Map<String, dynamic> verification,
    bool isDark,
    Color textColor,
  ) {
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final user = verification['users'] != null
        ? Map<String, dynamic>.from(verification['users'] as Map)
        : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminVerificationDetailScreen(
              verification: verification,
              isDarkMode: widget.isDarkMode,
              onStatusChanged: () {
                setState(() {
                  _loadVerifications();
                });
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info
              Text(
                user?['full_name'] ?? 'Unknown User',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?['email'] ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // Status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: const Text(
                      'Pending Review',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminVerificationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> verification;
  final bool isDarkMode;
  final VoidCallback onStatusChanged;

  const AdminVerificationDetailScreen({
    super.key,
    required this.verification,
    this.isDarkMode = true,
    required this.onStatusChanged,
  });

  @override
  State<AdminVerificationDetailScreen> createState() =>
      _AdminVerificationDetailScreenState();
}

class _AdminVerificationDetailScreenState
    extends State<AdminVerificationDetailScreen> {
  late TextEditingController _faceMatchController;
  late TextEditingController _rejectionReasonController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _faceMatchController = TextEditingController(text: '85.0');
    _rejectionReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _faceMatchController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _approveVerification() async {
    final faceMatch = double.tryParse(_faceMatchController.text) ?? 85.0;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final adminId = authService.currentUser?.id;

      if (adminId == null) throw Exception('Admin not authenticated');

      final result = await VerificationService.approveVerification(
        verificationId: widget.verification['id'],
        adminId: adminId,
        faceMatchPercentage: faceMatch,
      );

      if (result['success']) {
        widget.onStatusChanged();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Verification approved successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
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

  Future<void> _rejectVerification() async {
    if (_rejectionReasonController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide a rejection reason';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final adminId = authService.currentUser?.id;

      if (adminId == null) throw Exception('Admin not authenticated');

      final result = await VerificationService.rejectVerification(
        verificationId: widget.verification['id'],
        rejectionReason: _rejectionReasonController.text,
        adminId: adminId,
      );

      if (result['success']) {
        widget.onStatusChanged();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Verification rejected'),
              backgroundColor: AppColors.error,
            ),
          );
          Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;

    final idDocs = widget.verification['id_document_url'] as String?;
    final idParts = idDocs?.split('|') ?? [];
    final idFrontUrl = idParts.isNotEmpty ? idParts[0] : null;
    final idBackUrl = idParts.length > 1 ? idParts[1] : null;
    final facePhotoUrl = widget.verification['face_photo_url'] as String?;

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
          'Verification Review',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderColor
                      : AppColors.lightBorderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    'Name',
                    widget.verification['users']?['full_name'] ?? 'Unknown',
                    isDark,
                    textColor,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Email',
                    widget.verification['users']?['email'] ?? '',
                    isDark,
                    textColor,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Role',
                    widget.verification['users']?['role'] ?? '',
                    isDark,
                    textColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Documents
            Text(
              'Documents',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),

            // ID Front
            if (idFrontUrl != null)
              _buildDocumentPreview(
                'ID Front',
                idFrontUrl,
                isDark,
                cardColor,
                textColor,
              ),
            const SizedBox(height: 12),

            // ID Back
            if (idBackUrl != null)
              _buildDocumentPreview(
                'ID Back',
                idBackUrl,
                isDark,
                cardColor,
                textColor,
              ),
            const SizedBox(height: 12),

            // Face Photo
            if (facePhotoUrl != null)
              _buildDocumentPreview(
                'Face Photo',
                facePhotoUrl,
                isDark,
                cardColor,
                textColor,
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
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 16),

            // Approval controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderColor
                      : AppColors.lightBorderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Decision',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Face Match
                  Text(
                    'Face Match Percentage',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _faceMatchController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter percentage (0-100)',
                      suffixText: '%',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkBgSecondary
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.borderColor
                              : AppColors.lightBorderColor,
                        ),
                      ),
                    ),
                    style: TextStyle(color: textColor),
                  ),
                  const SizedBox(height: 16),

                  // Approval buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _approveVerification,
                          icon: const Icon(Icons.check_circle),
                          label: Text(_isLoading ? 'Processing...' : 'Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Rejection section
                  Text(
                    'Rejection Reason (if applicable)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rejectionReasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter rejection reason...',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkBgSecondary
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.borderColor
                              : AppColors.lightBorderColor,
                        ),
                      ),
                    ),
                    style: TextStyle(color: textColor),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _rejectVerification,
                      icon: const Icon(Icons.cancel),
                      label: Text(_isLoading ? 'Processing...' : 'Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildInfoRow(
    String label,
    String value,
    bool isDark,
    Color textColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentPreview(
    String label,
    String imageUrl,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: isDark ? AppColors.darkBgSecondary : Colors.grey[200],
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
