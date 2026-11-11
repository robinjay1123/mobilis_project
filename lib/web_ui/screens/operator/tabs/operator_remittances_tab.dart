part of '../operator_web_screen.dart';

extension _OperatorRemittancesTab on _OperatorWebScreenState {
  Widget _buildRemittancesContent(bool isDark) {
    final gold = _operatorGold;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : _operatorInk;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.shade200;

    final records = _getCombinedOperatorRemittances();

    // Filter by search query
    final searchFiltered = records.where((item) {
      if (_remittanceSearchQuery.isEmpty) return true;
      final q = _remittanceSearchQuery.toLowerCase();
      final ref = (item['booking_reference']?.toString() ?? '').toLowerCase();
      final veh = (item['vehicle_name']?.toString() ?? '').toLowerCase();
      final numRef = (item['reference_number']?.toString() ?? '').toLowerCase();
      final customer = (item['customer_name']?.toString() ?? '').toLowerCase();
      return ref.contains(q) || veh.contains(q) || numRef.contains(q) || customer.contains(q);
    }).toList();

    // Filter by status chip
    final filtered = searchFiltered.where((item) {
      final s = item['status']?.toString().toLowerCase() ?? 'unremitted';
      switch (_selectedRemittanceFilter) {
        case 'due':
          return s == 'unremitted' || s == 'rejected';
        case 'pending_review':
          return s == 'pending_review';
        case 'remitted':
          return s == 'remitted';
        case 'rejected':
          return s == 'rejected';
        case 'all':
        default:
          return true;
      }
    }).toList();

    // Calculate metrics
    double totalRemittedAmount = 0.0;
    double pendingReviewAmount = 0.0;
    double dueToRemitAmount = 0.0;
    int remittedCount = 0;
    int pendingReviewCount = 0;
    int dueToRemitCount = 0;
    int rejectedCount = 0;

    for (final r in records) {
      final comm = (r['commission_amount'] as num?)?.toDouble() ?? 0.0;
      final s = r['status']?.toString().toLowerCase() ?? 'unremitted';
      if (s == 'remitted') {
        totalRemittedAmount += comm;
        remittedCount++;
      } else if (s == 'pending_review') {
        pendingReviewAmount += comm;
        pendingReviewCount++;
      } else if (s == 'rejected') {
        dueToRemitAmount += comm;
        dueToRemitCount++;
        rejectedCount++;
      } else {
        dueToRemitAmount += comm;
        dueToRemitCount++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Platform Commission Remittances',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (dueToRemitCount > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '$dueToRemitCount Due to Remit',
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track, remit, and verify 5% platform commissions for completed rental bookings.',
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: _isLoadingOperatorRemittances
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Remittances',
                onPressed: _isLoadingOperatorRemittances
                    ? null
                    : () => _loadOperatorRemittances(showLoading: true),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Metrics Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final width = isWide ? (constraints.maxWidth - (3 * 16)) / 4 : (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _buildRemittanceMetricTile(
                      label: 'Due to Remit',
                      value: _formatRemittanceCurrency(dueToRemitAmount),
                      subtext: '$dueToRemitCount booking${dueToRemitCount == 1 ? '' : 's'} awaiting remittance',
                      icon: Icons.pending_actions_rounded,
                      color: const Color(0xFFF59E0B),
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecondary: textSecondary,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildRemittanceMetricTile(
                      label: 'Under Admin Review',
                      value: _formatRemittanceCurrency(pendingReviewAmount),
                      subtext: '$pendingReviewCount booking${pendingReviewCount == 1 ? '' : 's'} under verification',
                      icon: Icons.hourglass_top_rounded,
                      color: const Color(0xFF38BDF8),
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecondary: textSecondary,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildRemittanceMetricTile(
                      label: 'Remitted & Verified',
                      value: _formatRemittanceCurrency(totalRemittedAmount),
                      subtext: '$remittedCount booking${remittedCount == 1 ? '' : 's'} confirmed by PSDC Admin',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF10B981),
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecondary: textSecondary,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildRemittanceMetricTile(
                      label: 'Completed Rentals',
                      value: records.length.toString(),
                      subtext: 'Completed managed bookings',
                      icon: Icons.task_alt_rounded,
                      color: gold,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecondary: textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Policy & Guidance Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: gold.withValues(alpha: 0.28)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: gold, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platform Commission & Remittance Guidelines',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• You retain 95% of each completed rental. The platform 5% commission is remitted to PSDC after the booking is completed.\n'
                        '• For Cash Handover: A clear photo of the physical cash bills is required as handover proof.\n'
                        '• For Digital Transfer: A clear screenshot of the GCash / Bank transfer receipt with the reference number is required.',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRemittanceFilterChip(
                        label: 'All',
                        count: records.length,
                        filterKey: 'all',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildRemittanceFilterChip(
                        label: 'Due to Remit',
                        count: dueToRemitCount,
                        filterKey: 'due',
                        isDark: isDark,
                        badgeColor: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      _buildRemittanceFilterChip(
                        label: 'Under Review',
                        count: pendingReviewCount,
                        filterKey: 'pending_review',
                        isDark: isDark,
                        badgeColor: const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 8),
                      _buildRemittanceFilterChip(
                        label: 'Remitted',
                        count: remittedCount,
                        filterKey: 'remitted',
                        isDark: isDark,
                        badgeColor: const Color(0xFF10B981),
                      ),
                      if (rejectedCount > 0) ...[
                        const SizedBox(width: 8),
                        _buildRemittanceFilterChip(
                          label: 'Rejected',
                          count: rejectedCount,
                          filterKey: 'rejected',
                          isDark: isDark,
                          badgeColor: const Color(0xFFEF4444),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Booking List / Cards
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 54,
                    color: gold.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _selectedRemittanceFilter == 'all'
                        ? 'No completed bookings found yet.'
                        : 'No bookings matching "$_selectedRemittanceFilter".',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Once a rental trip is completed, its 5% platform commission will automatically appear here.',
                    style: TextStyle(fontSize: 13, color: textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildOperatorRemittanceCard(item, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRemittanceMetricTile({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(fontSize: 11.5, color: textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRemittanceFilterChip({
    required String label,
    required int count,
    required String filterKey,
    required bool isDark,
    Color? badgeColor,
  }) {
    final isSelected = _selectedRemittanceFilter == filterKey;
    final gold = _operatorGold;

    return InkWell(
      onTap: () => setOperatorState(() => _selectedRemittanceFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? gold.withValues(alpha: 0.22) : gold.withValues(alpha: 0.18))
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? gold : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : _operatorNavyDeep)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (badgeColor ?? gold)
                    : (badgeColor?.withValues(alpha: 0.2) ?? (isDark ? Colors.white12 : Colors.grey.shade300)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (badgeColor ?? (isDark ? Colors.white70 : Colors.black87)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorRemittanceCard(Map<String, dynamic> item, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : _operatorInk;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.shade200;

    final bookingRef = item['booking_reference']?.toString() ?? 'BK';
    final vehicleTitle = item['vehicle_name']?.toString() ?? 'Vehicle';
    final gross = (item['rental_gross_amount'] as num?)?.toDouble() ?? 0.0;
    final commission = (item['commission_amount'] as num?)?.toDouble() ?? (gross * 0.05);
    final operatorShare = (gross - commission).clamp(0.0, double.infinity);
    final status = item['status']?.toString().toLowerCase() ?? 'unremitted';
    final proofUrl = item['proof_image_url']?.toString() ?? '';
    final remType = item['remittance_type']?.toString() ?? 'digital';
    final refNumber = item['reference_number']?.toString() ?? '';
    final operatorNotes = item['operator_notes']?.toString() ?? '';
    final rejectionReason = item['rejection_reason']?.toString() ?? '';
    final completedDate = item['date'] as DateTime?;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'remitted':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'Remitted & Confirmed';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'pending_review':
        statusColor = const Color(0xFF38BDF8);
        statusLabel = 'Under Admin Review';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'Proof Rejected';
        statusIcon = Icons.error_outline_rounded;
        break;
      case 'unremitted':
      default:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'Due to Remit';
        statusIcon = Icons.pending_actions_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'rejected' ? const Color(0xFFEF4444).withValues(alpha: 0.35) : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Reference, Vehicle, Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _operatorGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.directions_car_filled_rounded, color: _operatorGold, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#$bookingRef',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (completedDate != null)
                                Text(
                                  DateFormat('MMM d, yyyy').format(completedDate.toLocal()),
                                  style: TextStyle(fontSize: 12, color: textSecondary),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vehicleTitle,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Financial Summary Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rental Gross', style: TextStyle(color: textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      _formatRemittanceCurrency(gross),
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Container(width: 1, height: 28, color: borderColor),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You Retain (95%)', style: TextStyle(color: textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      _formatRemittanceCurrency(operatorShare),
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Container(width: 1, height: 28, color: borderColor),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Platform Commission (5%)', style: TextStyle(color: _operatorGold, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      _formatRemittanceCurrency(commission),
                      style: TextStyle(color: _operatorGold, fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Rejection Alert Box
          if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rejection Note from Admin:',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rejectionReason,
                          style: TextStyle(color: textColor, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Submitted Proof Details (if uploaded)
          if (proofUrl.isNotEmpty && proofUrl != 'in_office_manual') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showEnlargedProofDialog(
                    proofUrl,
                    bookingRef,
                    item['operator_name']?.toString() ?? 'Operator',
                    remType,
                    isDark,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Image.network(
                            proofUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black26,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, size: 20),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            color: Colors.black38,
                            child: const Center(
                              child: Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            remType == 'cash' ? Icons.payments_rounded : Icons.phone_android_rounded,
                            size: 14,
                            color: remType == 'cash' ? Colors.greenAccent : Colors.lightBlueAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            remType == 'cash' ? 'Cash Handover Photo' : 'Digital Transfer Receipt',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (refNumber.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• Ref: $refNumber',
                              style: TextStyle(color: textSecondary, fontSize: 11.5),
                            ),
                          ],
                        ],
                      ),
                      if (operatorNotes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '"$operatorNotes"',
                          style: TextStyle(color: textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
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
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == 'unremitted' || status == 'rejected')
                FilledButton.icon(
                  onPressed: () => _showSubmitRemittanceDialog(item, isDark),
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(
                    status == 'rejected'
                        ? 'Re-upload Proof & Resubmit (${_formatRemittanceCurrency(commission)})'
                        : 'Remit Platform Commission (${_formatRemittanceCurrency(commission)})',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _operatorGold,
                    foregroundColor: _operatorNavyDeep,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else if (status == 'pending_review')
                OutlinedButton.icon(
                  onPressed: proofUrl.isNotEmpty && proofUrl != 'in_office_manual'
                      ? () => _showEnlargedProofDialog(
                            proofUrl,
                            bookingRef,
                            item['operator_name']?.toString() ?? 'Operator',
                            remType,
                            isDark,
                          )
                      : null,
                  icon: const Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFF38BDF8)),
                  label: const Text('Under Review • View Submitted Proof'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else if (status == 'remitted')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Verified & Confirmed by PSDC Admin',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSubmitRemittanceDialog(Map<String, dynamic> item, bool isDark) {
    final gold = _operatorGold;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : _operatorInk;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final messenger = ScaffoldMessenger.of(context);

    final bookingRef = item['booking_reference']?.toString() ?? '';
    final vehicleName = item['vehicle_name']?.toString() ?? '';
    final gross = (item['rental_gross_amount'] as num?)?.toDouble() ?? 0.0;
    final commission = (item['commission_amount'] as num?)?.toDouble() ?? (gross * 0.05);

    String remittanceType = 'digital';
    final refNumberController = TextEditingController(text: item['reference_number']?.toString() ?? '');
    final notesController = TextEditingController(text: item['operator_notes']?.toString() ?? '');
    Uint8List? proofBytes;
    String? proofFileName;
    bool isSubmitting = false;
    String? errorMessage;

    showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.price_check_rounded, color: gold, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Remit Platform Commission',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Booking & Commission Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Booking Reference:', style: TextStyle(color: textSecondary, fontSize: 13)),
                              Text('#$bookingRef', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Vehicle:', style: TextStyle(color: textSecondary, fontSize: 13)),
                              Text(vehicleName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Rental Gross:', style: TextStyle(color: textSecondary, fontSize: 13)),
                              Text(_formatRemittanceCurrency(gross), style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Platform 5% Commission Due:',
                                style: TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _formatRemittanceCurrency(commission),
                                style: TextStyle(color: gold, fontSize: 17, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Remittance Method Selector
                    Text(
                      'Payment Method',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => remittanceType = 'digital'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                              decoration: BoxDecoration(
                                color: remittanceType == 'digital'
                                    ? gold.withValues(alpha: 0.18)
                                    : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: remittanceType == 'digital' ? gold : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_android_rounded,
                                    size: 18,
                                    color: remittanceType == 'digital' ? gold : textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Digital Transfer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: remittanceType == 'digital' ? textColor : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => remittanceType = 'cash'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                              decoration: BoxDecoration(
                                color: remittanceType == 'cash'
                                    ? gold.withValues(alpha: 0.18)
                                    : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: remittanceType == 'cash' ? gold : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.payments_rounded,
                                    size: 18,
                                    color: remittanceType == 'cash' ? gold : textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cash Handover',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: remittanceType == 'cash' ? textColor : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Reference Number (for digital)
                    if (remittanceType == 'digital') ...[
                      Text(
                        'Transfer Reference Number *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: refNumberController,
                        decoration: InputDecoration(
                          hintText: 'e.g. GCash / Bank Ref: 123456789012',
                          prefixIcon: const Icon(Icons.receipt_long_rounded, size: 20),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Proof Image Upload Box
                    Text(
                      remittanceType == 'cash'
                          ? 'Photo of Cash Bills *'
                          : 'Transfer Receipt / Screenshot *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 6),
                    if (proofBytes != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                proofBytes!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    proofFileName ?? 'proof_image.jpg',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${(proofBytes!.lengthInBytes / (1024 * 1024)).toStringAsFixed(2)} MB • Ready to upload',
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final res = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                                  withData: true,
                                );
                                if (res != null && res.files.isNotEmpty) {
                                  setModalState(() {
                                    proofBytes = res.files.first.bytes;
                                    proofFileName = res.files.first.name;
                                    errorMessage = null;
                                  });
                                }
                              },
                              icon: const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('Change'),
                            ),
                          ],
                        ),
                      )
                    else
                      InkWell(
                        onTap: () async {
                          final res = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                            withData: true,
                          );
                          if (res != null && res.files.isNotEmpty) {
                            setModalState(() {
                              proofBytes = res.files.first.bytes;
                              proofFileName = res.files.first.name;
                              errorMessage = null;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.cloud_upload_outlined, size: 36, color: gold),
                              const SizedBox(height: 8),
                              Text(
                                remittanceType == 'cash'
                                    ? 'Click to upload photo of cash bills'
                                    : 'Click to upload GCash / Bank transfer receipt',
                                style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'JPG, PNG, or WEBP (Max 15MB)',
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Operator Notes Field
                    Text(
                      'Notes for Admin (Optional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Handed cash in office to Admin / Paid via GCash account',
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      ),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Dialog Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (proofBytes == null) {
                                    setModalState(() {
                                      errorMessage = remittanceType == 'cash'
                                          ? 'Please attach a clear photo of the cash bills.'
                                          : 'Please attach a screenshot of your transfer receipt.';
                                    });
                                    return;
                                  }
                                  if (remittanceType == 'digital' && refNumberController.text.trim().isEmpty) {
                                    setModalState(() {
                                      errorMessage = 'Please enter the transaction reference number.';
                                    });
                                    return;
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                    errorMessage = null;
                                  });

                                  try {
                                    final operatorId = _supabase.auth.currentUser?.id ?? '';
                                    final opName = (_operatorProfile['full_name']?.toString().trim().isNotEmpty == true)
                                        ? _operatorProfile['full_name'].toString().trim()
                                        : 'Operator';
                                    final bookingId = item['booking_id']?.toString() ?? '';

                                    final proofUrl = await OperatorRemittanceService().uploadRemittanceProof(
                                      bytes: proofBytes!,
                                      fileName: proofFileName ?? 'remittance_proof.jpg',
                                      bookingId: bookingId,
                                      operatorId: operatorId,
                                    );

                                    await OperatorRemittanceService().submitRemittance(
                                      bookingId: bookingId,
                                      bookingReference: bookingRef,
                                      operatorId: operatorId,
                                      operatorName: opName,
                                      vehicleName: vehicleName,
                                      rentalGrossAmount: gross,
                                      commissionAmount: commission,
                                      remittanceType: remittanceType,
                                      proofImageUrl: proofUrl,
                                      referenceNumber: refNumberController.text.trim(),
                                      operatorNotes: notesController.text.trim(),
                                    );

                                    if (ctx.mounted) Navigator.pop(ctx);
                                    await _loadOperatorRemittances();

                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('✨ Remittance for #$bookingRef submitted for Admin review!'),
                                          backgroundColor: const Color(0xFF10B981),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setModalState(() {
                                        isSubmitting = false;
                                        errorMessage = 'Failed to submit remittance: $e';
                                      });
                                    }
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.send_rounded, size: 16),
                          label: Text(
                            isSubmitting
                                ? 'Uploading & Submitting...'
                                : 'Submit Remittance (${_formatRemittanceCurrency(commission)})',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: _operatorNavyDeep,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEnlargedProofDialog(
    String imageUrl,
    String bookingRef,
    String operatorName,
    String remittanceType,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : _operatorInk;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remittance Proof: #$bookingRef',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '$operatorName • ${remittanceType == 'cash' ? 'Cash Handover Photo' : 'Digital Transfer Receipt'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, prog) {
                            if (prog == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('Could not load image.'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getCombinedOperatorRemittances() {
    final list = <Map<String, dynamic>>[];
    final remMap = <String, OperatorRemittanceModel>{};
    for (final rem in _operatorRemittances) {
      remMap[rem.bookingId] = rem;
    }

    final handledBookingIds = <String>{};

    for (final b in _operatorManagedBookings()) {
      final bId = b['id']?.toString() ?? '';
      if (bId.isEmpty) continue;

      final isCompleted = bookingStatusGroup(b['status']) == BookingStatusGroup.completed ||
          (b['status']?.toString().toLowerCase().trim() == 'completed');
      if (!isCompleted) continue;

      handledBookingIds.add(bId);

      final ref = b['booking_reference']?.toString().isNotEmpty == true
          ? b['booking_reference'].toString()
          : (bId.length > 8 ? bId.substring(0, 8).toUpperCase() : bId);

      final vehicle = b['vehicles'] is Map ? Map<String, dynamic>.from(b['vehicles'] as Map) : <String, dynamic>{};
      final vehicleDesc = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
      final vehicleTitle = vehicleDesc.isNotEmpty
          ? vehicleDesc
          : (b['vehicle_title']?.toString() ?? 'Managed Vehicle');

      final gross = (b['rental_subtotal'] as num?)?.toDouble() ??
          (b['total_price'] as num?)?.toDouble() ??
          0.0;
      final comm = (b['partner_payout_commission'] as num?)?.toDouble() ?? (gross * 0.05);

      final customer = b['users'] is Map
          ? (b['users']['full_name'] ?? b['users']['name'] ?? '')
          : (b['renter_name'] ?? '');

      final rem = remMap[bId];

      if (rem != null) {
        list.add({
          'remittance_id': rem.id,
          'booking_id': bId,
          'booking_reference': ref,
          'vehicle_name': rem.vehicleName.isNotEmpty ? rem.vehicleName : vehicleTitle,
          'customer_name': customer,
          'rental_gross_amount': rem.rentalGrossAmount > 0 ? rem.rentalGrossAmount : gross,
          'commission_amount': rem.commissionAmount > 0 ? rem.commissionAmount : comm,
          'remittance_type': rem.remittanceType,
          'proof_image_url': rem.proofImageUrl,
          'reference_number': rem.referenceNumber,
          'operator_notes': rem.operatorNotes,
          'status': rem.status,
          'date': rem.submittedAt,
          'rejection_reason': rem.rejectionReason,
        });
      } else {
        list.add({
          'remittance_id': '',
          'booking_id': bId,
          'booking_reference': ref,
          'vehicle_name': vehicleTitle,
          'customer_name': customer,
          'rental_gross_amount': gross,
          'commission_amount': comm,
          'remittance_type': 'digital',
          'proof_image_url': '',
          'reference_number': '',
          'operator_notes': '',
          'status': b['operator_remittance_status']?.toString().toLowerCase() ?? 'unremitted',
          'date': DateTime.tryParse(b['completed_at']?.toString() ?? '') ?? DateTime.tryParse(b['created_at']?.toString() ?? ''),
          'rejection_reason': null,
        });
      }
    }

    // Also include any historical remittances that might not be in _recentBookings
    for (final rem in _operatorRemittances) {
      if (!handledBookingIds.contains(rem.bookingId)) {
        list.add({
          'remittance_id': rem.id,
          'booking_id': rem.bookingId,
          'booking_reference': rem.bookingReference,
          'vehicle_name': rem.vehicleName.isNotEmpty ? rem.vehicleName : 'Managed Vehicle',
          'customer_name': '',
          'rental_gross_amount': rem.rentalGrossAmount,
          'commission_amount': rem.commissionAmount,
          'remittance_type': rem.remittanceType,
          'proof_image_url': rem.proofImageUrl,
          'reference_number': rem.referenceNumber,
          'operator_notes': rem.operatorNotes,
          'status': rem.status,
          'date': rem.submittedAt,
          'rejection_reason': rem.rejectionReason,
        });
      }
    }

    // Sort: Due/Rejected first, then pending_review, then remitted; within each group, by date descending
    list.sort((a, b) {
      final sa = a['status']?.toString().toLowerCase() ?? 'unremitted';
      final sb = b['status']?.toString().toLowerCase() ?? 'unremitted';

      int rank(String s) {
        if (s == 'rejected') return 0;
        if (s == 'unremitted') return 1;
        if (s == 'pending_review') return 2;
        if (s == 'remitted') return 3;
        return 4;
      }

      final rankCompare = rank(sa).compareTo(rank(sb));
      if (rankCompare != 0) return rankCompare;

      final da = a['date'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b['date'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    return list;
  }

  String _formatRemittanceCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '₱${formatter.format(amount)}';
  }
}

