part of '../admin_web_screen.dart';

extension AdminDashboardTab on _AdminWebScreenState {
  Widget _buildDashboardContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Banner
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFD97706,
                  ).withValues(alpha: isDark ? 0.35 : 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.monetization_on_rounded,
                            color: Colors.black.withValues(alpha: 0.65),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TOTAL REVENUE',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.65),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'PHP ${_formatCurrency(_totalRevenue)}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Aggregated from ${_formatNumber(_allBookings.where(_isValidRevenueBooking).length)} paid & active bookings (excludes cancelled)',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Colors.black,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // Stats Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 1.55,
            children: [
              _buildStatCard(
                title: 'Total Renters',
                value: _totalUsers.toString(),
                icon: Icons.person_rounded,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
                subtitle: 'Registered customer accounts',
                onTap: () {
                  setState(() {
                    _userRoleFilter = 'renter';
                    _selectedIndex = 1;
                  });
                },
              ),
              _buildStatCard(
                title: 'Partners',
                value: _totalPartners.toString(),
                icon: Icons.business_rounded,
                color: const Color(0xFF10B981),
                isDark: isDark,
                subtitle: 'Registered vehicle partners',
                onTap: () {
                  setState(() {
                    _userRoleFilter = 'partner';
                    _selectedIndex = 1;
                  });
                },
              ),
              _buildStatCard(
                title: 'Operators',
                value: _totalOperators.toString(),
                icon: Icons.shield_rounded,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
                subtitle: 'PSDC fleet administrators',
                onTap: () {
                  setState(() {
                    _userRoleFilter = 'operator';
                    _selectedIndex = 1;
                  });
                },
              ),
              _buildStatCard(
                title: 'Ongoing Bookings',
                value: _activeBookings.toString(),
                icon: Icons.event_available_rounded,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                subtitle: 'Active trips currently on road',
                onTap: () {
                  setState(() {
                    _bookingStatusFilter = 'active';
                    _selectedIndex = 3;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildCard(
                  'Recent Bookings',
                  _buildRecentBookingsTable(isDark),
                  isDark,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildCard(
                  'Booking Status Distribution',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Real-time breakdown of bookings by status',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildBookingStatusChartWithLegend(
                        isDark,
                        chartHeight: 180,
                      ),
                    ],
                  ),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusItem(
    String name,
    String status,
    Color color,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey.shade800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '• $status',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: 'Click to view $title details ($subtitle)',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: color.withValues(alpha: 0.08),
          splashColor: color.withValues(alpha: 0.12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? color.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.1 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: color,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildCard(String title, Widget content, bool isDark) {
    return Container(
      clipBehavior: Clip.antiAlias,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildRecentBookingsTable(bool isDark) {
    if (_allBookings.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(40), child: Text('No bookings')),
      );
    }

    final totalPages = (_allBookings.length / _recentBookingsPerPage).ceil();
    final currentPage = _recentBookingsPage.clamp(1, totalPages).toInt();
    final startIndex = (currentPage - 1) * _recentBookingsPerPage;
    final endIndex = (startIndex + _recentBookingsPerPage).clamp(
      0,
      _allBookings.length,
    );
    final pageBookings = _allBookings.sublist(startIndex, endIndex);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    horizontalMargin: 16,
                    columnSpacing: 32,
                    columns: [
                      DataColumn(
                        label: Text(
                          'Vehicle',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Renter',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Status',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Amount',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                    rows: pageBookings.map((booking) {
                      final vehicle =
                          (booking['vehicles'] as Map<String, dynamic>?) ??
                          (booking['vehicle'] as Map<String, dynamic>?);
                      final renterMap =
                          (booking['renter'] as Map<String, dynamic>?) ??
                          (booking['users'] as Map<String, dynamic>?) ??
                          (booking['user'] as Map<String, dynamic>?);
                      final renterName =
                          (renterMap?['full_name'] as String?)?.isNotEmpty ==
                              true
                          ? renterMap!['full_name'] as String
                          : ((renterMap?['name'] as String?)?.isNotEmpty == true
                                ? renterMap!['name'] as String
                                : ((booking['renter_name'] as String?)
                                              ?.isNotEmpty ==
                                          true
                                      ? booking['renter_name'] as String
                                      : ((booking['user_name'] as String?)
                                                    ?.isNotEmpty ==
                                                true
                                            ? booking['user_name'] as String
                                            : 'Unknown Renter')));
                      final brand = vehicle?['brand']?.toString().trim() ?? '';
                      final model = vehicle?['model']?.toString().trim() ?? '';
                      final combo = [brand, model].where((part) => part.isNotEmpty).join(' ');
                      final vName = vehicle?['vehicle_name']?.toString().trim() ?? '';
                      final vehicleTitle = combo.isNotEmpty
                          ? combo
                          : (vName.isNotEmpty &&
                                  vName.toLowerCase() != 'partner vehicle' &&
                                  vName.toLowerCase() != 'unknown vehicle'
                              ? vName
                              : (vehicle?['plate_number']?.toString().isNotEmpty == true
                                  ? 'Vehicle (${vehicle!['plate_number']})'
                                  : (booking['vehicle_name']?.toString() ?? 'Partner Vehicle')));
                      final status = booking['status'] as String? ?? 'pending';
                      final total =
                          (booking['total_cost'] as num?)?.toDouble() ??
                          (booking['amount'] as num?)?.toDouble() ??
                          0;

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  vehicleTitle.isNotEmpty
                                      ? vehicleTitle
                                      : 'Unknown Vehicle',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                if (!_viewedBookingIds.contains(booking['id']?.toString())) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              renterName,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          DataCell(_buildStatusBadge(status)),
                          DataCell(
                            Text(
                              'PHP ${total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Divider(
          height: 1,
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing ${startIndex + 1}-$endIndex of ${_allBookings.length}',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Previous page',
              onPressed: currentPage > 1
                  ? () => setState(() => _recentBookingsPage = currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$currentPage / $totalPages',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: currentPage < totalPages
                  ? () => setState(() => _recentBookingsPage = currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final group = bookingStatusGroup(status);
    final color = bookingStatusColor(group);
    final label = bookingStatusLabel(group);

    final statusDescription = switch (group) {
      BookingStatusGroup.pending => 'Pending: Reservation is waiting for operator/admin review',
      BookingStatusGroup.approved => 'Approved: Confirmed and awaiting vehicle handover',
      BookingStatusGroup.ongoing => 'Ongoing: Vehicle currently on trip with customer',
      BookingStatusGroup.completed => 'Completed: Rental concluded and successfully settled',
      BookingStatusGroup.cancelled => 'Cancelled: Booking was declined or cancelled',
      _ => 'Status: $label',
    };

    return Tooltip(
      message: statusDescription,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatus(bool isDark) {
    return Column(
      children: [
        _buildStatusRow('Database', 'Connected', Colors.green, isDark),
        const Divider(height: 24),
        _buildStatusRow('Auth Service', 'Active', Colors.green, isDark),
        const Divider(height: 24),
        _buildStatusRow('Storage', 'Operational', Colors.green, isDark),
        const Divider(height: 24),
        _buildStatusRow('API', 'Running', Colors.green, isDark),
      ],
    );
  }

  Widget _buildStatusRow(String name, String status, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        Text(
          status,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
