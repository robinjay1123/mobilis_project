part of '../admin_web_screen.dart';

extension AdminArchivedAccountsTab on _AdminWebScreenState {
  Widget _buildArchivedAccountsContent(bool isDark) {
    final archivedUsers =
        _allUsers.where((u) => u['is_archived'] == true).toList();

    final filteredUsers = archivedUsers.where((user) {
      final name = (user['full_name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final phone = (user['phone'] ?? '').toString().toLowerCase();
      final role = (user['role'] as String? ?? 'renter').toLowerCase();

      final q = _archivedSearchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          phone.contains(q);

      final matchesRole =
          _archivedRoleFilter == 'all' || role == _archivedRoleFilter;

      return matchesSearch && matchesRole;
    }).toList();

    final totalPages = (filteredUsers.length / _archivedPerPage).ceil();
    final startIndex = (_currentArchivedPage - 1) * _archivedPerPage;
    final endIndex =
        (startIndex + _archivedPerPage).clamp(0, filteredUsers.length);
    final paginatedUsers = filteredUsers.sublist(startIndex, endIndex.toInt());

    final rentersCount = archivedUsers
        .where((u) => (u['role'] ?? 'renter').toString().toLowerCase() == 'renter')
        .length;
    final partnersCount =
        archivedUsers.where((u) => u['role'] == 'partner').length;
    final operatorsCount =
        archivedUsers.where((u) => u['role'] == 'operator').length;
    final driversCount =
        archivedUsers.where((u) => u['role'] == 'driver').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header description & actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.archive_rounded,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Archived Accounts',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${archivedUsers.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Review deactivated user accounts. Archived accounts preserve all booking, financial, and activity history and can be restored at any time.',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _selectedIndex = 1);
                    },
                    icon: const Icon(Icons.people_outline_rounded, size: 18),
                    label: const Text('Back to Active Users'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _loadDashboardData(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildUserStatCard(
                  'Total Archived',
                  archivedUsers.length.toString(),
                  Icons.archive_rounded,
                  Colors.orange,
                  isDark,
                  onTap: () {
                    setState(() {
                      _archivedRoleFilter = 'all';
                      _currentArchivedPage = 1;
                    });
                  },
                  isSelected: _archivedRoleFilter == 'all',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Archived Renters',
                  rentersCount.toString(),
                  Icons.person_outline_rounded,
                  Colors.green,
                  isDark,
                  onTap: () {
                    setState(() {
                      _archivedRoleFilter =
                          _archivedRoleFilter == 'renter' ? 'all' : 'renter';
                      _currentArchivedPage = 1;
                    });
                  },
                  isSelected: _archivedRoleFilter == 'renter',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Archived Partners',
                  partnersCount.toString(),
                  Icons.business_rounded,
                  Colors.blue,
                  isDark,
                  onTap: () {
                    setState(() {
                      _archivedRoleFilter =
                          _archivedRoleFilter == 'partner' ? 'all' : 'partner';
                      _currentArchivedPage = 1;
                    });
                  },
                  isSelected: _archivedRoleFilter == 'partner',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Archived Drivers',
                  driversCount.toString(),
                  Icons.drive_eta_rounded,
                  Colors.teal,
                  isDark,
                  onTap: () {
                    setState(() {
                      _archivedRoleFilter =
                          _archivedRoleFilter == 'driver' ? 'all' : 'driver';
                      _currentArchivedPage = 1;
                    });
                  },
                  isSelected: _archivedRoleFilter == 'driver',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Archived Operators',
                  operatorsCount.toString(),
                  Icons.admin_panel_settings_rounded,
                  Colors.purple,
                  isDark,
                  onTap: () {
                    setState(() {
                      _archivedRoleFilter =
                          _archivedRoleFilter == 'operator' ? 'all' : 'operator';
                      _currentArchivedPage = 1;
                    });
                  },
                  isSelected: _archivedRoleFilter == 'operator',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Search & Filter controls
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minWidth: 260, maxWidth: 380),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _archivedSearchQuery = value;
                      _currentArchivedPage = 1;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search archived accounts by name, email, phone...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AppColors.primary, width: 2),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? Colors.grey : Colors.grey.shade500,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderColor
                        : Colors.grey.shade200,
                  ),
                ),
                child: DropdownButton<String>(
                  value: _archivedRoleFilter,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'All Roles',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'renter',
                      child: Text(
                        'Renters',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'partner',
                      child: Text(
                        'Partners',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'operator',
                      child: Text(
                        'Operators',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'driver',
                      child: Text(
                        'Drivers',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _archivedRoleFilter = value ?? 'all';
                      _currentArchivedPage = 1;
                    });
                  },
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Table or Empty State
          if (archivedUsers.isEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.archive_outlined,
                      size: 48,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Archived Accounts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When user accounts are archived from the active users list, they will appear here.',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedIndex = 1),
                    icon: const Icon(Icons.people_outline_rounded, size: 18),
                    label: const Text('View Active Users'),
                  ),
                ],
              ),
            )
          else if (filteredUsers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 40,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No matching archived accounts',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try changing your search keywords or role filters.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'User',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Email & Phone',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Role',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'Archived Date',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'Actions',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Table Rows
                  ...paginatedUsers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final user = entry.value;
                    final isEven = index % 2 == 0;
                    final role =
                        (user['role'] as String? ?? 'renter').toLowerCase();
                    final isPsdcDriver = user['is_psdc_driver'] == true;
                    final archivedAtStr = user['archived_at']?.toString() ??
                        user['updated_at']?.toString();
                    String formattedDate = 'Archived';
                    if (archivedAtStr != null && archivedAtStr.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(archivedAtStr);
                        formattedDate = '${dt.month}/${dt.day}/${dt.year}';
                      } catch (_) {
                        formattedDate = archivedAtStr.split('T').first;
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isEven
                            ? Colors.transparent
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.grey.shade50),
                        border: Border(
                          bottom: BorderSide(
                            color:
                                isDark ? Colors.white10 : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // User Name + Avatar
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                _buildUserAvatarCell(user, isPsdcDriver),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        user['full_name'] ??
                                            'User (${user['id']})',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'ID: ${user['id']}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Email & Phone
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user['email'] ?? 'No email',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((user['phone'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text(
                                    user['phone'].toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Role
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildRoleBadge(
                                role,
                                isPsdcDriver: isPsdcDriver,
                              ),
                            ),
                          ),
                          // Archived Date
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Tooltip(
                                message:
                                    archivedAtStr ?? 'No timestamp recorded',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 13,
                                      color: isDark
                                          ? Colors.grey
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      formattedDate,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Status Badge
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.archive_outlined,
                                      size: 12,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'ARCHIVED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Action Buttons
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message:
                                        'Restore Account to Active Status',
                                    child: ElevatedButton.icon(
                                      onPressed: () => _restoreUser(user),
                                      icon: const Icon(
                                        Icons.unarchive_rounded,
                                        size: 15,
                                      ),
                                      label: const Text(
                                        'Restore',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.green.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    splashRadius: 18,
                                    icon: Icon(
                                      Icons.more_vert,
                                      size: 18,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    onSelected: (value) {
                                      if (value == 'restore') {
                                        _restoreUser(user);
                                      } else if (value == 'details') {
                                        _showArchivedUserDetails(user, isDark);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'restore',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.unarchive_rounded,
                                              color: Colors.green,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Restore Account'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'details',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline_rounded,
                                              color: Colors.blue,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text('View Details'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  // Pagination
                  if (totalPages > 1)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${startIndex + 1} to $endIndex of ${filteredUsers.length} archived accounts',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentArchivedPage > 1
                                    ? () => setState(
                                        () => _currentArchivedPage--)
                                    : null,
                              ),
                              Text(
                                'Page $_currentArchivedPage of $totalPages',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentArchivedPage < totalPages
                                    ? () => setState(
                                        () => _currentArchivedPage++)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showArchivedUserDetails(Map<String, dynamic> user, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.account_box_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Archived Account Details'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _buildUserAvatarCell(
                  user,
                  user['is_psdc_driver'] == true,
                ),
                title: Text(
                  user['full_name'] ?? 'No Name',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(user['email'] ?? 'No email'),
              ),
              const Divider(),
              _buildArchivedDetailRow(
                'User ID',
                user['id']?.toString() ?? '-',
                isDark,
              ),
              _buildArchivedDetailRow(
                'Phone',
                user['phone']?.toString() ?? '-',
                isDark,
              ),
              _buildArchivedDetailRow(
                'Role',
                (user['role']?.toString() ?? 'renter').toUpperCase(),
                isDark,
              ),
              _buildArchivedDetailRow(
                'Created At',
                user['created_at']?.toString() ?? '-',
                isDark,
              ),
              _buildArchivedDetailRow(
                'Archived At',
                user['archived_at']?.toString() ?? 'Archived',
                isDark,
              ),
              _buildArchivedDetailRow(
                'Verification',
                (user['display_verification_status'] ??
                        user['verification_status'] ??
                        '-')
                    .toString(),
                isDark,
              ),
              _buildArchivedDetailRow(
                'Account Status',
                'Deactivated (Archived)',
                isDark,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _restoreUser(user);
            },
            icon: const Icon(Icons.unarchive_rounded, size: 16),
            label: const Text('Restore Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
