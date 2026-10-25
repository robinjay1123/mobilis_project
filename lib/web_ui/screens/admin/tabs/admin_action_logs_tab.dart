part of '../admin_web_screen.dart';

extension _AdminActionLogsTab on _AdminWebScreenState {
  Widget _buildActionLogsContent(bool isDark) {
    final search = _actionLogSearchQuery.trim().toLowerCase();
    final category = _actionLogCategoryFilter;
    final roleFilter = _actionLogRoleFilter.toLowerCase();

    final filteredLogs = _actionLogs.where((log) {
      final matchesSearch =
          search.isEmpty ||
          (log['notes']?.toString().toLowerCase().contains(search) ?? false) ||
          (log['actor_name']?.toString().toLowerCase().contains(search) ??
              false) ||
          (log['actor_role']?.toString().toLowerCase().contains(search) ??
              false) ||
          (log['booking_id']?.toString().toLowerCase().contains(search) ??
              false) ||
          (log['action_type']?.toString().toLowerCase().contains(search) ??
              false) ||
          (log['category']?.toString().toLowerCase().contains(search) ?? false);

      if (!matchesSearch) return false;

      if (roleFilter != 'all') {
        final logRole = (log['actor_role']?.toString() ?? '').toLowerCase();
        if (logRole != roleFilter) return false;
      }

      if (category == 'all') return true;
      final logCat = log['category']?.toString() ?? '';
      if (category == 'wishlist_likes') {
        return logCat == 'FAVORITES & WISHLIST';
      }
      if (category == 'account_security') {
        return logCat == 'ACCOUNT SECURITY & BANS';
      }
      if (category == 'executive_audit') {
        return logCat == 'EXECUTIVE AUDIT';
      }
      if (category == 'booking_cancels') {
        return logCat == 'BOOKING CANCEL';
      }
      if (category == 'refunds_payouts') {
        return logCat == 'REFUNDS & PAYOUTS';
      }
      if (category == 'desk_payments') {
        return logCat == 'DESK PAYMENT MPIN' || logCat == 'OPERATOR MPIN';
      }
      if (category == 'extensions') {
        return logCat == 'TRIP EXTENSION';
      }
      if (category == 'approvals') {
        return logCat == 'BOOKING APPROVAL' ||
            logCat == 'PARTNER APPROVAL' ||
            logCat == 'PARTNER FLEET' ||
            logCat == 'DRIVER APPLICATION';
      }
      if (category == 'drivers') {
        return logCat == 'DRIVER ASSIGNMENT' || logCat == 'DRIVER APPLICATION';
      }
      if (category == 'pricing_vehicles') {
        return logCat == 'PRICING & VEHICLES' || logCat == 'PARTNER FLEET';
      }
      if (category == 'renters') return logCat == 'RENTER REQUEST';
      if (category == 'payments') {
        return logCat == 'PAYMENT CONFIRMED' ||
            logCat == 'RETURN INSPECTION' ||
            logCat == 'RELEASE INSPECTION' ||
            logCat == 'TRIP PICKUP' ||
            logCat == 'TRIP RETURN' ||
            logCat == 'TRIP COMPLETED';
      }
      if (category == 'verifications') {
        return logCat == 'USER VERIFICATION' || logCat == 'DRIVER APPLICATION';
      }

      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fact_check_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Action & Audit Logs',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      color: Colors.green,
                                      size: 8,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'REALTIME AUDIT',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _isLoadingActionLogs
                                    ? null
                                    : () => _loadActionLogs(showLoading: true),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _isLoadingActionLogs
                                          ? const SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.refresh_rounded,
                                              size: 13,
                                              color: AppColors.primary,
                                            ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'REFRESH',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Comprehensive audit trail tracking operator actions, partner approvals, driver payouts, security deposit refunds, desk MPINs, and renter requests across Mobilis.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (val) =>
                      setState(() => _actionLogSearchQuery = val),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by Booking ID, Actor, Operator, Partner, Driver, Reference...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Role Filters
                Row(
                  children: [
                    Text(
                      'FILTER BY ROLE:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildActionLogRoleChip('all', 'All Roles', isDark),
                            const SizedBox(width: 8),
                            _buildActionLogRoleChip('operator', 'Operator', isDark),
                            const SizedBox(width: 8),
                            _buildActionLogRoleChip('partner', 'Partner', isDark),
                            const SizedBox(width: 8),
                            _buildActionLogRoleChip('driver', 'Driver', isDark),
                            const SizedBox(width: 8),
                            _buildActionLogRoleChip('admin', 'Admin', isDark),
                            const SizedBox(width: 8),
                            _buildActionLogRoleChip('renter', 'Renter', isDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Category Filters
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionLogCategoryChip('all', 'All Activity', isDark),
                    _buildActionLogCategoryChip(
                      'account_security',
                      'Account Security & Bans',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'wishlist_likes',
                      'Wishlist & Likes',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'renters',
                      'Renter Requests & Bookings',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'approvals',
                      'Approvals',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'verifications',
                      'KYC Verifications',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'refunds_payouts',
                      'Refunds & Disbursements',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'desk_payments',
                      'Desk MPIN Payments',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'extensions',
                      'Trip Extensions',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'drivers',
                      'Driver Assignments',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'pricing_vehicles',
                      'Pricing & Fleet',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'payments',
                      'Returns & Payments',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'booking_cancels',
                      'Cancellations',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'executive_audit',
                      'Executive Audits',
                      isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logs List
          Expanded(
            child: _isLoadingActionLogs
                ? const Center(child: CircularProgressIndicator())
                : filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 48,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No action logs found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          search.isNotEmpty
                              ? 'Try clearing your search query'
                              : 'System action logs will appear here live in real-time.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final item = filteredLogs[index];
                      return _buildActionLogCard(item, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionLogRoleChip(String key, String label, bool isDark) {
    final isSelected = _actionLogRoleFilter.toLowerCase() == key.toLowerCase();
    return InkWell(
      onTap: () => setState(() => _actionLogRoleFilter = key),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActionLogCategoryChip(String key, String label, bool isDark) {
    final isSelected = _actionLogCategoryFilter == key;
    return InkWell(
      onTap: () => setState(() => _actionLogCategoryFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActionLogCard(Map<String, dynamic> item, bool isDark) {
    final category = item['category']?.toString() ?? 'SYSTEM';
    final notes = item['notes']?.toString() ?? '';
    final actorName = item['actor_name']?.toString() ?? 'System';
    final actorRole = item['actor_role']?.toString() ?? 'operator';
    final timestampStr = item['timestamp']?.toString() ?? '';
    final bookingId = item['booking_id']?.toString() ?? '';

    Color iconColor = AppColors.primary;
    IconData iconData = Icons.info_rounded;
    Color badgeBg = AppColors.primary.withValues(alpha: 0.15);
    Color badgeText = AppColors.primary;

    if (category == 'FAVORITES & WISHLIST') {
      iconColor = const Color(0xFFE11D48);
      iconData = Icons.favorite_rounded;
      badgeBg = const Color(0xFFE11D48).withValues(alpha: 0.18);
      badgeText = const Color(0xFFE11D48);
    } else if (category == 'ACCOUNT SECURITY & BANS') {
      iconColor = const Color(0xFFDC2626);
      iconData = Icons.gavel_rounded;
      badgeBg = const Color(0xFFDC2626).withValues(alpha: 0.18);
      badgeText = const Color(0xFFDC2626);
    } else if (category == 'EXECUTIVE AUDIT') {
      iconColor = const Color(0xFF7C3AED);
      iconData = Icons.verified_rounded;
      badgeBg = const Color(0xFF7C3AED).withValues(alpha: 0.18);
      badgeText = const Color(0xFF7C3AED);
    } else if (category == 'BOOKING CANCEL') {
      iconColor = const Color(0xFFEA580C);
      iconData = Icons.cancel_rounded;
      badgeBg = const Color(0xFFEA580C).withValues(alpha: 0.18);
      badgeText = const Color(0xFFEA580C);
    } else if (category == 'ADMIN ACTION') {
      iconColor = const Color(0xFF2563EB);
      iconData = Icons.admin_panel_settings_rounded;
      badgeBg = const Color(0xFF2563EB).withValues(alpha: 0.18);
      badgeText = const Color(0xFF2563EB);
    } else if (category == 'REFUNDS & PAYOUTS') {
      iconColor = const Color(0xFF059669);
      iconData = Icons.account_balance_wallet_rounded;
      badgeBg = const Color(0xFF059669).withValues(alpha: 0.18);
      badgeText = const Color(0xFF059669);
    } else if (category == 'PRICING & VEHICLES' || category == 'PARTNER FLEET') {
      iconColor = const Color(0xFF6366F1);
      iconData = Icons.sell_rounded;
      badgeBg = const Color(0xFF6366F1).withValues(alpha: 0.18);
      badgeText = const Color(0xFF6366F1);
    } else if (category == 'TRIP PICKUP') {
      iconColor = const Color(0xFF0891B2);
      iconData = Icons.key_rounded;
      badgeBg = const Color(0xFF0891B2).withValues(alpha: 0.18);
      badgeText = const Color(0xFF0891B2);
    } else if (category == 'TRIP RETURN') {
      iconColor = const Color(0xFF0D9488);
      iconData = Icons.assignment_turned_in_rounded;
      badgeBg = const Color(0xFF0D9488).withValues(alpha: 0.18);
      badgeText = const Color(0xFF0D9488);
    } else if (category == 'DESK PAYMENT MPIN') {
      iconColor = const Color(0xFFD97706);
      iconData = Icons.pin_outlined;
      badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.18);
      badgeText = const Color(0xFFD97706);
    } else if (category == 'OPERATOR MPIN') {
      iconColor = const Color(0xFFF59E0B);
      iconData = Icons.shield_outlined;
      badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.18);
      badgeText = const Color(0xFFF59E0B);
    } else if (category == 'TRIP EXTENSION') {
      iconColor = const Color(0xFF0284C7);
      iconData = Icons.update_rounded;
      badgeBg = const Color(0xFF0284C7).withValues(alpha: 0.18);
      badgeText = const Color(0xFF0284C7);
    } else if (category == 'BOOKING APPROVAL' || category == 'PARTNER APPROVAL') {
      iconColor = Colors.green;
      iconData = Icons.check_circle_rounded;
      badgeBg = Colors.green.withValues(alpha: 0.15);
      badgeText = Colors.green;
    } else if (category == 'DRIVER ASSIGNMENT') {
      iconColor = Colors.blue;
      iconData = Icons.badge_rounded;
      badgeBg = Colors.blue.withValues(alpha: 0.15);
      badgeText = Colors.blue;
    } else if (category == 'RENTER REQUEST') {
      iconColor = Colors.purple;
      iconData = Icons.directions_car_rounded;
      badgeBg = Colors.purple.withValues(alpha: 0.15);
      badgeText = Colors.purple;
    } else if (category == 'PAYMENT CONFIRMED') {
      iconColor = Colors.amber.shade700;
      iconData = Icons.payments_rounded;
      badgeBg = Colors.amber.withValues(alpha: 0.18);
      badgeText = Colors.amber.shade700;
    } else if (category == 'RETURN INSPECTION' || category == 'RELEASE INSPECTION') {
      iconColor = Colors.orange;
      iconData = Icons.fact_check_rounded;
      badgeBg = Colors.orange.withValues(alpha: 0.15);
      badgeText = Colors.orange;
    } else if (category == 'USER VERIFICATION') {
      iconColor = Colors.teal;
      iconData = Icons.verified_user_rounded;
      badgeBg = Colors.teal.withValues(alpha: 0.15);
      badgeText = Colors.teal;
    } else if (category == 'DRIVER APPLICATION') {
      iconColor = Colors.teal.shade700;
      iconData = Icons.badge_rounded;
      badgeBg = Colors.teal.withValues(alpha: 0.18);
      badgeText = Colors.teal.shade700;
    }

    final parsedTime = DateTime.tryParse(timestampStr);

    return InkWell(
      onTap: () => _showActionLogDetailModal(context, item, isDark),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgSecondary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Avatar
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: badgeText,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        actorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          actorRole.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (bookingId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Booking ID: ${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Timestamp
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (parsedTime != null)
                  RelativeTimeText(
                    value: parsedTime,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 2),
                if (parsedTime != null)
                  Text(
                    '${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showActionLogDetailModal(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
  ) {
    final metadata = item['metadata'] is Map ? Map<String, dynamic>.from(item['metadata']) : <String, dynamic>{};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Audit Log Documentation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAuditDetailRow('Record ID', item['id']?.toString() ?? 'N/A', isDark),
                _buildAuditDetailRow('Category', item['category']?.toString() ?? 'SYSTEM', isDark),
                _buildAuditDetailRow('Action Type', item['action_type']?.toString() ?? 'N/A', isDark),
                _buildAuditDetailRow('Actor Name', item['actor_name']?.toString() ?? 'System', isDark),
                _buildAuditDetailRow('Actor Role', (item['actor_role']?.toString() ?? 'Operator').toUpperCase(), isDark),
                if (metadata['actor_email'] != null && metadata['actor_email'].toString().isNotEmpty)
                  _buildAuditDetailRow('Actor Email', metadata['actor_email'].toString(), isDark),
                _buildAuditDetailRow('Timestamp', item['timestamp']?.toString() ?? 'N/A', isDark),
                if (item['booking_id'] != null && item['booking_id'].toString().isNotEmpty)
                  _buildAuditDetailRow('Booking ID', item['booking_id'].toString(), isDark),
                if (item['vehicle_id'] != null && item['vehicle_id'].toString().isNotEmpty)
                  _buildAuditDetailRow('Vehicle ID', item['vehicle_id'].toString(), isDark),
                if (item['driver_id'] != null && item['driver_id'].toString().isNotEmpty)
                  _buildAuditDetailRow('Driver ID', item['driver_id'].toString(), isDark),
                const Divider(height: 24),
                const Text(
                  'Event Description / Audit Notes',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item['notes']?.toString() ?? 'No description provided.',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
                if (metadata.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Metadata & Audit Context Payload',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black38 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: metadata.entries
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e.key}: ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${e.value}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('Copy Audit JSON', style: TextStyle(fontSize: 12)),
            onPressed: () {
              final jsonStr = const JsonEncoder.withIndent('  ').convert(item);
              Clipboard.setData(ClipboardData(text: jsonStr));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Audit record JSON copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade700),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
