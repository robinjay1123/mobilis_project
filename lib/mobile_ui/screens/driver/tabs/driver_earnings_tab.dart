part of '../driver_home_screen.dart';

// EARNINGS TAB
class _EarningsTab extends StatefulWidget {
  const _EarningsTab();

  @override
  State<_EarningsTab> createState() => __EarningsTabState();
}

class __EarningsTabState extends State<_EarningsTab> {
  late Future<double> earningsFuture;
  late Future<List<PayoutMethod>> payoutMethodsFuture;
  late Future<List<Map<String, dynamic>>> disbursementsFuture;
  final PayoutMethodService _payoutMethodService = PayoutMethodService();
  final BookingSettlementService _settlementService = BookingSettlementService();
  String _selectedPeriod = 'Month';
  static const List<String> _periodOptions = ['Day', 'Week', 'Month', 'Year'];
  RealtimeChannel? _earningsChannel;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
    _loadPayoutMethods();
    _loadDisbursements();
    _setupRealtimeEarningsListener();
  }

  @override
  void dispose() {
    _earningsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeEarningsListener() {
    final userId = AuthService().currentUser?.id ?? '';
    if (userId.isEmpty) return;
    _earningsChannel = Supabase.instance.client.realtime.channel('driver-earnings-tab-$userId');
    void onPayoutChange(PostgresChangePayload _) {
      if (!mounted) return;
      setState(() {
        _loadEarnings();
        _loadDisbursements();
      });
    }
    _earningsChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'booking_payouts',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'recipient_user_id', value: userId),
        callback: onPayoutChange,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'driver_earnings',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'driver_id', value: userId),
        callback: onPayoutChange,
      )
      .subscribe();
  }

  void _loadPayoutMethods() {
    final userId = AuthService().currentUser?.id ?? '';
    payoutMethodsFuture = _payoutMethodService.getPayoutMethods(userId);
  }

  void _loadDisbursements() {
    final userId = AuthService().currentUser?.id ?? '';
    if (userId.isEmpty) {
      disbursementsFuture = Future.value(const []);
      return;
    }
    disbursementsFuture = _settlementService.getReleasedPayoutsForUser(
      userId: userId,
      recipientRole: 'driver',
    );
  }

  Future<void> _refreshPayoutMethods() async {
    final userId = AuthService().currentUser?.id ?? '';
    final req = _payoutMethodService.getPayoutMethods(userId);
    setState(() => payoutMethodsFuture = req);
    await req;
  }

  Future<void> _refreshDisbursements() async {
    final userId = AuthService().currentUser?.id ?? '';
    if (userId.isEmpty) return;
    final req = _settlementService.getReleasedPayoutsForUser(
      userId: userId,
      recipientRole: 'driver',
    );
    setState(() => disbursementsFuture = req);
    await req;
  }

  DateTime _periodStart() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Day':
        return DateTime(now.year, now.month, now.day);
      case 'Week':
        return now.subtract(const Duration(days: 7));
      case 'Year':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  void _loadEarnings() {
    final authService = AuthService();
    final driverService = DriverService();
    if (authService.currentUser != null) {
      earningsFuture = driverService
          .getEarnings(
            authService.currentUser!.id,
            fromDate: _periodStart(),
            toDate: DateTime.now(),
          )
          .catchError((_) => 0.0);
    } else {
      earningsFuture = Future.value(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildRevenueView();
  }

  Widget _buildLegacyRevenueView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<double>(
            future: earningsFuture,
            builder: (context, snapshot) {
              final earnings = snapshot.data ?? 0.0;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earnings (Last 30 Days)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₱${formatAmount(earnings, decimalDigits: 2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Earnings History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                'No earnings history available',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueView() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          _refreshPayoutMethods(),
          _refreshDisbursements(),
        ]);
      },
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Revenue & Earnings',
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
        const SizedBox(height: 22),
        FutureBuilder<double>(
          future: earningsFuture,
          builder: (context, snapshot) {
            final earnings = snapshot.data ?? 0.0;
            return Column(
              children: [
                _buildMetricCard(
                  label: 'Total Revenue',
                  value: _currency(earnings),
                  subtext: earnings <= 0
                      ? 'No revenue for this ${_selectedPeriod.toLowerCase()}'
                      : 'Driver earnings this ${_selectedPeriod.toLowerCase()}',
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallMetricCard(
                        label: 'Completed Jobs',
                        value: '0',
                        icon: Icons.route_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSmallMetricCard(
                        label: 'Avg / Job',
                        value: _currency(0),
                        icon: Icons.analytics_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        _buildSectionHeader(
          'Linked Payout Methods',
          action: 'Add New',
          onActionTap: () => _showAddPayoutMethodModal(context),
        ),
        const SizedBox(height: 12),
        _buildPayoutMethodsSection(),
        const SizedBox(height: 26),
        _buildSectionHeader('Disbursement History', action: null),
        const SizedBox(height: 12),
        _buildDisbursementHistorySection(),
      ],
      ),
    );
  }

  Widget _buildDisbursementHistorySection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: disbursementsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MobilisSkeletonList(
            isDark: Theme.of(context).brightness == Brightness.dark,
            itemCount: 2,
            padding: EdgeInsets.zero,
          );
        }
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _driverCardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Could not load disbursement history.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _loadDisbursements()),
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                ),
              ],
            ),
          );
        }
        final payouts = snapshot.data ?? const [];
        if (payouts.isEmpty) {
          return _buildEmptyPanel(
            icon: Icons.receipt_long_outlined,
            text: 'No disbursements released yet.',
          );
        }
        return Column(
          children: payouts
              .map((p) => _buildDisbursementRow(p))
              .toList(),
        );
      },
    );
  }

  Widget _buildDisbursementRow(Map<String, dynamic> payout) {
    final gross = (payout['gross_amount'] as num?)?.toDouble() ?? 0;
    final deductions = (payout['deductions'] as num?)?.toDouble() ?? 0;
    final net = (payout['net_amount'] as num?)?.toDouble() ?? 0;
    final bookingId = payout['booking_id']?.toString() ?? '';
    final releasedAt = _formatDriverDate(payout['released_at']?.toString());

    return GestureDetector(
      onTap: () => _showDriverReceiptDialog(payout),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _driverCardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _driverBorderColor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: AppColors.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookingId.isEmpty
                        ? 'Trip Disbursement'
                        : 'Trip #${bookingId.substring(0, bookingId.length.clamp(0, 8)).toUpperCase()}',
                    style: TextStyle(
                      color: _driverPrimaryText(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    releasedAt,
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

  void _showDriverReceiptDialog(Map<String, dynamic> payout) {
    final gross = (payout['gross_amount'] as num?)?.toDouble() ?? 0;
    final deductions = (payout['deductions'] as num?)?.toDouble() ?? 0;
    final net = (payout['net_amount'] as num?)?.toDouble() ?? 0;
    final releasedAt = payout['released_at']?.toString();
    final bookingId = payout['booking_id']?.toString() ?? '—';
    final metadata = payout['metadata'] as Map<String, dynamic>? ?? {};
    final commissionRate = (metadata['commission_rate'] as num?)?.toInt() ?? 5;
    final paymentMethod = metadata['payment_method']?.toString() ??
        payout['method']?.toString() ??
        payout['payout_method']?.toString() ??
        'GCash';
    final refNumber = metadata['reference_number']?.toString() ??
        payout['reference_number']?.toString() ??
        payout['payout_ref']?.toString() ??
        '—';
    final receiptUrl = metadata['receipt_url']?.toString() ??
        payout['receipt_url']?.toString() ??
        payout['payout_receipt_url']?.toString();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: _driverCardColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _driverBorderColor(context)),
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
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.03),
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
                          Text(
                            'Disbursement Receipt',
                            style: TextStyle(
                              color: _driverPrimaryText(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Booking #${bookingId.substring(0, bookingId.length.clamp(0, 8)).toUpperCase()}',
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
                      icon: Icon(
                        Icons.close,
                        color: _driverSecondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Body ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: [
                    _driverReceiptRow(
                      'Release Date',
                      _formatDriverDate(releasedAt),
                      icon: Icons.calendar_today_outlined,
                    ),
                    _driverReceiptDivider(),
                    _driverReceiptRow(
                      'Booking ID',
                      '#${bookingId.substring(0, bookingId.length.clamp(0, 8)).toUpperCase()}',
                      icon: Icons.confirmation_number_outlined,
                    ),
                    _driverReceiptDivider(),
                    _driverReceiptRow(
                      'Trip Fee (Gross)',
                      _currency(gross),
                      icon: Icons.attach_money_rounded,
                    ),
                    _driverReceiptDivider(),
                    _driverReceiptRow(
                      'PSDC Commission ($commissionRate%)',
                      '− ${_currency(deductions)}',
                      valueColor: AppColors.error.withValues(alpha: 0.85),
                      icon: Icons.percent_rounded,
                    ),
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
                    _driverReceiptRow(
                      'Payment Method',
                      paymentMethod,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    _driverReceiptDivider(),
                    _driverReceiptRow(
                      'Reference No.',
                      refNumber,
                      icon: Icons.tag_rounded,
                    ),
                    if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                      _driverReceiptDivider(),
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

  Widget _driverReceiptRow(
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
            style: TextStyle(color: _driverSecondaryText(context), fontSize: 13),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? _driverPrimaryText(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverReceiptDivider() => Divider(
        color: _driverBorderColor(context).withValues(alpha: 0.6),
        height: 1,
      );

  String _formatDriverDate(String? value) {
    if (value == null || value.isEmpty) return 'No date';
    try {
      final date = DateTime.parse(value).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final hour = date.hour == 0
          ? 12
          : date.hour > 12
          ? date.hour - 12
          : date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${months[date.month - 1]} ${date.day}, ${date.year} – $hour:$minute $period';
    } catch (_) {
      return value;
    }
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _driverBorderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          dropdownColor: _driverCardColor(context),
          iconEnabledColor: AppColors.primary,
          style: TextStyle(
            color: _driverPrimaryText(context),
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
            setState(() {
              _selectedPeriod = value;
              _loadEarnings();
            });
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
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _driverBorderColor(context)),
        boxShadow: AppColors.cardShadowOf(context),
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
                  style: TextStyle(color: _driverSecondaryText(context)),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    color: _driverPrimaryText(context),
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
          Icon(icon, color: AppColors.primary, size: 26),
        ],
      ),
    );
  }

  Widget _buildSmallMetricCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _driverBorderColor(context)),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: _driverSecondaryText(context),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _driverPrimaryText(context),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    String? action,
    VoidCallback? onActionTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _driverPrimaryText(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (action != null)
          InkWell(
            onTap: onActionTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Text(
                action,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPayoutMethodsSection() {
    return FutureBuilder<List<PayoutMethod>>(
      future: payoutMethodsFuture,
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
              const SizedBox(height: 12),
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
    final userId = AuthService().currentUser?.id ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: method.isDefault
              ? color.withValues(alpha: 0.6)
              : _driverBorderColor(context),
          width: method.isDefault ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
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
                  style: TextStyle(
                    color: _driverPrimaryText(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  method.accountNumber,
                  style: TextStyle(
                    color: _driverSecondaryText(context),
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
            icon: Icon(Icons.more_vert, color: _driverSecondaryText(context), size: 20),
            color: _driverCardColor(context),
            onSelected: (action) async {
              if (action == 'default') {
                await _payoutMethodService.setDefault(userId, method.id);
                await _refreshPayoutMethods();
              } else if (action == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _driverCardColor(context),
                    title: Text('Remove Payout Method', style: TextStyle(color: _driverPrimaryText(context), fontSize: 16)),
                    content: Text(
                      'Are you sure you want to remove ${method.provider} (${method.accountNumber})?',
                      style: TextStyle(color: _driverSecondaryText(context), fontSize: 13),
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
                  await _payoutMethodService.deletePayoutMethod(userId, method.id);
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
                      Text('Set as Default', style: TextStyle(fontSize: 13)),
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
          border: Border.all(color: _driverBorderColor(context)),
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
    final userId = AuthService().currentUser?.id ?? '';
    final defaultName = AuthService().currentUser?.userMetadata?['full_name']?.toString() ?? 'Driver';
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
          final isDark = _driverIsDark(ctx);

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C1B2A) : Colors.white,
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
                        'Link Payout Method',
                        style: TextStyle(
                          color: _driverPrimaryText(ctx),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select provider and provide your 11-digit account number and QR code for disbursements.',
                    style: TextStyle(color: _driverSecondaryText(ctx), fontSize: 12),
                  ),
                  const SizedBox(height: 18),

                  // 1. PROVIDER SELECTOR (GCash / Maya / MariBank / GoTyme only)
                  Text(
                    'Payment Provider',
                    style: TextStyle(
                      color: _driverSecondaryText(ctx),
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
                            color: isSelected ? Colors.black : _driverPrimaryText(ctx),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: isDark ? const Color(0xFF07111D) : const Color(0xFFF1F5F9),
                        side: BorderSide(
                          color: isSelected ? color : _driverBorderColor(ctx),
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
                  Text(
                    'Account Name',
                    style: TextStyle(
                      color: _driverSecondaryText(ctx),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: _driverPrimaryText(ctx), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Juan Dela Cruz',
                      hintStyle: TextStyle(color: _driverSecondaryText(ctx)),
                      prefixIcon: Icon(Icons.person_outline, color: _driverSecondaryText(ctx), size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF07111D) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _driverBorderColor(ctx)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _driverBorderColor(ctx)),
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
                      Text(
                        'Account / Mobile Number',
                        style: TextStyle(
                          color: _driverSecondaryText(ctx),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${numberController.text.replaceAll(RegExp(r'\\D'), '').length} / 11 digits',
                        style: TextStyle(
                          color: numberController.text.replaceAll(RegExp(r'\\D'), '').length == 11
                              ? AppColors.primary
                              : _driverSecondaryText(ctx),
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
                    style: TextStyle(color: _driverPrimaryText(ctx), fontSize: 14, letterSpacing: 1.1),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '09XXXXXXXXX (11 digits)',
                      hintStyle: TextStyle(color: _driverSecondaryText(ctx)),
                      prefixIcon: Icon(Icons.phone_iphone_rounded, color: _driverSecondaryText(ctx), size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF07111D) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _driverBorderColor(ctx)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _driverBorderColor(ctx)),
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
                    'Payment QR Code (Optional)',
                    style: TextStyle(
                      color: _driverSecondaryText(ctx),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (pickedQrFile != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF07111D) : const Color(0xFFF1F5F9),
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
                                  style: TextStyle(color: _driverPrimaryText(ctx), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${(pickedQrFile!.size / 1024).toStringAsFixed(1)} KB • Ready to upload',
                                  style: TextStyle(color: _driverSecondaryText(ctx), fontSize: 11),
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
                        side: BorderSide(color: _driverBorderColor(ctx)),
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
                    title: Text(
                      'Set as default payout account',
                      style: TextStyle(color: _driverPrimaryText(ctx), fontSize: 13, fontWeight: FontWeight.w600),
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
      builder: (dialogCtx) {
        final isDark = _driverIsDark(dialogCtx);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C1B2A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _driverBorderColor(dialogCtx)),
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
                          style: TextStyle(color: _driverPrimaryText(dialogCtx), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      icon: Icon(Icons.close, color: _driverSecondaryText(dialogCtx)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${method.accountName} • ${method.accountNumber}',
                  style: TextStyle(color: _driverSecondaryText(dialogCtx), fontSize: 12),
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
        );
      },
    );
  }

  Widget _buildEmptyPanel({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _driverBorderColor(context)),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _driverSecondaryText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _currency(num value) => 'PHP ${formatAmount(value, decimalDigits: 2)}';
}

