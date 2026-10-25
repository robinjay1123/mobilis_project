part of '../admin_web_screen.dart';

extension _AdminUsersTab on _AdminWebScreenState {
  Widget _buildUsersContent(bool isDark) {
    final activeUsers =
        _allUsers.where((u) => u['is_archived'] != true).toList();

    final filteredUsers = activeUsers.where((user) {
      final name = (user['full_name'] ?? '').toLowerCase();
      final email = (user['email'] ?? '').toLowerCase();
      final role = (user['role'] as String? ?? 'renter').toLowerCase();
      final isPsdc = user['is_psdc_driver'] == true;
      final verificationStatus =
          (user['display_verification_status'] ??
                  user['verification_status'] ??
                  '')
              .toString()
              .toLowerCase();
      final isPending = verificationStatus == 'pending' || verificationStatus == 'submitted';
      final isVerified = !isPending &&
          (user['id_verified'] == true ||
              user['is_verified'] == true ||
              verificationStatus == 'verified' ||
              verificationStatus == 'approved');

      final matchesSearch =
          name.contains(_userSearchQuery.toLowerCase()) ||
          email.contains(_userSearchQuery.toLowerCase());

      final matchesRole =
          _userRoleFilter == 'all' ||
          role == _userRoleFilter ||
          (_userRoleFilter == 'psdc' && isPsdc) ||
          (_userRoleFilter == 'verified' && isVerified) ||
          (_userRoleFilter == 'unverified' && !isVerified);

      final matchesVerification =
          _userVerificationFilter == 'all' ||
          (_userVerificationFilter == 'verified' && isVerified) ||
          (_userVerificationFilter == 'unverified' && !isVerified);

      return matchesSearch && matchesRole && matchesVerification;
    }).toList();

    final totalPages = (filteredUsers.length / _usersPerPage).ceil();
    final startIndex = (_currentUserPage - 1) * _usersPerPage;
    final endIndex = (startIndex + _usersPerPage).clamp(
      0,
      filteredUsers.length,
    );
    final paginatedUsers = filteredUsers.sublist(startIndex, endIndex.toInt());

    final partnersCount =
        activeUsers.where((u) => u['role'] == 'partner').length;
    final operatorsCount = activeUsers
        .where((u) => u['role'] == 'operator')
        .length;
    final psdcDriversCount = activeUsers
        .where((u) => u['is_psdc_driver'] == true)
        .length;
    final verifiedCount = activeUsers.where((u) {
      final status =
          (u['display_verification_status'] ?? u['verification_status'] ?? '')
              .toString()
              .toLowerCase();
      final isPending = status == 'pending' || status == 'submitted' || status == 'rejected';
      return !isPending &&
          (u['id_verified'] == true ||
              u['is_verified'] == true ||
              status == 'verified' ||
              status == 'approved');
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildUserStatCard(
                  'Active Users',
                  activeUsers.length.toString(),
                  Icons.people_rounded,
                  Colors.blue,
                  isDark,
                  onTap: () {
                    setState(() {
                      _userRoleFilter = 'all';
                      _userVerificationFilter = 'all';
                      _currentUserPage = 1;
                    });
                  },
                  isSelected:
                      _userRoleFilter == 'all' &&
                      _userVerificationFilter == 'all',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Verified',
                  verifiedCount.toString(),
                  Icons.verified_rounded,
                  Colors.green,
                  isDark,
                  onTap: () {
                    setState(() {
                      _userVerificationFilter =
                          _userVerificationFilter == 'verified'
                          ? 'all'
                          : 'verified';
                      _currentUserPage = 1;
                    });
                  },
                  isSelected: _userVerificationFilter == 'verified',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Partners',
                  partnersCount.toString(),
                  Icons.business_rounded,
                  Colors.purple,
                  isDark,
                  onTap: () {
                    setState(() {
                      _userRoleFilter = _userRoleFilter == 'partner'
                          ? 'all'
                          : 'partner';
                      _currentUserPage = 1;
                    });
                  },
                  isSelected: _userRoleFilter == 'partner',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Operators',
                  operatorsCount.toString(),
                  Icons.admin_panel_settings_rounded,
                  Colors.orange,
                  isDark,
                  onTap: () {
                    setState(() {
                      _userRoleFilter = _userRoleFilter == 'operator'
                          ? 'all'
                          : 'operator';
                      _currentUserPage = 1;
                    });
                  },
                  isSelected: _userRoleFilter == 'operator',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'PSDC Drivers',
                  psdcDriversCount.toString(),
                  Icons.badge_rounded,
                  const Color(0xFFF59E0B),
                  isDark,
                  onTap: () {
                    setState(() {
                      _userRoleFilter = _userRoleFilter == 'psdc'
                          ? 'all'
                          : 'psdc';
                      _currentUserPage = 1;
                    });
                  },
                  isSelected: _userRoleFilter == 'psdc',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Archived',
                  _archivedUsersCount.toString(),
                  Icons.archive_rounded,
                  Colors.blueGrey,
                  isDark,
                  onTap: () {
                    setState(() => _selectedIndex = 14);
                  },
                  isSelected: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 260, maxWidth: 380),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _userSearchQuery = value;
                      _currentUserPage = 1;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
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
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
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
                  cursorColor: AppColors.primary,
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
                  value: _userRoleFilter,
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
                    DropdownMenuItem(
                      value: 'psdc',
                      child: _buildUserFilterOption(
                        icon: Icons.badge_rounded,
                        label: 'PSDC Drivers',
                        color: isDark
                            ? Colors.amber.shade300
                            : Colors.amber.shade900,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'verified',
                      child: _buildUserFilterOption(
                        icon: Icons.verified_rounded,
                        label: 'Verified Users',
                        color: isDark
                            ? Colors.green.shade300
                            : Colors.green.shade800,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'unverified',
                      child: _buildUserFilterOption(
                        icon: Icons.pending_outlined,
                        label: 'Unverified Users',
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _userRoleFilter = value ?? 'all';
                      _currentUserPage = 1;
                    });
                  },
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
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
                  value: _userVerificationFilter,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'All Verification',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'verified',
                      child: _buildUserFilterOption(
                        icon: Icons.verified_rounded,
                        label: 'Verified Only',
                        color: isDark
                            ? Colors.green.shade300
                            : Colors.green.shade800,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'unverified',
                      child: _buildUserFilterOption(
                        icon: Icons.pending_outlined,
                        label: 'Unverified Only',
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _userVerificationFilter = value ?? 'all';
                      _currentUserPage = 1;
                    });
                  },
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddOperatorDialog(isDark),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
                label: const Text('Add Operator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 17,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                            'Name',
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
                            'Email',
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
                            'Verified',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
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
                if (paginatedUsers.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: isDark
                                ? Colors.white30
                                : Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No users found',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...paginatedUsers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final user = entry.value;
                    final role = user['role'] as String? ?? 'renter';
                    final isPsdcDriver = user['is_psdc_driver'] == true;
                    final isVerified = user['id_verified'] as bool? ?? false;
                    final isLast = index == paginatedUsers.length - 1;

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: !isLast
                                ? Border(
                                    bottom: BorderSide(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.grey.shade200,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            user['full_name'] ?? 'User',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if ((user['phone'] as String? ?? '')
                                              .isNotEmpty)
                                            Text(
                                              user['phone'].toString(),
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.grey.shade600,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  user['email'] ?? '',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
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
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: _buildVerificationBadge(
                                    isVerified,
                                    status: (user['display_verification_status'] ??
                                            user['verification_status'])
                                        ?.toString(),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      if (value == 'archive' ||
                                          value == 'delete') {
                                        _archiveUser(user);
                                      } else if (value == 'toggle_psdc') {
                                        _togglePsdcDriverStatus(user);
                                      } else {
                                        _updateUserRole(user['id'], value);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'toggle_psdc',
                                        child: Row(
                                          children: [
                                            Icon(
                                              isPsdcDriver
                                                  ? Icons
                                                        .remove_moderator_outlined
                                                  : Icons.badge_rounded,
                                              size: 18,
                                              color: isPsdcDriver
                                                  ? Colors.orange
                                                  : AppColors.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isPsdcDriver
                                                  ? 'Unflag as PSDC Driver'
                                                  : 'Flag as PSDC Driver',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: isPsdcDriver
                                                    ? Colors.orange
                                                    : AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'renter',
                                        child: Text('Set as Renter'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'partner',
                                        child: Text('Set as Partner'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'operator',
                                        child: Text('Set as Operator'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'driver',
                                        child: Text('Set as Driver'),
                                      ),
                                      const PopupMenuDivider(),
                                      PopupMenuItem(
                                        value: 'archive',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.archive_outlined,
                                              size: 18,
                                              color: Colors.orange.shade800,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Archive User',
                                              style: TextStyle(
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),

                if (totalPages > 1)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${startIndex + 1} to $endIndex of ${filteredUsers.length} users',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _currentUserPage > 1
                                  ? () => setState(() => _currentUserPage--)
                                  : null,
                              icon: const Icon(Icons.chevron_left, size: 18),
                              label: const Text('Previous'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                disabledBackgroundColor: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black26
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Page $_currentUserPage of $totalPages',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _currentUserPage < totalPages
                                  ? () => setState(() => _currentUserPage++)
                                  : null,
                              icon: const Icon(Icons.chevron_right, size: 18),
                              label: const Text('Next'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                disabledBackgroundColor: Colors.grey.shade400,
                              ),
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

  Widget _buildUserFilterOption({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildUserStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Tooltip(
      message: 'Filter user table by $title ($value total accounts)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppColors.borderColor : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  String _getUserAvatarUrl(Map<String, dynamic> user) {
    final direct =
        user['avatar_url']?.toString().trim() ??
        user['profile_picture_url']?.toString().trim() ??
        user['profile_image']?.toString().trim() ??
        user['photo_url']?.toString().trim() ??
        user['image_url']?.toString().trim() ??
        '';
    if (direct.isNotEmpty &&
        (direct.startsWith('http') || direct.startsWith('gs://'))) {
      return direct;
    }
    return '';
  }

  Widget _buildUserAvatarCell(Map<String, dynamic> user, bool isPsdcDriver) {
    final avatarUrl = _getUserAvatarUrl(user);
    final fullName = user['full_name']?.toString().trim() ?? 'User';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

    if (avatarUrl.isNotEmpty) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isPsdcDriver
                ? const Color(0xFFF59E0B)
                : AppColors.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: OptimizedNetworkImage(
            imageUrl: avatarUrl,
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorWidget: Container(
              color: isPsdcDriver
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                  : Colors.blue.withValues(alpha: 0.2),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: isPsdcDriver ? const Color(0xFFF59E0B) : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 19,
      backgroundColor: isPsdcDriver
          ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
          : Colors.blue.withValues(alpha: 0.2),
      child: Text(
        initial,
        style: TextStyle(
          color: isPsdcDriver ? const Color(0xFFF59E0B) : Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(bool isVerified, {String? status}) {
    final normalized = (status ?? '').trim().toLowerCase();
    if (isVerified || normalized == 'verified' || normalized == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: Colors.green, size: 14),
            SizedBox(width: 5),
            Text(
              'Verified',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (normalized == 'pending' || normalized == 'submitted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 14),
            SizedBox(width: 5),
            Text(
              'Pending',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.4),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pending_outlined, color: Colors.grey, size: 14),
          SizedBox(width: 5),
          Text(
            'Unverified',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role, {bool isPsdcDriver = false}) {
    if (isPsdcDriver) {
      return Tooltip(
        message: 'PSDC Dedicated In-House Fleet Driver',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706).withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_rounded, size: 13, color: Color(0xFFF59E0B)),
              SizedBox(width: 4),
              Text(
                'PSDC DRIVER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF59E0B),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Color color;
    switch (role) {
      case 'partner':
        color = Colors.blue;
        break;
      case 'operator':
        color = Colors.purple;
        break;
      case 'admin':
        color = Colors.red;
        break;
      case 'driver':
        color = Colors.teal;
        break;
      default:
        color = Colors.green;
    }

    final roleDescription = switch (role.toLowerCase()) {
      'partner' => 'Partner: Vehicle fleet owner registered on platform',
      'operator' => 'Operator: Operations desk managing bookings and fleet',
      'admin' => 'Administrator: Full system privileges and settings',
      'driver' => 'Driver: Assigned trip driver for chauffeur bookings',
      'renter' => 'Renter: Customer booking and renting vehicles',
      _ => 'Role: ${role.toUpperCase()}',
    };

    return Tooltip(
      message: roleDescription,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          role.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
