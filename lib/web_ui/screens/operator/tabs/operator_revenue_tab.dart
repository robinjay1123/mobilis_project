part of '../operator_web_screen.dart';

extension OperatorRevenueTab on _OperatorWebScreenState {
  Widget _buildRevenueContent(bool isDark) {
    final allManaged = _operatorManagedBookings();
    final allReleasedSettlements = _operatorSettlements
        .where(
          (settlement) =>
              settlement['status']?.toString().trim().toLowerCase() ==
              'released',
        )
        .toList();
    final managed = allManaged.where(_matchesOperatorRevenuePeriod).toList();
    final releasedSettlements = allReleasedSettlements
        .where(_matchesOperatorRevenuePeriod)
        .toList();
    final releasedBookingIds = _settlementBookingIds(releasedSettlements);
    final fullyPaid = managed.where((booking) {
      final financials = _extractBookingFinancials(booking);
      final finStatus =
          financials?['final_payment_status']?.toString().trim().toLowerCase();
      final paymentStatus = (booking['payment_status'] ??
              booking['final_payment_status'] ??
              finStatus)
          ?.toString()
          .trim()
          .toLowerCase();
      final hasPaidAmount = (booking['total_paid_amount'] as num? ?? 0) > 0;
      return paymentStatus == 'paid' ||
          paymentStatus == 'completed' ||
          hasPaidAmount ||
          releasedBookingIds.contains(booking['id']?.toString());
    }).toList();
    final completed = managed
        .where(
          (booking) =>
              bookingStatusGroup(booking['status']) ==
              BookingStatusGroup.completed,
        )
        .toList();
    final paidCompletedFallback = _paidCompletedWithoutSettlement(
      bookings: completed,
      settlements: releasedSettlements,
    );
    final active = managed.where((booking) {
      final group = bookingStatusGroup(booking['status']);
      return group == BookingStatusGroup.approved ||
          group == BookingStatusGroup.ongoing;
    }).length;
    final releasedGross = releasedSettlements.fold<double>(
      0,
      (total, settlement) =>
          total + ((settlement['gross_amount'] as num?)?.toDouble() ?? 0),
    );
    final fallbackRevenue = paidCompletedFallback.fold<double>(
      0,
      (total, booking) => total + _bookingAmount(booking),
    );
    final managedFallbackRevenue = _operatorManagedFallbackRevenue(
      paidCompletedFallback,
    );
    final managedValue =
        releasedSettlements.fold<double>(
          0,
          (total, settlement) =>
              total +
              ((settlement['operator_managed_amount'] as num?)?.toDouble() ??
                  0),
        ) +
        managedFallbackRevenue;
    final platformCommission = releasedSettlements.fold<double>(
      0,
      (total, settlement) =>
          total +
          ((settlement['platform_commission'] as num?)?.toDouble() ?? 0),
    );
    final processedRevenue = releasedGross + fallbackRevenue;
    final paidCompletedCount =
        releasedSettlements.length + paidCompletedFallback.length;
    final averageValue = completed.isEmpty
        ? 0.0
        : processedRevenue / completed.length;
    final now = DateTime.now();
    final monthly = List.generate(6, (index) {
      final monthDate = DateTime(now.year, now.month - (5 - index));
      final monthSettlements = allReleasedSettlements.where((settlement) {
        final date = DateTime.tryParse(
          settlement['released_at']?.toString() ?? '',
        )?.toLocal();
        return date != null &&
            date.year == monthDate.year &&
            date.month == monthDate.month;
      }).toList();
      final monthBookings = allManaged.where((booking) {
        final date = DateTime.tryParse(
          (booking['completed_at'] ?? booking['created_at'])?.toString() ?? '',
        )?.toLocal();
        return date != null &&
            date.year == monthDate.year &&
            date.month == monthDate.month;
      }).toList();
      final monthFallback = _paidCompletedWithoutSettlement(
        bookings: monthBookings,
        settlements: monthSettlements,
      );
      final monthSettlementAmount = monthSettlements.fold<double>(
        0,
        (total, settlement) =>
            total + ((settlement['gross_amount'] as num?)?.toDouble() ?? 0),
      );
      final monthFallbackAmount = monthFallback.fold<double>(
        0,
        (total, booking) => total + _bookingAmount(booking),
      );
      return <String, dynamic>{
        'label': _getMonthName(monthDate.month),
        'count': monthSettlements.length + monthFallback.length,
        'amount': monthSettlementAmount + monthFallbackAmount,
      };
    });
    final maxMonthly = monthly.fold<double>(
      1,
      (maximum, item) => (item['amount'] as double) > maximum
          ? item['amount'] as double
          : maximum,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operator Revenue & Analytics',
            style: TextStyle(
              color: isDark ? Colors.white : _operatorInk,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Only bookings assigned to and managed by this operator are included.',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          _buildOperatorRevenuePeriodSelector(isDark),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050
                  ? 4
                  : constraints.maxWidth >= 580
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 16)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _buildRevenueMetricCard(
                      'Managed Bookings',
                      managed.length.toString(),
                      'Bookings assisted by you',
                      Icons.assignment_turned_in_outlined,
                      const Color(0xFF0284C7),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildRevenueMetricCard(
                      'Active Trips',
                      active.toString(),
                      'Approved or ongoing',
                      Icons.route_outlined,
                      const Color(0xFF0284C7),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildRevenueMetricCard(
                      'Released Value',
                      'PHP ${processedRevenue.toStringAsFixed(2)}',
                      paidCompletedCount == 0
                          ? 'No paid completed trips yet'
                          : '$paidCompletedCount paid completed trips',
                      Icons.account_balance_wallet_outlined,
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildRevenueMetricCard(
                      paidCompletedCount == 0
                          ? 'Average Booking'
                          : 'PSDC Managed Value',
                      'PHP ${(paidCompletedCount == 0 ? averageValue : managedValue).toStringAsFixed(2)}',
                      paidCompletedCount == 0
                          ? 'Completed bookings only'
                          : 'Company vehicle value handled by this operator',
                      Icons.trending_up_rounded,
                      const Color(0xFFF59E0B),
                      isDark,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final chart = Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderColor
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Managed Booking Value',
                      style: TextStyle(
                        color: isDark ? Colors.white : _operatorInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      releasedSettlements.isEmpty
                          ? 'Last six months from historical completed bookings'
                          : 'Last six months from released settlement records',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: monthly.map((item) {
                          final amount = item['amount'] as double;
                          final ratio = amount / maxMonthly;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item['count']}',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : _operatorInk,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    height: 24 + (140 * ratio),
                                    decoration: BoxDecoration(
                                      color: _operatorGold,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item['label'].toString(),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
              final breakdown = _buildOperatorRevenueBreakdown(
                managed,
                completed,
                releasedSettlements: releasedSettlements,
                platformCommission: platformCommission,
                isDark,
              );
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [chart, const SizedBox(height: 16), breakdown],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: chart),
                  const SizedBox(width: 16),
                  Expanded(child: breakdown),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          _buildFullyPaidBookingsCard(fullyPaid, isDark),
        ],
      ),
    );
  }

  Widget _buildOperatorRevenuePeriodSelector(bool isDark) {
    const periods = <String, String>{
      'day': 'Day',
      'week': 'Week',
      'month': 'Month',
      'year': 'Year',
    };
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 9,
            runSpacing: 9,
            children: periods.entries.map((entry) {
              final selected = _revenuePeriod == entry.key;
              return ChoiceChip(
                selected: selected,
                onSelected: (_) => setState(() => _revenuePeriod = entry.key),
                label: Text(entry.value),
                labelStyle: TextStyle(
                  color: selected
                      ? _operatorInk
                      : (isDark ? Colors.grey[300] : _operatorInk),
                  fontWeight: FontWeight.w800,
                ),
                selectedColor: _operatorGold,
                backgroundColor: isDark
                    ? AppColors.darkCard
                    : Colors.grey.shade100,
                side: BorderSide(
                  color: selected
                      ? _operatorGold
                      : (isDark ? AppColors.borderColor : Colors.grey.shade300),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }).toList(),
          ),
        ),
        Text(
          _operatorRevenuePeriodLabel(),
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFullyPaidBookingsCard(
    List<Map<String, dynamic>> bookings,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF2E7D32)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fully Paid Bookings',
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${bookings.length} records',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (bookings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 34),
              alignment: Alignment.center,
              child: Text(
                'No fully paid bookings for ${_operatorRevenuePeriodLabel().toLowerCase()}.',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                ),
              ),
            )
          else
            ...bookings.map((booking) {
              final renter = booking['renter'] is Map
                  ? Map<String, dynamic>.from(booking['renter'] as Map)
                  : <String, dynamic>{};
              final vehicle = booking['vehicles'] is Map
                  ? Map<String, dynamic>.from(booking['vehicles'] as Map)
                  : <String, dynamic>{};
              final date = _operatorRevenueDate(booking);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildRevenueRenterAvatar(renter),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            renter['full_name']?.toString() ?? 'Renter',
                            style: TextStyle(
                              color: isDark ? Colors.white : _operatorInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            renter['email']?.toString() ?? '',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _vehicleTitle(vehicle),
                        style: TextStyle(
                          color: isDark ? Colors.grey[200] : _operatorInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        date == null
                            ? 'Date unavailable'
                            : _formatBookingDateTime(date),
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'PHP ${_bookingAmount(booking).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isDark ? Colors.white : _operatorInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'FULLY PAID',
                        style: TextStyle(
                          color: Color(0xFF43A047),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRevenueRenterAvatar(Map<String, dynamic> renter) {
    final avatarUrl = _operatorUserAvatarUrl(renter);
    final name = renter['full_name']?.toString().trim() ?? 'R';
    final fallback = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _operatorGold.withOpacity(0.16),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        name.isEmpty ? 'R' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(color: _operatorGold, fontWeight: FontWeight.w900),
      ),
    );
    if (avatarUrl == null || avatarUrl.isEmpty) return fallback;
    return OptimizedNetworkImage(
      imageUrl: avatarUrl,
      width: 38,
      height: 38,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(11),
      placeholder: fallback,
      errorWidget: fallback,
    );
  }

  Widget _buildRevenueMetricCard(
    String label,
    String value,
    String caption,
    IconData icon,
    Color accent,
    bool isDark,
  ) {
    final effectiveAccent = isDark && (accent.computeLuminance() < 0.22)
        ? const Color(0xFF38BDF8)
        : accent;

    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? effectiveAccent.withOpacity(0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: effectiveAccent.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: effectiveAccent.withOpacity(isDark ? 0.4 : 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: effectiveAccent, size: 20),
              ),
              const Spacer(),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                  fontSize: 9,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            caption,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorRevenueBreakdown(
    List<Map<String, dynamic>> managed,
    List<Map<String, dynamic>> completed,
    bool isDark, {
    required List<Map<String, dynamic>> releasedSettlements,
    required double platformCommission,
  }) {
    final pending = managed
        .where(
          (booking) =>
              bookingStatusGroup(booking['status']) ==
              BookingStatusGroup.pending,
        )
        .length;
    final cancelled = managed
        .where(
          (booking) =>
              bookingStatusGroup(booking['status']) ==
              BookingStatusGroup.cancelled,
        )
        .length;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _operatorNavy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _buildRevenueBreakdownLine('Completed', completed.length),
          _buildRevenueBreakdownLine(
            'Released settlements',
            releasedSettlements.length,
          ),
          _buildRevenueBreakdownLine('Pending review', pending),
          _buildRevenueBreakdownLine('Cancelled', cancelled),
          _buildRevenueBreakdownLine('All managed', managed.length),
          const SizedBox(height: 14),
          Text(
            releasedSettlements.isEmpty
                ? 'Deploy the settlement migration to record released funds automatically.'
                : 'Recorded platform commission: PHP ${platformCommission.toStringAsFixed(2)}. Operator analytics represent managed value, not personal payout.',
            style: const TextStyle(
              color: Color(0xFF9CB1C3),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdownLine(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFB8C6D2), fontSize: 12),
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: _operatorGold,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

