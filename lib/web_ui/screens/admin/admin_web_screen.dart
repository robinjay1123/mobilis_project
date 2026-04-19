import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../mobile_ui/theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../mobile_ui/screens/admin/message_review_screen.dart';

class AdminWebScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const AdminWebScreen({super.key, this.onThemeToggle, this.isDarkMode = true});

  @override
  State<AdminWebScreen> createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _sidebarExpanded = true;

  // Stats
  int _totalUsers = 0;
  int _totalPartners = 0;
  int _totalOperators = 0;
  int _totalVehicles = 0;

  int _pendingVerifications = 0;
  int _activeBookings = 0;
  int _totalBookings = 0;
  double _totalRevenue = 0;

  // Lists
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allBookings = [];
  List<Map<String, dynamic>> _allVehicles = [];
  List<Map<String, dynamic>> _pendingApplications = [];

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
        _loadAllUsers(),
        _loadAllBookings(),
        _loadAllVehicles(),
        _loadPendingApplications(),
      ]);
    } catch (e) {
      debugPrint('Error loading admin dashboard: $e');
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

      final operatorsResponse = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'operator');
      _totalOperators = (operatorsResponse as List).length;

      final vehiclesResponse = await _supabase.from('vehicles').select('id');
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
          .select('id, total_cost');
      _totalBookings = (totalBookingsResponse as List).length;

      _totalRevenue = 0;
      for (var booking in totalBookingsResponse) {
        _totalRevenue += (booking['total_cost'] as num?)?.toDouble() ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .order('created_at', ascending: false);

      _allUsers = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading users: $e');
      _allUsers = [];
    }
  }

  Future<void> _loadAllBookings() async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('''
            *,
            vehicles:vehicle_id (brand, model, year),
            users:renter_id (full_name, email)
          ''')
          .order('created_at', ascending: false);

      _allBookings = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      _allBookings = [];
    }
  }

  Future<void> _loadAllVehicles() async {
    try {
      final response = await _supabase
          .from('vehicles')
          .select('''
            *,
            users:owner_id (full_name, email)
          ''')
          .order('created_at', ascending: false);

      _allVehicles = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      _allVehicles = [];
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
          .order('created_at', ascending: false);

      _pendingApplications = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading applications: $e');
      _pendingApplications = [];
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await _supabase.from('users').update({'role': newRole}).eq('id', userId);

      if (newRole == 'partner' || newRole == 'driver') {
        await _supabase
            .from('users')
            .update({'application_status': 'pending'})
            .eq('id', userId);
      }

      if (newRole == 'partner') {
        final partnerRow = await _supabase
            .from('partners')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (partnerRow == null) {
          await _supabase.from('partners').insert({
            'user_id': userId,
            'verification_status': 'pending',
          });
        }
      }

      if (newRole == 'renter') {
        final renterRow = await _supabase
            .from('renters')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (renterRow == null) {
          await _supabase.from('renters').insert({'user_id': userId});
        }
      }

      if (newRole == 'driver') {
        final driverRow = await _supabase
            .from('drivers')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (driverRow == null) {
          await _supabase.from('drivers').insert({
            'user_id': userId,
            'verification_status': 'pending',
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User role updated to $newRole'),
          backgroundColor: Colors.green,
        ),
      );

      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('users').delete().eq('id', userId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDashboardData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthService().signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } catch (e) {
        debugPrint('Logout error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F5F5),
      body: Row(
        children: [
          _buildSidebar(isDark),
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

  Widget _buildSidebar(bool isDark) {
    final sidebarWidth = _sidebarExpanded ? 280.0 : 70.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarWidth,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo/Header
          Container(
            height: 80,
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarExpanded ? 20 : 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Super Admin',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'System Control',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavItem(0, Icons.dashboard, 'Overview', isDark),
                _buildNavItem(
                  1,
                  Icons.people,
                  'Users',
                  isDark,
                  badge: _allUsers.length,
                ),
                _buildNavItem(2, Icons.directions_car, 'Vehicles', isDark),
                _buildNavItem(3, Icons.book, 'Bookings', isDark),
                _buildNavItem(
                  4,
                  Icons.assignment,
                  'Applications',
                  isDark,
                  badge: _pendingVerifications > 0
                      ? _pendingVerifications
                      : null,
                ),
                _buildNavItem(5, Icons.mail, 'Message Review', isDark),
                const SizedBox(height: 24),
                if (_sidebarExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'SYSTEM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.4),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _buildNavItem(6, Icons.analytics, 'Analytics', isDark),
                _buildNavItem(7, Icons.settings, 'Settings', isDark),
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
                    color: Colors.white60,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          padding: EdgeInsets.symmetric(horizontal: _sidebarExpanded ? 16 : 0),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: [Colors.red, Colors.deepOrange])
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: _sidebarExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white60,
                size: 22,
              ),
              if (_sidebarExpanded) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
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
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : Colors.red,
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
          // Quick Actions
          _buildQuickAction('Add User', Icons.person_add, Colors.blue, () {
            _showAddUserDialog(isDark);
          }),
          const SizedBox(width: 12),
          _buildQuickAction('Export', Icons.download, Colors.green, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export feature coming soon')),
            );
          }),
          const SizedBox(width: 20),
          // Theme Toggle
          IconButton(
            onPressed: () => widget.onThemeToggle?.call(!widget.isDarkMode),
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          IconButton(
            onPressed: _loadDashboardData,
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 16),
          // User Menu
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _handleLogout();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Colors.deepOrange],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: const [
                  Icon(Icons.shield, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
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

  Widget _buildQuickAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard Overview';
      case 1:
        return 'User Management';
      case 2:
        return 'Vehicle Management';
      case 3:
        return 'Booking Management';
      case 4:
        return 'Applications';
      case 5:
        return 'Message Review';
      case 6:
        return 'Analytics';
      case 7:
        return 'System Settings';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }

    switch (_selectedIndex) {
      case 0:
        return _buildOverviewContent(isDark);
      case 1:
        return _buildUsersContent(isDark);
      case 2:
        return _buildVehiclesContent(isDark);
      case 3:
        return _buildBookingsContent(isDark);
      case 4:
        return _buildApplicationsContent(isDark);
      case 5:
        return _buildMessageReviewContent(isDark);
      case 6:
        return _buildAnalyticsContent(isDark);
      case 7:
        return _buildSettingsContent(isDark);
      default:
        return _buildOverviewContent(isDark);
    }
  }

  Widget _buildOverviewContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.red, Colors.deepOrange],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Revenue',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PHP ${_totalRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'From $_totalBookings total bookings',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
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
                'Total Renters',
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
                'Operators',
                _totalOperators.toString(),
                Icons.admin_panel_settings,
                Colors.purple,
                isDark,
              ),
              _buildStatCard(
                'Active Bookings',
                _activeBookings.toString(),
                Icons.event_available,
                Colors.teal,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 30),
          // Two Column Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildCard(
                  'Recent Bookings',
                  _buildRecentBookingsTable(isDark),
                  isDark,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildCard(
                  'System Status',
                  _buildSystemStatus(isDark),
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

  Widget _buildRecentBookingsTable(bool isDark) {
    if (_allBookings.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(40), child: Text('No bookings')),
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
        DataColumn(
          label: Text(
            'Amount',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
      ],
      rows: _allBookings.take(6).map((booking) {
        final vehicle = booking['vehicles'] as Map<String, dynamic>?;
        final user = booking['users'] as Map<String, dynamic>?;
        final status = booking['status'] as String? ?? 'pending';
        final total = (booking['total_cost'] as num?)?.toDouble() ?? 0;

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
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
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

  Widget _buildSystemStatus(bool isDark) {
    return Column(
      children: [
        _buildStatusRow('Database', 'Connected', Colors.green, isDark),
        const Divider(height: 24),
        _buildStatusRow('Auth Service', 'Active', Colors.green, isDark),
        const Divider(height: 24),
        _buildStatusRow('Storage', 'Operational', Colors.green, isDark),
        const Divider(height: 24),
        _buildStatusRow('API', 'Running', Colors.green, isDark),
      ],
    );
  }

  Widget _buildStatusRow(String name, String status, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        Text(
          status,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildUsersContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'All Users (${_allUsers.length})',
        _allUsers.isEmpty
            ? const Center(child: Text('No users found'))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
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
                    DataColumn(
                      label: Text(
                        'Actions',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                  rows: _allUsers.map((user) {
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
                        DataCell(
                          Row(
                            children: [
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteUser(user['id']);
                                  } else {
                                    _updateUserRole(user['id'], value);
                                  }
                                },
                                itemBuilder: (context) => [
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
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
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
        'All Vehicles (${_allVehicles.length})',
        _allVehicles.isEmpty
            ? const Center(child: Text('No vehicles found'))
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
                      'Owner',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Price/Day',
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
                ],
                rows: _allVehicles.map((vehicle) {
                  final owner = vehicle['users'] as Map<String, dynamic>?;
                  final status = vehicle['status'] as String? ?? 'pending';

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${vehicle['brand']} ${vehicle['model']} (${vehicle['year']})',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          owner?['full_name'] ?? 'Unknown',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          'PHP ${vehicle['price_per_day'] ?? 0}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(_buildStatusBadge(status)),
                    ],
                  );
                }).toList(),
              ),
        isDark,
      ),
    );
  }

  Widget _buildBookingsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'All Bookings (${_allBookings.length})',
        _allBookings.isEmpty
            ? const Center(child: Text('No bookings found'))
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
                rows: _allBookings.map((booking) {
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
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

  Widget _buildApplicationsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'Pending Applications (${_pendingApplications.length})',
        _pendingApplications.isEmpty
            ? Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 60,
                      color: Colors.green.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text('All applications reviewed!'),
                  ],
                ),
              )
            : Column(
                children: _pendingApplications.map((app) {
                  final partner = app['partners'] as Map<String, dynamic>?;
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
                                '${app['brand']} ${app['model']} (${app['year']})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                user?['full_name'] ?? 'Unknown',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await _supabase
                                .from('vehicle_applications')
                                .update({'status': 'approved'})
                                .eq('id', app['id']);
                            _loadDashboardData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Approve',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            await _supabase
                                .from('vehicle_applications')
                                .update({'status': 'rejected'})
                                .eq('id', app['id']);
                            _loadDashboardData();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
        isDark,
      ),
    );
  }

  Widget _buildMessageReviewContent(bool isDark) {
    return AdminMessageReviewScreen(isDarkMode: isDark);
  }

  Widget _buildAnalyticsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'Analytics',
        const Center(
          child: Padding(
            padding: EdgeInsets.all(60),
            child: Text('Analytics dashboard coming soon'),
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
                  activeColor: Colors.red,
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),
          _buildCard(
            'Account',
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              onTap: _handleLogout,
            ),
            isDark,
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(bool isDark) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text(
          'Promote to Operator',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter user email to promote:',
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: 'user@example.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;

              try {
                final response = await _supabase
                    .from('users')
                    .select('id')
                    .eq('email', email)
                    .maybeSingle();
                if (response == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User not found'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                await _updateUserRole(response['id'], 'operator');
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Promote', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
