import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/admin/admin_user_card.dart';
import '../../../widgets/admin/admin_stat_card.dart';

class UserDirectoryTab extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final Function(Map<String, dynamic>)? onUserTap;
  final Function(Map<String, dynamic>)? onVerifyUser;
  final VoidCallback? onAddUser;
  final VoidCallback? onExportCsv;

  const UserDirectoryTab({
    super.key,
    required this.users,
    this.onUserTap,
    this.onVerifyUser,
    this.onAddUser,
    this.onExportCsv,
  });

  @override
  State<UserDirectoryTab> createState() => _UserDirectoryTabState();
}

class _UserDirectoryTabState extends State<UserDirectoryTab> {
  String _selectedFilter = 'All Users';
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 4;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = [
    'All Users',
    'Renters',
    'Owners',
    'Operators',
    'Drivers',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var filtered = widget.users;

    // Apply role filter
    if (_selectedFilter != 'All Users') {
      final filterRole = _selectedFilter.toLowerCase().replaceAll('s', '');
      filtered = filtered.where((user) {
        final role = (user['role'] ?? '').toString().toLowerCase();
        return role.contains(filterRole);
      }).toList();
    }

    // Apply search
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

  List<Map<String, dynamic>> get _paginatedUsers {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    return _filteredUsers.length > start
        ? _filteredUsers.sublist(
            start,
            end > _filteredUsers.length ? _filteredUsers.length : end,
          )
        : [];
  }

  int get _totalPages => (_filteredUsers.length / _itemsPerPage).ceil();

  int get _newApplicationsCount =>
      widget.users.where((u) => u['is_new'] == true).length;

  int get _verifiedCount => widget.users
      .where(
        (u) =>
            (u['verification_status'] ?? '').toString().toLowerCase() ==
            'verified',
      )
      .length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Yellow Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Directory',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your ecosystem of renters, owners, and service drivers from a single command center.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onAddUser,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add New User'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onExportCsv,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: AdminStatCard(
                        title: 'New Applications',
                        value: _newApplicationsCount.toString(),
                        subtitle: '+3 since yesterday',
                        icon: Icons.person_add_outlined,
                        iconColor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AdminStatCard(
                        title: 'Active Fleet',
                        value: widget.users.length.toString(),
                        subtitle:
                            '${(_verifiedCount / (widget.users.isEmpty ? 1 : widget.users.length) * 100).toStringAsFixed(0)}% Verification rate',
                        icon: Icons.verified,
                        iconColor: AppColors.success,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = filter;
                              _currentPage = 1;
                            });
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: isDark
                              ? AppColors.darkCard
                              : AppColors.lightBgTertiary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : (isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                          checkmarkColor: Colors.black,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.borderColor
                                      : AppColors.lightBorderColor),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _currentPage = 1;
                    });
                  },
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search users by name or email...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.lightTextTertiary,
                      fontSize: 14,
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

                const SizedBox(height: 16),

                // User List
                ..._paginatedUsers.map(
                  (user) => AdminUserCard(
                    name: user['full_name'] ?? 'Unknown User',
                    email: user['email'] ?? '',
                    role: user['role'] ?? 'user',
                    status: user['verification_status'] ?? 'Pending',
                    avatarUrl: user['avatar_url'],
                    userId: user['id'] != null
                        ? '#USR-${user['id'].toString().substring(0, 4).toUpperCase()}'
                        : null,
                    isNew: user['is_new'] ?? false,
                    onViewDetails: () => widget.onUserTap?.call(user),
                    onVerify:
                        (user['verification_status'] ?? '').toLowerCase() ==
                            'pending'
                        ? () => widget.onVerifyUser?.call(user)
                        : null,
                  ),
                ),

                if (_paginatedUsers.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: isDark
                                ? AppColors.textTertiary
                                : AppColors.lightTextTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Pagination
                if (_filteredUsers.length > _itemsPerPage) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Showing ${(_currentPage - 1) * _itemsPerPage + 1}-${_currentPage * _itemsPerPage > _filteredUsers.length ? _filteredUsers.length : _currentPage * _itemsPerPage} of ${_filteredUsers.length} users',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _currentPage > 1
                            ? () => setState(() => _currentPage--)
                            : null,
                        icon: Icon(
                          Icons.chevron_left,
                          color: _currentPage > 1
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.textTertiary
                                    : AppColors.lightTextTertiary),
                        ),
                      ),
                      ...List.generate(_totalPages > 5 ? 5 : _totalPages, (
                        index,
                      ) {
                        final pageNum = index + 1;
                        final isActive = pageNum == _currentPage;
                        return GestureDetector(
                          onTap: () => setState(() => _currentPage = pageNum),
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isActive
                                  ? null
                                  : Border.all(
                                      color: isDark
                                          ? AppColors.borderColor
                                          : AppColors.lightBorderColor,
                                    ),
                            ),
                            child: Center(
                              child: Text(
                                pageNum.toString(),
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.black
                                      : (isDark
                                            ? AppColors.textSecondary
                                            : AppColors.lightTextSecondary),
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      IconButton(
                        onPressed: _currentPage < _totalPages
                            ? () => setState(() => _currentPage++)
                            : null,
                        icon: Icon(
                          Icons.chevron_right,
                          color: _currentPage < _totalPages
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.textTertiary
                                    : AppColors.lightTextTertiary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
