import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin/admin_drawer.dart';
import '../../../services/auth_service.dart';
import 'tabs/dashboard_overview_tab.dart';
import 'tabs/user_directory_tab.dart';
import 'tabs/verification_hub_tab.dart';
import 'tabs/driver_intake_tab.dart';
import 'tabs/vehicle_intake_tab.dart';
import 'user_verification_detail_screen.dart';
import 'partnership_review_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const AdminDashboardScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentDrawerIndex = 0;
  int _currentNavIndex = 0;
  bool _isLoading = true;

  // Stats
  double _totalRevenue = 42850.00;
  int _activeBookings = 124;
  int _pendingVerifications = 18;
  int _activeTrips = 52;

  // Data lists
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _pendingUsers = [];
  List<Map<String, dynamic>> _driverApplications = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _vehicleApplications = [];

  final _supabase = Supabase.instance.client;
  String _adminName = 'Admin User';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        // Get admin name
        final userData = await _supabase
            .from('users')
            .select('full_name')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (userData != null) {
          _adminName = userData['full_name'] ?? 'Admin User';
        }
      }

      // Load all users
      final usersResponse = await _supabase
          .from('users')
          .select('*')
          .order('created_at', ascending: false);
      _allUsers = List<Map<String, dynamic>>.from(usersResponse);

      // Filter pending users
      _pendingUsers = _allUsers
          .where(
            (u) =>
                (u['verification_status'] ?? '').toString().toLowerCase() ==
                'pending',
          )
          .toList();

      // Filter driver applications (drivers with pending status)
      _driverApplications = _allUsers
          .where(
            (u) =>
                (u['role'] ?? '').toString().toLowerCase() == 'driver' &&
                (u['verification_status'] ?? '').toString().toLowerCase() ==
                    'pending',
          )
          .toList();

      // Load vehicles
      final vehiclesResponse = await _supabase
          .from('vehicles')
          .select('*, users!vehicles_owner_id_fkey(full_name)')
          .order('created_at', ascending: false);
      _vehicles = List<Map<String, dynamic>>.from(vehiclesResponse);

      // Filter pending vehicle applications
      _vehicleApplications = _vehicles
          .where(
            (v) =>
                (v['status'] ?? '').toString().toLowerCase() == 'pending',
          )
          .map((v) {
            // Add owner name from joined users table
            final ownerData = v['users'];
            return {
              ...v,
              'owner_name': ownerData?['full_name'] ?? 'Unknown Owner',
            };
          })
          .toList();

      // Load bookings for stats
      final bookingsResponse = await _supabase
          .from('bookings')
          .select('*, vehicles(*)');
      final bookings = List<Map<String, dynamic>>.from(bookingsResponse);

      // Calculate stats
      _activeBookings = bookings.where((b) => b['status'] == 'active').length;
      _activeTrips = _vehicles.where((v) => v['status'] == 'active').length;
      _pendingVerifications = _pendingUsers.length;

      // Calculate revenue from completed bookings
      _totalRevenue = bookings
          .where((b) => b['status'] == 'completed')
          .fold(0.0, (sum, b) => sum + (b['total_price'] ?? 0).toDouble());
    } catch (e) {
      debugPrint('Error loading admin data: $e');
    }

    setState(() => _isLoading = false);
  }

  void _handleDrawerSelection(int index) {
    setState(() {
      _currentDrawerIndex = index;
      // Map drawer items to nav items where applicable
      if (index == 0) _currentNavIndex = 0; // Dashboard -> Users tab
      if (index == 1) _currentNavIndex = 0; // User Management -> Users tab
      if (index == 2) _currentNavIndex = 1; // Fleet Control -> Vehicles tab
      if (index == 3)
        _currentNavIndex = 2; // Booking Management -> Bookings tab
      if (index == 4) _currentNavIndex = 3; // Revenue -> Revenue tab
    });
  }

  void _navigateToVerificationDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserVerificationDetailScreen(
          user: user,
          onApprove: () async {
            await _updateUserVerification(user['id'], 'verified');
            if (mounted) Navigator.pop(context);
          },
          onReject: () async {
            await _updateUserVerification(user['id'], 'rejected');
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _navigateToPartnershipReview(Map<String, dynamic> partner) {
    // Get vehicles owned by this partner
    final partnerVehicles = _vehicles
        .where((v) => v['owner_id'] == partner['id'])
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartnershipReviewScreen(
          partner: partner,
          vehicles: partnerVehicles,
          onApprove: () async {
            await _updateUserVerification(partner['id'], 'verified');
            if (mounted) Navigator.pop(context);
          },
          onReject: (reason) async {
            await _updateUserVerification(partner['id'], 'rejected');
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _updateUserVerification(String userId, String status) async {
    try {
      await _supabase
          .from('users')
          .update({'verification_status': status})
          .eq('id', userId);

      // Refresh data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${status == 'verified' ? 'approved' : 'rejected'} successfully',
            ),
            backgroundColor: status == 'verified'
                ? AppColors.success
                : AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating user verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update user: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateVehicleStatus(String vehicleId, String status) async {
    try {
      await _supabase
          .from('vehicles')
          .update({'status': status})
          .eq('id', vehicleId);

      // Refresh data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vehicle ${status == 'active' ? 'approved' : 'rejected'} successfully',
            ),
            backgroundColor: status == 'active'
                ? AppColors.success
                : AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating vehicle status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update vehicle: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      drawer: AdminDrawer(
        selectedIndex: _currentDrawerIndex,
        onItemSelected: _handleDrawerSelection,
        adminName: _adminName,
        adminRole: 'Super Admin',
        onClose: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          // App Bar
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderColor
                              : AppColors.lightBorderColor,
                        ),
                      ),
                      child: Icon(
                        Icons.menu,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fleet Control',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _buildCurrentView(),
          ),
        ],
      ),
      // Bottom Navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.borderColor
                  : AppColors.lightBorderColor,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.people_outline, 'Users', 0),
                _buildNavItem(Icons.directions_car_outlined, 'Vehicles', 1),
                _buildNavItem(Icons.calendar_today_outlined, 'Bookings', 2),
                _buildNavItem(Icons.attach_money, 'Revenue', 3),
                _buildNavItem(Icons.settings_outlined, 'Settings', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    // Based on drawer selection, show different views
    switch (_currentDrawerIndex) {
      case 0: // Dashboard Overview
        return DashboardOverviewTab(
          totalRevenue: _totalRevenue,
          activeBookings: _activeBookings,
          pendingVerifications: _pendingVerifications,
          activeTrips: _activeTrips,
          onUsersPressed: () => setState(() => _currentDrawerIndex = 1),
          onFleetPressed: () => setState(() => _currentDrawerIndex = 2),
          onBookingsPressed: () => setState(() => _currentDrawerIndex = 3),
          onRevenuePressed: () => setState(() => _currentDrawerIndex = 4),
          onSettingsPressed: () => setState(() => _currentDrawerIndex = 7),
        );

      case 1: // User Management
        return UserDirectoryTab(
          users: _allUsers,
          onUserTap: (user) {
            final role = (user['role'] ?? '').toString().toLowerCase();
            if (role == 'partner' || role == 'owner') {
              _navigateToPartnershipReview(user);
            } else {
              _navigateToVerificationDetail(user);
            }
          },
          onVerifyUser: _navigateToVerificationDetail,
          onAddUser: () {
            // TODO: Implement add user
          },
          onExportCsv: () {
            // TODO: Implement CSV export
          },
        );

      case 2: // Fleet Control
        return _buildFleetControlView();

      case 3: // Booking Management
        return _buildBookingManagementView();

      case 4: // Revenue & Analytics
        return _buildRevenueView();

      case 5: // Driver Intake
        return DriverIntakeTab(
          driverApplications: _driverApplications,
          onApprove: (driver, note) async {
            await _updateUserVerification(driver['id'], 'verified');
          },
          onReject: (driver, note) async {
            await _updateUserVerification(driver['id'], 'rejected');
          },
        );

      case 6: // Vehicle Intake
        return VehicleIntakeTab(
          vehicleApplications: _vehicleApplications,
          onApprove: (vehicle, note) async {
            await _updateVehicleStatus(vehicle['id'], 'active');
          },
          onReject: (vehicle, note) async {
            await _updateVehicleStatus(vehicle['id'], 'rejected');
          },
          onViewDocuments: (vehicle) {
            // TODO: Implement document viewer
          },
        );

      case 7: // System Settings
        return _buildSettingsView();

      default:
        return VerificationHubTab(
          pendingUsers: _pendingUsers,
          onViewDetails: _navigateToVerificationDetail,
          onApprove: (user) async {
            await _updateUserVerification(user['id'], 'verified');
          },
          onReject: (user) async {
            await _updateUserVerification(user['id'], 'rejected');
          },
        );
    }
  }

  Widget _buildFleetControlView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fleet Control',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage ${_vehicles.length} vehicles in your fleet',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
          // Vehicle stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Vehicles',
                  _vehicles.length.toString(),
                  Icons.directions_car_outlined,
                  Colors.blue,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  _vehicles
                      .where((v) => v['status'] == 'active')
                      .length
                      .toString(),
                  Icons.check_circle_outline,
                  AppColors.success,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'In Maintenance',
                  _vehicles
                      .where((v) => v['status'] == 'maintenance')
                      .length
                      .toString(),
                  Icons.build_outlined,
                  AppColors.warning,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending Approval',
                  _vehicles
                      .where((v) => v['status'] == 'pending')
                      .length
                      .toString(),
                  Icons.pending_outlined,
                  Colors.purple,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Vehicle list
          ..._vehicles
              .take(5)
              .map((vehicle) => _buildVehicleListItem(vehicle, isDark)),
        ],
      ),
    );
  }

  Widget _buildBookingManagementView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: isDark
                ? AppColors.textTertiary
                : AppColors.lightTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'Booking Management',
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
            '$_activeBookings active bookings',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue & Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.borderColor
                    : AppColors.lightBorderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Revenue',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_totalRevenue.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        size: 14,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '+12.5% vs last month',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
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

  Widget _buildSettingsView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildSettingsItem(
            'Theme',
            'Switch between light and dark mode',
            Icons.palette_outlined,
            trailing: Switch(
              value: widget.isDarkMode,
              onChanged: (value) => widget.onThemeToggle?.call(value),
              activeColor: AppColors.primary,
            ),
            isDark: isDark,
          ),
          _buildSettingsItem(
            'Notifications',
            'Manage notification preferences',
            Icons.notifications_outlined,
            isDark: isDark,
          ),
          _buildSettingsItem(
            'Security',
            'Password and authentication settings',
            Icons.security_outlined,
            isDark: isDark,
          ),
          _buildSettingsItem(
            'About',
            'App version and information',
            Icons.info_outline,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => AuthService().signOut(),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _currentNavIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentNavIndex = index;
          // Map nav items to drawer views
          switch (index) {
            case 0:
              _currentDrawerIndex = 1; // Users -> User Management
              break;
            case 1:
              _currentDrawerIndex = 2; // Vehicles -> Fleet Control
              break;
            case 2:
              _currentDrawerIndex = 3; // Bookings -> Booking Management
              break;
            case 3:
              _currentDrawerIndex = 4; // Revenue -> Revenue & Analytics
              break;
            case 4:
              _currentDrawerIndex = 7; // Settings -> System Settings
              break;
          }
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isSelected
                ? AppColors.primary
                : (isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary),
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
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
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleListItem(Map<String, dynamic> vehicle, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_car, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle['brand'] ?? 'Unknown'} ${vehicle['model'] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  vehicle['year']?.toString() ?? '',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(vehicle['status']).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              (vehicle['status'] ?? 'Unknown').toString().toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(vehicle['status']),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    String title,
    String subtitle,
    IconData icon, {
    Widget? trailing,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
          trailing ??
              Icon(
                Icons.chevron_right,
                color: isDark
                    ? AppColors.textTertiary
                    : AppColors.lightTextTertiary,
              ),
        ],
      ),
    );
  }

  Color _getStatusColor(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'maintenance':
        return AppColors.warning;
      case 'pending':
        return Colors.purple;
      case 'inactive':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
