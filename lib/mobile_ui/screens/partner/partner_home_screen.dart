import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/partner_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/conversation_tile.dart';
import '../../widgets/notification_item.dart';

class PartnerHomeScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const PartnerHomeScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  State<PartnerHomeScreen> createState() => _PartnerHomeScreenState();
}

class _PartnerHomeScreenState extends State<PartnerHomeScreen> {
  int selectedNavIndex = 0;
  int selectedBookingTab = 0; // 0: Pending, 1: Active, 2: Past, 3: Cancelled
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Partner data
  String partnerName = 'Loading...';
  String verificationStatus = 'pending';
  Map<String, dynamic>? partnerProfile;
  String? partnerId;

  // Stats
  double totalEarnings = 0.0;
  int activeVehicles = 0;
  double rating = 0.0;

  // Application counts
  Map<String, int> applicationCounts = {
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'total': 0,
  };

  // Booking counts
  Map<String, int> bookingCounts = {
    'pending': 0,
    'active': 0,
    'completed': 0,
    'cancelled': 0,
    'total': 0,
  };

  // Lists
  List<Map<String, dynamic>> applications = [];
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> conversations = [];
  List<Map<String, dynamic>> notifications = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPartnerData();
    _initializeConnectivity();
  }

  void _initializeConnectivity() async {
    final connectivityService = ConnectivityService();
    await connectivityService.checkConnectivity();

    connectivityService.listenConnectivity((isOnline) {
      if (!isOnline && mounted) {
        _showOfflineWarning();
      }
    });
  }

  void _showOfflineWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 12),
            Text('No Internet Connection'),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadPartnerData() async {
    try {
      final authService = AuthService();
      final partnerService = PartnerService();
      final user = authService.currentUser;

      if (user != null) {
        // Get partner profile
        final profile = await partnerService.getPartnerProfile(user.id);

        if (profile != null) {
          partnerId = profile['id'] as String?;

          // Load counts and data
          final appCounts = await partnerService.getApplicationCounts(
            partnerId!,
          );
          final apps = await partnerService.getVehicleApplications(partnerId!);

          final bookingService = BookingService();
          final bCounts = await bookingService.getPartnerBookingCounts(
            partnerId!,
          );
          final bList = await bookingService.getRecentPartnerBookings(
            partnerId!,
          );

          final chatService = ChatService();
          final convs = await chatService.getConversations(user.id);

          final notificationService = NotificationService();
          final notifs = await notificationService.getNotifications(user.id);

          setState(() {
            partnerProfile = profile;
            partnerName = user.userMetadata?['full_name'] ?? 'Partner';
            verificationStatus = profile['verification_status'] ?? 'pending';
            applicationCounts = appCounts;
            applications = apps;
            bookingCounts = bCounts;
            bookings = bList;
            conversations = convs;
            notifications = notifs;
            activeVehicles = appCounts['approved'] ?? 0;
            isLoading = false;
          });
        } else {
          // Create partner profile if not exists
          await partnerService.createPartnerProfile(userId: user.id);
          _loadPartnerData(); // Reload
        }
      }
    } catch (e) {
      debugPrint('Error loading partner data: $e');
      // Use mock data for UI preview when database is not available
      _loadMockData();
    }
  }

  void _loadMockData() {
    setState(() {
      partnerName = 'Alex Rivera';
      verificationStatus = 'verified';
      partnerId = 'mock-partner-id';
      totalEarnings = 45750.00;
      activeVehicles = 3;
      rating = 4.8;
      applicationCounts = {
        'pending': 1,
        'approved': 3,
        'rejected': 1,
        'total': 5,
      };
      bookingCounts = {
        'pending': 2,
        'active': 1,
        'completed': 15,
        'cancelled': 2,
        'total': 20,
      };
      applications = [
        {
          'id': '1',
          'brand': 'Mercedes-Benz',
          'model': 'C-Class',
          'year': 2023,
          'plate_number': 'MNO 3456',
          'status': 'pending',
          'price_per_day': 6000.00,
          'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        },
        {
          'id': '2',
          'brand': 'Toyota',
          'model': 'Camry',
          'year': 2023,
          'plate_number': 'ABC 1234',
          'status': 'approved',
          'price_per_day': 2500.00,
          'created_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        },
        {
          'id': '3',
          'brand': 'BMW',
          'model': '5 Series',
          'year': 2022,
          'plate_number': 'XYZ 5678',
          'status': 'approved',
          'price_per_day': 5000.00,
          'created_at': DateTime.now().subtract(const Duration(days: 25)).toIso8601String(),
        },
      ];
      bookings = [
        {
          'id': '1',
          'vehicle_name': 'BMW 5 Series',
          'renter_name': 'Mark Jensen',
          'start_date': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          'end_date': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          'total_price': 15000.00,
          'status': 'pending',
          'pickup_location': 'Manila Airport Terminal 3',
        },
        {
          'id': '2',
          'vehicle_name': 'Honda CR-V',
          'renter_name': 'Sarah Lee',
          'start_date': DateTime.now().toIso8601String(),
          'end_date': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
          'total_price': 10500.00,
          'status': 'active',
          'pickup_location': 'Ortigas Center',
        },
      ];
      conversations = [
        {
          'id': '1',
          'other_user_name': 'Mark Jensen',
          'last_message': 'Is the car available for pickup at 10am?',
          'updated_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'unread_count': 2,
        },
        {
          'id': '2',
          'other_user_name': 'Sarah Lee',
          'last_message': 'Thank you! The car is great.',
          'updated_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'unread_count': 0,
        },
      ];
      notifications = [
        {
          'id': '1',
          'title': 'New Booking Request',
          'message': 'Mark Jensen wants to book your BMW 5 Series',
          'type': 'booking',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': '2',
          'title': 'Payment Received',
          'message': 'You received ₱7,500 for the Toyota Camry booking',
          'type': 'payment',
          'is_read': true,
          'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        },
      ];
      isLoading = false;
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.darkBg,
      drawer: _buildDrawer(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _buildTabContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedNavIndex,
        backgroundColor: AppColors.darkBgSecondary,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          setState(() {
            selectedNavIndex = index;
          });
        },
      ),
    );
  }

  // ===================== DRAWER =====================
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.darkBgSecondary,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mobilis by PSDC',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Fleet Manager',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderColor, height: 1),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard,
                    label: 'Dashboard Overview',
                    isSelected: selectedNavIndex == 0,
                    onTap: () {
                      setState(() => selectedNavIndex = 0);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.directions_car,
                    label: 'My Vehicles',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/vehicle-availability');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.handshake,
                    label: 'Partnership',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/apply-vehicle');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.book_online,
                    label: 'Booking Requests',
                    onTap: () {
                      setState(() => selectedNavIndex = 3);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.account_balance_wallet,
                    label: 'Revenue & Earnings',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: AppColors.borderColor, height: 1),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.dark_mode,
                    label: 'Dark Mode',
                    trailing: Switch(
                      value: widget.isDarkMode,
                      onChanged: (value) {
                        widget.onThemeToggle?.call(value);
                      },
                      activeThumbColor: AppColors.primary,
                    ),
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    icon: Icons.star,
                    label: 'Reviews & Ratings',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    label: 'Logout',
                    iconColor: AppColors.error,
                    labelColor: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      _handleLogout();
                    },
                  ),
                ],
              ),
            ),

            // User Profile at bottom
            const Divider(color: AppColors.borderColor, height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partnerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          verificationStatus == 'verified' ? 'VERIFIED OWNER' : 'PENDING VERIFICATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: verificationStatus == 'verified' ? AppColors.success : AppColors.warning,
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
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    bool isSelected = false,
    Widget? trailing,
    Color? iconColor,
    Color? labelColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withAlpha(30) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? (isSelected ? AppColors.primary : AppColors.textSecondary),
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: labelColor ?? (isSelected ? AppColors.primary : AppColors.textPrimary),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildTabContent() {
    switch (selectedNavIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildNotificationsTab();
      case 2:
        return _buildMessagesTab();
      case 3:
        return _buildBookingsTab();
      case 4:
        return _buildProfileTab();
      default:
        return _buildDashboardTab();
    }
  }

  // ===================== DASHBOARD TAB =====================
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with profile
          _buildDashboardHeader(),

          // Verification Banner
          if (verificationStatus != 'verified')
            _buildVerificationBanner()
          else
            _buildVerifiedBanner(),

          const SizedBox(height: 20),

          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildStatCard(
                  label: 'EARNINGS',
                  value: '₱${totalEarnings.toStringAsFixed(0)}',
                  subtext: '+12%',
                  subtextColor: AppColors.success,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  label: 'ACTIVE',
                  value: '$activeVehicles',
                  subtext: 'Cars on road',
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  label: 'RATING',
                  value: rating > 0 ? rating.toStringAsFixed(1) : '-',
                  subtext: rating >= 4.5 ? 'High' : 'Good',
                  subtextColor: AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUICK ACTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildQuickAction(
                      icon: Icons.add_circle_outline,
                      label: 'Add Vehicle',
                      onTap: () => Navigator.pushNamed(context, '/apply-vehicle'),
                    ),
                    const SizedBox(width: 12),
                    _buildQuickAction(
                      icon: Icons.directions_car,
                      label: 'Manage Fleet',
                      onTap: () => Navigator.pushNamed(context, '/vehicle-availability'),
                    ),
                    const SizedBox(width: 12),
                    _buildQuickAction(
                      icon: Icons.bar_chart,
                      label: 'View Revenue',
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    _buildQuickAction(
                      icon: Icons.workspace_premium,
                      label: 'Plan Details',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Pro Fleet Plan Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withAlpha(40),
                    AppColors.primary.withAlpha(20),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pro Fleet Plan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Unlimited vehicles & premium support',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Upgrade',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recent Requests Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildRecentRequestsSection(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      partnerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (verificationStatus == 'verified')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, color: AppColors.success, size: 12),
                            SizedBox(width: 2),
                            Text(
                              'VERIFIED',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const Text(
                  'Mobilis by PSDC Fleet Manager',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => selectedNavIndex = 1),
            child: Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.darkBgSecondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
                if (notifications.where((n) => n['is_read'] == false).isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.pending,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Verification',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  'Complete verification to start listing vehicles',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/owner-verification'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Verify',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.verified_user,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verified Owner',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'Your fleet is ready for listings',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Details',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String subtext,
    Color? subtextColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: subtextColor ?? AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Requests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => selectedNavIndex = 3),
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
        const SizedBox(height: 12),

        // Booking tabs
        Container(
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildBookingTabButton('Pending', 0),
              _buildBookingTabButton('Active', 1),
              _buildBookingTabButton('Past', 2),
              _buildBookingTabButton('Cancelled', 3),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Booking cards
        if (bookings.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.calendar_today, size: 48, color: AppColors.textTertiary),
                  SizedBox(height: 12),
                  Text(
                    'No booking requests yet',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ...bookings.take(3).map((booking) => _buildBookingRequestCard(booking)),
      ],
    );
  }

  Widget _buildBookingTabButton(String label, int index) {
    final isSelected = selectedBookingTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedBookingTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingRequestCard(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['users'] as Map<String, dynamic>?;
    final status = booking['status'] ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.darkBgTertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_car, color: AppColors.textSecondary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '₱${vehicle?['price_per_day']?.toString() ?? '0'}/day',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicle?['year']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderColor, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₱${booking['total_price']?.toString() ?? '0'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Total Profit',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateRange(booking['start_date'], booking['end_date']),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Booking Period',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      renter?['full_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Renter',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleBookingAction(booking['id'], 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.textSecondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleBookingAction(booking['id'], 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateRange(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) return 'N/A';
    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[start.month - 1]} ${start.day}-${end.day}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _handleBookingAction(String bookingId, String status) async {
    try {
      final bookingService = BookingService();
      await bookingService.updateBookingStatus(bookingId, status);
      _showSuccessSnackBar(status == 'confirmed' ? 'Booking accepted!' : 'Booking declined');
      _loadPartnerData();
    } catch (e) {
      _showErrorSnackBar('Failed to update booking');
    }
  }

  // ===================== NOTIFICATIONS TAB =====================
  Widget _buildNotificationsTab() {
    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => selectedNavIndex = 0),
                child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Alerts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              const Spacer(),
              if (notifications.isNotEmpty)
                GestureDetector(
                  onTap: _markAllNotificationsRead,
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: AppColors.textTertiary),
                      SizedBox(height: 16),
                      Text('No alerts yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return NotificationItem(
                      icon: _getNotificationIcon(notif['type']),
                      title: notif['title'] ?? 'Notification',
                      message: notif['message'] ?? '',
                      timestamp: _formatTime(notif['created_at']),
                      iconColor: _getNotificationColor(notif['type']),
                      onTap: () async {
                        final notificationService = NotificationService();
                        await notificationService.markAsRead(notif['id']);
                        _loadPartnerData();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ===================== MESSAGES TAB =====================
  Widget _buildMessagesTab() {
    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => selectedNavIndex = 0),
                child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Messages',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
              ),
            ],
          ),
        ),
        Expanded(
          child: conversations.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textTertiary),
                      SizedBox(height: 16),
                      Text('No messages yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    final messages = conv['messages'] as List<dynamic>? ?? [];
                    final lastMessage = messages.isNotEmpty ? messages.last['content'] ?? '' : 'No messages';

                    return ConversationTile(
                      senderName: 'Renter',
                      lastMessage: lastMessage,
                      timestamp: _formatTime(conv['updated_at']),
                      unreadCount: 0,
                      onTap: () {},
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ===================== BOOKINGS TAB =====================
  Widget _buildBookingsTab() {
    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => selectedNavIndex = 0),
                child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Bookings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/vehicle-availability'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_month, color: Colors.black, size: 16),
                      SizedBox(width: 4),
                      Text('Availability', style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w600)),
                    ],
                  ),
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
                  color: AppColors.darkBgSecondary,
                  child: const TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Active'),
                      Tab(text: 'Completed'),
                      Tab(text: 'Cancelled'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBookingsList('pending'),
                      _buildBookingsList('active'),
                      _buildBookingsList('completed'),
                      _buildBookingsList('cancelled'),
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

  Widget _buildBookingsList(String status) {
    final filteredBookings = bookings.where((b) => b['status']?.toLowerCase() == status.toLowerCase()).toList();

    if (filteredBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('No $status bookings', style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredBookings.length,
      itemBuilder: (context, index) {
        final booking = filteredBookings[index];
        final vehicle = booking['vehicles'] as Map<String, dynamic>?;
        final renter = booking['users'] as Map<String, dynamic>?;

        return BookingCard(
          carName: '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}',
          rentalPartner: renter?['full_name'] ?? 'Unknown Renter',
          status: booking['status'] ?? 'pending',
          days: _calculateDays(booking['start_date'], booking['end_date']),
          pickupLocation: booking['pickup_location'] ?? 'Not specified',
          dropoffLocation: booking['dropoff_location'] ?? 'Not specified',
          totalCost: (booking['total_price'] ?? 0).toInt(),
          rating: 0.0,
          onTap: () {},
          isActive: booking['status'] == 'active',
        );
      },
    );
  }

  int _calculateDays(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) return 1;
    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      return end.difference(start).inDays + 1;
    } catch (e) {
      return 1;
    }
  }

  // ===================== PROFILE TAB =====================
  Widget _buildProfileTab() {
    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => selectedNavIndex = 0),
                child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Icon(Icons.settings, color: Colors.black, size: 22),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.darkBgSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Center(
                          child: Text(
                            partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        partnerName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            verificationStatus == 'verified' ? Icons.verified : Icons.pending,
                            color: verificationStatus == 'verified' ? AppColors.success : AppColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            verificationStatus == 'verified' ? 'Verified Owner' : 'Pending Verification',
                            style: TextStyle(
                              fontSize: 12,
                              color: verificationStatus == 'verified' ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildProfileStat('Vehicles', activeVehicles.toString()),
                          ),
                          Container(width: 1, height: 40, color: AppColors.borderColor),
                          Expanded(
                            child: _buildProfileStat('Bookings', bookingCounts['total']?.toString() ?? '0'),
                          ),
                          Container(width: 1, height: 40, color: AppColors.borderColor),
                          Expanded(
                            child: _buildProfileStat('Rating', rating > 0 ? rating.toStringAsFixed(1) : '-'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Menu Items
                _buildProfileMenuItem(Icons.person_outline, 'Edit Profile', onTap: () {}),
                _buildProfileMenuItem(Icons.security, 'Verification', onTap: () => Navigator.pushNamed(context, '/owner-verification')),
                _buildProfileMenuItem(Icons.account_balance_wallet, 'Payment Settings', onTap: () {}),
                _buildProfileMenuItem(Icons.help_outline, 'Help & Support', onTap: () {}),
                _buildProfileMenuItem(Icons.logout, 'Logout', iconColor: AppColors.error, onTap: _handleLogout),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildProfileMenuItem(IconData icon, String label, {Color? iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: iconColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  // ===================== HELPERS =====================
  IconData _getNotificationIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'booking':
        return Icons.calendar_today;
      case 'application':
        return Icons.description;
      case 'message':
        return Icons.chat;
      case 'payment':
        return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'booking':
        return AppColors.success;
      case 'application':
        return AppColors.warning;
      case 'message':
        return AppColors.primary;
      case 'payment':
        return Colors.green;
      default:
        return AppColors.primary;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inDays}d ago';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _markAllNotificationsRead() async {
    try {
      final authService = AuthService();
      final userId = authService.currentUser?.id;
      if (userId != null) {
        final notificationService = NotificationService();
        await notificationService.markAllAsRead(userId);
        _loadPartnerData();
        _showSuccessSnackBar('All notifications marked as read');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to mark notifications as read');
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        title: const Text('Logout', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authService = AuthService();
              await authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
