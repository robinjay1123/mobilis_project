import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../services/booking_settlement_service.dart';
import '../../../services/payout_method_service.dart';
import '../../../services/operator_remittance_service.dart';
import '../../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/optimized_network_image.dart';

class PartnerRevenueScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final List<Map<String, dynamic>> bookings;
  final int completedTrips;
  final double recordedTotalEarnings;

  const PartnerRevenueScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    required this.bookings,
    required this.completedTrips,
    required this.recordedTotalEarnings,
  });

  @override
  State<PartnerRevenueScreen> createState() => _PartnerRevenueScreenState();
}

class _PartnerRevenueScreenState extends State<PartnerRevenueScreen> {
  final BookingSettlementService _settlementService =
      BookingSettlementService();
  final PayoutMethodService _payoutMethodService = PayoutMethodService();
  String _selectedPeriod = 'Month';
  int _selectedRevenueTab = 0; // 0: Earnings & Payouts, 1: Platform Remittances
  String _selectedRemittanceFilter = 'all';
  late Future<List<Map<String, dynamic>>> _payoutsFuture;
  late Future<List<PayoutMethod>> _payoutMethodsFuture;
  late Future<List<OperatorRemittanceModel>> _remittancesFuture;
  static const List<String> _periodOptions = ['Day', 'Week', 'Month', 'Year'];

  @override
  void initState() {
    super.initState();
    _payoutsFuture = _fetchPayouts();
    _payoutMethodsFuture = _fetchPayoutMethods();
    _remittancesFuture = _fetchRemittances();
  }

  Future<List<OperatorRemittanceModel>> _fetchRemittances() {
    return OperatorRemittanceService().getRemittances(operatorId: widget.partnerId);
  }

  Future<void> _refreshRemittances() async {
    final req = _fetchRemittances();
    setState(() => _remittancesFuture = req);
    await req;
  }

  Future<List<PayoutMethod>> _fetchPayoutMethods() {
    return _payoutMethodService.getPayoutMethods(widget.partnerId);
  }

  Future<void> _refreshPayoutMethods() async {
    final req = _fetchPayoutMethods();
    setState(() => _payoutMethodsFuture = req);
    await req;
  }

  Future<List<Map<String, dynamic>>> _fetchPayouts() {
    return _settlementService.getReleasedPayoutsForUser(
      userId: widget.partnerId,
      recipientRole: 'partner',
    );
  }

  Future<void> _refreshPayouts() async {
    final request = _fetchPayouts();
    setState(() => _payoutsFuture = request);
    await request;
  }

  @override
  Widget build(BuildContext context) {
    final completedBookings = widget.bookings
        .where(
          (booking) =>
              (booking['status']?.toString().toLowerCase() ?? '') ==
              'completed',
        )
        .where(_isWithinSelectedPeriod)
        .toList();
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _payoutsFuture,
          builder: (context, snapshot) {
            final payouts = (snapshot.data ?? const <Map<String, dynamic>>[])
                .where(_isPayoutWithinSelectedPeriod)
                .toList();
            final totalRevenue = payouts.fold<double>(
              0,
              (sum, payout) =>
                  sum + ((payout['net_amount'] as num?)?.toDouble() ?? 0),
            );
            final tripCount = completedBookings.length;
            final averageTrip = payouts.isEmpty
                ? 0.0
                : totalRevenue / payouts.length;
            final pendingSettlementCount = (tripCount - payouts.length).clamp(
              0,
              tripCount,
            );

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await _refreshPayouts();
                await _refreshRemittances();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'Mobilis ',
                            children: [
                              TextSpan(
                                text: 'Partner Hub',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(widget.partnerName),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildSubTabSelector(),
                  const SizedBox(height: 22),
                  if (_selectedRevenueTab == 0) ...[
                    Row(
                      children: [
                      const Expanded(
                        child: Text(
                          'Analytics',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _buildPeriodDropdown(),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildMetricCard(
                    label: 'Total Revenue',
                    value: snapshot.connectionState == ConnectionState.waiting
                        ? 'Loading...'
                        : _currency(totalRevenue),
                    subtext: payouts.isEmpty
                        ? 'No revenue for this ${_selectedPeriod.toLowerCase()}'
                        : 'Net released earnings this ${_selectedPeriod.toLowerCase()}',
                    icon: Icons.payments_outlined,
                  ),
                  const SizedBox(height: 24),
                  _buildMetricCard(
                    label: 'Completed Trips',
                    value: '$tripCount',
                    subtext: tripCount == 0
                        ? 'No completed trips yet'
                        : pendingSettlementCount > 0
                        ? '$pendingSettlementCount awaiting settlement'
                        : 'All trip earnings released',
                    icon: Icons.directions_car,
                  ),
                  const SizedBox(height: 24),
                  _buildMetricCard(
                    label: 'Avg per Trip',
                    value: _currency(averageTrip),
                    subtext: tripCount == 0
                        ? 'No average available yet'
                        : 'Based on completed trips',
                    icon: Icons.analytics_outlined,
                  ),
                  const SizedBox(height: 40),
                  _buildChartPlaceholder(),
                  const SizedBox(height: 30),
                  _buildSectionHeader(
                    'Linked Payout Methods',
                    action: 'Add New',
                    onActionTap: () => _showAddPayoutMethodModal(context),
                  ),
                  const SizedBox(height: 14),
                  _buildPayoutMethodsSection(),
                  const SizedBox(height: 34),
                  _buildSectionHeader('Disbursement History', action: null),
                  const SizedBox(height: 14),
                  if (snapshot.hasError)
                    _buildErrorPanel(snapshot.error)
                  else if (snapshot.connectionState == ConnectionState.waiting)
                    _buildLoadingPanel()
                  else if (payouts.isEmpty)
                    _buildEmptyPanel(
                      icon: Icons.receipt_long_outlined,
                      text: pendingSettlementCount > 0
                          ? 'Completed trip earnings are awaiting settlement.'
                          : 'No completed trip earnings yet.',
                    )
                  else
                    ...payouts.map(_buildEarningRow),
                  ] else ...[
                    _buildPlatformRemittancesSection(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingPanel() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }

  Widget _buildErrorPanel(Object? error) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF071D31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Earnings could not be loaded. Pull down to try again.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          IconButton(
            onPressed: _refreshPayouts,
            icon: const Icon(Icons.refresh, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          dropdownColor: AppColors.darkBgSecondary,
          iconEnabledColor: AppColors.primary,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
          items: _periodOptions
              .map(
                (period) =>
                    DropdownMenuItem(value: period, child: Text(period)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedPeriod = value);
          },
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF071D31),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtext,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: AppColors.primary, size: 24),
        ],
      ),
    );
  }

  Widget _buildChartPlaceholder() {
    return Container(
      height: 256,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF071D31),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_selectedPeriod Performance',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Revenue Overview',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _LegendDot(color: AppColors.primary, label: 'Gross'),
              SizedBox(width: 10),
              _LegendDot(color: AppColors.textSecondary, label: 'Net'),
            ],
          ),
          const Expanded(
            child: Center(
              child: Text(
                'No chart data yet',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['W1', 'W2', 'W3', 'W4', 'W5', 'W6']
                .map(
                  (week) => Text(
                    week,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? action, VoidCallback? onActionTap}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              action,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyPanel({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF071D31),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutMethodsSection() {
    return FutureBuilder<List<PayoutMethod>>(
      future: _payoutMethodsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }

        final methods = snapshot.data ?? const <PayoutMethod>[];

        if (methods.isEmpty) {
          return Column(
            children: [
              _buildEmptyPanel(
                icon: Icons.account_balance_wallet_outlined,
                text: 'No linked payout methods yet.',
              ),
              const SizedBox(height: 14),
              _buildDashedButton(),
            ],
          );
        }

        return Column(
          children: [
            ...methods.map((method) => _buildPayoutMethodCard(method)),
            const SizedBox(height: 10),
            _buildDashedButton(label: '+ Link Another Account'),
          ],
        );
      },
    );
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

  Widget _buildPayoutMethodCard(PayoutMethod method) {
    final color = _providerColor(method.provider);
    final hasQr = method.qrCodeUrl != null && method.qrCodeUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF071D31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: method.isDefault
              ? color.withValues(alpha: 0.6)
              : AppColors.borderColor,
          width: method.isDefault ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Provider Logo Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      method.provider,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (method.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Text(
                          'DEFAULT',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  method.accountName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  method.accountNumber,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (hasQr)
            IconButton(
              tooltip: 'View QR Code',
              onPressed: () => _showQrCodePreviewModal(context, method),
              icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
            color: AppColors.darkBgSecondary,
            onSelected: (action) async {
              if (action == 'default') {
                await _payoutMethodService.setDefault(
                  widget.partnerId,
                  method.id,
                );
                await _refreshPayoutMethods();
              } else if (action == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.darkBgSecondary,
                    title: const Text('Remove Payout Method', style: TextStyle(color: Colors.white, fontSize: 16)),
                    content: Text(
                      'Are you sure you want to remove ${method.provider} (${method.accountNumber})?',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _payoutMethodService.deletePayoutMethod(
                    widget.partnerId,
                    method.id,
                  );
                  await _refreshPayoutMethods();
                }
              }
            },
            itemBuilder: (ctx) => [
              if (!method.isDefault)
                const PopupMenuItem(
                  value: 'default',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Set as Default', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashedButton({String label = 'Link New Account'}) {
    return InkWell(
      onTap: () => _showAddPayoutMethodModal(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPayoutMethodModal(BuildContext context) async {
    String selectedProvider = 'GCash';
    final nameController = TextEditingController(text: widget.partnerName);
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
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.add_card_rounded, color: AppColors.primary, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Link Payout Method',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select provider and provide your 11-digit account number and QR code for disbursements.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 18),

                  // 1. PROVIDER SELECTOR (GCash / Maya / MariBank / GoTyme only)
                  const Text(
                    'Payment Provider',
                    style: TextStyle(
                      color: AppColors.textSecondary,
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
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: const Color(0xFF071D31),
                        side: BorderSide(
                          color: isSelected ? color : AppColors.borderColor,
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

                  // 2. ACCOUNT NAME
                  const Text(
                    'Account Name',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Juan Dela Cruz',
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: const Color(0xFF071D31),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. ACCOUNT NUMBER (STRICT 11 DIGITS)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Account / Mobile Number',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${numberController.text.replaceAll(RegExp(r'\\D'), '').length} / 11 digits',
                        style: TextStyle(
                          color: numberController.text.replaceAll(RegExp(r'\\D'), '').length == 11
                              ? AppColors.primary
                              : AppColors.textTertiary,
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
                    style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1.1),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '09XXXXXXXXX (11 digits)',
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: const Color(0xFF071D31),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 4. PAYMENT QR CODE IMAGE
                  const Text(
                    'Payment QR Code (Optional)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (pickedQrFile != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF071D31),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
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
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${(pickedQrFile!.size / 1024).toStringAsFixed(1)} KB • Ready to upload',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
                        side: const BorderSide(color: AppColors.borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
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
                    title: const Text(
                      'Set as default payout account',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
                              final number = numberController.text.replaceAll(RegExp(r'\\D'), '').trim();

                              if (name.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter your account name.'),
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
                                    userId: widget.partnerId,
                                    bytes: pickedQrFile!.bytes!,
                                    extension: pickedQrFile!.extension ?? 'jpg',
                                  );
                                }

                                await _payoutMethodService.savePayoutMethod(
                                  userId: widget.partnerId,
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
                                      content: Text('$selectedProvider payout account linked successfully!'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Error linking payout account: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text(
                              'Save Payout Account',
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
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, color: _providerColor(method.provider), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '${method.provider} QR Code',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${method.accountName} • ${method.accountNumber}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (method.qrCodeUrl != null && method.qrCodeUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    child: OptimizedNetworkImage(
                      imageUrl: method.qrCodeUrl!,
                      fit: BoxFit.contain,
                      width: 280,
                      height: 280,
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No QR Code available', style: TextStyle(color: Colors.grey)),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDisbursementReceiptDialog(
    BuildContext context,
    Map<String, dynamic> payout,
  ) {
    final booking = _bookingForPayout(payout);
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleName =
        '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}'.trim();
    final gross = (payout['gross_amount'] as num?)?.toDouble() ?? 0;
    final deductions = (payout['deductions'] as num?)?.toDouble() ?? 0;
    final net = (payout['net_amount'] as num?)?.toDouble() ?? 0;
    final releasedAt = payout['released_at']?.toString();
    final bookingId = payout['booking_id']?.toString() ?? '—';
    final metadata = payout['metadata'] as Map<String, dynamic>? ?? {};
    final commissionRate =
        (metadata['commission_rate'] as num?)?.toInt() ?? 5;
    final depositDeduction =
        (metadata['security_deposit_deduction'] as num?)?.toDouble() ?? 0;

    final paymentMethod = metadata['payment_method']?.toString() ??
        payout['method']?.toString() ??
        booking['partner_payout_method']?.toString() ??
        'GCash';
    final refNumber = metadata['reference_number']?.toString() ??
        payout['reference_number']?.toString() ??
        booking['partner_payout_ref']?.toString() ??
        '—';
    final receiptUrl = metadata['receipt_url']?.toString() ??
        payout['receipt_url']?.toString() ??
        booking['partner_payout_receipt_url']?.toString();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF071D31),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      AppColors.primary.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Disbursement Receipt',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            vehicleName.isEmpty
                                ? 'Booking #${bookingId.substring(0, bookingId.length.clamp(0, 8))}'
                                : vehicleName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              // ── Body ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: [
                    _receiptRow(
                      'Release Date',
                      _formatDateTime(releasedAt),
                      icon: Icons.calendar_today_outlined,
                    ),
                    _receiptDivider(),
                    _receiptRow(
                      'Booking ID',
                      '#${bookingId.substring(0, bookingId.length.clamp(0, 8)).toUpperCase()}',
                      icon: Icons.confirmation_number_outlined,
                    ),
                    _receiptDivider(),
                    _receiptRow(
                      'Gross Amount',
                      _currency(gross),
                      icon: Icons.attach_money_rounded,
                    ),
                    if (commissionRate > 0) ...[
                      _receiptDivider(),
                      _receiptRow(
                        'PSDC Commission ($commissionRate%)',
                        '− ${_currency(deductions)}',
                        valueColor: AppColors.error.withValues(alpha: 0.85),
                        icon: Icons.percent_rounded,
                      ),
                    ],
                    if (depositDeduction > 0) ...[
                      _receiptDivider(),
                      _receiptRow(
                        'Damage Compensation (From Deposit)',
                        '+ ${_currency(depositDeduction)}',
                        valueColor: AppColors.success.withValues(alpha: 0.85),
                        icon: Icons.security_rounded,
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Net amount highlight
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Net Disbursed',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _currency(net),
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _receiptRow(
                      'Payment Method',
                      paymentMethod,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    _receiptDivider(),
                    _receiptRow(
                      'Reference No.',
                      refNumber,
                      icon: Icons.tag_rounded,
                    ),
                    if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                      _receiptDivider(),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.receipt_rounded, color: AppColors.textTertiary, size: 16),
                          const SizedBox(width: 8),
                          const Text('Transfer Proof', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: InteractiveViewer(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(receiptUrl, fit: BoxFit.contain),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Image.network(receiptUrl, width: 64, height: 64, fit: BoxFit.cover),
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Close Receipt',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.textTertiary, size: 16),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptDivider() =>
      Divider(color: AppColors.borderColor.withValues(alpha: 0.5), height: 1);

  Widget _buildEarningRow(Map<String, dynamic> payout) {
    final booking = _bookingForPayout(payout);
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleName = '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}'
        .trim();
    final gross = (payout['gross_amount'] as num?)?.toDouble() ?? 0;
    final deductions = (payout['deductions'] as num?)?.toDouble() ?? 0;
    final net = (payout['net_amount'] as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: () => _showDisbursementReceiptDialog(context, payout),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF071D31),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF06233A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.directions_car, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicleName.isEmpty ? 'Completed Trip' : vehicleName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _formatDateTime(
                      payout['released_at']?.toString() ??
                          booking['completed_at']?.toString(),
                    ),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Gross ${_currency(gross)}  •  Commission ${_currency(deductions)}',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${_currency(net)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _bookingForPayout(Map<String, dynamic> payout) {
    final bookingId = payout['booking_id']?.toString();
    for (final booking in widget.bookings) {
      if (booking['id']?.toString() == bookingId) return booking;
    }
    return <String, dynamic>{};
  }

  static final NumberFormat _money = NumberFormat('#,##0.00');

  static String _currency(double value) => 'PHP ${_money.format(value)}';

  bool _isPayoutWithinSelectedPeriod(Map<String, dynamic> payout) {
    final date = DateTime.tryParse(payout['released_at']?.toString() ?? '');
    return date != null && _isDateWithinSelectedPeriod(date);
  }

  bool _isWithinSelectedPeriod(Map<String, dynamic> booking) {
    final date = _bookingDate(booking);
    if (date == null) return false;
    return _isDateWithinSelectedPeriod(date);
  }

  bool _isDateWithinSelectedPeriod(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    late final DateTime start;
    switch (_selectedPeriod) {
      case 'Day':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        break;
      case 'Year':
        start = DateTime(now.year);
        break;
      case 'Month':
      default:
        start = DateTime(now.year, now.month);
    }
    return !local.isBefore(start) && !local.isAfter(now);
  }

  DateTime? _bookingDate(Map<String, dynamic> booking) {
    for (final key in [
      'completed_at',
      'updated_at',
      'end_at',
      'end_date',
      'created_at',
    ]) {
      final parsed = DateTime.tryParse(booking[key]?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String _formatDateTime(String? value) {
    if (value == null || value.isEmpty) return 'No date';
    try {
      final date = DateTime.parse(value);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour = date.hour == 0
          ? 12
          : date.hour > 12
          ? date.hour - 12
          : date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${months[date.month - 1]} ${date.day}, ${date.year} - $hour:$minute $period';
    } catch (_) {
      return value;
    }
  }

  Widget _buildSubTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRevenueTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedRevenueTab == 0
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: _selectedRevenueTab == 0
                          ? Colors.black
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Earnings & Payouts',
                      style: TextStyle(
                        color: _selectedRevenueTab == 0
                            ? Colors.black
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRevenueTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedRevenueTab == 1
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.price_check_rounded,
                      size: 16,
                      color: _selectedRevenueTab == 1
                          ? Colors.black
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Platform Remittances',
                      style: TextStyle(
                        color: _selectedRevenueTab == 1
                            ? Colors.black
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformRemittancesSection() {
    return FutureBuilder<List<OperatorRemittanceModel>>(
      future: _remittancesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final remittances = snapshot.data ?? <OperatorRemittanceModel>[];
        final remittanceByBooking = <String, OperatorRemittanceModel>{
          for (final r in remittances) r.bookingId: r,
        };

        final completedBookings = widget.bookings.where((b) {
          final s = (b['status']?.toString() ?? '').toLowerCase().trim();
          return s == 'completed' || s == 'returned';
        }).toList();

        double totalRemitted = 0.0;
        double pendingReview = 0.0;
        double dueToRemit = 0.0;
        int remittedCount = 0;
        int pendingCount = 0;
        int dueCount = 0;
        int rejectedCount = 0;

        for (final booking in completedBookings) {
          final bookingId = booking['id']?.toString() ?? '';
          final rem = remittanceByBooking[bookingId];
          final gross = _getBookingRentalGross(booking);
          final commission = rem?.commissionAmount ?? (gross * 0.05);
          final status = rem?.status ?? (booking['operator_remittance_status']?.toString().toLowerCase() ?? 'unremitted');

          if (status == 'remitted') {
            totalRemitted += commission;
            remittedCount++;
          } else if (status == 'pending_review') {
            pendingReview += commission;
            pendingCount++;
          } else if (status == 'rejected') {
            dueToRemit += commission;
            rejectedCount++;
            dueCount++;
          } else {
            dueToRemit += commission;
            dueCount++;
          }
        }

        final filteredBookings = completedBookings.where((booking) {
          final bookingId = booking['id']?.toString() ?? '';
          final rem = remittanceByBooking[bookingId];
          final status = rem?.status ?? (booking['operator_remittance_status']?.toString().toLowerCase() ?? 'unremitted');

          switch (_selectedRemittanceFilter) {
            case 'due':
              return status == 'unremitted' || status == 'rejected';
            case 'pending_review':
              return status == 'pending_review';
            case 'remitted':
              return status == 'remitted';
            case 'rejected':
              return status == 'rejected';
            case 'all':
            default:
              return true;
          }
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Platform Commission Remittances',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _refreshRemittances,
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
                  tooltip: 'Refresh Remittances',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRemittanceMetricRow(
              totalRemitted: totalRemitted,
              remittedCount: remittedCount,
              pendingReview: pendingReview,
              pendingCount: pendingCount,
              dueToRemit: dueToRemit,
              dueCount: dueCount,
            ),
            const SizedBox(height: 20),
            _buildRemittancePolicyBanner(),
            const SizedBox(height: 20),
            _buildRemittanceFilterChips(
              allCount: completedBookings.length,
              dueCount: dueCount,
              pendingCount: pendingCount,
              remittedCount: remittedCount,
              rejectedCount: rejectedCount,
            ),
            const SizedBox(height: 18),
            if (filteredBookings.isEmpty)
              _buildEmptyPanel(
                icon: Icons.check_circle_outline_rounded,
                text: _selectedRemittanceFilter == 'all'
                    ? 'No completed bookings yet. Once a rental is completed, its 5% platform commission will appear here ready for remittance.'
                    : 'No bookings found matching "$_selectedRemittanceFilter".',
              )
            else
              ...filteredBookings.map((b) {
                final bId = b['id']?.toString() ?? '';
                final rem = remittanceByBooking[bId];
                return _buildOperatorRemittanceCard(b, rem);
              }),
          ],
        );
      },
    );
  }

  Widget _buildRemittanceMetricRow({
    required double totalRemitted,
    required int remittedCount,
    required double pendingReview,
    required int pendingCount,
    required double dueToRemit,
    required int dueCount,
  }) {
    return Column(
      children: [
        _buildMetricCard(
          label: 'Total Platform Commission Remitted',
          value: _currency(totalRemitted),
          subtext: '$remittedCount booking${remittedCount == 1 ? '' : 's'} verified & remitted to PSDC',
          icon: Icons.check_circle_rounded,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkBgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade400, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Under Review',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currency(pendingReview),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pendingCount pending admin check',
                      style: TextStyle(color: Colors.amber.shade300, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkBgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Due to Remit',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currency(dueToRemit),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dueCount trip${dueCount == 1 ? '' : 's'} awaiting proof',
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRemittancePolicyBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF041E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operator Remittance & Proof Guidelines',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '• You retain 95% of each rental. The platform 5% commission is remitted to PSDC after the booking is completed.\n• For Cash Handover: A clear photo of the actual cash bills is strictly required.\n• For Digital Transfer: A clear screenshot of the GCash / Bank transfer receipt is strictly required.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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

  Widget _buildRemittanceFilterChips({
    required int allCount,
    required int dueCount,
    required int pendingCount,
    required int remittedCount,
    required int rejectedCount,
  }) {
    final filters = [
      {'key': 'all', 'label': 'All', 'count': allCount},
      {'key': 'due', 'label': 'Due to Remit', 'count': dueCount},
      {'key': 'pending_review', 'label': 'Under Review', 'count': pendingCount},
      {'key': 'remitted', 'label': 'Remitted', 'count': remittedCount},
      if (rejectedCount > 0) {'key': 'rejected', 'label': 'Rejected', 'count': rejectedCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedRemittanceFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              label: Text('${f['label']} (${f['count']})'),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
              backgroundColor: AppColors.darkBgSecondary,
              selectedColor: AppColors.primary,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.borderColor,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (_) {
                setState(() => _selectedRemittanceFilter = f['key'] as String);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOperatorRemittanceCard(
    Map<String, dynamic> booking,
    OperatorRemittanceModel? remittance,
  ) {
    final bookingRef = _getBookingReference(booking);
    final vehicleTitle = _getBookingVehicleName(booking);
    final gross = _getBookingRentalGross(booking);
    final operatorShare = gross * 0.95;
    final commission = remittance?.commissionAmount ?? (gross * 0.05);
    final status = remittance?.status ?? (booking['operator_remittance_status']?.toString().toLowerCase() ?? 'unremitted');
    final completedDate = _bookingDate(booking);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'remitted'
              ? const Color(0xFF10B981).withOpacity(0.35)
              : status == 'pending_review'
              ? Colors.amber.withOpacity(0.35)
              : status == 'rejected'
              ? AppColors.error.withOpacity(0.4)
              : AppColors.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bookingRef,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (completedDate != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, yyyy').format(completedDate),
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                    ),
                  ],
                ],
              ),
              _buildRemittanceStatusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.directions_car_rounded, color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  vehicleTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rental Gross', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(_currency(gross), style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(width: 1, height: 26, color: AppColors.borderColor),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Operator (95%)', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(_currency(operatorShare), style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(width: 1, height: 26, color: AppColors.borderColor),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Platform (5%)', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(_currency(commission), style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
          if (remittance != null && remittance.proofImageUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showProofPreviewDialog(remittance, bookingRef, vehicleTitle),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Image.network(
                            remittance.proofImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.darkBg,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, color: AppColors.textTertiary, size: 24),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.25),
                            child: const Center(
                              child: Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            remittance.remittanceType == 'cash' ? Icons.payments_rounded : Icons.phone_android_rounded,
                            size: 14,
                            color: remittance.remittanceType == 'cash' ? Colors.greenAccent : Colors.lightBlueAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            remittance.remittanceType == 'cash' ? 'Cash Handover' : 'Digital Transfer',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (remittance.referenceNumber.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Ref: ${remittance.referenceNumber}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                      if (remittance.operatorNotes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '"${remittance.operatorNotes}"',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (status == 'rejected' && remittance?.rejectionReason != null && remittance!.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rejection Reason from Admin:',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Text(
                          remittance.rejectionReason!,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (status == 'remitted' && remittance?.reviewedAt != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                const SizedBox(width: 4),
                Text(
                  'Verified by Admin on ${DateFormat('MMM d, yyyy h:mm a').format(remittance!.reviewedAt!.toLocal())}',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (status == 'unremitted' || status == 'rejected')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showSubmitRemittanceModal(booking, remittance),
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(
                  status == 'rejected'
                      ? 'Re-upload Proof & Resubmit (₱${commission.toStringAsFixed(2)})'
                      : 'Remit Platform Commission (₱${commission.toStringAsFixed(2)})',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          else if (status == 'pending_review')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: remittance != null
                    ? () => _showProofPreviewDialog(remittance, bookingRef, vehicleTitle)
                    : null,
                icon: const Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.amber),
                label: const Text('Under Review • View Submitted Proof'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: BorderSide(color: Colors.amber.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          else if (status == 'remitted')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: remittance != null
                    ? () => _showProofPreviewDialog(remittance, bookingRef, vehicleTitle)
                    : null,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                label: const Text('Confirmed Remitted • View Receipt'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRemittanceStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case 'remitted':
        bg = const Color(0xFF10B981).withOpacity(0.15);
        fg = const Color(0xFF10B981);
        text = 'Remitted & Verified';
        icon = Icons.check_circle_rounded;
        break;
      case 'pending_review':
        bg = Colors.amber.withOpacity(0.15);
        fg = Colors.amber.shade400;
        text = 'Under Review';
        icon = Icons.hourglass_top_rounded;
        break;
      case 'rejected':
        bg = AppColors.error.withOpacity(0.15);
        fg = AppColors.error;
        text = 'Rejected';
        icon = Icons.error_outline_rounded;
        break;
      case 'unremitted':
      default:
        bg = Colors.orangeAccent.withOpacity(0.15);
        fg = Colors.orangeAccent;
        text = 'Due to Remit';
        icon = Icons.priority_high_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  double _getBookingRentalGross(Map<String, dynamic> booking) {
    for (final key in ['rental_gross_amount', 'total_price', 'total_amount', 'grand_total', 'amount']) {
      final val = (booking[key] as num?)?.toDouble() ?? double.tryParse(booking[key]?.toString() ?? '');
      if (val != null && val > 0) return val;
    }
    return 0.0;
  }

  String _getBookingVehicleName(Map<String, dynamic> booking) {
    if (booking['vehicle_name'] != null && booking['vehicle_name'].toString().isNotEmpty) {
      return booking['vehicle_name'].toString();
    }
    if (booking['vehicles'] is Map) {
      final v = booking['vehicles'] as Map;
      final make = v['make']?.toString() ?? '';
      final model = v['model']?.toString() ?? '';
      final year = v['year']?.toString() ?? '';
      final combined = '$year $make $model'.trim();
      if (combined.isNotEmpty) return combined;
      if (v['title'] != null) return v['title'].toString();
      if (v['name'] != null) return v['name'].toString();
    }
    final vehId = booking['vehicle_id']?.toString() ?? '';
    return vehId.isNotEmpty ? 'Vehicle #${vehId.substring(0, vehId.length > 6 ? 6 : vehId.length)}' : 'Rental Vehicle';
  }

  String _getBookingReference(Map<String, dynamic> booking) {
    final ref = booking['booking_reference']?.toString();
    if (ref != null && ref.isNotEmpty) return ref;
    final id = booking['id']?.toString() ?? '';
    if (id.length > 8) return 'BK-${id.substring(0, 8).toUpperCase()}';
    return id.isNotEmpty ? 'BK-$id' : 'BK-N/A';
  }

  void _showProofPreviewDialog(
    OperatorRemittanceModel remittance,
    String bookingRef,
    String vehicleTitle,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.darkBgSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Icon(
                      remittance.remittanceType == 'cash'
                          ? Icons.payments_rounded
                          : Icons.phone_android_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            remittance.remittanceType == 'cash'
                                ? 'Cash Handover Proof (Money Photo)'
                                : 'Digital Transfer Proof (Receipt)',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$bookingRef • $vehicleTitle',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.borderColor, height: 1),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 420),
                  color: Colors.black,
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      remittance.proofImageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'Could not load proof image.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(color: AppColors.borderColor, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Commission: ${_currency(remittance.commissionAmount)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        _buildRemittanceStatusBadge(remittance.status),
                      ],
                    ),
                    if (remittance.referenceNumber.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Reference No: ${remittance.referenceNumber}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                    if (remittance.operatorNotes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Note: ${remittance.operatorNotes}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                    if (remittance.rejectionReason != null && remittance.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Rejection Reason: ${remittance.rejectionReason}',
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubmitRemittanceModal(
    Map<String, dynamic> booking, [
    OperatorRemittanceModel? existingRemittance,
  ]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _RemittanceSubmissionSheet(
          booking: booking,
          existingRemittance: existingRemittance,
          operatorId: widget.partnerId,
          operatorName: widget.partnerName,
          onSubmitted: () {
            _refreshRemittances();
          },
        );
      },
    );
  }
}

class _RemittanceSubmissionSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final OperatorRemittanceModel? existingRemittance;
  final String operatorId;
  final String operatorName;
  final VoidCallback onSubmitted;

  const _RemittanceSubmissionSheet({
    required this.booking,
    this.existingRemittance,
    required this.operatorId,
    required this.operatorName,
    required this.onSubmitted,
  });

  @override
  State<_RemittanceSubmissionSheet> createState() => _RemittanceSubmissionSheetState();
}

class _RemittanceSubmissionSheetState extends State<_RemittanceSubmissionSheet> {
  final ImagePicker _picker = ImagePicker();
  late String _remittanceType;
  Uint8List? _imageBytes;
  String? _imageName;
  late final TextEditingController _refController;
  late final TextEditingController _notesController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _remittanceType = widget.existingRemittance?.remittanceType ?? 'digital';
    _refController = TextEditingController(text: widget.existingRemittance?.referenceNumber ?? '');
    _notesController = TextEditingController(text: widget.existingRemittance?.operatorNotes ?? '');
  }

  @override
  void dispose() {
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = file.name;
          _errorMessage = null;
        });
      }
    } catch (e) {
      try {
        final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
        if (result != null && result.files.isNotEmpty) {
          final f = result.files.first;
          if (f.bytes != null) {
            setState(() {
              _imageBytes = f.bytes;
              _imageName = f.name;
              _errorMessage = null;
            });
          }
        }
      } catch (err) {
        setState(() => _errorMessage = 'Failed to select image: $err');
      }
    }
  }

  Future<void> _handleSubmit() async {
    final hasExistingImage = widget.existingRemittance != null && widget.existingRemittance!.proofImageUrl.isNotEmpty;

    if (_imageBytes == null && !hasExistingImage) {
      setState(() {
        _errorMessage = _remittanceType == 'cash'
            ? 'A clear photo of the actual cash bills is strictly required by the admin.'
            : 'A photo or screenshot of the transaction receipt is strictly required by the admin.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final bookingId = widget.booking['id']?.toString() ?? '';
      final bookingRef = widget.booking['booking_reference']?.toString().isNotEmpty == true
          ? widget.booking['booking_reference'].toString()
          : (bookingId.length > 8 ? 'BK-${bookingId.substring(0, 8).toUpperCase()}' : 'BK-$bookingId');

      final gross = (widget.booking['rental_gross_amount'] as num?)?.toDouble() ??
          (widget.booking['total_price'] as num?)?.toDouble() ??
          (widget.booking['total_amount'] as num?)?.toDouble() ??
          (widget.booking['grand_total'] as num?)?.toDouble() ??
          0.0;
      final commissionAmount = widget.existingRemittance?.commissionAmount ?? (gross * 0.05);

      String vehicleName = widget.booking['vehicle_name']?.toString() ?? '';
      if (vehicleName.isEmpty && widget.booking['vehicles'] is Map) {
        final v = widget.booking['vehicles'] as Map;
        vehicleName = '${v['year'] ?? ''} ${v['make'] ?? ''} ${v['model'] ?? ''}'.trim();
      }
      if (vehicleName.isEmpty) vehicleName = 'Partner Vehicle';

      String proofUrl = widget.existingRemittance?.proofImageUrl ?? '';
      if (_imageBytes != null) {
        proofUrl = await OperatorRemittanceService().uploadRemittanceProof(
          bytes: _imageBytes!,
          fileName: _imageName ?? 'proof.jpg',
          bookingId: bookingId,
        );
      }

      await OperatorRemittanceService().submitRemittance(
        bookingId: bookingId,
        bookingReference: bookingRef,
        operatorId: widget.operatorId,
        operatorName: widget.operatorName,
        vehicleName: vehicleName,
        rentalGrossAmount: gross,
        commissionRate: 5.0,
        commissionAmount: commissionAmount,
        remittanceType: _remittanceType,
        proofImageUrl: proofUrl,
        referenceNumber: _refController.text.trim(),
        operatorNotes: _notesController.text.trim(),
      );

      widget.onSubmitted();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Remittance request for #$bookingRef submitted! The admin will review your proof.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to submit remittance: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bookingId = widget.booking['id']?.toString() ?? '';
    final bookingRef = widget.booking['booking_reference']?.toString().isNotEmpty == true
        ? widget.booking['booking_reference'].toString()
        : (bookingId.length > 8 ? 'BK-${bookingId.substring(0, 8).toUpperCase()}' : 'BK-$bookingId');

    final gross = (widget.booking['rental_gross_amount'] as num?)?.toDouble() ??
        (widget.booking['total_price'] as num?)?.toDouble() ??
        (widget.booking['total_amount'] as num?)?.toDouble() ??
        (widget.booking['grand_total'] as num?)?.toDouble() ??
        0.0;
    final commission = widget.existingRemittance?.commissionAmount ?? (gross * 0.05);

    final hasExistingImage = widget.existingRemittance != null && widget.existingRemittance!.proofImageUrl.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remit Platform Commission',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Booking #$bookingRef',
                      style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gross Rental',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₱${NumberFormat('#,##0.00').format(gross)}',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 28, color: AppColors.borderColor),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Platform Commission (5%)',
                              style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₱${NumberFormat('#,##0.00').format(commission)}',
                              style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Remittance Payment Method *',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _remittanceType = 'digital'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: _remittanceType == 'digital' ? AppColors.primary.withOpacity(0.15) : AppColors.darkBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _remittanceType == 'digital' ? AppColors.primary : AppColors.borderColor,
                                width: _remittanceType == 'digital' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.phone_android_rounded,
                                  color: _remittanceType == 'digital' ? AppColors.primary : AppColors.textSecondary,
                                  size: 22,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Digital Transfer',
                                  style: TextStyle(
                                    color: _remittanceType == 'digital' ? AppColors.primary : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'GCash / Bank',
                                  style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _remittanceType = 'cash'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: _remittanceType == 'cash' ? AppColors.primary.withOpacity(0.15) : AppColors.darkBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _remittanceType == 'cash' ? AppColors.primary : AppColors.borderColor,
                                width: _remittanceType == 'cash' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.payments_rounded,
                                  color: _remittanceType == 'cash' ? AppColors.primary : AppColors.textSecondary,
                                  size: 22,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Cash Handover',
                                  style: TextStyle(
                                    color: _remittanceType == 'cash' ? AppColors.primary : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Physical Money',
                                  style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _remittanceType == 'cash'
                        ? 'Photo of Actual Money Bills (MANDATORY) *'
                        : 'Screenshot of Transfer Receipt (MANDATORY) *',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _remittanceType == 'cash'
                        ? 'The admin strictly requires a clear photo of the physical cash bills being handed over.'
                        : 'Upload a clear screenshot of your GCash, Maya, or bank transfer receipt showing the amount and reference number.',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  if (_imageBytes != null) ...[
                    Container(
                      height: 170,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_imageBytes!, fit: BoxFit.contain),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                  onPressed: () => setState(() {
                                    _imageBytes = null;
                                    _imageName = null;
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _imageName ?? 'image_selected.jpg',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                        TextButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary),
                          label: const Text('Change Photo', style: TextStyle(color: AppColors.primary, fontSize: 11)),
                        ),
                      ],
                    ),
                  ] else if (hasExistingImage) ...[
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.existingRemittance!.proofImageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 16),
                            label: const Text('Take New Photo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 16),
                            label: const Text('Choose from Gallery'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.darkBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _errorMessage != null ? AppColors.error : AppColors.borderColor,
                          width: _errorMessage != null ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _remittanceType == 'cash' ? Icons.camera_alt_rounded : Icons.receipt_long_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _remittanceType == 'cash'
                                ? 'Take a clear photo of the actual money bills'
                                : 'Upload screenshot of digital payment receipt',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                label: const Text('Camera'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_rounded, size: 16),
                                label: const Text('Gallery'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(color: AppColors.borderColor),
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    _remittanceType == 'cash'
                        ? 'Envelope / Cash Receipt Note (Optional)'
                        : 'GCash / Bank Reference Number',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _refController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _remittanceType == 'cash' ? 'e.g., PSDC Handover Receipt #104' : 'e.g., GCash Ref 1002 9384 1928',
                      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.darkBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Notes for Admin (Optional)',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _remittanceType == 'cash' ? 'e.g., Handed cash to Sir Robin at PSDC office.' : 'e.g., Sent from 0917-xxx-xxxx to PSDC account.',
                      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.darkBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleSubmit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSubmitting ? 'Uploading Proof & Submitting...' : 'Submit Remittance for Admin Verification',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                elevation: 3,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
