part of '../admin_web_screen.dart';

extension _AdminAnalyticsTab on _AdminWebScreenState {
  Widget _buildAnalyticsContent(bool isDark) {
    final fin = _calculatePlatformFinancials();
    final grossVolume = fin['totalGrossVolume'] ?? 0.0;
    final netRevenue = fin['actualCompanyNetRevenue'] ?? 0.0;
    final platformCommission = fin['totalPlatformCommission'] ?? 0.0;
    final partnerComm = fin['totalPartnerCommissions'] ?? 0.0;
    final driverComm = fin['totalDriverCommissions'] ?? 0.0;
    final fleetRevenue = fin['companyFleetRevenue'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue & Financial Analytics',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : _adminInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time overview of company net revenue, PSDC 5% platform commissions, and payout disbursements.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _loadDashboardData(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh Data'),
                style: FilledButton.styleFrom(
                  backgroundColor: _adminGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Financial KPI Cards
          _buildRevenueAndCommissionStatCards(
            isDark: isDark,
            totalGrossVolume: grossVolume,
            actualCompanyNetRevenue: netRevenue,
            totalPlatformCommission: platformCommission,
            partnerCommissions: partnerComm,
            driverCommissions: driverComm,
            companyFleetRevenue: fleetRevenue,
          ),
          const SizedBox(height: 24),

          // Revenue Architecture Breakdown Card
          _buildRevenueArchitectureCard(
            isDark: isDark,
            companyFleetRevenue: fleetRevenue,
            partnerCommissions: partnerComm,
            driverCommissions: driverComm,
            totalPartnerGross: fin['totalPartnerGross'] ?? 0.0,
            totalDriverGross: fin['totalDriverGross'] ?? 0.0,
            totalDisbursedNet: (fin['totalPartnerDisbursedNet'] ?? 0.0) + (fin['totalDriverDisbursedNet'] ?? 0.0),
            totalPendingNet: (fin['totalPartnerPendingNet'] ?? 0.0) + (fin['totalDriverPendingNet'] ?? 0.0),
          ),
          const SizedBox(height: 24),

          // Analytics Charts Row 1
          Row(
            children: [
              Expanded(
                child: _buildCard(
                  'Bookings Trend',
                  SizedBox(height: 250, child: _buildBookingsLineChart(isDark)),
                  isDark,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildCard(
                  'Booking Status Distribution',
                  _buildBookingStatusChartWithLegend(isDark, chartHeight: 180),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Analytics Charts Row 2
          Row(
            children: [
              Expanded(
                child: _buildCard(
                  'User Growth',
                  SizedBox(height: 250, child: _buildUserGrowthChart(isDark)),
                  isDark,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildCard(
                  'Operational Metrics',
                  _buildMetricsTable(isDark),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Commission Earnings & Disbursement History Section
          _buildCommissionHistoryCard(isDark),
        ],
      ),
    );
  }

  Widget _buildBookingsLineChart(bool isDark) {
    final weeklyData = _calculateWeeklyBookingData();
    final horizontalInterval = (_totalBookings / 7).ceil().toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: horizontalInterval > 0 ? horizontalInterval : 1.0,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                const labels = [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ];
                return Text(
                  labels[value.toInt() % 7],
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            left: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: weeklyData,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _calculateWeeklyBookingData() {
    final weekdayCounts = List<double>.filled(7, 0.0);
    
    for (final b in _allBookings) {
      if (!_isValidRevenueBooking(b)) continue;
      final dateStr = b['created_at'] ?? b['pickup_date'] ?? b['start_date'];
      if (dateStr != null) {
        final parsed = DateTime.tryParse(dateStr.toString());
        if (parsed != null) {
          final weekdayIndex = (parsed.weekday - 1) % 7; // 0: Mon ... 6: Sun
          weekdayCounts[weekdayIndex] += 1.0;
        }
      }
    }
    
    return List.generate(7, (i) => FlSpot(i.toDouble(), weekdayCounts[i]));
  }

  Widget _buildRevenueChart(bool isDark) {
    final statusData = _calculateBookingStatusDistribution();
    if (statusData.isEmpty) {
      return Center(
        child: Text(
          'No booking data yet',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      );
    }

    return PieChart(PieChartData(centerSpaceRadius: 38, sections: statusData));
  }

  Widget _buildBookingStatusChartWithLegend(
    bool isDark, {
    required double chartHeight,
  }) {
    final counts = _bookingStatusCounts();
    final visibleGroups = bookingStatusOrder
        .where((group) => (counts[group] ?? 0) > 0)
        .toList();

    return Column(
      children: [
        SizedBox(height: chartHeight, child: _buildRevenueChart(isDark)),
        if (visibleGroups.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: visibleGroups.map((group) {
              final color = bookingStatusColor(group);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${bookingStatusLabel(group)} (${counts[group]})',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Map<BookingStatusGroup, int> _bookingStatusCounts() {
    final counts = <BookingStatusGroup, int>{
      for (final group in bookingStatusOrder) group: 0,
    };
    for (final booking in _allBookings) {
      final group = bookingStatusGroup(booking['status']);
      counts[group] = (counts[group] ?? 0) + 1;
    }
    return counts;
  }

  List<PieChartSectionData> _calculateBookingStatusDistribution() {
    final counts = _bookingStatusCounts();
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) return [];

    return bookingStatusOrder.where((group) => (counts[group] ?? 0) > 0).map((
      group,
    ) {
      final percentage = (counts[group]! / total) * 100;
      return PieChartSectionData(
        color: bookingStatusColor(group),
        value: percentage,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 52,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }).toList();
  }

  Widget _buildUserGrowthChart(bool isDark) {
    final userGrowthData = _calculateUserGrowthData();
    final maxUsers = userGrowthData.fold<double>(
      0,
      (max, val) => val > max ? val : max,
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxUsers * 1.1).ceilToDouble(),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                return Text(
                  months[value.toInt() % 6],
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          6,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: userGrowthData[index],
                color: Colors.green.shade400,
                width: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<double> _calculateUserGrowthData() {
    final monthCounts = List<double>.filled(6, 0.0);
    final now = DateTime.now();
    
    for (final u in _allUsers) {
      final dateStr = u['created_at'];
      if (dateStr != null) {
        final parsed = DateTime.tryParse(dateStr.toString());
        if (parsed != null) {
          final monthDiff = (now.year - parsed.year) * 12 + (now.month - parsed.month);
          if (monthDiff >= 0 && monthDiff < 6) {
            final slotIndex = 5 - monthDiff;
            monthCounts[slotIndex] += 1.0;
          }
        }
      }
    }
    
    double running = 0;
    final cumulative = List<double>.filled(6, 0.0);
    for (int i = 0; i < 6; i++) {
      running += monthCounts[i];
      cumulative[i] = running > 0 ? running : ((_totalUsers / 6) * (i + 1)).clamp(0, _totalUsers.toDouble());
    }
    return cumulative;
  }

  Widget _buildMetricsTable(bool isDark) {
    final fin = _calculatePlatformFinancials();
    final platformCommission = fin['totalPlatformCommission'] ?? 0.0;
    final netRevenue = fin['actualCompanyNetRevenue'] ?? 0.0;

    return Column(
      children: [
        _buildMetricRow(
          'Total Bookings',
          '$_totalBookings',
          Icons.calendar_today,
          Colors.blue,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildMetricRow(
          'Ongoing Bookings',
          '$_activeBookings',
          Icons.check_circle,
          Colors.green,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildMetricRow(
          'Gross Revenue',
          'PHP ${_totalRevenue.toStringAsFixed(0)}',
          Icons.money,
          Colors.orange,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildMetricRow(
          'PSDC Commission (5%)',
          'PHP ${platformCommission.toStringAsFixed(0)}',
          Icons.percent_rounded,
          _adminGold,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildMetricRow(
          'Company Net Revenue',
          'PHP ${netRevenue.toStringAsFixed(0)}',
          Icons.account_balance_wallet_rounded,
          Colors.teal,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildMetricRow(
          'Pending Approvals',
          '$_pendingVerifications',
          Icons.hourglass_top,
          Colors.red,
          isDark,
        ),
      ],
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showReceiptProofDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text(
                                    'Failed to load receipt proof image',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                        ),
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

  Map<String, double> _calculatePlatformFinancials() {
    final validBookings = _allBookings.where((b) => _isValidRevenueBooking(b)).toList();

    double totalGrossVolume = 0.0;
    double companyFleetRevenue = 0.0;
    double totalPartnerCommissions = 0.0;
    double totalPartnerGross = 0.0;
    double totalPartnerDisbursedNet = 0.0;
    double totalPartnerPendingNet = 0.0;

    double totalDriverCommissions = 0.0;
    double totalDriverGross = 0.0;
    double totalDriverDisbursedNet = 0.0;
    double totalDriverPendingNet = 0.0;

    for (final b in validBookings) {
      final total = (b['total_price'] as num?)?.toDouble() ??
          (b['total_cost'] as num?)?.toDouble() ??
          0.0;
      totalGrossVolume += total;

      final vehicle = b['vehicles'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(b['vehicles'])
          : <String, dynamic>{};
      final isPartner = b['is_partner_vehicle'] == true ||
          vehicle['is_partner_vehicle'] == true ||
          vehicle['owner_role']?.toString().toLowerCase() == 'partner';

      final rentalSubtotal = (b['rental_subtotal'] as num?)?.toDouble() ?? total;

      if (isPartner) {
        final pGross = rentalSubtotal;
        final pComm = (b['partner_payout_commission'] as num?)?.toDouble() ?? (pGross * 0.05);
        final pNet = (b['partner_payout_amount'] as num?)?.toDouble() ?? (pGross - pComm);
        totalPartnerGross += pGross;
        totalPartnerCommissions += pComm;
        final isDisbursed = b['partner_payout_disbursed'] == true ||
            b['settlement']?['status']?.toString().toLowerCase() == 'released';
        if (isDisbursed) {
          totalPartnerDisbursedNet += pNet;
        } else {
          totalPartnerPendingNet += pNet;
        }
      } else {
        companyFleetRevenue += rentalSubtotal;
      }

      final hasDriver = b['driver_id'] != null ||
          b['drivers'] != null ||
          ((b['driver_fee'] as num?)?.toDouble() ?? 0) > 0;
      if (hasDriver) {
        final dFee = (b['driver_fee'] as num?)?.toDouble() ?? 0.0;
        if (dFee > 0 || b['driver_payout_disbursed'] == true) {
          final dComm = (b['driver_payout_commission'] as num?)?.toDouble() ?? (dFee * 0.05);
          final dNet = (b['driver_payout_amount'] as num?)?.toDouble() ?? (dFee - dComm);
          totalDriverGross += dFee;
          totalDriverCommissions += dComm;
          if (b['driver_payout_disbursed'] == true) {
            totalDriverDisbursedNet += dNet;
          } else {
            totalDriverPendingNet += dNet;
          }
        }
      }
    }

    final totalPlatformCommission = totalPartnerCommissions + totalDriverCommissions;
    final actualCompanyNetRevenue = companyFleetRevenue + totalPlatformCommission;

    return {
      'totalGrossVolume': totalGrossVolume,
      'actualCompanyNetRevenue': actualCompanyNetRevenue,
      'totalPlatformCommission': totalPlatformCommission,
      'companyFleetRevenue': companyFleetRevenue,
      'totalPartnerCommissions': totalPartnerCommissions,
      'totalPartnerGross': totalPartnerGross,
      'totalPartnerDisbursedNet': totalPartnerDisbursedNet,
      'totalPartnerPendingNet': totalPartnerPendingNet,
      'totalDriverCommissions': totalDriverCommissions,
      'totalDriverGross': totalDriverGross,
      'totalDriverDisbursedNet': totalDriverDisbursedNet,
      'totalDriverPendingNet': totalDriverPendingNet,
    };
  }

  List<Map<String, dynamic>> _getCommissionDisbursementRecords() {
    final records = <Map<String, dynamic>>[];

    for (final b in _allBookings) {
      final bId = b['id']?.toString() ?? '';
      final refCode = b['booking_reference']?.toString().isNotEmpty == true
          ? b['booking_reference'].toString()
          : (bId.length > 8 ? bId.substring(0, 8).toUpperCase() : bId);
      final bookingStatus = (b['status']?.toString() ?? '').toLowerCase().trim();

      final vehicle = b['vehicles'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(b['vehicles'])
          : <String, dynamic>{};
      final isPartner = b['is_partner_vehicle'] == true ||
          vehicle['is_partner_vehicle'] == true ||
          vehicle['owner_role']?.toString().toLowerCase() == 'partner';

      // 1. Partner record
      if (isPartner) {
        final total = (b['total_price'] as num?)?.toDouble() ??
            (b['total_cost'] as num?)?.toDouble() ??
            0.0;
        final gross = (b['rental_subtotal'] as num?)?.toDouble() ?? total;
        final comm = (b['partner_payout_commission'] as num?)?.toDouble() ?? (gross * 0.05);
        final net = (b['partner_payout_amount'] as num?)?.toDouble() ?? (gross - comm);

        final isDisbursed = b['partner_payout_disbursed'] == true ||
            b['settlement']?['status']?.toString().toLowerCase() == 'released';
        final statusStr = isDisbursed
            ? 'Disbursed'
            : (bookingStatus == 'completed'
                ? 'Eligible / Pending'
                : (bookingStatus == 'cancelled' || bookingStatus == 'rejected'
                    ? 'Cancelled'
                    : 'In Progress'));

        final releasedAtRaw = b['partner_payout_disbursed_at'] ??
            b['settlement']?['released_at'] ??
            b['created_at'];
        DateTime? date;
        if (releasedAtRaw != null) {
          date = DateTime.tryParse(releasedAtRaw.toString());
        }

        final partnerName = b['partner_business_name'] ??
            b['partner_name'] ??
            'Mobilis Partner';
        final vehicleDesc = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();

        records.add({
          'type': 'partner',
          'role': 'Partner',
          'booking_id': bId,
          'booking_reference': refCode,
          'recipient_name': partnerName,
          'recipient_subtitle': vehicleDesc.isNotEmpty ? vehicleDesc : 'Partner Vehicle',
          'gross_amount': gross,
          'commission_amount': comm,
          'commission_rate': '5%',
          'net_amount': net,
          'status': statusStr,
          'is_disbursed': isDisbursed,
          'payout_method': b['partner_payout_method'] ?? 'GCash / Bank',
          'payout_reference': b['partner_payout_reference'] ?? '',
          'receipt_url': b['partner_payout_receipt_url'] ?? b['settlement']?['receipt_url'],
          'date': date,
          'booking_status': bookingStatus,
        });
      }

      // 2. Driver record
      final hasDriver = b['driver_id'] != null ||
          b['drivers'] != null ||
          ((b['driver_fee'] as num?)?.toDouble() ?? 0) > 0;
      if (hasDriver) {
        final driverFee = (b['driver_fee'] as num?)?.toDouble() ?? 0.0;
        if (driverFee > 0 || b['driver_payout_disbursed'] == true) {
          final comm = (b['driver_payout_commission'] as num?)?.toDouble() ?? (driverFee * 0.05);
          final net = (b['driver_payout_amount'] as num?)?.toDouble() ?? (driverFee - comm);

          final isDisbursed = b['driver_payout_disbursed'] == true;
          final statusStr = isDisbursed
              ? 'Disbursed'
              : (bookingStatus == 'completed'
                  ? 'Eligible / Pending'
                  : (bookingStatus == 'cancelled' || bookingStatus == 'rejected'
                      ? 'Cancelled'
                      : 'In Progress'));

          final releasedAtRaw = b['driver_payout_disbursed_at'] ?? b['created_at'];
          DateTime? date;
          if (releasedAtRaw != null) {
            date = DateTime.tryParse(releasedAtRaw.toString());
          }

          final driverMap = b['drivers'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(b['drivers'])
              : null;
          final driverUser = driverMap?['users'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(driverMap!['users'])
              : null;
          final driverName = driverUser?['full_name'] ??
              b['driver_name'] ??
              'Assigned Driver';

          records.add({
            'type': 'driver',
            'role': 'Driver',
            'booking_id': bId,
            'booking_reference': refCode,
            'recipient_name': driverName,
            'recipient_subtitle': 'Trip Chauffeur',
            'gross_amount': driverFee,
            'commission_amount': comm,
            'commission_rate': '5%',
            'net_amount': net,
            'status': statusStr,
            'is_disbursed': isDisbursed,
            'payout_method': b['driver_payout_method'] ?? 'GCash / Bank',
            'payout_reference': b['driver_payout_reference'] ?? '',
            'receipt_url': b['driver_payout_receipt_url'],
            'date': date,
            'booking_status': bookingStatus,
          });
        }
      }
    }

    records.sort((a, b) {
      final aDate = a['date'] as DateTime? ?? DateTime(1970);
      final bDate = b['date'] as DateTime? ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return records;
  }

  List<Map<String, dynamic>> _getFilteredCommissionRecords() {
    final all = _getCommissionDisbursementRecords();
    return all.where((item) {
      // Role filter
      if (_commissionRoleFilter == 'partner' && item['type'] != 'partner') return false;
      if (_commissionRoleFilter == 'driver' && item['type'] != 'driver') return false;

      // Status filter
      if (_commissionStatusFilter == 'disbursed' && item['is_disbursed'] != true) return false;
      if (_commissionStatusFilter == 'pending' && item['is_disbursed'] == true) return false;

      // Search query
      if (_commissionSearchQuery.isNotEmpty) {
        final q = _commissionSearchQuery.toLowerCase().trim();
        final ref = (item['booking_reference'] ?? '').toString().toLowerCase();
        final name = (item['recipient_name'] ?? '').toString().toLowerCase();
        final sub = (item['recipient_subtitle'] ?? '').toString().toLowerCase();
        final payRef = (item['payout_reference'] ?? '').toString().toLowerCase();
        final method = (item['payout_method'] ?? '').toString().toLowerCase();
        if (!ref.contains(q) &&
            !name.contains(q) &&
            !sub.contains(q) &&
            !payRef.contains(q) &&
            !method.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildRevenueAndCommissionStatCards({
    required bool isDark,
    required double totalGrossVolume,
    required double actualCompanyNetRevenue,
    required double totalPlatformCommission,
    required double partnerCommissions,
    required double driverCommissions,
    required double companyFleetRevenue,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final cardWidth = isWide ? (constraints.maxWidth - 60) / 4 : (constraints.maxWidth - 20) / 2;

        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildFinancialKpiCard(
                title: 'Gross Booking Volume',
                value: 'PHP ${NumberFormat('#,##0.00').format(totalGrossVolume)}',
                subtitle: 'Total volume across all valid bookings',
                icon: Icons.payments_rounded,
                color: Colors.blue,
                isDark: isDark,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildFinancialKpiCard(
                title: 'Actual Company Net Revenue',
                value: 'PHP ${NumberFormat('#,##0.00').format(actualCompanyNetRevenue)}',
                subtitle: 'PSDC Fleet Direct + 5% Platform Commissions',
                icon: Icons.account_balance_wallet_rounded,
                color: Colors.teal,
                isDark: isDark,
                highlightBadge: 'ACTUAL NET',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildFinancialKpiCard(
                title: 'Total PSDC Commission (5%)',
                value: 'PHP ${NumberFormat('#,##0.00').format(totalPlatformCommission)}',
                subtitle: 'PHP ${NumberFormat('#,##0.00').format(partnerCommissions)} partner + PHP ${NumberFormat('#,##0.00').format(driverCommissions)} driver',
                icon: Icons.percent_rounded,
                color: _adminGold,
                isDark: isDark,
                highlightBadge: 'PSDC EARNINGS',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildFinancialKpiCard(
                title: 'Company Fleet Direct',
                value: 'PHP ${NumberFormat('#,##0.00').format(companyFleetRevenue)}',
                subtitle: '100% rental fee from company-owned cars',
                icon: Icons.directions_car_rounded,
                color: Colors.purpleAccent,
                isDark: isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinancialKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    String? highlightBadge,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightBadge != null
              ? color.withOpacity(0.4)
              : (isDark ? AppColors.borderColor : Colors.grey.shade200),
          width: highlightBadge != null ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (highlightBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    highlightBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey.shade500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueArchitectureCard({
    required bool isDark,
    required double companyFleetRevenue,
    required double partnerCommissions,
    required double driverCommissions,
    required double totalPartnerGross,
    required double totalDriverGross,
    required double totalDisbursedNet,
    required double totalPendingNet,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _adminGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_tree_rounded, color: _adminGold, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PSDC Revenue & Commission Architecture',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Breakdown of company direct income, 5% platform commissions, and payout releases',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item 1: Partner 5% vs 95%
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.handshake_rounded, size: 16, color: _adminGold),
                              const SizedBox(width: 6),
                              Text(
                                'Partner Fleet Payouts',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Partner Gross:', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey.shade600)),
                              Text('PHP ${NumberFormat('#,##0.00').format(totalPartnerGross)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('PSDC Commission (5%):', style: TextStyle(fontSize: 12, color: _adminGold, fontWeight: FontWeight.bold)),
                              Text('PHP ${NumberFormat('#,##0.00').format(partnerCommissions)}', style: TextStyle(fontWeight: FontWeight.bold, color: _adminGold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Partner Net (95%):', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey.shade600)),
                              Text('PHP ${NumberFormat('#,##0.00').format((totalPartnerGross - partnerCommissions).clamp(0.0, double.infinity))}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Item 2: Driver 5% vs 95%
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_pin_circle_rounded, size: 16, color: Colors.cyanAccent),
                              const SizedBox(width: 6),
                              Text(
                                'Driver Service Payouts',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Driver Gross:', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey.shade600)),
                              Text('PHP ${NumberFormat('#,##0.00').format(totalDriverGross)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('PSDC Commission (5%):', style: TextStyle(fontSize: 12, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                              Text('PHP ${NumberFormat('#,##0.00').format(driverCommissions)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Driver Net (95%):', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey.shade600)),
                              Text('PHP ${NumberFormat('#,##0.00').format((totalDriverGross - driverCommissions).clamp(0.0, double.infinity))}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Item 3: Disbursed vs Pending Net
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.currency_exchange_rounded, size: 16, color: Colors.tealAccent),
                              const SizedBox(width: 6),
                              Text(
                                'Net Disbursement Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Disbursed Net:', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey.shade600)),
                              Text('PHP ${NumberFormat('#,##0.00').format(totalDisbursedNet)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Pending Net Releases:', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey.shade600)),
                              Text('PHP ${NumberFormat('#,##0.00').format(totalPendingNet)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Company Fleet Direct:', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey.shade600)),
                              Text('PHP ${NumberFormat('#,##0.00').format(companyFleetRevenue)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionHistoryCard(bool isDark) {
    final filteredRecords = _getFilteredCommissionRecords();
    final totalPages = (filteredRecords.length / _commissionHistoryPerPage).ceil();
    final currentPage = _commissionHistoryPage.clamp(1, totalPages > 0 ? totalPages : 1).toInt();
    final startIndex = (currentPage - 1) * _commissionHistoryPerPage;
    final pagedRecords = filteredRecords.skip(startIndex).take(_commissionHistoryPerPage).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _adminGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: _adminGold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Platform Commission & Disbursement History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _adminNavy.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _adminGold.withOpacity(0.4)),
                            ),
                            child: Text(
                              '${filteredRecords.length} records',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _adminGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Audit trail of all PSDC 5% commission earnings and partner/driver payout disbursements',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters and Search Bar
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search Field
              SizedBox(
                width: 280,
                height: 40,
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _commissionSearchQuery = val;
                      _commissionHistoryPage = 1;
                    });
                  },
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search ref, recipient, method...',
                    hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _commissionSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              setState(() {
                                _commissionSearchQuery = '';
                                _commissionHistoryPage = 1;
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Role Filter Pills
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCommissionFilterChip(
                    label: 'All Sources',
                    selected: _commissionRoleFilter == 'all',
                    onTap: () => setState(() {
                      _commissionRoleFilter = 'all';
                      _commissionHistoryPage = 1;
                    }),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildCommissionFilterChip(
                    label: 'Partners (5%)',
                    selected: _commissionRoleFilter == 'partner',
                    onTap: () => setState(() {
                      _commissionRoleFilter = 'partner';
                      _commissionHistoryPage = 1;
                    }),
                    isDark: isDark,
                    badgeColor: _adminGold,
                  ),
                  const SizedBox(width: 6),
                  _buildCommissionFilterChip(
                    label: 'Drivers (5%)',
                    selected: _commissionRoleFilter == 'driver',
                    onTap: () => setState(() {
                      _commissionRoleFilter = 'driver';
                      _commissionHistoryPage = 1;
                    }),
                    isDark: isDark,
                    badgeColor: Colors.cyanAccent,
                  ),
                ],
              ),

              // Status Filter Pills
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCommissionFilterChip(
                    label: 'All Status',
                    selected: _commissionStatusFilter == 'all',
                    onTap: () => setState(() {
                      _commissionStatusFilter = 'all';
                      _commissionHistoryPage = 1;
                    }),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildCommissionFilterChip(
                    label: 'Disbursed',
                    selected: _commissionStatusFilter == 'disbursed',
                    onTap: () => setState(() {
                      _commissionStatusFilter = 'disbursed';
                      _commissionHistoryPage = 1;
                    }),
                    isDark: isDark,
                    badgeColor: Colors.green,
                  ),
                  const SizedBox(width: 6),
                  _buildCommissionFilterChip(
                    label: 'Pending',
                    selected: _commissionStatusFilter == 'pending',
                    onTap: () => setState(() {
                      _commissionStatusFilter = 'pending';
                      _commissionHistoryPage = 1;
                    }),
                    isDark: isDark,
                    badgeColor: Colors.orange,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Table Content
          if (filteredRecords.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No commission or disbursement records match the filter criteria.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 1240),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.3), // Date & Time
                    1: FlexColumnWidth(1.1), // Booking Ref
                    2: FlexColumnWidth(2.3), // Recipient & Role
                    3: FlexColumnWidth(1.2), // Gross
                    4: FlexColumnWidth(1.3), // PSDC 5% Comm
                    5: FlexColumnWidth(1.3), // Net Payout
                    6: FlexColumnWidth(1.4), // Method & Ref
                    7: FlexColumnWidth(1.8), // Status (Generous width to prevent badge overflow)
                    8: FlexColumnWidth(1.3), // Receipt / Proof
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Header row
                    TableRow(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      children: [
                        _buildTableHeaderCell('DATE & TIME', isDark),
                        _buildTableHeaderCell('BOOKING REF', isDark),
                        _buildTableHeaderCell('RECIPIENT & ROLE', isDark),
                        _buildTableHeaderCell('GROSS VOLUME', isDark),
                        _buildTableHeaderCell('PSDC 5% COMM.', isDark),
                        _buildTableHeaderCell('NET DISBURSED', isDark),
                        _buildTableHeaderCell('METHOD & REF #', isDark),
                        _buildTableHeaderCell('STATUS', isDark),
                        _buildTableHeaderCell('PROOF', isDark),
                      ],
                    ),

                    // Data Rows
                    ...pagedRecords.map((item) {
                      final date = item['date'] as DateTime?;
                      final isDisbursed = item['is_disbursed'] == true;
                      final isPartner = item['type'] == 'partner';
                      final receiptUrl = item['receipt_url']?.toString().trim();
                      final hasReceipt = receiptUrl != null && receiptUrl.isNotEmpty;

                      return TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        children: [
                          // Date & Time
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  date != null ? DateFormat('MMM d, yyyy').format(date) : 'N/A',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (date != null)
                                  Text(
                                    DateFormat('h:mm a').format(date),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Booking Ref
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${item['booking_reference']}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? _adminGold : Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ),

                          // Recipient & Role
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['recipient_name']?.toString() ?? 'Recipient',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPartner ? _adminGold.withOpacity(0.18) : Colors.cyan.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isPartner ? 'Partner Vehicle' : 'Trip Driver',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isPartner ? _adminGold : Colors.cyanAccent,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item['recipient_subtitle']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Gross Amount
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Text(
                              'PHP ${NumberFormat('#,##0.00').format(item['gross_amount'] ?? 0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.grey.shade800,
                              ),
                            ),
                          ),

                          // PSDC 5% Commission
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PHP ${NumberFormat('#,##0.00').format(item['commission_amount'] ?? 0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _adminGold,
                                  ),
                                ),
                                Text(
                                  '5% Platform Fee',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isDark ? Colors.grey[500] : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Net Payout (95%)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Text(
                              'PHP ${NumberFormat('#,##0.00').format(item['net_amount'] ?? 0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDisbursed
                                    ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                                    : (isDark ? Colors.grey[300] : Colors.black87),
                              ),
                            ),
                          ),

                          // Method & Ref #
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['payout_method']?.toString() ?? 'GCash / Bank',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                                  ),
                                ),
                                if (item['payout_reference']?.toString().isNotEmpty == true)
                                  Text(
                                    'Ref: ${item['payout_reference']}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),

                          // Status
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDisbursed
                                      ? Colors.green.withOpacity(0.18)
                                      : (item['status'] == 'Eligible / Pending'
                                          ? Colors.orange.withOpacity(0.18)
                                          : Colors.grey.withOpacity(0.18)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isDisbursed ? Icons.check_circle_rounded : Icons.pending_rounded,
                                        size: 11,
                                        color: isDisbursed
                                            ? Colors.green
                                            : (item['status'] == 'Eligible / Pending' ? Colors.orange : Colors.grey),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item['status']?.toString() ?? 'Pending',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDisbursed
                                              ? Colors.green
                                              : (item['status'] == 'Eligible / Pending' ? Colors.orange : Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Proof Receipt
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: hasReceipt
                                  ? InkWell(
                                      onTap: () => _showReceiptProofDialog(
                                        receiptUrl,
                                        'Disbursement Proof #${item['booking_reference']} (${item['recipient_name']})',
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _adminGold.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _adminGold.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.image_rounded, size: 12, color: _adminGold),
                                            const SizedBox(width: 4),
                                            Text(
                                              'View Proof',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _adminGold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'No receipt',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // Pagination controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${startIndex + 1}–${(startIndex + _commissionHistoryPerPage).clamp(1, filteredRecords.length)} of ${filteredRecords.length} records',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: currentPage > 1
                          ? () => setState(() => _commissionHistoryPage = currentPage - 1)
                          : null,
                    ),
                    Text(
                      'Page $currentPage of ${totalPages > 0 ? totalPages : 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: currentPage < totalPages
                          ? () => setState(() => _commissionHistoryPage = currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey[300] : Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCommissionFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
    Color? badgeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (badgeColor != null ? badgeColor.withOpacity(0.2) : (isDark ? Colors.white12 : Colors.grey.shade200))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? (badgeColor ?? (isDark ? Colors.white38 : Colors.grey.shade400))
                : (isDark ? Colors.white12 : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? (badgeColor ?? (isDark ? Colors.white : Colors.black87))
                    : (isDark ? Colors.grey[400] : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _settingsInputDecoration(
    bool isDark, {
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
      hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade500),
      filled: true,
      fillColor: isDark ? AppColors.darkBgSecondary : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _buildSupportFaqEditor(bool isDark) {
    final faqs = _supportFaqsByRole[_supportFaqRole] ?? const <SupportFaq>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit the automatic answers shown before a user opens a live admin chat.',
          style: TextStyle(
            color: isDark ? Colors.grey : Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: const ['renter', 'partner', 'driver'].map((role) {
            final selected = _supportFaqRole == role;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => setState(() => _supportFaqRole = role),
              label: Text('${role[0].toUpperCase()}${role.substring(1)}'),
              selectedColor: AppColors.primary,
              backgroundColor: isDark
                  ? AppColors.darkBgSecondary
                  : Colors.grey.shade100,
              labelStyle: TextStyle(
                color: selected
                    ? Colors.black
                    : (isDark ? Colors.white : Colors.black87),
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.borderColor,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (_isLoadingSupportFaqs)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (faqs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text('No FAQ configuration is available.'),
          )
        else
          ...faqs.asMap().entries.map((entry) {
            final index = entry.key;
            final faq = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq.question,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('${_supportFaqRole}_${faq.key}'),
                    initialValue: faq.answer,
                    minLines: 3,
                    maxLines: 6,
                    enabled: !_isSavingSupportFaqs,
                    onChanged: (value) {
                      _supportFaqsByRole[_supportFaqRole]![index] = faq
                          .copyWith(answer: value);
                    },
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      height: 1.4,
                    ),
                    decoration: _settingsInputDecoration(
                      isDark,
                      label: 'Automatic reply',
                      hint: 'Enter the answer shown to users...',
                    ),
                  ),
                ],
              ),
            );
          }),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _isLoadingSupportFaqs || _isSavingSupportFaqs
                  ? null
                  : _loadSupportFaqSettings,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed:
                  _isLoadingSupportFaqs || _isSavingSupportFaqs || faqs.isEmpty
                  ? null
                  : _saveSupportFaqSettings,
              icon: _isSavingSupportFaqs
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isSavingSupportFaqs ? 'Saving...' : 'Save Auto-Replies',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showFullImageDialog(String url) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: OptimizedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                errorWidget: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 54,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
