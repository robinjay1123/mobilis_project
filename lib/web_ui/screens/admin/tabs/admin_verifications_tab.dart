part of '../admin_web_screen.dart';

extension _AdminVerificationsTab on _AdminWebScreenState {
  Widget _buildVerificationsContent(bool isDark) {
    // 1. Calculate role stats for badges
    int allCount = _verificationRecords.length;
    int renterCount = 0;
    int driverCount = 0;
    int partnerCount = 0;

    for (final r in _verificationRecords) {
      final user = r['users'] as Map<String, dynamic>?;
      final role = (user?['role']?.toString() ?? r['role']?.toString() ?? '')
          .toLowerCase()
          .trim();
      if (role == 'partner') {
        partnerCount++;
      } else if (role == 'driver') {
        driverCount++;
      } else {
        renterCount++;
      }
    }

    // 2. Filter records based on search query and selected role sub-tab
    final filteredRecords = _verificationRecords.where((r) {
      if (_verificationRoleFilter != 'all') {
        final user = r['users'] as Map<String, dynamic>?;
        final role = (user?['role']?.toString() ?? r['role']?.toString() ?? '')
            .toLowerCase()
            .trim();

        if (_verificationRoleFilter == 'renter') {
          if (role != 'renter' && role.isNotEmpty && role != 'customer') {
            return false;
          }
        } else if (_verificationRoleFilter == 'driver') {
          if (role != 'driver') return false;
        } else if (_verificationRoleFilter == 'partner') {
          if (role != 'partner') return false;
        }
      }

      if (_verificationSearchQuery.trim().isNotEmpty) {
        final q = _verificationSearchQuery.toLowerCase().trim();
        final user = r['users'] as Map<String, dynamic>?;
        final name =
            (user?['full_name']?.toString() ?? r['full_name']?.toString() ?? '')
                .toLowerCase();
        final email =
            (user?['email']?.toString() ?? r['email']?.toString() ?? '')
                .toLowerCase();
        final role = (user?['role']?.toString() ?? r['role']?.toString() ?? '')
            .toLowerCase();
        final idType = (r['id_type']?.toString() ?? '').toLowerCase();
        final status = (r['verification_status']?.toString() ?? '')
            .toLowerCase();

        return name.contains(q) ||
            email.contains(q) ||
            role.contains(q) ||
            idType.contains(q) ||
            status.contains(q);
      }
      return true;
    }).toList();

    // 3. Separate filtered records into pending, approved, rejected
    final pendingVerifications = filteredRecords
        .where(
          (r) =>
              (r['verification_status']?.toString().toLowerCase() ?? '') ==
              'pending',
        )
        .toList();
    final approvedVerifications = filteredRecords
        .where(
          (r) =>
              (r['verification_status']?.toString().toLowerCase() ?? '') ==
                  'verified' ||
              (r['verification_status']?.toString().toLowerCase() ?? '') ==
                  'approved',
        )
        .toList();
    final rejectedVerifications = filteredRecords
        .where(
          (r) =>
              (r['verification_status']?.toString().toLowerCase() ?? '') ==
              'rejected',
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Search & Role Filter Sub-Tabs
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fact_check_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Identity & Document Verifications',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Filter and review identity verification submissions by user role (Renters, Drivers, Partners).',
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
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  height: 1,
                ),
                const SizedBox(height: 16),

                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _verificationSearchQuery = val),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search verifications by Name, Email, Role, ID Type, or Status...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black26
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _revealAllVerificationDocuments =
                              !_revealAllVerificationDocuments;
                        });
                      },
                      icon: Icon(
                        _revealAllVerificationDocuments
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 16,
                        color: _revealAllVerificationDocuments
                            ? Colors.amber
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      label: Text(
                        _revealAllVerificationDocuments
                            ? 'Hide All Documents'
                            : 'Reveal All Documents',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _revealAllVerificationDocuments
                              ? Colors.amber
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: _revealAllVerificationDocuments
                              ? Colors.amber.withValues(alpha: 0.6)
                              : (isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        backgroundColor: _revealAllVerificationDocuments
                            ? Colors.amber.withValues(alpha: 0.12)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Role Filter Sub-Tabs Chips (Matching Image 2)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildVerificationRoleTab(
                      'all',
                      'All Users',
                      allCount,
                      isDark,
                      icon: Icons.fact_check_rounded,
                    ),
                    _buildVerificationRoleTab(
                      'renter',
                      'Renters',
                      renterCount,
                      isDark,
                      icon: Icons.directions_car_rounded,
                      color: AppColors.primary,
                    ),
                    _buildVerificationRoleTab(
                      'driver',
                      'Drivers',
                      driverCount,
                      isDark,
                      icon: Icons.badge_rounded,
                      color: AppColors.primary,
                    ),
                    _buildVerificationRoleTab(
                      'partner',
                      'Partners',
                      partnerCount,
                      isDark,
                      icon: Icons.handshake_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Verification Sections
          _buildVerificationSection(
            title: 'Pending Approvals',
            records: pendingVerifications,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildVerificationSection(
            title: 'Approved Verifications',
            records: approvedVerifications,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildVerificationSection(
            title: 'Rejected Verifications',
            records: rejectedVerifications,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationRoleTab(
    String key,
    String label,
    int count,
    bool isDark, {
    IconData? icon,
    Color? color,
  }) {
    final isSelected = _verificationRoleFilter == key;
    final activeColor = color ?? AppColors.primary;
    final displayIcon = icon ?? Icons.verified_user_rounded;

    return InkWell(
      onTap: () => setState(() => _verificationRoleFilter = key),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              displayIcon,
              size: 17,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white10 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
