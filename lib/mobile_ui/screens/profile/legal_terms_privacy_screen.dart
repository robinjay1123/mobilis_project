import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/terms_service.dart';
import '../../theme/app_colors.dart';

class LegalTermsPrivacyScreen extends StatefulWidget {
  final String initialTab; // 'terms' or 'privacy'
  final bool isDarkMode;
  final VoidCallback? onBack;

  const LegalTermsPrivacyScreen({
    super.key,
    this.initialTab = 'terms',
    this.isDarkMode = true,
    this.onBack,
  });

  @override
  State<LegalTermsPrivacyScreen> createState() =>
      _LegalTermsPrivacyScreenState();
}

class _LegalTermsPrivacyScreenState extends State<LegalTermsPrivacyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _termsContent = '';
  String _privacyContent = '';
  String? _pdfUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.toLowerCase() == 'privacy' ? 1 : 0,
    );
    _loadLegalDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLegalDocuments() async {
    setState(() => _isLoading = true);
    try {
      final termsService = TermsService();
      final terms = await termsService.getTermsOfService();
      final privacy = await termsService.getPrivacyPolicy();
      final pdfUrl = await termsService.getRentalTermsPdfUrl();
      if (!mounted) return;
      setState(() {
        _termsContent = terms;
        _privacyContent = privacy;
        _pdfUrl = pdfUrl;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark
        ? AppColors.darkBgSecondary
        : AppColors.lightBgSecondary;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2837) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: textPrimary,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            ),
          ),
        ),
        title: Text(
          'Terms and Conditions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: cardBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Terms of Service'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.privacy_tip_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Privacy Policy'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLegalDocuments,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Terms of Service
                  _buildContentCard(
                    title: 'Terms of Service',
                    icon: Icons.description_outlined,
                    content: _termsContent,
                    isDark: isDark,
                    cardBg: cardBg,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  // Tab 2: Privacy Policy
                  _buildContentCard(
                    title: 'Privacy Policy',
                    icon: Icons.privacy_tip_outlined,
                    content: _privacyContent,
                    isDark: isDark,
                    cardBg: cardBg,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildContentCard({
    required String title,
    required IconData icon,
    required String content,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.borderColor
                    : AppColors.lightBorderColor,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mobilis Official Policy',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_pdfUrl != null && title == 'Terms of Service') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(_pdfUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF10B981)),
                label: const Text('View Official Rental Agreement (PDF Document)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.borderColor
                    : AppColors.lightBorderColor,
              ),
            ),
            child: SelectableText(
              content.isNotEmpty ? content : 'No policy text provided yet.',
              style: TextStyle(fontSize: 14, height: 1.6, color: textPrimary),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© ${DateTime.now().year} Mobilis. All rights reserved.',
              style: TextStyle(fontSize: 11, color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
