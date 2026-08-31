import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class AccountVerificationScreen extends StatefulWidget {
  const AccountVerificationScreen({super.key});

  @override
  State<AccountVerificationScreen> createState() =>
      _AccountVerificationScreenState();
}

class _AccountVerificationScreenState extends State<AccountVerificationScreen> {
  bool _isLoading = true;
  String _verificationStatus = 'pending';
  bool _isVerified = false;
  String? _userRole;
  Map<String, dynamic>? _verificationRecord;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = AuthService().currentUser;
      if (user != null) {
        final state = await VerificationService.getUserVerificationState(user.id);
        final record = await VerificationService.getUserVerification(user.id);

        if (mounted) {
          setState(() {
            _verificationStatus = (state['verification_status']?.toString() ?? 'pending').toLowerCase();
            _isVerified = state['is_verified'] as bool? ?? false;
            _userRole = state['role']?.toString();
            _verificationRecord = record;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading verification status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleResubmit() {
    final role = _userRole?.toLowerCase();
    if (role == 'partner') {
      Navigator.pushReplacementNamed(context, '/owner-verification');
    } else if (role == 'driver') {
      Navigator.pushReplacementNamed(context, '/driver-identity-verification');
    } else {
      Navigator.pushReplacementNamed(context, '/id-verification');
    }
  }

  void _handleBackToDashboard() async {
    final role = await AuthService().getUserRole();
    if (!mounted) return;

    if (role == 'partner') {
      Navigator.of(context).pushNamedAndRemoveUntil('/partner-home', (r) => false);
    } else if (role == 'driver') {
      Navigator.of(context).pushNamedAndRemoveUntil('/driver-home', (r) => false);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (r) => false);
    }
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
          'Verification Status',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadVerificationStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadVerificationStatus,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBanner(),
                    const SizedBox(height: 24),
                    _buildProgressCard(),
                    const SizedBox(height: 28),
                    const Text(
                      'Verification Progress',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTimeline(),
                    const SizedBox(height: 32),
                    if (_verificationStatus == 'rejected') ...[
                      CustomButton(
                        label: 'Resubmit Verification',
                        onPressed: _handleResubmit,
                      ),
                      const SizedBox(height: 12),
                    ],
                    CustomButton(
                      label: 'Back to Dashboard',
                      onPressed: _handleBackToDashboard,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusBanner() {
    Color bannerColor;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;

    if (_isVerified || _verificationStatus == 'verified' || _verificationStatus == 'approved') {
      bannerColor = AppColors.success;
      iconColor = AppColors.success;
      icon = Icons.verified_user_rounded;
      title = 'Account Fully Verified';
      subtitle = 'Your identity documents have been approved by admin. You have full platform access!';
    } else if (_verificationStatus == 'rejected') {
      bannerColor = AppColors.error;
      iconColor = AppColors.error;
      icon = Icons.cancel_outlined;
      title = 'Verification Rejected';
      subtitle = 'Your verification was not approved. Please check details and resubmit.';
    } else {
      bannerColor = AppColors.warning;
      iconColor = AppColors.warning;
      icon = Icons.hourglass_top_rounded;
      title = 'Verification Under Review';
      subtitle = 'Your verification documents are currently under admin review. Most reviews complete within 1-2 hours.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bannerColor.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerColor.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bannerColor.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: bannerColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    double progress = 0.75;
    String percentText = '75%';
    String label = 'Under Admin Review';

    if (_isVerified || _verificationStatus == 'verified' || _verificationStatus == 'approved') {
      progress = 1.0;
      percentText = '100%';
      label = 'Fully Verified';
    } else if (_verificationStatus == 'rejected') {
      progress = 0.33;
      percentText = 'Needs Resubmission';
      label = 'Action Required';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                percentText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isVerified ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final isDone = _isVerified || _verificationStatus == 'verified' || _verificationStatus == 'approved';

    return Column(
      children: [
        _buildTimelineItem(
          stepNumber: '1',
          title: 'Documents Submitted',
          subtitle: _verificationRecord?['id_type'] != null
              ? 'Submitted (${_verificationRecord!['id_type']})'
              : 'Identity document & details received',
          isDone: true,
          isInProgress: false,
        ),
        _buildTimelineItem(
          stepNumber: '2',
          title: 'Admin Verification Review',
          subtitle: isDone
              ? 'Review complete & verified'
              : (_verificationStatus == 'rejected'
                  ? 'Verification rejected by admin'
                  : 'Currently under review by Mobilis team'),
          isDone: isDone,
          isInProgress: !isDone && _verificationStatus != 'rejected',
        ),
        _buildTimelineItem(
          stepNumber: '3',
          title: 'Account Approval',
          subtitle: isDone
              ? 'Full account features unlocked'
              : 'Awaiting admin decision',
          isDone: isDone,
          isInProgress: false,
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String stepNumber,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isInProgress,
  }) {
    Color circleColor = AppColors.borderColor;
    Widget leadingWidget = Text(
      stepNumber,
      style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.bold),
    );

    if (isDone) {
      circleColor = AppColors.success;
      leadingWidget = const Icon(Icons.check, color: Colors.black, size: 16);
    } else if (isInProgress) {
      circleColor = AppColors.warning;
      leadingWidget = const Icon(Icons.hourglass_top, color: Colors.black, size: 16);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Center(child: leadingWidget),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDone || isInProgress ? AppColors.textPrimary : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isInProgress ? AppColors.warning : AppColors.textSecondary,
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
