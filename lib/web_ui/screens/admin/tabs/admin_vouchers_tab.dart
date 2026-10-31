part of '../admin_web_screen.dart';

extension _AdminVouchersTab on _AdminWebScreenState {
  Widget _buildVouchersContent(bool isDark) {
    final adminGold = _adminGold;
    final cardBg = isDark ? const Color(0xFF021F35) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? AppColors.primary.withValues(alpha: 0.25) : Colors.grey.shade300;

    // Filter vouchers based on search and category filter
    final filteredVouchers = _vouchers.where((v) {
      if (_voucherSearchQuery.isNotEmpty) {
        final q = _voucherSearchQuery.toLowerCase();
        final matchCode = v.code.toLowerCase().contains(q);
        final matchTitle = v.title.toLowerCase().contains(q);
        final matchDesc = v.description.toLowerCase().contains(q);
        if (!matchCode && !matchTitle && !matchDesc) return false;
      }

      switch (_selectedVoucherCategoryFilter) {
        case 'seasonal':
          return v.category == 'seasonal';
        case 'loyalty_milestone':
          return v.category == 'loyalty_milestone';
        case 'promo':
          return v.category == 'promo';
        case 'active':
          return v.isActive && !v.isExpired;
        case 'expired':
          return v.isExpired || !v.isActive;
        case 'all':
        default:
          return true;
      }
    }).toList();

    final totalCount = _vouchers.length;
    final activeCount = _vouchers.where((v) => v.isActive && !v.isExpired).length;
    final seasonalCount = _vouchers.where((v) => v.category == 'seasonal').length;
    final loyaltyCount = _vouchers.where((v) => v.category == 'loyalty_milestone').length;
    final totalUses = _vouchers.fold<int>(0, (sum, v) => sum + v.usedCount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner / Header Card
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
                    Icons.confirmation_number_rounded,
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
                        'Vouchers, Discounts & Loyalty System',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create dynamic discount codes, seasonal promotions (e.g. Summer rental discounts with expiration), and loyalty milestones.',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () {
                    if (_voucherSubTab == 0) {
                      _showVoucherDialog(null, isDark);
                    } else {
                      _showLoyaltyMilestoneDialog(null, isDark);
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(
                    _voucherSubTab == 0
                        ? 'Create New Voucher'
                        : 'Add Card Milestone',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: adminGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Sub-Tab Navigation Bar
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setAdminState(() => _voucherSubTab = 0),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _voucherSubTab == 0 ? adminGold : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_offer_rounded,
                            size: 18,
                            color: _voucherSubTab == 0 ? Colors.black : textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Seasonal & Promo Vouchers (${_vouchers.length})',
                            style: TextStyle(
                              color: _voucherSubTab == 0 ? Colors.black : textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setAdminState(() => _voucherSubTab = 1);
                      if (_loyaltyMilestones.isEmpty) {
                        _loadLoyaltyMilestones();
                      }
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _voucherSubTab == 1 ? adminGold : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.military_tech_rounded,
                            size: 19,
                            color: _voucherSubTab == 1 ? Colors.black : textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PSDC Loyalty Card Milestones (${_loyaltyMilestones.length})',
                            style: TextStyle(
                              color: _voucherSubTab == 1 ? Colors.black : textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          if (_voucherSubTab == 0) ...[

          // Stats Metrics Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final statCards = [
                _buildVoucherStatCard(
                  'Total Vouchers',
                  '$totalCount',
                  Icons.receipt_long_rounded,
                  Colors.blue,
                  isDark,
                ),
                _buildVoucherStatCard(
                  'Active Codes',
                  '$activeCount',
                  Icons.check_circle_outline_rounded,
                  const Color(0xFF10B981),
                  isDark,
                ),
                _buildVoucherStatCard(
                  'Seasonal Promos',
                  '$seasonalCount',
                  Icons.wb_sunny_rounded,
                  Colors.amber.shade700,
                  isDark,
                ),
                _buildVoucherStatCard(
                  'Loyalty Milestones',
                  '$loyaltyCount',
                  Icons.military_tech_rounded,
                  adminGold,
                  isDark,
                ),
                _buildVoucherStatCard(
                  'Total Redemptions',
                  '$totalUses',
                  Icons.shopping_bag_outlined,
                  Colors.purple,
                  isDark,
                ),
              ];

              if (isNarrow) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: statCards.map((c) => SizedBox(width: (constraints.maxWidth - 24) / 2, child: c)).toList(),
                );
              }

              return Row(
                children: statCards.map((c) => Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: c,
                ))).toList(),
              );
            },
          ),
          const SizedBox(height: 22),

          // Search, Filter and Actions Toolbar
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
                    controller: TextEditingController(text: _voucherSearchQuery)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _voucherSearchQuery.length),
                      ),
                    onChanged: (val) => setAdminState(() => _voucherSearchQuery = val),
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search code (e.g. SUMMER2026), title...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                      suffixIcon: _voucherSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setAdminState(() => _voucherSearchQuery = ''),
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

                // Category filter chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('All (${_vouchers.length})', 'all', isDark),
                    _buildFilterChip('Seasonal ($seasonalCount)', 'seasonal', isDark),
                    _buildFilterChip('Loyalty ($loyaltyCount)', 'loyalty_milestone', isDark),
                    _buildFilterChip('Active ($activeCount)', 'active', isDark),
                    _buildFilterChip('Expired / Inactive', 'expired', isDark),
                  ],
                ),

                // Refresh Button
                IconButton.filledTonal(
                  onPressed: _isLoadingVouchers ? null : _loadVouchers,
                  icon: _isLoadingVouchers
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh Vouchers',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Vouchers List / Empty State
          if (_isLoadingVouchers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (filteredVouchers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 64,
                    color: textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _voucherSearchQuery.isNotEmpty
                        ? 'No vouchers match "$_voucherSearchQuery"'
                        : 'No vouchers found for this filter',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a seasonal discount code like SUMMER2026 or a loyalty reward for renters.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _showVoucherDialog(null, isDark),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Voucher'),
                    style: FilledButton.styleFrom(
                      backgroundColor: adminGold,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1000;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 2 : 1,
                    mainAxisExtent: 250,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredVouchers.length,
                  itemBuilder: (context, index) {
                    final voucher = filteredVouchers[index];
                    return _buildVoucherCard(voucher, isDark);
                  },
                );
              },
            ),
          ] else ...[
            _buildLoyaltyMilestonesSection(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildVoucherStatCard(
    String title,
    String value,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedVoucherCategoryFilter == value;
    final adminGold = _adminGold;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setAdminState(() => _selectedVoucherCategoryFilter = value),
      selectedColor: adminGold,
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected
            ? adminGold
            : (isDark ? AppColors.primary.withValues(alpha: 0.2) : Colors.grey.shade300),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildVoucherCard(VoucherModel voucher, bool isDark) {
    final adminGold = _adminGold;
    final cardBg = isDark ? const Color(0xFF021F35) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? AppColors.primary.withValues(alpha: 0.25) : Colors.grey.shade300;

    final isExpired = voucher.isExpired;
    final isActive = voucher.isActive && !isExpired;

    Color categoryColor;
    IconData categoryIcon;
    switch (voucher.category) {
      case 'seasonal':
        categoryColor = Colors.orange;
        categoryIcon = Icons.wb_sunny_rounded;
        break;
      case 'loyalty_milestone':
        categoryColor = adminGold;
        categoryIcon = Icons.military_tech_rounded;
        break;
      case 'promo':
      default:
        categoryColor = Colors.purple;
        categoryIcon = Icons.local_offer_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? borderColor : Colors.red.withValues(alpha: 0.3),
          width: isActive ? 1.0 : 1.2,
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
          // Top Row: Code Tag + Category Chip + Active Toggle
          Row(
            children: [
              // Code chip with copy button
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: voucher.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied "${voucher.code}" to clipboard!'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: adminGold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: adminGold.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        voucher.code,
                        style: TextStyle(
                          color: adminGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.8,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.copy_rounded, color: adminGold, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(categoryIcon, size: 13, color: categoryColor),
                    const SizedBox(width: 4),
                    Text(
                      voucher.formattedCategory,
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Active / Inactive switch
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isActive ? 'Active' : (isExpired ? 'Expired' : 'Inactive'),
                    style: TextStyle(
                      color: isActive
                          ? Colors.green
                          : (isExpired ? Colors.red : textSecondary),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: voucher.isActive,
                      activeThumbColor: adminGold,
                      onChanged: (val) => _handleToggleVoucherStatus(voucher, val),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Description
          Text(
            voucher.title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            voucher.description.isNotEmpty ? voucher.description : 'No description provided.',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Highlights / Criteria Chips (Discount, Trips, Min Spend, Expiry)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Discount Tag
              _buildCriteriaBadge(
                voucher.formattedDiscount,
                Icons.local_offer_rounded,
                Colors.green,
                isDark,
              ),

              // Trips Required
              _buildCriteriaBadge(
                voucher.minTripsRequired == 0
                    ? 'Open to All (0 trips)'
                    : 'Requires ${voucher.minTripsRequired}+ trips',
                Icons.directions_car_rounded,
                Colors.blue,
                isDark,
              ),

              // Min Spend
              if (voucher.minSpend > 0)
                _buildCriteriaBadge(
                  'Min ₱${NumberFormat('#,##0').format(voucher.minSpend)}',
                  Icons.payments_outlined,
                  Colors.amber.shade700,
                  isDark,
                ),

              // Expiry Date
              if (voucher.expiresAt != null)
                _buildCriteriaBadge(
                  isExpired
                      ? 'Expired on ${DateFormat('MMM d, yyyy').format(voucher.expiresAt!)}'
                      : 'Expires ${DateFormat('MMM d, yyyy').format(voucher.expiresAt!)}',
                  Icons.event_outlined,
                  isExpired ? Colors.red : Colors.teal,
                  isDark,
                )
              else
                _buildCriteriaBadge(
                  'Never expires',
                  Icons.all_inclusive_rounded,
                  textSecondary,
                  isDark,
                ),

              // Usage counter
              _buildCriteriaBadge(
                voucher.maxUses != null
                    ? '${voucher.usedCount} / ${voucher.maxUses} uses'
                    : '${voucher.usedCount} uses',
                Icons.people_outline_rounded,
                Colors.indigo,
                isDark,
              ),
            ],
          ),
          const Spacer(),
          const Divider(height: 14),

          // Footer action buttons: Edit and Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showVoucherDialog(voucher, isDark),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit Voucher'),
                style: TextButton.styleFrom(
                  foregroundColor: adminGold,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _confirmDeleteVoucher(voucher, isDark),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaBadge(String label, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggleVoucherStatus(VoucherModel voucher, bool newStatus) async {
    try {
      await VoucherService().toggleVoucherStatus(voucher.id, newStatus);
      await AuditService().logAudit(
        action: newStatus ? 'voucher_activated' : 'voucher_deactivated',
        category: 'vouchers',
        entityId: voucher.id,
        entityType: 'voucher',
        notes: 'Admin toggled voucher ${voucher.code} to ${newStatus ? 'active' : 'inactive'}',
      );
      if (mounted) {
        setAdminState(() {
          final idx = _vouchers.indexWhere((v) => v.id == voucher.id);
          if (idx != -1) {
            _vouchers[idx] = _vouchers[idx].copyWith(isActive: newStatus);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteVoucher(VoucherModel voucher, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text('Delete Voucher "${voucher.code}"?'),
        content: Text(
          'Are you sure you want to delete this voucher? Renters will no longer be able to use "${voucher.code}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Voucher'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await VoucherService().deleteVoucher(voucher.id);
        await AuditService().logAudit(
          action: 'voucher_deleted',
          category: 'vouchers',
          entityId: voucher.id,
          entityType: 'voucher',
          notes: 'Admin deleted voucher ${voucher.code}',
        );
        if (mounted) {
          setAdminState(() {
            _vouchers.removeWhere((v) => v.id == voucher.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voucher "${voucher.code}" deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete voucher: $e')),
          );
        }
      }
    }
  }

  Future<void> _showVoucherDialog(VoucherModel? existing, bool isDark) async {
    final adminGold = _adminGold;
    final isEditing = existing != null;

    final codeController = TextEditingController(text: existing?.code ?? '');
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final valueController = TextEditingController(
      text: isEditing
          ? (existing.isPercent
              ? existing.discountPercent.toString()
              : existing.discountAmount.toString())
          : '10',
    );
    final minTripsController = TextEditingController(
      text: existing?.minTripsRequired.toString() ?? '0',
    );
    final minSpendController = TextEditingController(
      text: existing != null && existing.minSpend > 0 ? existing.minSpend.toString() : '0',
    );
    final maxUsesController = TextEditingController(
      text: existing?.maxUses?.toString() ?? '',
    );

    bool isPercent = existing?.isPercent ?? true;
    String category = existing?.category ?? 'seasonal';
    bool isActive = existing?.isActive ?? true;
    bool hasExpiry = existing?.expiresAt != null;
    DateTime selectedExpiry = existing?.expiresAt ?? DateTime.now().add(const Duration(days: 60));
    bool hasMaxUses = existing?.maxUses != null;
    bool isSaving = false;
    String? formError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cardBg = isDark ? const Color(0xFF03223A) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black87;
          final textSecondary = isDark ? Colors.white60 : Colors.black54;

          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dialog Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: adminGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                            color: adminGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Voucher: ${existing.code}' : 'Create Voucher / Discount Code',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Configure seasonal discount rates, promo codes, or loyalty rewards.',
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Scrollable form body
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (formError != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        formError!,
                                        style: const TextStyle(color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Row 1: Code and Category
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Voucher Code *', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: codeController,
                                        textCapitalization: TextCapitalization.characters,
                                        style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. SUMMER2026',
                                          hintStyle: TextStyle(color: textSecondary),
                                          filled: true,
                                          fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Category *', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: category,
                                        dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                                        style: TextStyle(color: textColor, fontSize: 13),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'seasonal',
                                            child: Text('Seasonal Promo (Summer/Holiday)'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'promo',
                                            child: Text('General Promo Code'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'loyalty_milestone',
                                            child: Text('Loyalty Milestone Reward'),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setDialogState(() {
                                              category = val;
                                              if (category == 'seasonal' && minTripsController.text.trim().isEmpty) {
                                                minTripsController.text = '0';
                                              }
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Row 2: Title
                            Text('Voucher Title *', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: titleController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: 'e.g. Summer Getaway 15% OFF Special',
                                hintStyle: TextStyle(color: textSecondary),
                                filled: true,
                                fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Row 3: Description
                            Text('Description', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: descController,
                              maxLines: 2,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: 'Short promotional message for renters...',
                                hintStyle: TextStyle(color: textSecondary),
                                filled: true,
                                fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Row 4: Discount Type & Value
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Discount Type *', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      SegmentedButton<bool>(
                                        segments: const [
                                          ButtonSegment(
                                            value: true,
                                            label: Text('Percentage (%)'),
                                            icon: Icon(Icons.percent, size: 16),
                                          ),
                                          ButtonSegment(
                                            value: false,
                                            label: Text('Flat (₱)'),
                                            icon: Icon(Icons.payments_outlined, size: 16),
                                          ),
                                        ],
                                        selected: {isPercent},
                                        onSelectionChanged: (set) {
                                          setDialogState(() => isPercent = set.first);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isPercent ? 'Percent Off (%) *' : 'Amount Off (₱) *',
                                        style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: valueController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
                                        decoration: InputDecoration(
                                          hintText: isPercent ? 'e.g. 15' : 'e.g. 500',
                                          prefixText: isPercent ? '' : '₱ ',
                                          suffixText: isPercent ? '%' : '',
                                          filled: true,
                                          fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Row 5: Criteria (Min Trips Required & Min Spend)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Min Completed Trips', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text('0 = open to all renters', style: TextStyle(color: textSecondary, fontSize: 11)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: minTripsController,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(color: textColor),
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          filled: true,
                                          fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Min Booking Spend (₱)', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text('0 = no minimum', style: TextStyle(color: textSecondary, fontSize: 11)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: minSpendController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: TextStyle(color: textColor),
                                        decoration: InputDecoration(
                                          prefixText: '₱ ',
                                          hintText: '0',
                                          filled: true,
                                          fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Row 6: Expiration Date Controls (Critical for seasonal summer rentals)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: hasExpiry
                                      ? adminGold.withValues(alpha: 0.5)
                                      : (isDark ? Colors.white12 : Colors.grey.shade300),
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
                                          Icon(
                                            Icons.calendar_month_rounded,
                                            color: hasExpiry ? adminGold : textSecondary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Seasonal / Expiration Date',
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Switch(
                                        value: hasExpiry,
                                        activeThumbColor: adminGold,
                                        onChanged: (val) {
                                          setDialogState(() => hasExpiry = val);
                                        },
                                      ),
                                    ],
                                  ),
                                  if (hasExpiry) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Expires on: ${DateFormat('MMMM d, yyyy (EEE)').format(selectedExpiry)}',
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: selectedExpiry,
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now().add(const Duration(days: 730)),
                                            );
                                            if (picked != null) {
                                              setDialogState(() {
                                                selectedExpiry = DateTime(
                                                  picked.year,
                                                  picked.month,
                                                  picked.day,
                                                  23,
                                                  59,
                                                  59,
                                                );
                                              });
                                            }
                                          },
                                          icon: const Icon(Icons.date_range_rounded, size: 16),
                                          label: const Text('Change Date'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: adminGold,
                                            side: BorderSide(color: adminGold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Row 7: Max redemptions limit
                            Row(
                              children: [
                                Checkbox(
                                  value: hasMaxUses,
                                  activeColor: adminGold,
                                  onChanged: (val) {
                                    setDialogState(() => hasMaxUses = val ?? false);
                                  },
                                ),
                                Text(
                                  'Limit total redemptions (e.g. first 100 renters)',
                                  style: TextStyle(color: textColor, fontSize: 13),
                                ),
                                if (hasMaxUses) ...[
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: maxUsesController,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(color: textColor),
                                      decoration: InputDecoration(
                                        hintText: '100',
                                        filled: true,
                                        fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Row 8: Active immediately toggle
                            Row(
                              children: [
                                Switch(
                                  value: isActive,
                                  activeThumbColor: adminGold,
                                  onChanged: (val) => setDialogState(() => isActive = val),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Make voucher active immediately',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final cleanCode = codeController.text.trim().toUpperCase();
                                  final cleanTitle = titleController.text.trim();
                                  final discountVal = double.tryParse(valueController.text.trim()) ?? 0.0;
                                  final minTrips = int.tryParse(minTripsController.text.trim()) ?? 0;
                                  final minSpend = double.tryParse(minSpendController.text.trim()) ?? 0.0;
                                  final maxUses = hasMaxUses
                                      ? int.tryParse(maxUsesController.text.trim())
                                      : null;

                                  if (cleanCode.isEmpty) {
                                    setDialogState(() => formError = 'Please enter a voucher code.');
                                    return;
                                  }
                                  if (cleanTitle.isEmpty) {
                                    setDialogState(() => formError = 'Please enter a voucher title.');
                                    return;
                                  }
                                  if (discountVal <= 0) {
                                    setDialogState(() => formError = 'Discount value must be greater than 0.');
                                    return;
                                  }
                                  if (isPercent && discountVal > 100) {
                                    setDialogState(() => formError = 'Percentage discount cannot exceed 100%.');
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(context);
                                  setDialogState(() {
                                    isSaving = true;
                                    formError = null;
                                  });

                                  try {
                                    final now = DateTime.now();
                                    final newVoucher = VoucherModel(
                                      id: existing?.id ?? '',
                                      code: cleanCode,
                                      title: cleanTitle,
                                      description: descController.text.trim(),
                                      discountPercent: isPercent ? discountVal : 0.0,
                                      discountAmount: !isPercent ? discountVal : 0.0,
                                      isPercent: isPercent,
                                      minTripsRequired: minTrips,
                                      minSpend: minSpend,
                                      expiresAt: hasExpiry ? selectedExpiry : null,
                                      isActive: isActive,
                                      maxUses: maxUses,
                                      usedCount: existing?.usedCount ?? 0,
                                      category: category,
                                      createdAt: existing?.createdAt ?? now,
                                      updatedAt: now,
                                    );

                                    if (isEditing) {
                                      final updated = await VoucherService().updateVoucher(newVoucher);
                                      await AuditService().logAudit(
                                        action: 'voucher_updated',
                                        category: 'vouchers',
                                        entityId: updated.id,
                                        entityType: 'voucher',
                                        notes: 'Admin updated voucher ${updated.code} ($category, ${updated.formattedDiscount})',
                                      );
                                    } else {
                                      final created = await VoucherService().createVoucher(newVoucher);
                                      await AuditService().logAudit(
                                        action: 'voucher_created',
                                        category: 'vouchers',
                                        entityId: created.id,
                                        entityType: 'voucher',
                                        notes: 'Admin created voucher ${created.code} ($category, ${created.formattedDiscount})',
                                      );
                                    }

                                    await _loadVouchers();

                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isEditing
                                              ? 'Voucher "$cleanCode" updated successfully!'
                                              : 'Voucher "$cleanCode" created successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    setDialogState(() {
                                      isSaving = false;
                                      formError = 'Failed to save voucher: $e';
                                    });
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(isEditing ? 'Save Changes' : 'Create Voucher'),
                          style: FilledButton.styleFrom(
                            backgroundColor: adminGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Widget _buildLoyaltyMilestonesSection(bool isDark) {
    final adminGold = _adminGold;
    final cardBg = isDark ? const Color(0xFF021F35) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? AppColors.primary.withValues(alpha: 0.25) : Colors.grey.shade300;

    final sortedMilestones = List<LoyaltyRewardMilestone>.from(_loyaltyMilestones)
      ..sort((a, b) => a.stamp.compareTo(b.stamp));
    final activeCount = sortedMilestones.where((m) => m.isActive).length;
    final grandMilestone = sortedMilestones.firstWhere(
      (m) => m.stamp == 18,
      orElse: () => const LoyaltyRewardMilestone(18, 'None', isActive: false),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Loyalty Overview Card with Quick Actions
        Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.stars_rounded, color: adminGold, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '18-Stamp PSDC Loyalty Rewards Card Rules',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Renters earn 1 stamp on their digital card in their Profile tab for every completed booking. Configure which stamp numbers unlock discounts, gifts, or free hours.',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _confirmResetLoyaltyMilestones(isDark),
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Reset Defaults'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSecondary,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _showLoyaltyMilestoneDialog(null, isDark),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Milestone'),
                    style: FilledButton.styleFrom(
                      backgroundColor: adminGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 18),

              // Overview Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildVoucherStatCard(
                      'Configured Milestones',
                      '${sortedMilestones.length} / 18 Stamps',
                      Icons.military_tech_rounded,
                      Colors.blue,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVoucherStatCard(
                      'Active Rewards',
                      '$activeCount Active',
                      Icons.check_circle_outline_rounded,
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVoucherStatCard(
                      'Grand Reward (Stamp 18)',
                      grandMilestone.isActive ? grandMilestone.label : 'Inactive',
                      Icons.emoji_events_rounded,
                      adminGold,
                      isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Milestones List / Grid
        if (_isLoadingLoyaltyMilestones)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          )
        else if (sortedMilestones.isEmpty)
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
                  Icons.card_membership_outlined,
                  size: 64,
                  color: textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No loyalty milestones configured yet',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Restore the 7 default PSDC milestones (Stamps 3, 6, 8, 10, 12, 15, 18) or add custom ones.',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _confirmResetLoyaltyMilestones(isDark),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('Load PSDC Default Milestones'),
                  style: FilledButton.styleFrom(
                    backgroundColor: adminGold,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1000;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 2 : 1,
                  mainAxisExtent: 220,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: sortedMilestones.length,
                itemBuilder: (context, index) {
                  final milestone = sortedMilestones[index];
                  return _buildLoyaltyMilestoneCard(milestone, isDark);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildLoyaltyMilestoneCard(LoyaltyRewardMilestone milestone, bool isDark) {
    final adminGold = _adminGold;
    final cardBg = isDark ? const Color(0xFF021F35) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? AppColors.primary.withValues(alpha: 0.25) : Colors.grey.shade300;

    final isGrand = milestone.stamp == 18;
    final isActive = milestone.isActive;

    Color rewardColor;
    IconData rewardIcon;
    String rewardTypeLabel;
    switch (milestone.rewardType) {
      case 'gift':
        rewardColor = Colors.orange;
        rewardIcon = Icons.card_giftcard_rounded;
        rewardTypeLabel = 'Merchandise Gift';
        break;
      case 'free_time':
        rewardColor = Colors.deepPurpleAccent;
        rewardIcon = Icons.hourglass_top_rounded;
        rewardTypeLabel = '${milestone.freeHours}h Free Rental';
        break;
      case 'discount':
      default:
        rewardColor = const Color(0xFF10B981);
        rewardIcon = Icons.payments_outlined;
        rewardTypeLabel = milestone.discountPercent > 0
            ? '${milestone.discountPercent}% OFF'
            : '₱${NumberFormat('#,##0').format(milestone.discountAmount)} OFF';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGrand
              ? adminGold.withValues(alpha: 0.6)
              : (isActive ? borderColor : Colors.grey.withValues(alpha: 0.3)),
          width: isGrand ? 1.6 : 1.0,
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
          // Header Row: Stamp badge, Reward Type chip, and Active Switch
          Row(
            children: [
              // Stamp Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isGrand
                      ? adminGold.withValues(alpha: 0.25)
                      : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isGrand ? adminGold : AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGrand ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
                      size: 14,
                      color: isGrand ? adminGold : AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isGrand ? 'STAMP #18 (GRAND)' : 'STAMP #${milestone.stamp}',
                      style: TextStyle(
                        color: isGrand ? adminGold : AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Reward Type Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rewardColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(rewardIcon, size: 12, color: rewardColor),
                    const SizedBox(width: 4),
                    Text(
                      rewardTypeLabel,
                      style: TextStyle(
                        color: rewardColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Active Switch
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isActive ? 'Active' : 'Disabled',
                    style: TextStyle(
                      color: isActive ? Colors.green : textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: isActive,
                      activeThumbColor: adminGold,
                      onChanged: (val) => _handleToggleMilestoneStatus(milestone, val),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Label
          Text(
            milestone.label,
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),

          // Description
          Text(
            milestone.description.isNotEmpty
                ? milestone.description
                : 'Unlocked when renter completes ${milestone.stamp} verified trips.',
            style: TextStyle(color: textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Chips (Voucher Code if present, Reward Value details)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildCriteriaBadge(
                'Requires ${milestone.stamp} completed trips',
                Icons.directions_car_rounded,
                Colors.blue,
                isDark,
              ),
              if (milestone.voucherCode != null && milestone.voucherCode!.isNotEmpty)
                _buildCriteriaBadge(
                  'Code: ${milestone.voucherCode}',
                  Icons.qr_code_rounded,
                  adminGold,
                  isDark,
                ),
            ],
          ),
          const Spacer(),
          const Divider(height: 12),

          // Action Buttons: Edit and Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showLoyaltyMilestoneDialog(milestone, isDark),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit Milestone'),
                style: TextButton.styleFrom(
                  foregroundColor: adminGold,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _confirmDeleteMilestone(milestone, isDark),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggleMilestoneStatus(LoyaltyRewardMilestone milestone, bool newStatus) async {
    try {
      await LoyaltyRewardService().toggleMilestoneStatus(milestone.stamp, newStatus);
      await AuditService().logAudit(
        action: newStatus ? 'loyalty_milestone_activated' : 'loyalty_milestone_deactivated',
        category: 'loyalty',
        entityId: milestone.stamp.toString(),
        entityType: 'loyalty_milestone',
        notes: 'Admin toggled milestone stamp ${milestone.stamp} to ${newStatus ? 'active' : 'inactive'}',
      );
      if (mounted) {
        setAdminState(() {
          final idx = _loyaltyMilestones.indexWhere((m) => m.stamp == milestone.stamp);
          if (idx != -1) {
            _loyaltyMilestones[idx] = _loyaltyMilestones[idx].copyWith(isActive: newStatus);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteMilestone(LoyaltyRewardMilestone milestone, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text('Delete Milestone Stamp #${milestone.stamp}?'),
        content: Text(
          'Are you sure you want to delete Stamp #${milestone.stamp} ("${milestone.label}") from the loyalty card? Renters will no longer receive this reward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Milestone'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await LoyaltyRewardService().deleteMilestone(milestone.stamp);
        await AuditService().logAudit(
          action: 'loyalty_milestone_deleted',
          category: 'loyalty',
          entityId: milestone.stamp.toString(),
          entityType: 'loyalty_milestone',
          notes: 'Admin deleted loyalty milestone stamp ${milestone.stamp} (${milestone.label})',
        );
        await _loadLoyaltyMilestones();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Milestone Stamp #${milestone.stamp} deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete milestone: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmResetLoyaltyMilestones(bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: const Text('Reset Loyalty Card to Defaults?'),
        content: const Text(
          'This will restore the 7 default PSDC milestones (Stamps 3, 6, 8, 10, 12, 15, and 18) on the loyalty card.\n\nAny custom milestones you created will be replaced with the standard PSDC reward set.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _adminGold, foregroundColor: Colors.black),
            child: const Text('Reset to Defaults'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = LoyaltyRewardService();
        for (final m in LoyaltyRewardState.defaultMilestones) {
          await service.saveMilestone(m);
        }
        await AuditService().logAudit(
          action: 'loyalty_milestones_reset_defaults',
          category: 'loyalty',
          entityId: 'all',
          entityType: 'loyalty_milestone',
          notes: 'Admin reset loyalty milestones to PSDC 18-stamp defaults',
        );
        await _loadLoyaltyMilestones();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PSDC loyalty card milestones restored to defaults!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reset milestones: $e')),
          );
        }
      }
    }
  }

  Future<void> _showLoyaltyMilestoneDialog(LoyaltyRewardMilestone? existing, bool isDark) async {
    final adminGold = _adminGold;
    final isEditing = existing != null;

    int selectedStamp = existing?.stamp ?? 1;
    String rewardType = existing?.rewardType ?? 'discount';
    bool isPercent = existing != null && existing.discountPercent > 0;
    bool isActive = existing?.isActive ?? true;

    final labelController = TextEditingController(text: existing?.label ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final amountController = TextEditingController(
      text: existing != null
          ? (isPercent
              ? existing.discountPercent.toString()
              : existing.discountAmount.toString())
          : '50',
    );
    final freeHoursController = TextEditingController(
      text: existing?.freeHours.toString() ?? '3',
    );
    final voucherCodeController = TextEditingController(
      text: existing?.voucherCode ?? '',
    );

    bool isSaving = false;
    String? formError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cardBg = isDark ? const Color(0xFF03223A) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black87;
          final textSecondary = isDark ? Colors.white60 : Colors.black54;

          final stampAlreadyUsed = !isEditing &&
              _loyaltyMilestones.any((m) => m.stamp == selectedStamp);

          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: adminGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_rounded : Icons.military_tech_rounded,
                            color: adminGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? 'Edit Milestone: Stamp #${existing.stamp}'
                                    : 'Add Loyalty Card Milestone',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Set reward given when renters reach this stamp on their 18-stamp card.',
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Scrollable form body
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (formError != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        formError!,
                                        style: const TextStyle(color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Stamp selector & Reward type
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Stamp Number (1 - 18) *',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<int>(
                                        initialValue: selectedStamp,
                                        dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                                        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w700),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        ),
                                        items: List.generate(18, (i) => i + 1).map((s) {
                                          final isExistingMilestone = _loyaltyMilestones.any((m) => m.stamp == s);
                                          return DropdownMenuItem<int>(
                                            value: s,
                                            child: Text(
                                              s == 18
                                                  ? 'Stamp #18 (Grand Finale)'
                                                  : (isExistingMilestone ? 'Stamp #$s (Configured)' : 'Stamp #$s'),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: isEditing
                                            ? null
                                            : (val) {
                                                if (val != null) {
                                                  setDialogState(() => selectedStamp = val);
                                                }
                                              },
                                      ),
                                      if (stampAlreadyUsed)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Note: Stamp #$selectedStamp already exists and will be updated.',
                                            style: const TextStyle(color: Colors.amber, fontSize: 11),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reward Category *',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: rewardType,
                                        dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                                        style: TextStyle(color: textColor, fontSize: 13),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'discount',
                                            child: Text('Discount (₱ / %)'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'gift',
                                            child: Text('Merchandise Gift'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'free_time',
                                            child: Text('Free Rental Hours'),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setDialogState(() {
                                              rewardType = val;
                                              if (rewardType == 'free_time' && labelController.text.isEmpty) {
                                                labelController.text = 'Free 3 Hours';
                                              } else if (rewardType == 'gift' && labelController.text.isEmpty) {
                                                labelController.text = 'PSDC Umbrella';
                                              }
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Milestone Label / Display Name
                            Text(
                              'Reward Title / Label *',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: labelController,
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                hintText: rewardType == 'gift'
                                    ? 'e.g. PSDC Umbrella'
                                    : (rewardType == 'free_time' ? 'e.g. Free 24 Hours' : 'e.g. ₱200 OFF'),
                                hintStyle: TextStyle(color: textSecondary),
                                filled: true,
                                fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Conditional input based on rewardType
                            if (rewardType == 'discount') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Discount Type', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                                        const SizedBox(height: 6),
                                        SegmentedButton<bool>(
                                          segments: const [
                                            ButtonSegment(value: false, label: Text('Flat (₱)')),
                                            ButtonSegment(value: true, label: Text('Percent (%)')),
                                          ],
                                          selected: {isPercent},
                                          onSelectionChanged: (set) {
                                            setDialogState(() => isPercent = set.first);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isPercent ? 'Percent Off (%) *' : 'Amount Off (₱) *',
                                          style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: amountController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
                                          decoration: InputDecoration(
                                            prefixText: isPercent ? '' : '₱ ',
                                            suffixText: isPercent ? '%' : '',
                                            hintText: isPercent ? '10' : '200',
                                            filled: true,
                                            fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ] else if (rewardType == 'free_time') ...[
                              Text('Free Rental Hours *', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: freeHoursController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 3 or 24',
                                  suffixText: 'hours',
                                  filled: true,
                                  fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Voucher Code (optional)
                            Text('Auto-Generated Voucher Code (Optional)', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('When the renter claims this reward, this code will be copied to their clipboard or activated.', style: TextStyle(color: textSecondary, fontSize: 11)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: voucherCodeController,
                              textCapitalization: TextCapitalization.characters,
                              style: TextStyle(color: textColor, fontFamily: 'monospace', fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                hintText: 'e.g. LOYALTY200 or FREE24H',
                                hintStyle: TextStyle(color: textSecondary),
                                filled: true,
                                fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Description
                            Text('Description', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: descController,
                              maxLines: 2,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: 'Detailed note for renters on the loyalty card...',
                                hintStyle: TextStyle(color: textSecondary),
                                filled: true,
                                fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Active Switch
                            Row(
                              children: [
                                Switch(
                                  value: isActive,
                                  activeThumbColor: adminGold,
                                  onChanged: (val) => setDialogState(() => isActive = val),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Make milestone active on loyalty cards immediately',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final cleanLabel = labelController.text.trim();
                                  final discountVal = double.tryParse(amountController.text.trim()) ?? 0.0;
                                  final freeHoursVal = int.tryParse(freeHoursController.text.trim()) ?? 0;

                                  if (cleanLabel.isEmpty) {
                                    setDialogState(() => formError = 'Please enter a reward label.');
                                    return;
                                  }
                                  if (rewardType == 'discount' && discountVal <= 0) {
                                    setDialogState(() => formError = 'Discount amount must be greater than 0.');
                                    return;
                                  }
                                  if (rewardType == 'discount' && isPercent && discountVal > 100) {
                                    setDialogState(() => formError = 'Percentage discount cannot exceed 100%.');
                                    return;
                                  }
                                  if (rewardType == 'free_time' && freeHoursVal <= 0) {
                                    setDialogState(() => formError = 'Free rental hours must be greater than 0.');
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(context);
                                  setDialogState(() {
                                    isSaving = true;
                                    formError = null;
                                  });

                                  try {
                                    final milestone = LoyaltyRewardMilestone(
                                      selectedStamp,
                                      cleanLabel,
                                      id: existing?.id,
                                      description: descController.text.trim(),
                                      rewardType: rewardType,
                                      discountAmount: rewardType == 'discount' && !isPercent ? discountVal : 0.0,
                                      discountPercent: rewardType == 'discount' && isPercent ? discountVal : 0.0,
                                      freeHours: rewardType == 'free_time' ? freeHoursVal : 0,
                                      voucherCode: voucherCodeController.text.trim().isEmpty
                                          ? null
                                          : voucherCodeController.text.trim().toUpperCase(),
                                      isActive: isActive,
                                    );

                                    await LoyaltyRewardService().saveMilestone(milestone);
                                    await AuditService().logAudit(
                                      action: isEditing ? 'loyalty_milestone_updated' : 'loyalty_milestone_created',
                                      category: 'loyalty',
                                      entityId: selectedStamp.toString(),
                                      entityType: 'loyalty_milestone',
                                      notes: 'Admin saved loyalty milestone stamp $selectedStamp ($cleanLabel)',
                                    );

                                    await _loadLoyaltyMilestones();

                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Milestone Stamp #$selectedStamp ("$cleanLabel") saved successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    setDialogState(() {
                                      isSaving = false;
                                      formError = 'Failed to save milestone: $e';
                                    });
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(isEditing ? 'Save Changes' : 'Add Milestone'),
                          style: FilledButton.styleFrom(
                            backgroundColor: adminGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
}
