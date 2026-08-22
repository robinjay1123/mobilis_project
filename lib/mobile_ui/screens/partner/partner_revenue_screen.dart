import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/booking_settlement_service.dart';
import '../../../services/payout_method_service.dart';
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
  late Future<List<Map<String, dynamic>>> _payoutsFuture;
  late Future<List<PayoutMethod>> _payoutMethodsFuture;
  static const List<String> _periodOptions = ['Day', 'Week', 'Month', 'Year'];

  @override
  void initState() {
    super.initState();
    _payoutsFuture = _fetchPayouts();
    _payoutMethodsFuture = _fetchPayoutMethods();
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
              onRefresh: _refreshPayouts,
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
                                text: 'Mobilis',
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
                  const SizedBox(height: 32),
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
                  _buildSectionHeader('Earnings Breakdown', action: 'View All'),
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

  Widget _buildSectionHeader(String title, {required String action, VoidCallback? onActionTap}) {
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

  Widget _buildEarningRow(Map<String, dynamic> payout) {
    final booking = _bookingForPayout(payout);
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleName = '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}'
        .trim();
    final gross = (payout['gross_amount'] as num?)?.toDouble() ?? 0;
    final deductions = (payout['deductions'] as num?)?.toDouble() ?? 0;
    final net = (payout['net_amount'] as num?)?.toDouble() ?? 0;

    return Container(
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
                  'Gross ${_currency(gross)}  -  Commission ${_currency(deductions)}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${_currency(net)}',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
