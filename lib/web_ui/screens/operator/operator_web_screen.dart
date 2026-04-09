import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../mobile_ui/theme/app_colors.dart';
import '../../../services/auth_service.dart';

class OperatorWebScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const OperatorWebScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  State<OperatorWebScreen> createState() => _OperatorWebScreenState();
}

class _OperatorWebScreenState extends State<OperatorWebScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _sidebarExpanded = true;

  // Stats
  int _totalUsers = 0;
  int _totalPartners = 0;
  int _totalVehicles = 0;
  int _pendingVerifications = 0;
  int _activeBookings = 0;
  int _totalBookings = 0;

  // Lists
  List<Map<String, dynamic>> _pendingApplications = [];
  List<Map<String, dynamic>> _recentBookings = [];
  List<Map<String, dynamic>> _users = [];

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadStats(),
        _loadPendingApplications(),
        _loadRecentBookings(),
        _loadUsers(),
      ]);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    try {
      final usersResponse = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'renter');
      _totalUsers = (usersResponse as List).length;

      final partnersResponse = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'partner');
      _totalPartners = (partnersResponse as List).length;

      final vehiclesResponse = await _supabase
          .from('vehicles')
          .select('id')
          .eq('status', 'active');
      _totalVehicles = (vehiclesResponse as List).length;

      final pendingResponse = await _supabase
          .from('vehicle_applications')
          .select('id')
          .eq('status', 'pending');
      _pendingVerifications = (pendingResponse as List).length;

      final activeBookingsResponse = await _supabase
          .from('bookings')
          .select('id')
          .eq('status', 'active');
      _activeBookings = (activeBookingsResponse as List).length;

      final totalBookingsResponse = await _supabase
          .from('bookings')
          .select('id');
      _totalBookings = (totalBookingsResponse as List).length;
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadPendingApplications() async {
    try {
      final response = await _supabase
          .from('vehicle_applications')
          .select('''
            *,
            partners:partner_id (
              user_id,
              users:user_id (full_name, email)
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);

      _pendingApplications = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading pending applications: $e');
      _pendingApplications = [];
    }
  }

  Future<void> _loadRecentBookings() async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('''
            *,
            vehicles:vehicle_id (brand, model, year),
            users:renter_id (full_name, email)
          ''')
          .order('created_at', ascending: false)
          .limit(50);

      _recentBookings = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading recent bookings: $e');
      _recentBookings = [];
    }
  }

  Future<void> _loadUsers() async {
    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .order('created_at', ascending: false)
          .limit(100);

      _users = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading users: $e');
      _users = [];
    }
  }

  Future<void> _handleApplicationAction(
    String applicationId,
    String action,
  ) async {
    try {
      await _supabase
          .from('vehicle_applications')
          .update({'status': action})
          .eq('id', applicationId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Application ${action == 'approved' ? 'approved' : 'rejected'}',
          ),
          backgroundColor: action == 'approved' ? Colors.green : Colors.red,
        ),
      );

      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1200;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F5F5),
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(isDark, isCompact),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isDark),
                Expanded(child: _buildContent(isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDark, bool isCompact) {
    final sidebarWidth = _sidebarExpanded ? 260.0 : 70.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo/Header
          Container(
            height: 70,
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarExpanded ? 20 : 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PSDC Operator',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          'Management Portal',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildNavItem(0, Icons.dashboard, 'Dashboard', isDark),
                _buildNavItem(
                  1,
                  Icons.assignment,
                  'Applications',
                  isDark,
                  badge: _pendingVerifications > 0
                      ? _pendingVerifications
                      : null,
                ),
                _buildNavItem(2, Icons.book, 'Bookings', isDark),
                _buildNavItem(3, Icons.people, 'Users', isDark),
                _buildNavItem(4, Icons.directions_car, 'Vehicles', isDark),
                const SizedBox(height: 20),
                if (_sidebarExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'SETTINGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey : Colors.grey.shade500,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                _buildNavItem(5, Icons.settings, 'Settings', isDark),
              ],
            ),
          ),
          // Collapse Button
          InkWell(
            onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: _sidebarExpanded
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.center,
                children: [
                  Icon(
                    _sidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    bool isDark, {
    int? badge,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: _sidebarExpanded ? 16 : 0),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: _sidebarExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.grey : Colors.grey.shade600),
                size: 22,
              ),
              if (_sidebarExpanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white : Colors.black),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _getPageTitle(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const Spacer(),
          // Theme Toggle
          IconButton(
            onPressed: () => widget.onThemeToggle?.call(!widget.isDarkMode),
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 10),
          // Refresh
          IconButton(
            onPressed: _loadDashboardData,
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 20),
          // User Menu
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _handleLogout();
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.person,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Operator',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 10),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Vehicle Applications';
      case 2:
        return 'Bookings';
      case 3:
        return 'Users';
      case 4:
        return 'Vehicles';
      case 5:
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent(isDark);
      case 1:
        return _buildApplicationsContent(isDark);
      case 2:
        return _buildBookingsContent(isDark);
      case 3:
        return _buildUsersContent(isDark);
      case 4:
        return _buildVehiclesContent(isDark);
      case 5:
        return _buildSettingsContent(isDark);
      default:
        return _buildDashboardContent(isDark);
    }
  }

  Widget _buildDashboardContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 2,
            children: [
              _buildStatCard(
                'Total Users',
                _totalUsers.toString(),
                Icons.person,
                Colors.blue,
                isDark,
              ),
              _buildStatCard(
                'Partners',
                _totalPartners.toString(),
                Icons.business,
                Colors.green,
                isDark,
              ),
              _buildStatCard(
                'Active Vehicles',
                _totalVehicles.toString(),
                Icons.directions_car,
                Colors.orange,
                isDark,
              ),
              _buildStatCard(
                'Pending Reviews',
                _pendingVerifications.toString(),
                Icons.pending_actions,
                Colors.red,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 30),
          // Two Column Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recent Bookings
              Expanded(
                flex: 2,
                child: _buildCard(
                  'Recent Bookings',
                  _buildBookingsTable(isDark),
                  isDark,
                ),
              ),
              const SizedBox(width: 20),
              // Pending Applications
              Expanded(
                child: _buildCard(
                  'Pending Applications',
                  _buildPendingList(isDark),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, Widget content, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildBookingsTable(bool isDark) {
    if (_recentBookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No bookings found',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return DataTable(
      columns: [
        DataColumn(
          label: Text(
            'Vehicle',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        DataColumn(
          label: Text(
            'Renter',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        DataColumn(
          label: Text(
            'Status',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
      ],
      rows: _recentBookings.take(8).map((booking) {
        final vehicle = booking['vehicles'] as Map<String, dynamic>?;
        final user = booking['users'] as Map<String, dynamic>?;
        final status = booking['status'] as String? ?? 'pending';

        return DataRow(
          cells: [
            DataCell(
              Text(
                vehicle != null
                    ? '${vehicle['brand']} ${vehicle['model']}'
                    : 'Unknown',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            DataCell(
              Text(
                user?['full_name'] ?? 'Unknown',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            DataCell(_buildStatusBadge(status)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPendingList(bool isDark) {
    if (_pendingApplications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                size: 48,
                color: Colors.green.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No pending applications',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _pendingApplications.take(5).map((app) {
        return _buildApplicationTile(app, isDark);
      }).toList(),
    );
  }

  Widget _buildApplicationTile(Map<String, dynamic> application, bool isDark) {
    final partner = application['partners'] as Map<String, dynamic>?;
    final user = partner?['users'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${application['brand'] ?? ''} ${application['model'] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  user?['full_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _handleApplicationAction(
              application['id'].toString(),
              'approved',
            ),
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Approve',
          ),
          IconButton(
            onPressed: () => _handleApplicationAction(
              application['id'].toString(),
              'rejected',
            ),
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Reject',
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'Vehicle Applications (${_pendingApplications.length} pending)',
        _pendingApplications.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(60),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.green.withOpacity(0.5),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'All applications reviewed!',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: _pendingApplications
                    .map((app) => _buildApplicationTile(app, isDark))
                    .toList(),
              ),
        isDark,
      ),
    );
  }

  Widget _buildBookingsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'All Bookings (${_recentBookings.length})',
        _recentBookings.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No bookings'),
                ),
              )
            : DataTable(
                columns: [
                  DataColumn(
                    label: Text(
                      'Vehicle',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Renter',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Total',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
                rows: _recentBookings.map((booking) {
                  final vehicle = booking['vehicles'] as Map<String, dynamic>?;
                  final user = booking['users'] as Map<String, dynamic>?;
                  final status = booking['status'] as String? ?? 'pending';
                  final total =
                      (booking['total_cost'] as num?)?.toDouble() ?? 0;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          vehicle != null
                              ? '${vehicle['brand']} ${vehicle['model']}'
                              : 'Unknown',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          user?['full_name'] ?? 'Unknown',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      DataCell(_buildStatusBadge(status)),
                      DataCell(
                        Text(
                          'PHP ${total.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
        isDark,
      ),
    );
  }

  Widget _buildUsersContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'Users (${_users.length})',
        _users.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No users'),
                ),
              )
            : DataTable(
                columns: [
                  DataColumn(
                    label: Text(
                      'Name',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Email',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Role',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Verified',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
                rows: _users.map((user) {
                  final role = user['role'] as String? ?? 'renter';
                  final isVerified = user['id_verified'] as bool? ?? false;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          user['full_name'] ?? 'No Name',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          user['email'] ?? '',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      DataCell(_buildRoleBadge(role)),
                      DataCell(
                        Icon(
                          isVerified ? Icons.verified : Icons.pending,
                          color: isVerified ? Colors.blue : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
        isDark,
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
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
      default:
        color = Colors.green;
    }

    return Container(
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
    );
  }

  Widget _buildVehiclesContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'Vehicles',
        const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('Vehicle management coming soon'),
          ),
        ),
        isDark,
      ),
    );
  }

  Widget _buildSettingsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            'Appearance',
            Row(
              children: [
                Text(
                  'Dark Mode',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                const Spacer(),
                Switch(
                  value: widget.isDarkMode,
                  onChanged: widget.onThemeToggle,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),
          _buildCard(
            'Account',
            Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _handleLogout,
                ),
              ],
            ),
            isDark,
          ),
        ],
      ),
    );
  }
}
