import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
  List<Map<String, dynamic>> _vehicles = [];

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([_loadStats(), _loadRecentBookings(), _loadVehicles()]);
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

  Future<void> _loadVehicles() async {
    try {
      // Get current user ID from auth
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch own vehicles with images
      final ownVehicles = await _supabase
          .from('vehicles')
          .select('*, vehicle_images(id, image_url, display_order)')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      // Fetch partner vehicles assigned to this operator
      final partnerVehicles = await _supabase
          .from('partner_vehicles')
          .select('*, vehicle_id, is_posted')
          .eq('operator_id', userId)
          .order('created_at', ascending: false);

      // Combine both lists
      final combined = [...?ownVehicles, ...?partnerVehicles];

      _vehicles = List<Map<String, dynamic>>.from(combined);
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      _vehicles = [];
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
                  child: Image.asset(
                    'assets/icon/logo-black.png',
                    fit: BoxFit.contain,
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
                _buildNavItem(1, Icons.book, 'Bookings', isDark),
                _buildNavItem(2, Icons.directions_car, 'Vehicles', isDark),
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
                _buildNavItem(3, Icons.settings, 'Settings', isDark),
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
        return 'Bookings';
      case 2:
        return 'Vehicles';
      case 3:
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
        return _buildBookingsContent(isDark);
      case 2:
        return _buildVehiclesContent(isDark);
      case 3:
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
    // Separate bookings by status
    final pendingBookings = _recentBookings
        .where((b) => (b['status'] as String? ?? 'pending') == 'pending')
        .toList();
    final activeBookings = _recentBookings
        .where((b) => (b['status'] as String? ?? 'pending') == 'active')
        .toList();
    final completedBookings = _recentBookings
        .where((b) => (b['status'] as String? ?? 'pending') == 'completed')
        .toList();
    final cancelledBookings = _recentBookings
        .where((b) => (b['status'] as String? ?? 'pending') == 'cancelled')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bookings Management (${_recentBookings.length})',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 30),

          // Pending Bookings
          _buildBookingSection(
            'Pending Bookings',
            pendingBookings,
            isDark,
            Colors.orange,
          ),
          const SizedBox(height: 30),

          // Active Bookings
          _buildBookingSection(
            'Active Bookings',
            activeBookings,
            isDark,
            Colors.green,
          ),
          const SizedBox(height: 30),

          // Completed Bookings
          _buildBookingSection(
            'Completed Bookings',
            completedBookings,
            isDark,
            Colors.blue,
          ),
          const SizedBox(height: 30),

          // Cancelled Bookings
          _buildBookingSection(
            'Cancelled Bookings',
            cancelledBookings,
            isDark,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSection(
    String title,
    List<Map<String, dynamic>> bookings,
    bool isDark,
    Color statusColor,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$title (${bookings.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          bookings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No ${title.toLowerCase()}',
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              : DataTable(
                  columns: [
                    DataColumn(
                      label: Text(
                        'Vehicle',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Renter',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Total',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  rows: bookings.map((booking) {
                    final vehicle =
                        booking['vehicles'] as Map<String, dynamic>?;
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
        ],
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
    // Separate vehicles into own and partner vehicles
    final ownVehicles = _vehicles
        .where((v) => !v.containsKey('operator_id'))
        .toList();
    final partnerVehicles = _vehicles
        .where((v) => v.containsKey('operator_id'))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Vehicle Button
          Row(
            children: [
              Text(
                'Vehicles (${_vehicles.length})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddVehicleDialog(isDark),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add Vehicle',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Company Vehicles Section
          Text(
            'Company Vehicles (${ownVehicles.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (ownVehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 60,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No company vehicles added yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: ownVehicles
                  .map((vehicle) => _buildVehicleCard(vehicle, isDark))
                  .toList(),
            ),

          const SizedBox(height: 40),

          // Partner Vehicles Section
          Text(
            'Partner Vehicles (${partnerVehicles.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (partnerVehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 60,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No partner vehicles assigned yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: partnerVehicles
                  .map((vehicle) => _buildVehicleCard(vehicle, isDark))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle, bool isDark) {
    final brand = vehicle['brand'] ?? 'Unknown';
    final model = vehicle['model'] ?? 'Model';
    final year = vehicle['year'] ?? '';
    final pricePerDay = vehicle['price_per_day'] ?? 0;
    final status = vehicle['status'] ?? 'pending';
    final isPosted = vehicle['is_posted'] ?? false;
    final isPartnerVehicle = vehicle.containsKey('operator_id');
    final images = (vehicle['vehicle_images'] as List?) ?? [];

    return StatefulBuilder(
      builder: (context, setCardState) {
        int currentImageIndex = 0;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Gallery with Navigation
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                    ),
                    child: images.isNotEmpty
                        ? Image.network(
                            images[currentImageIndex]['image_url'] ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: isDark
                                        ? Colors.grey[600]
                                        : Colors.grey.shade400,
                                  ),
                                ),
                          )
                        : Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 32,
                              color: isDark
                                  ? Colors.grey[600]
                                  : Colors.grey.shade400,
                            ),
                          ),
                  ),
                  // Image counter
                  if (images.isNotEmpty)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${currentImageIndex + 1}/${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Navigation arrows
                  if (images.length > 1) ...[
                    Positioned(
                      left: 4,
                      child: GestureDetector(
                        onTap: () {
                          setCardState(() {
                            currentImageIndex =
                                (currentImageIndex - 1) % images.length;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setCardState(() {
                            currentImageIndex =
                                (currentImageIndex + 1) % images.length;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Header with status badge
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$brand $model',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            year.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Price and Posting Switch
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('PHP ', style: TextStyle(fontSize: 12)),
                          Text(
                            pricePerDay.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text('/day', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Post Vehicle',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Transform.scale(
                            scale: 0.8,
                            alignment: Alignment.centerLeft,
                            child: Switch(
                              value: isPosted,
                              onChanged: (value) =>
                                  _togglePostingStatus(vehicle, value),
                              activeColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!isPartnerVehicle) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showEditVehicleDialog(vehicle, isDark),
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text(
                            'Edit',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteVehicle(vehicle['id']),
                          icon: const Icon(Icons.delete, size: 14),
                          label: const Text(
                            'Delete',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showAddVehicleDialog(bool isDark) {
    final brandController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final priceController = TextEditingController();
    String selectedStatus = 'active';
    List<File> selectedImages = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 1000),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add New Vehicle',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.close,
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Image Gallery Preview
                        Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey.shade300,
                            ),
                            color: isDark
                                ? Colors.black26
                                : Colors.grey.shade50,
                          ),
                          child: selectedImages.isNotEmpty
                              ? Image.file(
                                  selectedImages.first,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_outlined,
                                        size: 50,
                                        color: isDark
                                            ? Colors.grey[600]
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No images selected',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[600]
                                              : Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        // Image Thumbnails Scroll
                        if (selectedImages.isNotEmpty)
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: selectedImages.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: index == 0
                                              ? AppColors.primary
                                              : (isDark
                                                    ? Colors.grey[700]!
                                                    : Colors.grey.shade300),
                                          width: index == 0 ? 3 : 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          selectedImages[index],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Image Picker Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final pickedFile = await _imagePicker
                                      .pickImage(source: ImageSource.gallery);
                                  if (pickedFile != null) {
                                    setState(() {
                                      selectedImages.add(File(pickedFile.path));
                                    });
                                  }
                                },
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('Add Image'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (selectedImages.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      selectedImages.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.clear, size: 18),
                                  label: const Text('Clear All'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: brandController,
                          cursorColor: AppColors.primary,
                          decoration: InputDecoration(
                            labelText: 'Brand',
                            labelStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.black26
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: modelController,
                          cursorColor: AppColors.primary,
                          decoration: InputDecoration(
                            labelText: 'Model',
                            labelStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.black26
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: yearController,
                          cursorColor: AppColors.primary,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            labelStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.black26
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: priceController,
                          cursorColor: AppColors.primary,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Price per Day (PHP)',
                            labelStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.black26
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Inactive'),
                            ),
                            DropdownMenuItem(
                              value: 'maintenance',
                              child: Text('Maintenance'),
                            ),
                          ],
                          onChanged: (value) =>
                              selectedStatus = value ?? 'active',
                          decoration: InputDecoration(
                            labelText: 'Status',
                            labelStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.black26
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          dropdownColor: isDark
                              ? AppColors.darkCard
                              : Colors.white,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey.shade700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (brandController.text.isEmpty ||
                              modelController.text.isEmpty ||
                              yearController.text.isEmpty ||
                              priceController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill all fields'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          try {
                            final userId = _supabase.auth.currentUser?.id;
                            if (userId == null) {
                              throw 'User not authenticated';
                            }

                            // Create vehicle record first
                            final vehicleResponse = await _supabase
                                .from('vehicles')
                                .insert({
                                  'brand': brandController.text,
                                  'model': modelController.text,
                                  'year': int.parse(yearController.text),
                                  'price_per_day': double.parse(
                                    priceController.text,
                                  ),
                                  'status': selectedStatus,
                                  'owner_id': userId,
                                })
                                .select()
                                .single();

                            final vehicleId = vehicleResponse['id'];

                            // Upload images and insert into vehicle_images
                            for (int i = 0; i < selectedImages.length; i++) {
                              final fileName =
                                  'vehicle_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                              final filePath = 'vehicles/$userId/$fileName';

                              try {
                                await _supabase.storage
                                    .from('vehicle-images')
                                    .upload(
                                      filePath,
                                      selectedImages[i],
                                      fileOptions: const FileOptions(
                                        cacheControl: '3600',
                                        upsert: false,
                                      ),
                                    );

                                final imageUrl = _supabase.storage
                                    .from('vehicle-images')
                                    .getPublicUrl(filePath);

                                // Insert image record
                                await _supabase.from('vehicle_images').insert({
                                  'vehicle_id': vehicleId,
                                  'image_url': imageUrl,
                                  'display_order': i,
                                });
                              } catch (e) {
                                debugPrint('Error uploading image $i: $e');
                              }
                            }

                            Navigator.pop(context);
                            _loadVehicles();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Vehicle added successfully with ${selectedImages.length} images!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Add Vehicle',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditVehicleDialog(Map<String, dynamic> vehicle, bool isDark) {
    final brandController = TextEditingController(text: vehicle['brand'] ?? '');
    final modelController = TextEditingController(text: vehicle['model'] ?? '');
    final yearController = TextEditingController(
      text: (vehicle['year'] ?? '').toString(),
    );
    final priceController = TextEditingController(
      text: (vehicle['price_per_day'] ?? '').toString(),
    );
    String selectedStatus = vehicle['status'] ?? 'active';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text(
          'Edit Vehicle',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: brandController,
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  labelText: 'Brand',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelController,
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  labelText: 'Model',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearController,
                cursorColor: AppColors.primary,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Year',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                cursorColor: AppColors.primary,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Price per Day (PHP)',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('Maintenance'),
                  ),
                ],
                onChanged: (value) => selectedStatus = value ?? 'active',
                decoration: InputDecoration(
                  labelText: 'Status',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabase
                    .from('vehicles')
                    .update({
                      'brand': brandController.text,
                      'model': modelController.text,
                      'year': int.parse(yearController.text),
                      'price_per_day': double.parse(priceController.text),
                      'status': selectedStatus,
                    })
                    .eq('id', vehicle['id']);

                Navigator.pop(context);
                _loadVehicles();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vehicle updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Update Vehicle',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVehicle(dynamic vehicleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: const Text('Are you sure you want to delete this vehicle?'),
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
        await _supabase.from('vehicles').delete().eq('id', vehicleId);
        _loadVehicles();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _togglePostingStatus(
    Map<String, dynamic> vehicle,
    bool isPosted,
  ) async {
    try {
      final isPartnerVehicle = vehicle.containsKey('operator_id');

      if (isPartnerVehicle) {
        // Update partner_vehicles table
        await _supabase
            .from('partner_vehicles')
            .update({'is_posted': isPosted})
            .eq('id', vehicle['id']);
      } else {
        // For own vehicles, update local state
        vehicle['is_posted'] = isPosted;
      }

      _loadVehicles();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPosted
                ? 'Vehicle posted successfully!'
                : 'Vehicle unlisted successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
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
