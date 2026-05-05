import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/admin/admin_user_card.dart';

class VerificationHubTab extends StatefulWidget {
  final List<Map<String, dynamic>> pendingUsers;
  final Function(Map<String, dynamic>)? onViewDetails;
  final Function(Map<String, dynamic>)? onApprove;
  final Function(Map<String, dynamic>)? onReject;

  const VerificationHubTab({
    super.key,
    required this.pendingUsers,
    this.onViewDetails,
    this.onApprove,
    this.onReject,
  });

  @override
  State<VerificationHubTab> createState() => _VerificationHubTabState();
}

class _VerificationHubTabState extends State<VerificationHubTab> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = ['All', 'Renters', 'Owners', 'Drivers'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var filtered = widget.pendingUsers;

    if (_selectedFilter != 'All') {
      final filterRole = _selectedFilter.toLowerCase().replaceAll('s', '');
      filtered = filtered.where((user) {
        final role = (user['role'] ?? '').toString().toLowerCase();
        return role.contains(filterRole);
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = (user['full_name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    return filtered;
  }

  int _getFilterCount(String filter) {
    if (filter == 'All') return widget.pendingUsers.length;
    final filterRole = filter.toLowerCase().replaceAll('s', '');
    return widget.pendingUsers.where((user) {
      final role = (user['role'] ?? '').toString().toLowerCase();
      return role.contains(filterRole);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending Users',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review and verify new registrations for the Mobilis fleet ecosystem.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search applicants by name, email or role...',
              hintStyle: TextStyle(
                color: isDark
                    ? AppColors.textTertiary
                    : AppColors.lightTextTertiary,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.borderColor
                      : AppColors.lightBorderColor,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.borderColor
                      : AppColors.lightBorderColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Filter Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              final count = _getFilterCount(filter);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: filter != _filters.last ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.borderColor
                                    : AppColors.lightBorderColor),
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              filter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.black
                                    : (isDark
                                          ? AppColors.textSecondary
                                          : AppColors.lightTextSecondary),
                              ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.black.withOpacity(0.2)
                                      : (isDark
                                            ? AppColors.darkBgSecondary
                                            : AppColors.lightBgTertiary),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  count.toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.black
                                        : (isDark
                                              ? AppColors.textTertiary
                                              : AppColors.lightTextTertiary),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // User List
        Expanded(
          child: _filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppColors.success.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All caught up!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No pending verifications',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return AdminUserCard(
                      name: user['full_name'] ?? 'Unknown User',
                      email: user['email'] ?? '',
                      role: user['role'] ?? 'user',
                      status: 'Pending',
                      avatarUrl: user['avatar_url'],
                      documents: _getDocuments(user),
                      onViewDetails: () => widget.onViewDetails?.call(user),
                      onApprove: () => widget.onApprove?.call(user),
                      onReject: () => widget.onReject?.call(user),
                    );
                  },
                ),
        ),

        // Pagination
        if (_filteredUsers.length > 10)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Page 1 of ${(_filteredUsers.length / 10).ceil()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<String> _getDocuments(Map<String, dynamic> user) {
    final docs = <String>[];
    final role = (user['role'] ?? '').toString().toLowerCase();

    // Add documents based on what's available
    if (user['id_card_url'] != null) docs.add('ID Card');
    if (user['drivers_license_url'] != null) docs.add('Driver License');
    if (user['face_verified'] == true) docs.add('Face Scan');

    // Role-specific docs
    if (role == 'owner' || role == 'partner') {
      if (user['vehicle_title_url'] != null) docs.add('Title');
      if (user['insurance_url'] != null) docs.add('Insurance');
    }
    if (role == 'driver') {
      if (user['nbi_clearance_url'] != null) docs.add('Background');
      if (user['professional_license_url'] != null) docs.add('License');
    }

    return docs;
  }
}
