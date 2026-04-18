import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../../services/auth_service.dart';
import '../../../services/operator_activity_logger.dart';

class OperatorHomeScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const OperatorHomeScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  State<OperatorHomeScreen> createState() => _OperatorHomeScreenState();
}

class _OperatorHomeScreenState extends State<OperatorHomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  // Stats
  int _totalVehicles = 0;
  int _availableVehicles = 0;
  int _unavailableVehicles = 0;
  int _pendingBookings = 0;
  int _activeBookings = 0;
  int _totalBookings = 0;

  int _availableDrivers = 0;

  // Lists
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _partners = [];

  // Filters
  String _vehicleFilter = 'all'; // all, available, unavailable
  String _bookingFilter =
      'pending'; // pending, approved, active, completed, all

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _logOperatorLogin();
    _loadDashboardData();
  }

  /// Log operator login activity
  Future<void> _logOperatorLogin() async {
    try {
      await OperatorActivityLogger.logLogin(
        description: 'Operator logged in to dashboard',
      );
    } catch (e) {
      debugPrint('Error logging operator login: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadStats(),
        _loadVehicles(),
        _loadBookings(),
        _loadDrivers(),
        _loadPartners(),
      ]);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    try {
      // Total vehicles (approved/active)
      final vehiclesResponse = await _supabase
          .from('vehicles')
          .select('id, is_available')
          .eq('status', 'active');
      final vehicles = vehiclesResponse as List;
      _totalVehicles = vehicles.length;
      _availableVehicles = vehicles
          .where((v) => v['is_available'] == true)
          .length;
      _unavailableVehicles = vehicles
          .where((v) => v['is_available'] != true)
          .length;

      // Pending bookings
      final pendingBookingsResponse = await _supabase
          .from('bookings')
          .select('id')
          .eq('status', 'pending');
      _pendingBookings = (pendingBookingsResponse as List).length;

      // Active bookings
      final activeBookingsResponse = await _supabase
          .from('bookings')
          .select('id')
          .eq('status', 'active');
      _activeBookings = (activeBookingsResponse as List).length;

      // Total bookings
      final totalBookingsResponse = await _supabase
          .from('bookings')
          .select('id');
      _totalBookings = (totalBookingsResponse as List).length;

      // Available drivers (users with role = 'driver' and is_available = true)
      final driversResponse = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'driver')
          .eq('is_available', true);
      _availableDrivers = (driversResponse as List).length;
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadVehicles() async {
    try {
      final response = await _supabase
          .from('vehicles')
          .select('''
            *,
            owner:owner_id (id, full_name, email, role, is_driver)
          ''')
          .eq('status', 'active')
          .order('created_at', ascending: false);

      _vehicles = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      _vehicles = [];
    }
  }

  Future<void> _loadBookings() async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('''
            *,
            vehicles:vehicle_id (
              id, brand, model, year, plate_number, image_url, owner_id,
              owner:owner_id (id, full_name, email, role, is_driver, phone)
            ),
            renter:renter_id (id, full_name, email, phone),
            driver:driver_id (id, full_name, email, phone)
          ''')
          .order('created_at', ascending: false);

      _bookings = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      _bookings = [];
    }
  }

  Future<void> _loadDrivers() async {
    try {
      // Load company drivers (users with role = 'driver')
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('role', 'driver')
          .order('full_name', ascending: true);

      _drivers = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading drivers: $e');
      _drivers = [];
    }
  }

  Future<void> _loadPartners() async {
    try {
      final response = await _supabase
          .from('users')
          .select('id, full_name, email')
          .eq('role', 'partner')
          .order('full_name', ascending: true);

      _partners = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading partners: $e');
      _partners = [];
    }
  }

  Future<void> _addVehicle({
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
    required double pricePerDay,
    String? imageUrl,
    String? partnerId,
  }) async {
    try {
      await _supabase.from('vehicles').insert({
        'owner_id': partnerId,
        'brand': brand,
        'model': model,
        'year': year,
        'plate_number': plateNumber,
        'price_per_day': pricePerDay,
        'status': 'active',
        'is_available': false,
        'image_url': imageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add vehicle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddVehicleDialog() {
    final brandController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final plateController = TextEditingController();
    final priceController = TextEditingController();
    final imageController = TextEditingController();

    String source = 'company';
    String? selectedPartnerId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Vehicle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: source,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Source',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'company',
                        child: Text('Company Vehicle'),
                      ),
                      DropdownMenuItem(
                        value: 'partner',
                        child: Text('Partner Vehicle'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        source = value ?? 'company';
                        if (source == 'company') {
                          selectedPartnerId = null;
                        }
                      });
                    },
                  ),
                  if (source == 'partner') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPartnerId,
                      decoration: const InputDecoration(
                        labelText: 'Partner Owner',
                      ),
                      items: _partners
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p['id']?.toString(),
                              child: Text(
                                p['full_name']?.toString() ??
                                    p['email']?.toString() ??
                                    'Unknown Partner',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedPartnerId = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: brandController,
                    decoration: const InputDecoration(labelText: 'Brand'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modelController,
                    decoration: const InputDecoration(labelText: 'Model'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: plateController,
                    decoration: const InputDecoration(
                      labelText: 'Plate Number',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price Per Day',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL (optional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final brand = brandController.text.trim();
                  final model = modelController.text.trim();
                  final plate = plateController.text.trim().toUpperCase();
                  final year = int.tryParse(yearController.text.trim());
                  final price = double.tryParse(priceController.text.trim());

                  if (brand.isEmpty ||
                      model.isEmpty ||
                      plate.isEmpty ||
                      year == null ||
                      price == null ||
                      price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please complete all required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (source == 'partner' &&
                      (selectedPartnerId == null ||
                          selectedPartnerId!.isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a partner owner'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _addVehicle(
                    brand: brand,
                    model: model,
                    year: year,
                    plateNumber: plate,
                    pricePerDay: price,
                    imageUrl: imageController.text.trim().isEmpty
                        ? null
                        : imageController.text.trim(),
                    partnerId: source == 'partner' ? selectedPartnerId : null,
                  );
                },
                child: const Text('Add Vehicle'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleVehicleAvailability(
    String vehicleId,
    bool currentStatus,
  ) async {
    try {
      await _supabase
          .from('vehicles')
          .update({'is_available': !currentStatus})
          .eq('id', vehicleId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus
                ? 'Vehicle is now visible in user feed'
                : 'Vehicle hidden from user feed',
          ),
          backgroundColor: !currentStatus ? Colors.green : Colors.orange,
        ),
      );

      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _approveBooking(
    Map<String, dynamic> booking, {
    String? driverId,
  }) async {
    try {
      final updateData = {
        'status': 'approved',
        'approved_at': DateTime.now().toIso8601String(),
      };

      if (driverId != null) {
        updateData['driver_id'] = driverId;
      }

      await _supabase
          .from('bookings')
          .update(updateData)
          .eq('id', booking['id']);

      // Log the approval
      await OperatorActivityLogger.logBookingApproved(
        bookingId: booking['id'],
        reason: 'Booking approved by operator',
        totalPrice: booking['total_price'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking approved successfully'),
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

  Future<void> _rejectBooking(String bookingId, String reason) async {
    try {
      await _supabase
          .from('bookings')
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'rejected_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      // Log the rejection
      await OperatorActivityLogger.logBookingRejected(
        bookingId: bookingId,
        reason: reason,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking rejected'),
          backgroundColor: Colors.red,
        ),
      );

      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _assignDriver(String bookingId, String driverId) async {
    try {
      // Get driver info for logging
      final driverInfo = await _supabase
          .from('users')
          .select('full_name')
          .eq('id', driverId)
          .maybeSingle();

      await _supabase
          .from('bookings')
          .update({
            'driver_id': driverId,
            'driver_assigned_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      // Log the driver assignment
      await OperatorActivityLogger.logDriverAssigned(
        bookingId: bookingId,
        driverId: driverId,
        tripFee: 0.0, // Will be set separately
        driverName: driverInfo?['full_name'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver assigned successfully'),
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

  List<Map<String, dynamic>> get _filteredVehicles {
    switch (_vehicleFilter) {
      case 'available':
        return _vehicles.where((v) => v['is_available'] == true).toList();
      case 'unavailable':
        return _vehicles.where((v) => v['is_available'] != true).toList();
      default:
        return _vehicles;
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    switch (_bookingFilter) {
      case 'pending':
        return _bookings.where((b) => b['status'] == 'pending').toList();
      case 'approved':
        return _bookings.where((b) => b['status'] == 'approved').toList();
      case 'active':
        return _bookings.where((b) => b['status'] == 'active').toList();
      case 'completed':
        return _bookings.where((b) => b['status'] == 'completed').toList();
      default:
        return _bookings;
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
        // Log operator logout
        await OperatorActivityLogger.logLogout(
          description: 'Operator logged out from dashboard',
        );

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
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboardTab(isDark),
            _buildManageVehiclesTab(isDark),
            _buildBookingsTab(isDark),
            _buildSettingsTab(isDark),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark ? Colors.grey : Colors.grey.shade600,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'Vehicles',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _pendingBookings > 0,
              label: Text(_pendingBookings.toString()),
              backgroundColor: Colors.red,
              child: const Icon(Icons.book_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: _pendingBookings > 0,
              label: Text(_pendingBookings.toString()),
              backgroundColor: Colors.red,
              child: const Icon(Icons.book),
            ),
            label: 'Bookings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ===================== DASHBOARD TAB =====================
  Widget _buildDashboardTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 24),
            _buildStatsGrid(isDark),
            const SizedBox(height: 24),
            _buildQuickActions(isDark),
            const SizedBox(height: 24),
            _buildPendingBookingsPreview(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            color: Colors.black,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PSDC Operator',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                'Vehicle & Booking Management',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadDashboardData,
          icon: Icon(
            Icons.refresh,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          'Available Vehicles',
          _availableVehicles.toString(),
          Icons.directions_car,
          Colors.green,
          isDark,
          subtitle: 'In user feed',
        ),
        _buildStatCard(
          'Pending Bookings',
          _pendingBookings.toString(),
          Icons.pending_actions,
          Colors.orange,
          isDark,
          subtitle: 'Needs action',
          onTap: () {
            setState(() {
              _currentIndex = 2;
              _bookingFilter = 'pending';
            });
          },
        ),
        _buildStatCard(
          'Active Bookings',
          _activeBookings.toString(),
          Icons.event_available,
          Colors.blue,
          isDark,
          subtitle: 'In progress',
        ),
        _buildStatCard(
          'Available Drivers',
          _availableDrivers.toString(),
          Icons.person,
          Colors.purple,
          isDark,
          subtitle: 'Ready to assign',
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Manage Vehicles',
                Icons.directions_car,
                () => setState(() => _currentIndex = 1),
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'View Bookings',
                Icons.book,
                () => setState(() => _currentIndex = 2),
                isDark,
                badge: _pendingBookings > 0 ? _pendingBookings : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onTap,
    bool isDark, {
    Color? iconColor,
    int? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Badge(
              isLabelVisible: badge != null && badge > 0,
              label: Text(badge?.toString() ?? ''),
              backgroundColor: Colors.red,
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBookingsPreview(bool isDark) {
    final pendingBookings = _bookings
        .where((b) => b['status'] == 'pending')
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Approvals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            if (pendingBookings.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 2;
                    _bookingFilter = 'pending';
                  });
                },
                child: const Text('See All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        else if (pendingBookings.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Colors.green.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No pending bookings',
                    style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingBookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildCompactBookingCard(pendingBookings[index], isDark);
            },
          ),
      ],
    );
  }

  Widget _buildCompactBookingCard(Map<String, dynamic> booking, bool isDark) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['renter'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.pending_actions,
              color: Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle != null
                      ? '${vehicle['brand']} ${vehicle['model']}'
                      : 'Unknown Vehicle',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  renter?['full_name'] ?? 'Unknown Renter',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentIndex = 2;
                _bookingFilter = 'pending';
              });
            },
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

  // ===================== MANAGE VEHICLES TAB =====================
  Widget _buildManageVehiclesTab(bool isDark) {
    return Column(
      children: [
        // Yellow header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          color: AppColors.primary,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Vehicles',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toggle availability to show/hide vehicles in user feed',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _showAddVehicleDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Vehicle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Filter tabs
        Container(
          color: isDark ? AppColors.darkCard : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              _buildFilterChip(
                'All ($_totalVehicles)',
                'all',
                isDark,
                isVehicle: true,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Available ($_availableVehicles)',
                'available',
                isDark,
                color: Colors.green,
                isVehicle: true,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Hidden ($_unavailableVehicles)',
                'unavailable',
                isDark,
                color: Colors.orange,
                isVehicle: true,
              ),
            ],
          ),
        ),

        // Vehicle list
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _filteredVehicles.isEmpty
              ? _buildEmptyState(
                  Icons.directions_car_outlined,
                  'No vehicles found',
                  isDark,
                )
              : RefreshIndicator(
                  onRefresh: _loadVehicles,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredVehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = _filteredVehicles[index];
                      return _buildVehicleManageCard(vehicle, isDark);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String message, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark ? Colors.grey : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    bool isDark, {
    Color? color,
    bool isVehicle = false,
  }) {
    final isSelected = isVehicle
        ? _vehicleFilter == value
        : _bookingFilter == value;
    final chipColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: () => setState(() {
        if (isVehicle) {
          _vehicleFilter = value;
        } else {
          _bookingFilter = value;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor
                : (isDark ? AppColors.borderColor : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? chipColor
                : (isDark ? Colors.grey : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleManageCard(Map<String, dynamic> vehicle, bool isDark) {
    final isAvailable = vehicle['is_available'] == true;
    final owner = vehicle['owner'] as Map<String, dynamic>?;
    final imageUrl = vehicle['image_url'] as String?;
    final isPartnerOwned = owner?['role'] == 'partner';
    final ownerIsDriver = owner?['is_driver'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAvailable
              ? Colors.green.withOpacity(0.3)
              : (isDark ? AppColors.borderColor : Colors.grey.shade200),
          width: isAvailable ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 60,
                  color: isDark
                      ? AppColors.darkBgSecondary
                      : AppColors.lightBgTertiary,
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildVehiclePlaceholder(isDark);
                          },
                        )
                      : _buildVehiclePlaceholder(isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges row
                    Row(
                      children: [
                        _buildMiniStatusBadge(
                          isAvailable ? 'VISIBLE' : 'HIDDEN',
                          isAvailable ? Colors.green : Colors.orange,
                          isAvailable ? Icons.visibility : Icons.visibility_off,
                        ),
                        const SizedBox(width: 6),
                        if (isPartnerOwned)
                          _buildMiniStatusBadge(
                            'PARTNER',
                            Colors.blue,
                            Icons.handshake,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      '${vehicle['year'] ?? ''} • ${vehicle['plate_number'] ?? ''}',
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
          ),

          const SizedBox(height: 12),

          // Owner info with driver status
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isPartnerOwned ? Icons.business : Icons.apartment,
                  size: 16,
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPartnerOwned
                            ? 'Partner: ${owner?['full_name'] ?? 'Unknown'}'
                            : 'Company Vehicle',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      if (isPartnerOwned)
                        Text(
                          ownerIsDriver
                              ? 'Partner drives this vehicle'
                              : 'Requires driver assignment',
                          style: TextStyle(
                            fontSize: 10,
                            color: ownerIsDriver ? Colors.green : Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isPartnerOwned)
                  Icon(
                    ownerIsDriver ? Icons.person : Icons.person_add,
                    size: 16,
                    color: ownerIsDriver ? Colors.green : Colors.orange,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Toggle button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _toggleVehicleAvailability(
                vehicle['id'].toString(),
                isAvailable,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isAvailable ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: Icon(
                isAvailable ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              label: Text(
                isAvailable ? 'Hide from User Feed' : 'Show in User Feed',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatusBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclePlaceholder(bool isDark) {
    return Center(
      child: Icon(
        Icons.directions_car_outlined,
        size: 28,
        color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
      ),
    );
  }

  // ===================== BOOKINGS TAB =====================
  Widget _buildBookingsTab(bool isDark) {
    return Column(
      children: [
        // Yellow header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          color: AppColors.primary,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Booking Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Approve bookings and assign drivers when needed',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Filter tabs
        Container(
          color: isDark ? AppColors.darkCard : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Pending ($_pendingBookings)',
                  'pending',
                  isDark,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Approved',
                  'approved',
                  isDark,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Active',
                  'active',
                  isDark,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Completed',
                  'completed',
                  isDark,
                  color: Colors.purple,
                ),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'all', isDark),
              ],
            ),
          ),
        ),

        // Booking list
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _filteredBookings.isEmpty
              ? _buildEmptyState(
                  Icons.book_outlined,
                  'No ${_bookingFilter == 'all' ? '' : _bookingFilter} bookings found',
                  isDark,
                )
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredBookings.length,
                    itemBuilder: (context, index) {
                      return _buildBookingCard(
                        _filteredBookings[index],
                        isDark,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, bool isDark) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['renter'] as Map<String, dynamic>?;
    final driver = booking['driver'] as Map<String, dynamic>?;
    final owner = vehicle?['owner'] as Map<String, dynamic>?;
    final status = booking['status'] as String? ?? 'pending';

    // Check booking type: with_driver = true means they want a driver service
    // with_driver = false (or null) means self-drive (renter drives themselves)
    final withDriver = booking['with_driver'] == true;
    final isSelfDrive = !withDriver;

    final isPartnerOwned = owner?['role'] == 'partner';
    final ownerIsDriver = owner?['is_driver'] == true;

    // Driver assignment is only needed when:
    // 1. Booking is with driver service (not self-drive)
    // 2. AND (partner doesn't drive OR it's a company vehicle)
    // 3. AND no driver assigned yet
    final needsDriverAssignment =
        withDriver && !ownerIsDriver && driver == null && status == 'pending';

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'active':
        statusColor = Colors.blue;
        break;
      case 'completed':
        statusColor = Colors.purple;
        break;
      case 'cancelled':
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'pending'
              ? Colors.orange.withOpacity(0.5)
              : (isDark ? AppColors.borderColor : Colors.grey.shade200),
          width: status == 'pending' ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_car, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle != null
                          ? '${vehicle['brand']} ${vehicle['model']}'
                          : 'Unknown Vehicle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      vehicle?['plate_number'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: isDark ? AppColors.borderColor : Colors.grey.shade200),
          const SizedBox(height: 12),

          // Renter info
          _buildInfoRow(
            Icons.person_outline,
            'Renter',
            renter?['full_name'] ?? 'Unknown',
            renter?['phone'],
            isDark,
          ),

          const SizedBox(height: 8),

          // Booking Type (Self-drive vs With Driver)
          _buildInfoRow(
            isSelfDrive ? Icons.drive_eta : Icons.person_pin,
            'Type',
            isSelfDrive ? 'Self-Drive Rental' : 'With Driver Service',
            isSelfDrive ? 'Renter will drive' : 'Driver required',
            isDark,
            subtitleColor: isSelfDrive ? Colors.blue : Colors.purple,
          ),

          const SizedBox(height: 8),

          // Owner/Source info
          _buildInfoRow(
            isPartnerOwned ? Icons.handshake : Icons.apartment,
            isPartnerOwned ? 'Partner' : 'Company Vehicle',
            isPartnerOwned ? (owner?['full_name'] ?? 'Unknown') : 'PSDC Fleet',
            isPartnerOwned && withDriver
                ? (ownerIsDriver
                      ? 'Partner will drive'
                      : 'Needs company driver')
                : null,
            isDark,
            subtitleColor: isPartnerOwned && withDriver
                ? (ownerIsDriver ? Colors.green : Colors.orange)
                : null,
          ),

          const SizedBox(height: 8),

          // Driver info (if assigned or partner is driving)
          if (driver != null)
            _buildInfoRow(
              Icons.badge_outlined,
              'Driver',
              driver['full_name'] ?? 'Assigned',
              driver['phone'],
              isDark,
              subtitleColor: Colors.green,
            )
          else if (withDriver && ownerIsDriver && isPartnerOwned)
            _buildInfoRow(
              Icons.badge_outlined,
              'Driver',
              owner?['full_name'] ?? 'Partner',
              'Partner drives their vehicle',
              isDark,
              subtitleColor: Colors.green,
            ),

          const SizedBox(height: 12),

          // Date info
          Row(
            children: [
              Expanded(
                child: _buildDateChip(
                  'Start',
                  booking['start_date'] ?? 'N/A',
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateChip(
                  'End',
                  booking['end_date'] ?? 'N/A',
                  isDark,
                ),
              ),
            ],
          ),

          // Action buttons for pending
          if (status == 'pending') ...[
            const SizedBox(height: 16),

            // Self-drive notice (no driver needed)
            if (isSelfDrive)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.drive_eta, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Self-drive rental. Renter will drive the vehicle.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              )
            // Driver assignment notice
            else if (needsDriverAssignment)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isPartnerOwned
                            ? 'With driver service. Partner won\'t drive - assign a company driver.'
                            : 'With driver service. Assign a company driver.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(booking['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (needsDriverAssignment) {
                        _showDriverAssignmentDialog(booking);
                      } else {
                        _approveBooking(booking);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      needsDriverAssignment
                          ? 'Approve & Assign Driver'
                          : 'Approve Booking',
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Assign driver button for approved bookings that need a driver but don't have one yet
          if (status == 'approved' &&
              withDriver &&
              driver == null &&
              !ownerIsDriver) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDriverAssignmentDialog(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Assign Driver'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    String? subtitle,
    bool isDark, {
    Color? subtitleColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.grey : Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey : Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        subtitleColor ??
                        (isDark ? Colors.grey : Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String bookingId) {
    final reasonController = TextEditingController();
    final isDark = widget.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text(
          'Reject Booking',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please provide a reason for rejection:',
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason...',
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
            onPressed: () {
              Navigator.pop(context);
              _rejectBooking(
                bookingId,
                reasonController.text.isNotEmpty
                    ? reasonController.text
                    : 'No reason provided',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showDriverAssignmentDialog(Map<String, dynamic> booking) {
    final isDark = widget.isDarkMode;
    final availableDrivers = _drivers
        .where((d) => d['is_available'] == true)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assign Driver',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select a driver for this booking:',
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            if (availableDrivers.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 48,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No drivers available',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = availableDrivers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          (driver['full_name'] as String?)
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        driver['full_name'] ?? 'Unknown',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        driver['phone'] ?? driver['email'] ?? '',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'AVAILABLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _approveBooking(booking, driverId: driver['id']);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ===================== SETTINGS TAB =====================
  Widget _buildSettingsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 32),
          _buildSettingsSection('Appearance', [
            _buildSettingsTile(
              'Dark Mode',
              'Switch between light and dark theme',
              Icons.dark_mode,
              isDark,
              trailing: Switch(
                value: widget.isDarkMode,
                onChanged: widget.onThemeToggle,
                activeColor: AppColors.primary,
              ),
            ),
          ], isDark),
          const SizedBox(height: 24),
          _buildSettingsSection('Account', [
            _buildSettingsTile(
              'Profile',
              'View and edit your profile',
              Icons.person_outline,
              isDark,
            ),
            _buildSettingsTile(
              'Security',
              'Password and authentication',
              Icons.security,
              isDark,
            ),
          ], isDark),
          const SizedBox(height: 24),
          _buildSettingsSection('Support', [
            _buildSettingsTile(
              'Help Center',
              'Get help with common issues',
              Icons.help_outline,
              isDark,
            ),
            _buildSettingsTile(
              'Contact Support',
              'Reach out to our team',
              Icons.support_agent,
              isDark,
            ),
          ], isDark),
          const SizedBox(height: 32),
          CustomButton(
            label: 'Sign Out',
            onPressed: _handleLogout,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    String title,
    List<Widget> children,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade200,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    String title,
    String subtitle,
    IconData icon,
    bool isDark, {
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey : Colors.grey.shade600,
        ),
      ),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right,
            color: isDark ? Colors.grey : Colors.grey.shade400,
          ),
    );
  }
}
