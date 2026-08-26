import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/auth_service.dart';
import '../../../services/payout_method_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/optimized_network_image.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool isDarkMode;
  final String role; // 'renter', 'driver', 'partner', 'operator'

  const PaymentMethodsScreen({
    super.key,
    this.onBack,
    this.isDarkMode = true,
    this.role = 'renter',
  });

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final PayoutMethodService _payoutMethodService = PayoutMethodService();
  late Future<List<PayoutMethod>> _payoutMethodsFuture;
  bool _isLoading = false;

  bool get _isRenter => widget.role.toLowerCase() == 'renter';
  bool get _isPartner => widget.role.toLowerCase() == 'partner';
  bool get _isDriver => widget.role.toLowerCase() == 'driver';

  @override
  void initState() {
    super.initState();
    _loadPayoutMethods();
  }

  void _loadPayoutMethods() {
    final userId = AuthService().currentUser?.id ?? '';
    _payoutMethodsFuture = _payoutMethodService.getPayoutMethods(userId);
  }

  Future<void> _refreshPayoutMethods() async {
    final userId = AuthService().currentUser?.id ?? '';
    final req = _payoutMethodService.getPayoutMethods(userId);
    setState(() {
      _payoutMethodsFuture = req;
    });
    await req;
  }

  Color _providerColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'gcash':
        return const Color(0xFF007DFE);
      case 'maya':
        return const Color(0xFF00D668);
      case 'maribank':
        return const Color(0xFFFF5E00);
      case 'gotyme':
        return const Color(0xFF00D2D2);
      default:
        return AppColors.primary;
    }
  }

  String _formatAccountNumber(String raw) {
    final clean = raw.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 11) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 7)} ${clean.substring(7)}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0B141E) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF132235) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final borderColor = isDark ? const Color(0xFF1E3A5F) : Colors.grey.shade200;

    final screenTitle = _isRenter
        ? 'Refund & Payment Accounts'
        : (_isPartner || _isDriver ? 'Disbursement & Payout Accounts' : 'Payment & Payout Accounts');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF07111D) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          screenTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPayoutMethods,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
          children: [
            // Informative Context Banner
            _buildContextBanner(isDark, cardBg, textColor, subtitleColor, borderColor),
            const SizedBox(height: 20),

            // Linked Accounts Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Linked Accounts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddPayoutMethodModal(context),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                  label: const Text(
                    'Add Account',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Accounts List via FutureBuilder
            FutureBuilder<List<PayoutMethod>>(
              future: _payoutMethodsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !_isLoading) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load accounts',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(color: subtitleColor, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _refreshPayoutMethods,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final methods = snapshot.data ?? const <PayoutMethod>[];

                if (methods.isEmpty) {
                  return _buildEmptyState(isDark, cardBg, textColor, subtitleColor, borderColor);
                }

                return Column(
                  children: methods
                      .map(
                        (method) => _buildPayoutMethodCard(
                          method,
                          isDark,
                          cardBg,
                          textColor,
                          subtitleColor,
                          borderColor,
                        ),
                      )
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Supported Providers Notice Card
            _buildSupportedProvidersCard(isDark, cardBg, textColor, subtitleColor, borderColor),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF07111D) : Colors.white,
          border: Border(
            top: BorderSide(color: borderColor),
          ),
        ),
        child: ElevatedButton.icon(
          onPressed: () => _showAddPayoutMethodModal(context),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(
            _isRenter ? 'Link Refund Account (QR Code)' : 'Link Disbursement Account (QR Code)',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildContextBanner(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    final title = _isRenter
        ? 'Security Deposit & Cancellation Refunds'
        : (_isPartner
            ? 'Partner Earnings & Revenue Payouts'
            : 'Driver Commission & Trip Disbursements');

    final description = _isRenter
        ? 'Upload your recipient QR code (GCash, Maya, MariBank, or GoTyme) so the operator can swiftly return your refundable security deposit upon vehicle return inspection or processed cancellations.'
        : (_isPartner
            ? 'Link your verified payout QR and recipient details to receive rental earnings, completed trip payouts, and approved revenue disbursements directly.'
            : 'Link your payout QR code so PSDC operators can disburse your driver fees, trip commissions, and earned allowances directly to your e-wallet or bank.');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 44,
              color: isDark ? Colors.grey[500] : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Payment Methods Linked Yet',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isRenter
                ? 'Link your GCash, Maya, MariBank, or GoTyme QR to receive security deposit refunds quickly.'
                : 'Link your QR code and account details to receive payouts and disbursements.',
            style: TextStyle(
              color: subtitleColor,
              fontSize: 12.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _showAddPayoutMethodModal(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Link Account Now'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutMethodCard(
    PayoutMethod method,
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    final color = _providerColor(method.provider);
    final hasQr = method.qrCodeUrl != null && method.qrCodeUrl!.isNotEmpty;
    final formattedNumber = _formatAccountNumber(method.accountNumber);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: method.isDefault ? color.withOpacity(0.6) : borderColor,
          width: method.isDefault ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Provider Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  method.provider.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              if (method.isDefault) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'DEFAULT',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // QR Code Preview Button
              if (hasQr)
                IconButton(
                  tooltip: 'View QR Code',
                  onPressed: () => _showQrCodePreviewModal(context, method),
                  icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 8),

              // Popup Actions Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: subtitleColor, size: 20),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (action) async {
                  final userId = AuthService().currentUser?.id ?? '';
                  if (action == 'default') {
                    await _payoutMethodService.setDefault(userId, method.id);
                    await _refreshPayoutMethods();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${method.provider} set as default.'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  } else if (action == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(
                          'Remove Account',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        ),
                        content: Text(
                          'Are you sure you want to remove ${method.provider} ($formattedNumber)?',
                          style: TextStyle(color: subtitleColor),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await _payoutMethodService.deletePayoutMethod(userId, method.id);
                      await _refreshPayoutMethods();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${method.provider} account removed.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  if (!method.isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Set as Default'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                        SizedBox(width: 8),
                        Text('Remove Account', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Recipient Name
          Row(
            children: [
              Icon(Icons.person_outline_rounded, color: subtitleColor, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  method.accountName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Account Number
          Row(
            children: [
              Icon(Icons.phone_iphone_rounded, color: subtitleColor, size: 15),
              const SizedBox(width: 6),
              Text(
                formattedNumber,
                style: TextStyle(
                  color: subtitleColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          if (hasQr) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showQrCodePreviewModal(context, method),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Payment QR Code Attached (Tap to Preview)',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportedProvidersCard(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B2B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supported Payment Providers',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PayoutMethodService.allowedProviders.map((provider) {
              final color = _providerColor(provider);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF162538) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      provider,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPayoutMethodModal(BuildContext context) async {
    final userId = AuthService().currentUser?.id ?? '';
    final defaultName = AuthService().currentUser?.userMetadata?['full_name']?.toString() ??
        AuthService().currentUser?.userMetadata?['name']?.toString() ??
        '';

    String selectedProvider = 'GCash';
    final nameController = TextEditingController(text: defaultName);
    final numberController = TextEditingController();
    PlatformFile? pickedQrFile;
    bool isDefault = false;
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = widget.isDarkMode;
          final sheetBg = isDark ? const Color(0xFF0C1B2A) : Colors.white;
          final modalTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final modalSubColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
          final inputBg = isDark ? const Color(0xFF07111D) : const Color(0xFFF1F5F9);
          final inputBorder = isDark ? const Color(0xFF1E3A5F) : Colors.grey.shade300;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.add_card_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        _isRenter ? 'Link Refund Account' : 'Link Disbursement Account',
                        style: TextStyle(
                          color: modalTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select provider and provide your 11-digit account/mobile number and QR code image.',
                    style: TextStyle(color: modalSubColor, fontSize: 12),
                  ),
                  const SizedBox(height: 18),

                  // 1. PROVIDER SELECTOR
                  Text(
                    'Payment Provider',
                    style: TextStyle(
                      color: modalSubColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PayoutMethodService.allowedProviders.map((provider) {
                      final isSelected = selectedProvider == provider;
                      final color = _providerColor(provider);

                      return ChoiceChip(
                        label: Text(
                          provider,
                          style: TextStyle(
                            color: isSelected ? Colors.black : modalTextColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: inputBg,
                        side: BorderSide(
                          color: isSelected ? color : inputBorder,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setSheetState(() => selectedProvider = provider);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // 2. RECIPIENT / ACCOUNT NAME
                  Text(
                    'Recipient / Account Name',
                    style: TextStyle(
                      color: modalSubColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: modalTextColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Juan Dela Cruz',
                      hintStyle: TextStyle(color: modalSubColor),
                      prefixIcon: Icon(Icons.person_outline, color: modalSubColor, size: 20),
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. ACCOUNT / MOBILE NUMBER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Account / Mobile Number',
                        style: TextStyle(
                          color: modalSubColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${numberController.text.replaceAll(RegExp(r'\D'), '').length} / 11 digits',
                        style: TextStyle(
                          color: numberController.text.replaceAll(RegExp(r'\D'), '').length == 11
                              ? AppColors.primary
                              : modalSubColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: numberController,
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    onChanged: (_) => setSheetState(() {}),
                    style: TextStyle(color: modalTextColor, fontSize: 14, letterSpacing: 1.1),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '09XXXXXXXXX (11 digits)',
                      hintStyle: TextStyle(color: modalSubColor),
                      prefixIcon: Icon(Icons.phone_iphone_rounded, color: modalSubColor, size: 20),
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 4. PAYMENT QR CODE IMAGE
                  Text(
                    'Payment QR Code Image',
                    style: TextStyle(
                      color: modalSubColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (pickedQrFile != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code_rounded, color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickedQrFile!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: modalTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${(pickedQrFile!.size / 1024).toStringAsFixed(1)} KB • Ready to upload',
                                  style: TextStyle(color: modalSubColor, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => setSheetState(() => pickedQrFile = null),
                            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          setSheetState(() => pickedQrFile = result.files.first);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: inputBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.upload_file_outlined, size: 20),
                      label: Text('Upload $selectedProvider QR Code Image'),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // 5. DEFAULT CHECKBOX
                  CheckboxListTile(
                    value: isDefault,
                    onChanged: (val) => setSheetState(() => isDefault = val ?? false),
                    activeColor: AppColors.primary,
                    checkColor: Colors.black,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Set as default account',
                      style: TextStyle(
                        color: modalTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 20),

                  // 6. SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final number = numberController.text.replaceAll(RegExp(r'\D'), '').trim();

                              if (name.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter your recipient / account name.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              if (number.length != 11) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Account number must be exactly 11 digits (e.g. 09171234567).'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isSaving = true);
                              try {
                                String? qrUrl;
                                if (pickedQrFile != null && pickedQrFile!.bytes != null) {
                                  qrUrl = await _payoutMethodService.uploadQrCode(
                                    userId: userId,
                                    bytes: pickedQrFile!.bytes!,
                                    extension: pickedQrFile!.extension ?? 'jpg',
                                  );
                                }

                                await _payoutMethodService.savePayoutMethod(
                                  userId: userId,
                                  provider: selectedProvider,
                                  accountName: name,
                                  accountNumber: number,
                                  qrCodeUrl: qrUrl,
                                  isDefault: isDefault,
                                );

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                await _refreshPayoutMethods();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$selectedProvider account linked successfully!'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Error linking account: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text(
                              'Save Account Details',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showQrCodePreviewModal(BuildContext context, PayoutMethod method) {
    final isDark = widget.isDarkMode;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF132235) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          color: _providerColor(method.provider),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${method.provider} QR Code',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${method.accountName} • ${_formatAccountNumber(method.accountNumber)}',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (method.qrCodeUrl != null && method.qrCodeUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: OptimizedNetworkImage(
                        imageUrl: method.qrCodeUrl!,
                        height: 240,
                        width: 240,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 180,
                    alignment: Alignment.center,
                    child: const Text('No QR Code available', style: TextStyle(color: Colors.grey)),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
