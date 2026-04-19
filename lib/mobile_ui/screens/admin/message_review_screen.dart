import 'package:flutter/material.dart';
import '../../../services/message_filter_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class AdminMessageReviewScreen extends StatefulWidget {
  final bool isDarkMode;

  const AdminMessageReviewScreen({super.key, this.isDarkMode = true});

  @override
  State<AdminMessageReviewScreen> createState() =>
      _AdminMessageReviewScreenState();
}

class _AdminMessageReviewScreenState extends State<AdminMessageReviewScreen> {
  int _selectedTab = 0; // 0: Pending, 1: Confirmed, 2: Dismissed
  late Future<List<Map<String, dynamic>>> _flagsFuture;

  @override
  void initState() {
    super.initState();
    _loadFlags();
  }

  void _loadFlags() {
    // This would ideally load all flags filtered by status from the service
    // For now, this is a placeholder
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Message Review Hub',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab navigation
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.borderColor
                      : AppColors.lightBorderColor,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildTab('Pending', 0, isDark, textColor),
                _buildTab('Confirmed', 1, isDark, textColor),
                _buildTab('Dismissed', 2, isDark, textColor),
              ],
            ),
          ),

          // Flags list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_selectedTab == 0)
                  _buildPendingFlags(isDark, cardColor, textColor),
                if (_selectedTab == 1)
                  _buildConfirmedFlags(isDark, cardColor, textColor),
                if (_selectedTab == 2)
                  _buildDismissedFlags(isDark, cardColor, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, bool isDark, Color textColor) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: isActive ? 3 : 0,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : textColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingFlags(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Review flagged messages and decide action',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildFlagCard(
          isDark,
          cardColor,
          textColor,
          flagId: 'flag_001',
          userName: 'John Doe',
          userId: 'user_123',
          messageContent:
              'Hey, my WhatsApp is +1-555-123-4567, contact me there',
          riskLevel: 'high',
          keywords: ['whatsapp', 'phone_number'],
          timestamp: '2 minutes ago',
          onApprove: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Flag confirmed. User may be restricted.'),
                backgroundColor: AppColors.success,
              ),
            );
          },
          onDismiss: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Flag dismissed'),
                backgroundColor: AppColors.textSecondary,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildConfirmedFlags(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Text('No confirmed flags yet', style: TextStyle(color: textColor)),
      ],
    );
  }

  Widget _buildDismissedFlags(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        Text('No dismissed flags yet', style: TextStyle(color: textColor)),
      ],
    );
  }

  Widget _buildFlagCard(
    bool isDark,
    Color cardColor,
    Color textColor, {
    required String flagId,
    required String userName,
    required String userId,
    required String messageContent,
    required String riskLevel,
    required List<String> keywords,
    required String timestamp,
    required VoidCallback onApprove,
    required VoidCallback onDismiss,
  }) {
    final riskColor = riskLevel == 'high'
        ? AppColors.error
        : riskLevel == 'medium'
        ? AppColors.warning
        : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          // User info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    userId,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: riskColor),
                ),
                child: Text(
                  riskLevel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Message content
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgSecondary : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              messageContent,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Keywords
          Wrap(
            spacing: 8,
            children: keywords
                .map(
                  (keyword) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: riskColor, width: 0.5),
                    ),
                    child: Text(
                      keyword,
                      style: TextStyle(
                        fontSize: 11,
                        color: riskColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),

          // Timestamp
          Text(
            timestamp,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.textTertiary
                  : AppColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                  label: const Text('Dismiss'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.textPrimary
                        : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
