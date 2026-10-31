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
                  onPressed: () => _showVoucherDialog(null, isDark),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Create New Voucher',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
}
