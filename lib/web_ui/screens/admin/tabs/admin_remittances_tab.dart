part of '../admin_web_screen.dart';

extension _AdminRemittancesTab on _AdminWebScreenState {
  Widget _buildOperatorRemittancesContent(bool isDark) {
    final adminGold = _adminGold;
    final cardBg = isDark ? const Color(0xFF021F35) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? AppColors.primary.withValues(alpha: 0.25) : Colors.grey.shade300;

    // Combine all completed partner bookings with remittance records
    final combinedRecords = _getCombinedRemittanceRecords();

    // Filter by search query
    final searchFiltered = combinedRecords.where((item) {
      if (_remittanceSearchQuery.isEmpty) return true;
      final q = _remittanceSearchQuery.toLowerCase();
      final ref = (item['booking_reference']?.toString() ?? '').toLowerCase();
      final op = (item['operator_name']?.toString() ?? '').toLowerCase();
      final veh = (item['vehicle_name']?.toString() ?? '').toLowerCase();
      final numRef = (item['reference_number']?.toString() ?? '').toLowerCase();
      return ref.contains(q) || op.contains(q) || veh.contains(q) || numRef.contains(q);
    }).toList();

    // Filter by status chip
    final filtered = searchFiltered.where((item) {
      final s = item['status']?.toString().toLowerCase() ?? 'unremitted';
      switch (_selectedRemittanceFilter) {
        case 'pending_review':
          return s == 'pending_review';
        case 'unremitted':
          return s == 'unremitted';
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
    double unremittedAmount = 0.0;
    int pendingReviewCount = 0;
    int unremittedCount = 0;
    int remittedCount = 0;

    for (final r in combinedRecords) {
      final comm = (r['commission_amount'] as num?)?.toDouble() ?? 0.0;
      final s = r['status']?.toString().toLowerCase() ?? 'unremitted';
      if (s == 'remitted') {
        totalRemittedAmount += comm;
        remittedCount++;
      } else if (s == 'pending_review') {
        pendingReviewAmount += comm;
        pendingReviewCount++;
      } else if (s == 'unremitted' || s == 'rejected') {
        unremittedAmount += comm;
        unremittedCount++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: adminGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.price_check_rounded,
                    color: adminGold,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operator Commission Remittance & Profit Tracking',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verify and confirm platform commission remittances from vehicle operators. Review uploaded cash handover photos or digital transfer receipts.',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                IconButton.filledTonal(
                  onPressed: _isLoadingOperatorRemittances ? null : _loadOperatorRemittances,
                  icon: _isLoadingOperatorRemittances
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 22),
                  tooltip: 'Refresh Remittances',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Stats Metrics Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 950;
              final cards = [
                _buildRemittanceStatCard(
                  'Total Remitted Profit',
                  '₱${NumberFormat('#,##0.00').format(totalRemittedAmount)}',
                  '$remittedCount bookings remitted',
                  Icons.check_circle_rounded,
                  const Color(0xFF10B981),
                  isDark,
                ),
                _buildRemittanceStatCard(
                  'Pending Admin Verification',
                  '₱${NumberFormat('#,##0.00').format(pendingReviewAmount)}',
                  '$pendingReviewCount submitted with proof',
                  Icons.hourglass_top_rounded,
                  Colors.amber.shade700,
                  isDark,
                ),
                _buildRemittanceStatCard(
                  'Awaiting Operator Remit',
                  '₱${NumberFormat('#,##0.00').format(unremittedAmount)}',
                  '$unremittedCount bookings due',
                  Icons.warning_amber_rounded,
                  Colors.orangeAccent,
                  isDark,
                ),
                _buildRemittanceStatCard(
                  'Total Completed Bookings',
                  '${combinedRecords.length}',
                  'Partner fleet completed trips',
                  Icons.directions_car_rounded,
                  Colors.blue,
                  isDark,
                ),
              ];

              if (isNarrow) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 24) / 2, child: c)).toList(),
                );
              }

              return Row(
                children: cards.map((c) => Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: c,
                ))).toList(),
              );
            },
          ),
          const SizedBox(height: 22),

          // Search & Filter Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 12,
              children: [
                // Search box
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360, minWidth: 260),
                  child: TextField(
                    controller: TextEditingController(text: _remittanceSearchQuery)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _remittanceSearchQuery.length),
                      ),
                    onChanged: (val) => setAdminState(() => _remittanceSearchQuery = val),
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by Booking #, Operator, Vehicle...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                      suffixIcon: _remittanceSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setAdminState(() => _remittanceSearchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                ),

                // Status Filter Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildRemittanceFilterChip('All (${combinedRecords.length})', 'all', isDark),
                    _buildRemittanceFilterChip(
                      'For Review ($pendingReviewCount)',
                      'pending_review',
                      isDark,
                      accentColor: Colors.amber.shade700,
                    ),
                    _buildRemittanceFilterChip(
                      'Awaiting Operator ($unremittedCount)',
                      'unremitted',
                      isDark,
                      accentColor: Colors.orangeAccent,
                    ),
                    _buildRemittanceFilterChip(
                      'Remitted ($remittedCount)',
                      'remitted',
                      isDark,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Remittances List / Grid
          if (_isLoadingOperatorRemittances)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _remittanceSearchQuery.isNotEmpty
                        ? 'No remittances match "$_remittanceSearchQuery"'
                        : 'No remittances found for this filter',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When operators complete bookings and submit cash or digital transfer proofs, they will appear here for verification.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1050;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 2 : 1,
                    mainAxisExtent: 290,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildRemittanceCard(item, isDark);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRemittanceStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF021F35) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? AppColors.primary.withValues(alpha: 0.25) : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemittanceFilterChip(
    String label,
    String value,
    bool isDark, {
    Color? accentColor,
  }) {
    final isSelected = _selectedRemittanceFilter == value;
    final adminGold = _adminGold;
    final activeColor = accentColor ?? adminGold;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setAdminState(() => _selectedRemittanceFilter = value),
      selectedColor: activeColor,
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected
            ? activeColor
            : (isDark ? AppColors.primary.withValues(alpha: 0.2) : Colors.grey.shade300),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildRemittanceCard(Map<String, dynamic> item, bool isDark) {
    final adminGold = _adminGold;
    final cardBg = isDark ? const Color(0xFF021F35) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? AppColors.primary.withValues(alpha: 0.25) : Colors.grey.shade300;

    final bookingRef = item['booking_reference']?.toString() ?? '';
    final operatorName = item['operator_name']?.toString() ?? 'Operator';
    final vehicleName = item['vehicle_name']?.toString() ?? 'Partner Vehicle';
    final gross = (item['rental_gross_amount'] as num?)?.toDouble() ?? 0.0;
    final comm = (item['commission_amount'] as num?)?.toDouble() ?? 0.0;
    final status = item['status']?.toString().toLowerCase() ?? 'unremitted';
    final remittanceType = item['remittance_type']?.toString() ?? 'digital';
    final proofUrl = item['proof_image_url']?.toString() ?? '';
    final refNumber = item['reference_number']?.toString() ?? '';
    final notes = item['operator_notes']?.toString() ?? '';
    final date = item['date'] is DateTime ? item['date'] as DateTime : null;
    final rejectionReason = item['rejection_reason']?.toString();

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
        statusColor = Colors.amber.shade700;
        statusLabel = 'Under Review (Proof Uploaded)';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'Proof Rejected';
        statusIcon = Icons.cancel_rounded;
        break;
      case 'unremitted':
      default:
        statusColor = Colors.orangeAccent;
        statusLabel = 'Pending Operator Remittance';
        statusIcon = Icons.pending_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'pending_review'
              ? Colors.amber.withValues(alpha: 0.6)
              : borderColor,
          width: status == 'pending_review' ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Booking Ref + Status Badge + Remittance Type
          Row(
            children: [
              // Booking Ref Chip
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: bookingRef));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied "#$bookingRef" to clipboard!'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: adminGold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: adminGold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#$bookingRef',
                        style: TextStyle(
                          color: adminGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.copy_rounded, color: adminGold, size: 13),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Remittance Type Chip
              if (proofUrl.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        remittanceType == 'cash'
                            ? Icons.payments_outlined
                            : Icons.receipt_long_rounded,
                        size: 13,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        remittanceType == 'cash' ? 'Cash Handover' : 'Digital Transfer',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Operator & Vehicle Info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operatorName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicleName,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Financial Box (Rental Gross & Platform Commission)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Commission: ₱${NumberFormat('#,##0.00').format(comm)}',
                      style: TextStyle(
                        color: status == 'remitted' ? const Color(0xFF10B981) : adminGold,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Rental: ₱${NumberFormat('#,##0.00').format(gross)} (5%)',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 3: Proof Photo Thumbnail + Notes / Reference
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Thumbnail (clickable)
              if (proofUrl.isNotEmpty && proofUrl != 'in_office_manual')
                InkWell(
                  onTap: () => _showEnlargedProofDialog(proofUrl, bookingRef, operatorName, remittanceType, isDark),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: adminGold.withValues(alpha: 0.5)),
                      color: Colors.black26,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          proofUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
                          ),
                        ),
                        Container(
                          color: Colors.black.withValues(alpha: 0.25),
                          child: const Center(
                            child: Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (proofUrl == 'in_office_manual')
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Icon(Icons.storefront_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.withValues(alpha: 0.1),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Icon(Icons.image_not_supported_outlined, color: textSecondary, size: 20),
                  ),
                ),
              const SizedBox(width: 12),

              // Details (Ref, Notes, Date, Rejection Reason)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (refNumber.isNotEmpty) ...[
                      Text(
                        'Ref No: $refNumber',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    if (notes.isNotEmpty) ...[
                      Text(
                        notes,
                        style: TextStyle(color: textSecondary, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                      Text(
                        'Reason: $rejectionReason',
                        style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (date != null) ...[
                      Text(
                        DateFormat('MMM d, yyyy • h:mm a').format(date),
                        style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          const Divider(height: 12),

          // Row 4: Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (proofUrl.isNotEmpty && proofUrl != 'in_office_manual')
                TextButton.icon(
                  onPressed: () => _showEnlargedProofDialog(proofUrl, bookingRef, operatorName, remittanceType, isDark),
                  icon: const Icon(Icons.visibility_rounded, size: 15),
                  label: const Text('View Proof'),
                  style: TextButton.styleFrom(foregroundColor: adminGold, textStyle: const TextStyle(fontSize: 12)),
                ),
              const Spacer(),

              // Actions based on status
              if (status == 'pending_review') ...[
                OutlinedButton.icon(
                  onPressed: () => _confirmRejectRemittance(item, isDark),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Reject Proof'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade400),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _confirmApproveRemittance(item, isDark),
                  icon: const Icon(Icons.check_rounded, size: 15),
                  label: const Text('Approve & Confirm Remitted'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ] else if (status == 'unremitted') ...[
                OutlinedButton.icon(
                  onPressed: () => _confirmManualMarkRemitted(item, isDark),
                  icon: const Icon(Icons.handshake_rounded, size: 14),
                  label: const Text('Mark Remitted (In-Office Cash)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: adminGold,
                    side: BorderSide(color: adminGold),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ] else if (status == 'remitted') ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Remittance Confirmed',
                      style: TextStyle(
                        color: const Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
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
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
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
                            color: isDark ? Colors.white : Colors.black87,
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

  Future<void> _confirmApproveRemittance(Map<String, dynamic> item, bool isDark) async {
    final remittanceId = item['remittance_id']?.toString() ?? '';
    final bookingId = item['booking_id']?.toString() ?? '';
    final ref = item['booking_reference']?.toString() ?? '';
    final comm = (item['commission_amount'] as num?)?.toDouble() ?? 0.0;
    final op = item['operator_name']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text('Approve Remittance for #$ref?'),
        content: Text(
          'Confirm that you have verified the proof and received the platform commission of ₱${NumberFormat('#,##0.00').format(comm)} from $op.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Confirm & Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final adminId = _supabase.auth.currentUser?.id;
        await OperatorRemittanceService().approveRemittance(
          remittanceId: remittanceId,
          bookingId: bookingId,
          adminId: adminId,
          adminNotes: 'Approved by admin',
        );

        await _loadOperatorRemittances();
        await _loadAllBookings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Remittance for #$ref approved and marked as remitted!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to approve remittance: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmRejectRemittance(Map<String, dynamic> item, bool isDark) async {
    final remittanceId = item['remittance_id']?.toString() ?? '';
    final bookingId = item['booking_id']?.toString() ?? '';
    final ref = item['booking_reference']?.toString() ?? '';
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text('Reject Proof for #$ref'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the reason for rejection (operator will be notified so they can re-upload proper proof):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Photo of cash is blurry, receipt amount does not match...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final r = reasonController.text.trim();
              if (r.isNotEmpty) Navigator.pop(ctx, r);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject Proof'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        final adminId = _supabase.auth.currentUser?.id;
        await OperatorRemittanceService().rejectRemittance(
          remittanceId: remittanceId,
          bookingId: bookingId,
          reason: reason,
          adminId: adminId,
        );

        await _loadOperatorRemittances();
        await _loadAllBookings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Remittance for #$ref rejected. Operator notified.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reject remittance: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmManualMarkRemitted(Map<String, dynamic> item, bool isDark) async {
    final bookingId = item['booking_id']?.toString() ?? '';
    final ref = item['booking_reference']?.toString() ?? '';
    final opId = item['operator_id']?.toString() ?? '';
    final op = item['operator_name']?.toString() ?? '';
    final veh = item['vehicle_name']?.toString() ?? '';
    final gross = (item['rental_gross_amount'] as num?)?.toDouble() ?? 0.0;
    final comm = (item['commission_amount'] as num?)?.toDouble() ?? 0.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text('Mark Cash Remitted for #$ref?'),
        content: Text(
          'Confirm that operator $op handed cash of ₱${NumberFormat('#,##0.00').format(comm)} directly in office.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _adminGold, foregroundColor: Colors.black),
            child: const Text('Confirm Cash Received'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final adminId = _supabase.auth.currentUser?.id ?? 'admin';
        await OperatorRemittanceService().manualMarkRemitted(
          bookingId: bookingId,
          bookingReference: ref,
          operatorId: opId,
          operatorName: op,
          vehicleName: veh,
          rentalGrossAmount: gross,
          commissionAmount: comm,
          adminId: adminId,
          notes: 'Cash received directly in office by Admin.',
        );

        await _loadOperatorRemittances();
        await _loadAllBookings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking #$ref marked as remitted via in-office cash!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mark remittance: $e')),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> _getCombinedRemittanceRecords() {
    final list = <Map<String, dynamic>>[];

    // Map remittance records by booking_id
    final remMap = <String, OperatorRemittanceModel>{};
    for (final rem in _operatorRemittances) {
      remMap[rem.bookingId] = rem;
    }

    // Go through completed partner bookings
    for (final b in _allBookings) {
      final bId = b['id']?.toString() ?? '';
      final ref = b['booking_reference']?.toString().isNotEmpty == true
          ? b['booking_reference'].toString()
          : (bId.length > 8 ? bId.substring(0, 8).toUpperCase() : bId);
      final bookingStatus = (b['status']?.toString() ?? '').toLowerCase().trim();

      final vehicle = b['vehicles'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(b['vehicles'])
          : <String, dynamic>{};
      final isPartner = b['is_partner_vehicle'] == true ||
          vehicle['is_partner_vehicle'] == true ||
          vehicle['owner_role']?.toString().toLowerCase() == 'partner';

      // Only completed partner bookings require operator platform commission remittance
      if (!isPartner || bookingStatus != 'completed') continue;

      final gross = (b['rental_subtotal'] as num?)?.toDouble() ??
          (b['total_price'] as num?)?.toDouble() ??
          0.0;
      final comm = (b['partner_payout_commission'] as num?)?.toDouble() ?? (gross * 0.05);
      final partnerName = b['partner_business_name'] ?? b['partner_name'] ?? 'Partner';
      final vehicleDesc = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
      final opId = b['partner_id']?.toString() ?? vehicle['partner_id']?.toString() ?? '';

      final rem = remMap[bId];

      if (rem != null) {
        list.add({
          'remittance_id': rem.id,
          'booking_id': bId,
          'booking_reference': ref,
          'operator_id': rem.operatorId,
          'operator_name': rem.operatorName.isNotEmpty ? rem.operatorName : partnerName,
          'vehicle_name': rem.vehicleName.isNotEmpty ? rem.vehicleName : vehicleDesc,
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
        // Not yet submitted by operator
        list.add({
          'remittance_id': '',
          'booking_id': bId,
          'booking_reference': ref,
          'operator_id': opId,
          'operator_name': partnerName,
          'vehicle_name': vehicleDesc.isNotEmpty ? vehicleDesc : 'Partner Vehicle',
          'rental_gross_amount': gross,
          'commission_amount': comm,
          'remittance_type': 'digital',
          'proof_image_url': '',
          'reference_number': '',
          'operator_notes': '',
          'status': 'unremitted',
          'date': DateTime.tryParse(b['completed_at']?.toString() ?? '') ?? DateTime.tryParse(b['created_at']?.toString() ?? ''),
          'rejection_reason': null,
        });
      }
    }

    return list;
  }
}

