part of '../operator_web_screen.dart';

extension _OperatorDashboardTab on _OperatorWebScreenState {
  Widget _buildDashboardContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Operations Summary',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : _operatorInk,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7D6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: _operatorGold),
                    SizedBox(width: 7),
                    Text(
                      'LIVE SYSTEM STATUS',
                      style: TextStyle(
                        color: _operatorInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!MpinService().currentState().isConfigured) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A200B)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(
                    alpha: isDark ? 0.4 : 0.6,
                  ),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Desk Authorization MPIN Not Configured',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF92400E),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Renters paying via PSDC Desk Cash or Over-the-Counter POS require your 6-digit MPIN to authorize immediate payment approval.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey[300]
                                : const Color(0xFFB45309),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showOperatorMpinSetupDialog(isDark),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF1E293B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.pin_rounded, size: 18),
                    label: const Text(
                      'Setup MPIN Now',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildDashboardSnapshots(isDark),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 18)) / columns;
              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  SizedBox(
                    width: width,
                    child: _buildStatCard(
                      'Active Trips',
                      _activeBookings.toString(),
                      Icons.route_outlined,
                      const Color(0xFF0284C7),
                      isDark,
                      onTap: () => _openDashboardSection(
                        selectedIndex: 1,
                        bookingFilter: 'ongoing',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildStatCard(
                      'Pending Assignments',
                      _recentBookings
                          .where(
                            (booking) =>
                                bookingStatusGroup(booking['status']) ==
                                BookingStatusGroup.pending,
                          )
                          .length
                          .toString(),
                      Icons.assignment_late_outlined,
                      const Color(0xFFEF4444),
                      isDark,
                      onTap: () => _openDashboardSection(
                        selectedIndex: 1,
                        bookingFilter: 'pending',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildStatCard(
                      'Vehicles',
                      _totalVehicles.toString(),
                      Icons.directions_car_outlined,
                      const Color(0xFF10B981),
                      isDark,
                      onTap: () => _openDashboardSection(selectedIndex: 4),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildStatCard(
                      'Total Bookings',
                      _totalBookings.toString(),
                      Icons.fact_check_outlined,
                      const Color(0xFFF59E0B),
                      isDark,
                      onTap: () => _openDashboardSection(
                        selectedIndex: 1,
                        bookingFilter: 'all',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          _buildCard(
            'Live Booking Queue',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incoming and recent requests awaiting operator action',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                Scrollbar(
                  controller: _dashboardQueueScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _dashboardQueueScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildBookingsTable(isDark),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedIndex = 1),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                    label: const Text('View all bookings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : _operatorInk,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardSnapshots(bool isDark) {
    final releasedSettlements = _operatorSettlements
        .where(
          (settlement) =>
              settlement['status']?.toString().trim().toLowerCase() ==
              'released',
        )
        .toList();
    final paidCompletedFallback = _paidCompletedWithoutSettlement(
      bookings: _operatorManagedBookings(),
      settlements: releasedSettlements,
    );
    final managedValue =
        releasedSettlements.fold<double>(
          0,
          (total, settlement) =>
              total +
              ((settlement['operator_managed_amount'] as num?)?.toDouble() ??
                  0),
        ) +
        _operatorManagedFallbackRevenue(paidCompletedFallback);
    final settledTripCount =
        releasedSettlements.length + paidCompletedFallback.length;
    final tracked = _visibleTrackingLocations();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
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
                          color: Colors.black.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TOTAL MANAGED REVENUE',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'PHP ${_formatCurrency(managedValue)}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Aggregated from ${_formatNumber(settledTripCount)} completed trips',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => _openDashboardSection(selectedIndex: 7),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Revenue Analytics',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: Colors.amber,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.black,
                  size: 42,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildDashboardInsightCard(
          title: 'Live Tracking Snapshot',
          value: '${_formatNumber(tracked.length)} Active Vehicles',
          description: tracked.isEmpty
              ? 'No company vehicles are transmitting an active trip location.'
              : 'Authorized company trips are currently transmitting location data.',
          icon: Icons.my_location_rounded,
          accent: const Color(0xFF1976D2),
          buttonLabel: 'Open Live Tracking',
          onTap: () => _openDashboardSection(selectedIndex: 6),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildDashboardInsightCard({
    required String title,
    required String value,
    required String description,
    required IconData icon,
    required Color accent,
    required String buttonLabel,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 205),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : _operatorInk,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              height: 1.35,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: Text(buttonLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : _operatorInk,
              minimumSize: const Size(0, 43),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String rawValue,
    IconData icon,
    Color color,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    final parsedNum = num.tryParse(rawValue);
    final value = parsedNum != null ? _formatNumber(parsedNum) : rawValue;
    final borderRadius = BorderRadius.circular(18);

    final effectiveColor = isDark
        ? (color == _operatorNavy || color.computeLuminance() < 0.22
            ? const Color(0xFF38BDF8)
            : color)
        : (color == _operatorNavy
            ? const Color(0xFF0284C7)
            : color);

    final cardWidget = Semantics(
      button: onTap != null,
      label: onTap == null ? null : 'Open $title',
      child: Material(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          mouseCursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          borderRadius: borderRadius,
          hoverColor: _operatorGold.withOpacity(0.08),
          child: Container(
            constraints: const BoxConstraints(minHeight: 110),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: isDark
                    ? effectiveColor.withOpacity(0.25)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: effectiveColor.withOpacity(isDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: effectiveColor.withOpacity(isDark ? 0.45 : 0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: effectiveColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : _operatorInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: 'Click to view $title details',
      waitDuration: const Duration(milliseconds: 400),
      child: cardWidget,
    );
  }

  void _openDashboardSection({
    required int selectedIndex,
    String? bookingFilter,
  }) {
    setState(() {
      _selectedIndex = selectedIndex;
      if (bookingFilter != null) {
        _bookingFilter = bookingFilter;
        _bookingPage = 0;
        _bookingSearchQuery = '';
        _bookingSearchController.clear();
      }
    });
  }

  Widget _buildCard(String title, Widget content, bool isDark) {
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
}

