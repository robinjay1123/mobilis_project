import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../renter/vehicle_search_screen.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/notification_item.dart';
import '../../widgets/cost_breakdown_row.dart';
import '../../widgets/trip_timeline_step.dart';
import '../profile/settings_screen.dart';
import '../profile/payment_methods_screen.dart';
import '../profile/verification_documents_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;
  const DashboardScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ---------------------------------------------------------------------------
  // State fields
  // ---------------------------------------------------------------------------
  String userName = 'User';
  String userLocation = 'Not specified';
  bool emailConfirmed = true;
  bool userVerified = false;
  int _userCreatedYear = DateTime.now().year;
  int _totalTrips = 0;

  int selectedNavIndex = 0;
  int? selectedBookingIndex;
  String? selectedProfilePage;
  String selectedCategory = '';

  bool _isLoadingVehicles = false;

  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filteredVehicles = [];
  List<Map<String, dynamic>> _notifications = [];

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> categories = [
    {'name': 'All Cars', 'icon': Icons.directions_car},
    {'name': 'Sedan', 'icon': Icons.directions_car},
    {'name': 'SUV', 'icon': Icons.directions_car},
    {'name': 'Van', 'icon': Icons.directions_car},
  ];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadUserData();
    _initializeConnectivity();
    _searchController.addListener(_applyVehicleFilters);
    _loadVehicles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Auth / data helpers (stubs — keep your existing implementations)
  // ---------------------------------------------------------------------------
  void _checkAuth() {}

  Future<void> _loadUserData() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return;

      final supabase = Supabase.instance.client;
      final resp = await _fetchUserProfileRecord(supabase, user.id);

      final metadata = user.userMetadata ?? <String, dynamic>{};
      final fullName =
          (resp?['full_name'] ??
                  resp?['name'] ??
                  resp?['display_name'] ??
                  metadata['full_name'] ??
                  metadata['name'] ??
                  metadata['display_name'] ??
                  metadata['user_name'] ??
                  metadata['first_name'])
              ?.toString()
              .trim();
      final location =
          (resp?['location'] ?? metadata['location'] ?? metadata['address'])
              ?.toString()
              .trim();

      final hasSavedLocation = location != null && location.isNotEmpty;

      if (resp != null) {
        setState(() {
          userName = (fullName != null && fullName.isNotEmpty)
              ? fullName
              : (user.email?.split('@').first ?? userName);
          userLocation = (location != null && location.isNotEmpty)
              ? location
              : userLocation;
          userVerified = (resp['id_verified'] as bool?) ?? userVerified;
          if (resp['created_at'] != null) {
            try {
              _userCreatedYear = DateTime.parse(resp['created_at']).year;
            } catch (_) {}
          }
        });
        if (!hasSavedLocation) {
          await _getDeviceLocation();
        }
      } else {
        if (mounted) {
          setState(() {
            userName = (fullName != null && fullName.isNotEmpty)
                ? fullName
                : (user.email?.split('@').first ?? userName);
            if (location != null && location.isNotEmpty) {
              userLocation = location;
            }
          });
        }
        if (!hasSavedLocation) {
          await _getDeviceLocation();
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchUserProfileRecord(
    SupabaseClient supabase,
    String userId,
  ) async {
    try {
      // Keep this schema-safe across projects where users.location is absent.
      return await supabase
          .from('users')
          .select('full_name, id_verified, created_at')
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Profile lookup skipped for users: $e');
      return null;
    }
  }

  Future<void> _getDeviceLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          debugPrint('Location permission denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final place = [
            p.locality,
            p.subAdministrativeArea,
            p.subLocality,
          ].where((s) => s != null && s.isNotEmpty).join(', ');
          if (mounted)
            setState(
              () => userLocation = place.isNotEmpty ? place : userLocation,
            );
        }
      } catch (e) {
        debugPrint('Reverse geocoding failed: $e');
      }
    } catch (e) {
      debugPrint('Error obtaining device location: $e');
    }
  }

  void _initializeConnectivity() {}

  Future<void> _loadVehicles() async {
    if (!mounted) return;
    setState(() => _isLoadingVehicles = true);
    try {
      final vehicles = await VehicleService().getAvailableVehicles(
        category: selectedCategory.isEmpty ? null : selectedCategory,
      );
      if (!mounted) return;
      setState(() => _vehicles = vehicles);
      _applyVehicleFilters();
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      if (!mounted) return;
      setState(() {
        _vehicles = [];
        _filteredVehicles = [];
      });
    } finally {
      if (mounted) setState(() => _isLoadingVehicles = false);
    }
  }

  void _applyVehicleFilters() {
    final search = _searchController.text.trim().toLowerCase();
    final filtered = _vehicles.where((vehicle) {
      if (search.isEmpty) return true;
      final brand = (vehicle['brand'] ?? '').toString().toLowerCase();
      final model = (vehicle['model'] ?? '').toString().toLowerCase();
      final vehicleName = (vehicle['vehicle_name'] ?? '')
          .toString()
          .toLowerCase();
      final category = (vehicle['category'] ?? '').toString().toLowerCase();
      final vehicleType = (vehicle['vehicle_type'] ?? '')
          .toString()
          .toLowerCase();
      final source = (vehicle['source'] ?? '').toString().toLowerCase();
      return brand.contains(search) ||
          model.contains(search) ||
          vehicleName.contains(search) ||
          vehicleType.contains(search) ||
          category.contains(search) ||
          source.contains(search);
    }).toList();

    if (!mounted) return;
    setState(() => _filteredVehicles = filtered);
  }

  Future<void> _refreshDashboard() async {
    await _loadVehicles();
    _loadUserData();
  }

  // ---------------------------------------------------------------------------
  // Verification helpers
  // ---------------------------------------------------------------------------
  void _showRentalVerificationModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.warning,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Verification Required',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Complete your identity verification\nto book and rent cars',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed('/id-verification');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Verify Identity',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _checkRentalVerification() {
    if (!userVerified) {
      _showRentalVerificationModal();
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Data mappers
  // ---------------------------------------------------------------------------
  List<Map<String, dynamic>> _uiBookings() {
    return _bookings.map((booking) {
      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final totalCost =
          (booking['total_price'] as num?)?.toDouble() ??
          (booking['total_cost'] as num?)?.toDouble() ??
          0.0;

      final startDateRaw = booking['start_date']?.toString();
      final endDateRaw = booking['end_date']?.toString();
      final startDate = _formatDateShort(startDateRaw);
      final endDate = _formatDateShort(endDateRaw);

      int days = 1;
      try {
        if (startDateRaw != null && endDateRaw != null) {
          final start = DateTime.parse(startDateRaw);
          final end = DateTime.parse(endDateRaw);
          days = end.difference(start).inDays.abs();
          if (days == 0) days = 1;
        }
      } catch (_) {
        days = 1;
      }

      final rawStatus = (booking['status'] ?? '').toString().toLowerCase();
      String uiStatus;
      if (rawStatus == 'active') {
        uiStatus = 'Active';
      } else if (rawStatus == 'completed') {
        uiStatus = 'Past';
      } else if (rawStatus == 'cancelled' || rawStatus == 'rejected') {
        uiStatus = 'Cancelled';
      } else {
        uiStatus = 'Upcoming';
      }

      return {
        'id': booking['id']?.toString() ?? '',
        'carName':
            '${vehicle?['brand'] ?? 'Unknown'} ${vehicle?['model'] ?? ''}'
                .trim(),
        'carImage': Icons.directions_car,
        'status': uiStatus,
        'startDate': startDate,
        'endDate': endDate,
        'pickupLocation':
            booking['pickup_location']?.toString() ?? 'Pickup not specified',
        'dropoffLocation':
            booking['dropoff_location']?.toString() ?? 'Drop-off not specified',
        'totalCost': totalCost,
        'days': days,
        'rentalPartner':
            vehicle?['owner_name']?.toString() ?? 'Mobilis Partner',
        'rating': (vehicle?['rating'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _uiNotifications() {
    return _notifications.map((n) {
      final type = (n['type'] ?? 'general').toString().toLowerCase();
      IconData icon;
      Color iconColor;
      if (type.contains('booking')) {
        icon = Icons.calendar_today;
        iconColor = AppColors.warning;
      } else if (type.contains('message')) {
        icon = Icons.message;
        iconColor = AppColors.primary;
      } else if (type.contains('payment') || type.contains('success')) {
        icon = Icons.check_circle;
        iconColor = AppColors.success;
      } else {
        icon = Icons.notifications;
        iconColor = AppColors.textSecondary;
      }

      return {
        'title': n['title']?.toString() ?? 'Notification',
        'message': n['message']?.toString() ?? '',
        'timestamp': _formatTimeAgo(n['created_at']?.toString()),
        'icon': icon,
        'iconColor': iconColor,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _topRentalPartners() {
    final partnerMap = <String, Map<String, dynamic>>{};

    for (final vehicle in _vehicles) {
      final owner = vehicle['owner'] as Map<String, dynamic>?;
      final ownerRole = owner?['role']?.toString().toLowerCase() ?? '';
      final source = vehicle['source']?.toString().toLowerCase() ?? '';
      if (ownerRole.isNotEmpty &&
          ownerRole != 'partner' &&
          source != 'partner') {
        continue;
      }

      final ownerName =
          owner?['full_name']?.toString() ??
          vehicle['owner_name']?.toString() ??
          vehicle['partner_name']?.toString() ??
          'Mobilis Partner';
      final rating = (vehicle['rating'] as num?)?.toDouble() ?? 0.0;

      final current = partnerMap[ownerName];
      if (current == null) {
        partnerMap[ownerName] = {
          'name': ownerName,
          'ratingTotal': rating,
          'ratingCount': rating > 0 ? 1 : 0,
          'trips': 1,
          'image': Icons.person,
          'verified': true,
        };
      } else {
        current['ratingTotal'] = (current['ratingTotal'] as double) + rating;
        current['ratingCount'] =
            (current['ratingCount'] as int) + (rating > 0 ? 1 : 0);
        current['trips'] = (current['trips'] as int) + 1;
      }
    }

    final result = partnerMap.values.map((p) {
      final count = p['ratingCount'] as int;
      final avg = count > 0 ? (p['ratingTotal'] as double) / count : 0.0;
      return {
        'name': p['name'],
        'rating': avg,
        'reviews': '${p['trips']} vehicles',
        'image': p['image'],
        'verified': p['verified'],
      };
    }).toList();

    result.sort(
      (a, b) => (b['rating'] as double).compareTo(a['rating'] as double),
    );
    return result.take(10).toList();
  }

  // ---------------------------------------------------------------------------
  // Formatters
  // ---------------------------------------------------------------------------
  String _formatDateShort(String? date) {
    if (date == null || date.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(date).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return date;
    }
  }

  String _formatTimeAgo(String? date) {
    if (date == null || date.isEmpty) return 'just now';
    try {
      final d = DateTime.parse(date).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return _formatDateShort(date);
    } catch (_) {
      return date;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: _buildTabContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedNavIndex,
        backgroundColor: AppColors.darkBgSecondary,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          setState(() {
            selectedNavIndex = index;
            selectedBookingIndex = null;
          });
        },
      ),
    );
  }

  Widget _buildTabContent() {
    switch (selectedNavIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildBookingsTab();
      case 2:
        return _buildMessagesTab();
      case 3:
        return _buildNotificationsTab();
      case 4:
        return _buildProfileTab();
      default:
        return _buildHomeTab();
    }
  }

  // ---------------------------------------------------------------------------
  // Home Tab
  // ---------------------------------------------------------------------------
  Widget _buildHomeTab() {
    final uiBookings = _uiBookings();
    final homeTrips = uiBookings
        .where((b) => b['status'] == 'Active' || b['status'] == 'Upcoming')
        .take(10)
        .toList();

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.of(context).padding.top + 24,
                24,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile row
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome,',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'CURRENT LOCATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userLocation,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _applyVehicleFilters(),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Find a car near you...',
                        hintStyle: const TextStyle(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textTertiary,
                        ),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.tune,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Your Trips ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Trips',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => selectedNavIndex = 1),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 160,
                child: homeTrips.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          color: AppColors.darkBgSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: const Center(
                          child: Text(
                            'No trips yet',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: homeTrips.length,
                        itemBuilder: (context, index) {
                          final booking = homeTrips[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Container(
                              width: 260,
                              decoration: BoxDecoration(
                                color: AppColors.darkBgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booking['carName'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking['rentalPartner'],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 12,
                                        color: AppColors.textTertiary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${booking['days']} days',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 12,
                                        color: AppColors.ratingGold,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${booking['rating']}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Categories ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Navigate to full categories/vehicles list
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VehicleSearchScreen(
                            initialCategory: selectedCategory.isEmpty
                                ? null
                                : selectedCategory,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final categoryName = category['name'] as String;
                    final isSelected = categoryName == 'All Cars'
                        ? selectedCategory.isEmpty
                        : selectedCategory == categoryName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = categoryName == 'All Cars'
                                ? ''
                                : categoryName;
                            _isLoadingVehicles = true;
                          });
                          _loadVehicles();
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.darkBgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.borderColor,
                                ),
                              ),
                              child: Icon(
                                category['icon'] as IconData,
                                color: isSelected
                                    ? Colors.black
                                    : AppColors.textSecondary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              categoryName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Available Cars ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Cars',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${_filteredVehicles.length} cars',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VehicleSearchScreen(
                                initialCategory: selectedCategory.isEmpty
                                    ? null
                                    : selectedCategory,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _isLoadingVehicles
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : _vehicles.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Opacity(
                              opacity: 0.3,
                              child: Image.asset(
                                'assets/icon/logo1.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No vehicles available',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _filteredVehicles.length,
                    itemBuilder: (context, index) {
                      final car = _filteredVehicles[index];
                      final carName =
                          '${car['brand'] ?? 'Unknown'} ${car['model'] ?? 'Model'}';
                      final category =
                          (car['vehicle_type'] ?? car['category'] ?? 'Standard')
                              .toString()
                              .toUpperCase();
                      final price =
                          (car['price_per_hour'] as num?)?.toDouble() ??
                          (car['price_per_day'] as num?)?.toDouble() ??
                          0.0;
                      final rating = (car['rating'] as num?)?.toDouble() ?? 4.5;
                      final vehicleType = car['vehicle_type'] ?? 'Standard';
                      final color = car['color'] ?? 'Unknown';
                      final seats = car['seats'] ?? 5;
                      final imageUrl = car['image_url'] as String?;
                      const providerName = 'PSDC';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/vehicle-detail',
                              arguments: {
                                'vehicleId': car['id']?.toString() ?? '',
                                'vehicleData': car,
                              },
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.darkBgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        height: 200,
                                        color: AppColors.darkBgTertiary,
                                        child: imageUrl != null
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (_, __, ___) =>
                                                    const Center(
                                                      child: Icon(
                                                        Icons.directions_car,
                                                        size: 60,
                                                        color: AppColors
                                                            .textTertiary,
                                                      ),
                                                    ),
                                              )
                                            : const Center(
                                                child: Icon(
                                                  Icons.directions_car,
                                                  size: 60,
                                                  color: AppColors.textTertiary,
                                                ),
                                              ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        left: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.darkBgSecondary,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: AppColors.borderColor,
                                            ),
                                          ),
                                          child: const Text(
                                            providerName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.darkBgSecondary,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: AppColors.borderColor,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: AppColors.ratingGold,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: AppColors.darkBgSecondary,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppColors.borderColor,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.favorite_border,
                                            color: AppColors.textSecondary,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          carName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          category,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _buildFeatureIcon(
                                              Icons.directions_car,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              vehicleType.toString(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            _buildFeatureIcon(
                                              Icons.palette_outlined,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              color.toString(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            _buildFeatureIcon(Icons.person),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$seats Seats',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '₱${price.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                const Text(
                                                  '/hour',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: 44,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  if (_checkRentalVerification()) {
                                                    Navigator.of(
                                                      context,
                                                    ).pushNamed(
                                                      '/vehicle-detail',
                                                      arguments: {
                                                        'vehicleId':
                                                            car['id']
                                                                ?.toString() ??
                                                            '',
                                                        'vehicleData': car,
                                                      },
                                                    );
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.primary,
                                                  foregroundColor: Colors.black,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Book Now',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
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
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),

            // ── Partners Near You ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Partners Near You',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _topRentalPartners().length,
                  itemBuilder: (context, index) {
                    final partner = _topRentalPartners()[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        width: 160,
                        decoration: BoxDecoration(
                          color: AppColors.darkBgSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Icon(
                                    partner['image'] as IconData? ??
                                        Icons.person,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    partner['name'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: AppColors.ratingGold,
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (partner['rating'] as double).toStringAsFixed(
                                    1,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bookings Tab
  // ---------------------------------------------------------------------------
  Widget _buildBookingsTab() {
    final uiBookings = _uiBookings();

    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            12,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => selectedNavIndex = 0),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'My Bookings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                Container(
                  color: AppColors.darkBg,
                  child: const TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Active'),
                      Tab(text: 'Past'),
                      Tab(text: 'Cancelled'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBookingsList(
                        uiBookings
                            .where((b) => b['status'] == 'Upcoming')
                            .toList(),
                      ),
                      _buildBookingsList(
                        uiBookings
                            .where((b) => b['status'] == 'Active')
                            .toList(),
                      ),
                      _buildBookingsList(
                        uiBookings.where((b) => b['status'] == 'Past').toList(),
                      ),
                      _buildBookingsList(
                        uiBookings
                            .where((b) => b['status'] == 'Cancelled')
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text(
              'No bookings found',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          bookings.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () {
                setState(() => selectedBookingIndex = index);
                _showBookingDetails(bookings[index]);
              },
              child: BookingCard(
                carName: bookings[index]['carName'],
                rentalPartner: bookings[index]['rentalPartner'],
                status: bookings[index]['status'],
                days: bookings[index]['days'],
                pickupLocation: bookings[index]['pickupLocation'],
                dropoffLocation: bookings[index]['dropoffLocation'],
                totalCost: bookings[index]['totalCost'],
                rating: bookings[index]['rating'],
                isActive: bookings[index]['status'] == 'Active',
                onTap: () => _showBookingDetails(bookings[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Notifications Tab
  // ---------------------------------------------------------------------------
  Widget _buildNotificationsTab() {
    final notificationItems = _uiNotifications();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 16,
        16,
        16,
      ),
      child: Column(
        children: List.generate(
          notificationItems.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NotificationItem(
              icon: notificationItems[index]['icon'],
              title: notificationItems[index]['title'],
              message: notificationItems[index]['message'],
              timestamp: notificationItems[index]['timestamp'],
              iconColor: notificationItems[index]['iconColor'],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Messages Tab
  // ---------------------------------------------------------------------------
  Widget _buildMessagesTab() {
    final messageItems = _uiNotifications()
        .where((item) => item['icon'] == Icons.message)
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 16,
        16,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Messages',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (messageItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: const Text(
                'No messages yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            Column(
              children: List.generate(
                messageItems.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NotificationItem(
                    icon: messageItems[index]['icon'],
                    title: messageItems[index]['title'],
                    message: messageItems[index]['message'],
                    timestamp: messageItems[index]['timestamp'],
                    iconColor: messageItems[index]['iconColor'],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Tab
  // ---------------------------------------------------------------------------
  Widget _buildProfileTab() {
    if (selectedProfilePage == 'settings') {
      return SettingsScreen(
        onThemeToggle: widget.onThemeToggle,
        isDarkMode: widget.isDarkMode,
        onBack: () => setState(() => selectedProfilePage = null),
      );
    } else if (selectedProfilePage == 'payment') {
      return PaymentMethodsScreen(
        isDarkMode: widget.isDarkMode,
        onBack: () => setState(() => selectedProfilePage = null),
      );
    } else if (selectedProfilePage == 'verification') {
      return VerificationDocumentsScreen(
        isDarkMode: widget.isDarkMode,
        onBack: () => setState(() => selectedProfilePage = null),
      );
    }

    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            12,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => selectedNavIndex = 0),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Icon(
                  Icons.notifications_none,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.black,
                              size: 50,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.darkBg,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: userVerified
                              ? AppColors.success.withOpacity(0.2)
                              : AppColors.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          userVerified ? 'Verified Renter' : 'Basic Renter',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: userVerified
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Member since $_userCreatedYear',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$_totalTrips',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Total Trips',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Menu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Messages & Notifications',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildProfileMenuOption(
                        Icons.chat_bubble_outline,
                        'Messages',
                        badgeCount: 3,
                        onTap: () => setState(() => selectedNavIndex = 2),
                      ),
                      _buildProfileMenuOption(
                        Icons.notifications_none,
                        'Notifications',
                        badgeCount: _notifications.length,
                        onTap: () => setState(() => selectedNavIndex = 3),
                      ),
                      const SizedBox(height: 8),
                      _buildProfileMenuOption(
                        Icons.calendar_today,
                        'My Bookings',
                        onTap: () => setState(() => selectedNavIndex = 1),
                      ),
                      _buildProfileMenuOption(
                        Icons.payment,
                        'Payment Methods',
                        onTap: () =>
                            setState(() => selectedProfilePage = 'payment'),
                      ),
                      _buildProfileMenuOption(
                        Icons.verified_user,
                        'Verification Documents',
                        onTap: () => setState(
                          () => selectedProfilePage = 'verification',
                        ),
                      ),
                      _buildProfileMenuOption(
                        Icons.settings,
                        'Settings',
                        onTap: () =>
                            setState(() => selectedProfilePage = 'settings'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Log Out
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Log Out'),
                            content: const Text(
                              'Are you sure you want to log out?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Log Out',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          final authService = AuthService();
                          await authService.signOut();
                          if (mounted) {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/login');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMenuOption(
    IconData icon,
    String label, {
    int badgeCount = 0,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Booking detail modal
  // ---------------------------------------------------------------------------
  void _showBookingDetails(Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trip Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.darkBgTertiary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['carName'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          booking['rentalPartner'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: booking['status']),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Trip Timeline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TripTimelineStep(
              label: 'Pickup',
              date: booking['startDate'],
              time: '2:00 PM',
              icon: Icons.location_on,
              isActive: true,
            ),
            const SizedBox(height: 16),
            TripTimelineStep(
              label: 'Dropoff',
              date: booking['endDate'],
              time: '2:00 PM',
              icon: Icons.location_on,
              isCompleted: booking['status'] == 'Completed',
            ),
            const SizedBox(height: 16),
            const Text(
              'Cost Breakdown',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            CostBreakdownRow(
              label:
                  '${booking['days']} days × ₱${booking['totalCost'] ~/ booking['days']}/day',
              amount: '₱${booking['totalCost']}',
            ),
            const CostBreakdownRow(label: 'Insurance', amount: '₱50'),
            CostBreakdownRow(
              label: 'Tax (10%)',
              amount:
                  '₱${((booking['totalCost'] + 50) * 0.1).toStringAsFixed(0)}',
            ),
            const Divider(color: AppColors.borderColor),
            CostBreakdownRow(
              label: 'Total',
              amount:
                  '₱${(booking['totalCost'] + 50 + ((booking['totalCost'] + 50) * 0.1)).toStringAsFixed(0)}',
              isBold: true,
              amountColor: AppColors.primary,
            ),
            const SizedBox(height: 20),
            if (booking['status'] == 'Active')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Extend Trip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel Trip'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon) {
    return Icon(icon, size: 14, color: AppColors.textTertiary);
  }
}
