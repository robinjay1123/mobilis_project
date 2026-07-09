import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class PartnerRevenueScreen extends StatefulWidget {
  final String partnerName;
  final List<Map<String, dynamic>> bookings;
  final int completedTrips;
  final double recordedTotalEarnings;

  const PartnerRevenueScreen({
    super.key,
    required this.partnerName,
    required this.bookings,
    required this.completedTrips,
    required this.recordedTotalEarnings,
  });

  @override
  State<PartnerRevenueScreen> createState() => _PartnerRevenueScreenState();
}

class _PartnerRevenueScreenState extends State<PartnerRevenueScreen> {
  String _selectedPeriod = 'Month';
  static const List<String> _periodOptions = ['Day', 'Week', 'Month', 'Year'];

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
    final computedRevenue = completedBookings.fold<double>(
      0,
      (sum, booking) =>
          sum + ((booking['total_price'] as num?)?.toDouble() ?? 0),
    );
    final totalRevenue = computedRevenue;
    final tripCount = completedBookings.length;
    final averageTrip = tripCount == 0 ? 0.0 : totalRevenue / tripCount;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: ListView(
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
                          text: 'by PSDC',
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
              value: _currency(totalRevenue),
              subtext: completedBookings.isEmpty
                  ? 'No revenue for this ${_selectedPeriod.toLowerCase()}'
                  : 'From completed trips this ${_selectedPeriod.toLowerCase()}',
              icon: Icons.payments_outlined,
            ),
            const SizedBox(height: 24),
            _buildMetricCard(
              label: 'Completed Trips',
              value: '$tripCount',
              subtext: tripCount == 0
                  ? 'No completed trips yet'
                  : 'Trips completed',
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
            _buildSectionHeader('Linked Payout Methods', action: 'Manage'),
            const SizedBox(height: 14),
            _buildEmptyPanel(
              icon: Icons.account_balance_wallet_outlined,
              text: 'No linked payout methods yet.',
            ),
            const SizedBox(height: 16),
            _buildDashedButton(),
            const SizedBox(height: 34),
            _buildSectionHeader('Earnings Breakdown', action: 'View All'),
            const SizedBox(height: 14),
            if (completedBookings.isEmpty)
              _buildEmptyPanel(
                icon: Icons.receipt_long_outlined,
                text: 'No completed trip earnings yet.',
              )
            else
              ...completedBookings.map(_buildEarningRow),
          ],
        ),
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

  Widget _buildSectionHeader(String title, {required String action}) {
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
        Text(
          action,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
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

  Widget _buildDashedButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, color: AppColors.textSecondary),
          SizedBox(width: 8),
          Text(
            'Link New Account',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningRow(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleName = '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}'
        .trim();
    final total = (booking['total_price'] as num?)?.toDouble() ?? 0;

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
                  _formatDateTime(booking['created_at']?.toString()),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${_currency(total)}',
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

  static String _currency(double value) => 'PHP ${value.toStringAsFixed(2)}';

  bool _isWithinSelectedPeriod(Map<String, dynamic> booking) {
    final date = _bookingDate(booking);
    if (date == null) return false;
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
