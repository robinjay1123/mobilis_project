import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/auth_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/partner_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/notification_permission_service.dart';
import '../../../services/tracking_service.dart';
import '../../../services/trip_rating_service.dart';
import '../../../services/user_restriction_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/conversation_tile.dart';
import '../../widgets/notification_item.dart';
import '../../widgets/restriction_ui.dart';
import '../profile/ratings_reviews_screen.dart';
import '../profile/trip_rating_flow_screen.dart';
import 'partner_tracking_screen.dart';
import 'partner_revenue_screen.dart';

bool _bookingNeedsDriver(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == 'yes' || normalized == '1';
  }
  return false;
}

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
  String partnershipStatus = 'basic'; // 'basic', 'approved', 'certified'
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
  List<Map<String, dynamic>> trackingLocations = [];

  // 🔔 Real-time bookings listener
  RealtimeChannel? _bookingsSubscription;
  RealtimeChannel? _notificationsSubscription;
  final UserRestrictionService _restrictionService = UserRestrictionService();
  UserRestrictionState _restrictionState = UserRestrictionState.empty;
  final Set<String> _shownRestrictionNotificationIds = {};

  bool isLoading = true;
  bool dismissedVerificationBanner = false;

  String _normalizeVerificationStatus(String? status) {
    final value = (status ?? 'pending').toLowerCase();
    if (value == 'approved') return 'verified';
    return value;
  }

  bool get _isPartnerVerified =>
      verificationStatus == 'verified' || partnershipStatus == 'certified';

  bool get _isPartnerCertified => partnershipStatus == 'certified';

  @override
  void initState() {
    super.initState();
    _loadPartnerData();
    _initializeConnectivity();
    _setupBookingsListener(); // 🔔 Listen for real-time bookings
  }

  @override
  void dispose() {
    _bookingsSubscription?.unsubscribe();
    _notificationsSubscription?.unsubscribe();
    super.dispose();
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
        // Partner-centric records use users.id as partner_id/owner_id.
        partnerId = user.id;

        // Optional profile table support for legacy setups.
        Map<String, dynamic>? profile;
        try {
          profile = await partnerService.getPartnerProfile(user.id);
        } catch (_) {
          profile = null;
        }

        final appCounts = await partnerService.getApplicationCounts(partnerId!);
        final apps = await partnerService.getVehicleApplications(partnerId!);

        final bookingService = BookingService();
        final bCounts = await bookingService.getPartnerBookingCounts(
          partnerId!,
        );
        final bList = await bookingService.getRecentPartnerBookings(partnerId!);

        final chatService = ChatService();
        final convs = await chatService.getConversations(user.id);

        final notificationService = NotificationService();
        final notifs = await notificationService.getNotifications(user.id);
        final liveTracking = await TrackingService()
            .getActiveTrackingLocations();
        final ratingSummary = await TripRatingService().getRatingSummary(
          user.id,
        );
        final restrictionState = await _restrictionService.getUserRestriction(
          user.id,
        );

        if (_notificationsSubscription == null) {
          _setupNotificationsListener(user.id);
        }

        setState(() {
          partnerProfile = profile;
          partnerName = user.userMetadata?['full_name'] ?? 'Partner';
          verificationStatus = _normalizeVerificationStatus(
            profile?['verification_status']?.toString(),
          );
          partnershipStatus = (profile?['partnership_status'] ?? 'basic')
              .toString()
              .toLowerCase();
          applicationCounts = appCounts;
          applications = apps;
          bookingCounts = bCounts;
          bookings = bList;
          conversations = convs;
          notifications = notifs;
          trackingLocations = liveTracking;
          activeVehicles = appCounts['approved'] ?? 0;
          rating = (ratingSummary['average'] as num?)?.toDouble() ?? 0.0;
          _restrictionState = restrictionState;
          isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowRestrictionNotification();
        });
      }
    } catch (e) {
      debugPrint('Error loading partner data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// 🔔 Set up real-time listener for new bookings
  void _setupBookingsListener() {
    try {
      if (partnerId == null) {
        debugPrint('⚠️ No partner ID for bookings listener');
        return;
      }

      final supabase = Supabase.instance.client;

      _bookingsSubscription = supabase.realtime.channel('public:bookings');

      _bookingsSubscription!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'bookings',
            callback: (payload) {
              debugPrint('🔔 New booking received');

              if (mounted) {
                // Reload bookings to reflect changes
                _loadPartnerData();
              }
            },
          )
          .subscribe();

      debugPrint('✅ Real-time bookings listener started');
    } catch (e) {
      debugPrint('⚠️ Error setting up bookings listener: $e');
    }
  }

  void _setupNotificationsListener(String userId) {
    try {
      final supabase = Supabase.instance.client;

      _notificationsSubscription = supabase.realtime.channel(
        'public:notifications:user_id=eq.$userId',
      );

      _notificationsSubscription!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final newNotification =
                  payload.newRecord as Map<String, dynamic>?;
              if (newNotification == null || !mounted) return;

              setState(() {
                notifications.insert(0, newNotification);
              });

              final title =
                  newNotification['title']?.toString().trim().isNotEmpty == true
                  ? newNotification['title'].toString().trim()
                  : 'New notification';
              final message =
                  newNotification['message']?.toString().trim().isNotEmpty ==
                      true
                  ? newNotification['message'].toString().trim()
                  : 'You have a new update.';

              NotificationPermissionService().showBrowserNotification(
                title: title,
                body: message,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title\n$message'),
                  backgroundColor: AppColors.primary,
                  duration: const Duration(seconds: 3),
                ),
              );
              _maybeShowRestrictionNotification();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('âš ï¸ Error setting up notifications listener: $e');
    }
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

  void _handleApplyVehicleNavigation() {
    if (_isPartnerVerified) {
      Navigator.pushNamed(context, '/apply-vehicle');
      return;
    }

    _showErrorSnackBar(
      'Complete your verification first before applying a vehicle.',
    );
    Navigator.pushNamed(context, '/identity-verification-form');
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoading &&
        (_restrictionState.isAccountRestricted ||
            _restrictionState.isBlocked)) {
      return _buildRestrictedScaffold();
    }

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
            label: 'Notifications',
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

  Scaffold _buildRestrictedScaffold() {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Account Restricted',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                height: 238,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF243A2C), Color(0xFF1E2A33)],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 180,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_rounded,
                      color: Colors.white70,
                      size: 62,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  color: Color(0xFF3A3120),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Your account is\ntemporarily restricted',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _restrictionState.isBlocked
                    ? 'For safety reasons and due to repeated policy violations, this owner account has been permanently blocked from messaging and bookings.'
                    : 'For safety reasons and due to a policy violation, this owner account cannot accept new messages or bookings during the restriction period.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF10243A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(
                      _restrictionState.isBlocked
                          ? 'ACCOUNT STATUS'
                          : 'AVAILABLE AGAIN IN',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_restrictionState.isBlocked)
                      const Text(
                        'PERMANENTLY BLOCKED',
                        style: TextStyle(
                          color: Color(0xFFFF5B5B),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      RestrictionCountdownRow(
                        until: _restrictionState.activeUntil,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => showPolicyDetailsSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF083562),
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'View Policy Details',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _contactSupport,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Contact Support',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Learn more about our Community Guidelines',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
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
                      _handleApplyVehicleNavigation();
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
                      _showRatesReviewsDialog();
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
                        partnerName.isNotEmpty
                            ? partnerName[0].toUpperCase()
                            : 'P',
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
                          _getPartnerBadge(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getPartnerBadgeColor(),
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
        color: isSelected
            ? AppColors.primary.withAlpha(30)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color:
              iconColor ??
              (isSelected ? AppColors.primary : AppColors.textSecondary),
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color:
                labelColor ??
                (isSelected ? AppColors.primary : AppColors.textPrimary),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  String _getPartnerBadge() {
    if (_isPartnerCertified) {
      return 'CERTIFIED PSDC PARTNER';
    } else if (_isPartnerVerified) {
      return 'VERIFIED PARTNER';
    } else {
      return 'BASIC PARTNER';
    }
  }

  Color _getPartnerBadgeColor() {
    if (_isPartnerCertified) {
      return const Color(0xFF6366F1); // Indigo for certified
    } else if (_isPartnerVerified) {
      return AppColors.success;
    } else {
      return AppColors.warning;
    }
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
          if (!_isPartnerVerified && !dismissedVerificationBanner)
            _buildVerificationBanner(),

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
                      onTap: _handleApplyVehicleNavigation,
                    ),
                    const SizedBox(width: 12),
                    _buildQuickAction(
                      icon: Icons.directions_car,
                      label: 'Manage Fleet',
                      onTap: () =>
                          Navigator.pushNamed(context, '/vehicle-availability'),
                    ),
                    const SizedBox(width: 12),
                    _buildQuickAction(
                      icon: Icons.bar_chart,
                      label: 'View Revenue',
                      onTap: _openRevenuePayoutScreen,
                    ),
                    const SizedBox(width: 12),
                    _buildQuickAction(
                      icon: Icons.star_rate,
                      label: 'Rates & Reviews',
                      onTap: _showRatesReviewsDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Start Application Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStartApplicationAd(),
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
                    if (_isPartnerVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              color: AppColors.success,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _isPartnerCertified ? 'CERTIFIED' : 'VERIFIED',
                              style: const TextStyle(
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
                if (notifications
                    .where((n) => n['is_read'] == false)
                    .isNotEmpty)
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      'Complete Verification',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                    Text(
                      'Unlock full features and build trust with renters',
                      style: TextStyle(
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      dismissedVerificationBanner = true;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.warning.withAlpha(50)),
                  ),
                  child: const Text(
                    'Later',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/identity-verification-form',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Verify Now',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
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
                Text(
                  _isPartnerCertified
                      ? 'Certified Partner'
                      : 'Verified Partner',
                  style: const TextStyle(
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
        child: SizedBox(
          height: 86,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(height: 10),
                SizedBox(
                  height: 14,
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartApplicationAd() {
    final hasPendingApplication = applications.any((application) {
      final status =
          (application['application_status'] ?? application['status'] ?? '')
              .toString()
              .toLowerCase();
      return status == 'pending' || status == 'under_review';
    });

    return GestureDetector(
      onTap: hasPendingApplication
          ? () => setState(() => selectedNavIndex = 0)
          : _handleApplyVehicleNavigation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF06233A), Color(0xFF0B3146)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withAlpha(55)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasPendingApplication
                    ? Icons.hourglass_bottom
                    : Icons.handshake,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPendingApplication
                        ? 'Application Under Review'
                        : 'Start Vehicle Application',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasPendingApplication
                        ? 'You can apply again after this request is reviewed.'
                        : 'List your next vehicle and send it for approval.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasPendingApplication ? 'Status' : 'Start',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatesReviewsDialog() {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingsReviewsScreen(
          userId: userId,
          title: 'Partner Ratings & Reviews',
        ),
      ),
    );
  }

  void _contactSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Support has been notified. Please wait for a follow-up.',
        ),
      ),
    );
  }

  Future<void> _maybeShowRestrictionNotification() async {
    for (final notification in notifications) {
      final notificationId = notification['id']?.toString();
      final type = notification['type']?.toString().trim().toLowerCase();
      final data = notification['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(notification['data'])
          : <String, dynamic>{};

      if (notificationId == null ||
          _shownRestrictionNotificationIds.contains(notificationId) ||
          type != 'policy_restriction' ||
          data['event']?.toString() != 'booking_void') {
        continue;
      }

      _shownRestrictionNotificationIds.add(notificationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restriction notice added to your notifications'),
          backgroundColor: AppColors.warning,
        ),
      );
      break;
    }
  }

  Future<void> _showBookingVoidDialog(Map<String, dynamic> notification) async {
    final notificationId = notification['id']?.toString();
    final data = notification['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(notification['data'])
        : <String, dynamic>{};
    final affectedBookings = (data['affected_bookings'] as num?)?.toInt() ?? 0;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2134),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  ),
                  const Expanded(
                    child: Text(
                      'Important Safety Update',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4B2430),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFFF7B7B),
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Booking Cancelled',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your account has been suspended from booking activity for violating our Community Guidelines. For safety, ${affectedBookings <= 0 ? 'affected bookings' : '$affectedBookings active booking${affectedBookings == 1 ? '' : 's'}'} are no longer active.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF112A43),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A3D72),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Refund Initiated',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'The renter reservation fee is being returned to their E-wallet.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.circle,
                      color: Colors.greenAccent,
                      size: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showPolicyDetailsSheet(this.context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF083562),
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.policy_outlined, size: 18),
                  label: const Text(
                    'View Policy Details',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _contactSupport();
                },
                child: const Center(
                  child: Text(
                    'Contact Support',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (notificationId != null) {
      await NotificationService().markAsRead(notificationId);
      if (!mounted) return;
      setState(() {
        final index = notifications.indexWhere(
          (item) => item['id']?.toString() == notificationId,
        );
        if (index != -1) {
          notifications[index] = {...notifications[index], 'is_read': true};
        }
      });
    }
  }

  void _openRevenuePayoutScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerRevenueScreen(
          partnerName: partnerName,
          bookings: bookings,
          completedTrips: bookingCounts['completed'] ?? 0,
          recordedTotalEarnings: totalEarnings,
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
                  Icon(
                    Icons.calendar_today,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No booking requests yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...bookings
              .take(3)
              .map((booking) => _buildBookingRequestCard(booking)),
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
                child: Image.asset(
                  'assets/icon/logo1.png',
                  fit: BoxFit.contain,
                ),
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
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateRange(
                        booking['start_date'],
                        booking['end_date'],
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Booking Period',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
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
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
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
                    onPressed: () =>
                        _handleBookingAction(booking['id'], 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.textSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleBookingAction(booking['id'], 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
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
      final months = [
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
      return '${months[start.month - 1]} ${start.day}-${end.day}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _handleBookingAction(String bookingId, String status) async {
    try {
      final bookingService = BookingService();
      await bookingService.updateBookingStatus(bookingId, status);
      _showSuccessSnackBar(
        status == 'confirmed' ? 'Booking accepted!' : 'Booking declined',
      );
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
                'Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              if (notifications.isNotEmpty)
                GestureDetector(
                  onTap: _markAllNotificationsRead,
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
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
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: AppColors.textTertiary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
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
                'Messages',
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
          child: conversations.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: AppColors.textTertiary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    final messages = conv['messages'] as List<dynamic>? ?? [];
                    final lastMessage = messages.isNotEmpty
                        ? messages.last['content'] ?? ''
                        : 'No messages';

                    return ConversationTile(
                      senderName: 'Renter',
                      lastMessage: lastMessage,
                      timestamp: _formatTime(conv['updated_at']),
                      unreadCount: 0,
                      onTap: () {
                        final conversationId = conv['id'];
                        Navigator.of(context).pushNamed(
                          '/chat-detail',
                          arguments: {
                            'conversationId': conversationId,
                            'recipientName': 'Renter',
                            'recipientAvatar': '',
                            'isDarkMode': false,
                          },
                        );
                      },
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
          color: const Color(0xFF131E2D),
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            12,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: const Icon(
                  Icons.menu,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
              const Spacer(),
              const Text(
                'Ongoing Bookings',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => selectedNavIndex = 1),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    if (notifications.any((item) => item['is_read'] != true))
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
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
                  color: const Color(0xFF131E2D),
                  child: TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: const Color(0xFF98A4B7),
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Pending'),
                      Tab(text: 'Active'),
                      Tab(text: 'Past'),
                      Tab(text: 'Cancelled'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBookingsList('pending'),
                      _buildBookingsList('active'),
                      _buildBookingsList('past'),
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

  Widget _buildBookingsList(String tabKey) {
    final filteredBookings = bookings
        .where((booking) => _matchesBookingTab(booking, tabKey))
        .toList();

    filteredBookings.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['start_at']?.toString() ?? '') ??
          DateTime.tryParse(a['start_date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          DateTime.tryParse(b['start_at']?.toString() ?? '') ??
          DateTime.tryParse(b['start_date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });

    if (filteredBookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadPartnerData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 56,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No ${_bookingTabLabel(tabKey).toLowerCase()} bookings',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadPartnerData();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (tabKey == 'active') _buildActiveBookingsHero(filteredBookings),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: filteredBookings
                  .map(
                    (booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildPartnerBookingCard(
                        booking,
                        emphasizeLive: tabKey == 'active',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBookingsHero(List<Map<String, dynamic>> filteredBookings) {
    final liveCount = filteredBookings
        .where((booking) => _trackingForBooking(booking) != null)
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: const BoxDecoration(color: Color(0xFF0D2A1F)),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Ongoing Rentals',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF173A2E),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${liveCount == 0 ? filteredBookings.length : liveCount} Live',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerBookingCard(
    Map<String, dynamic> booking, {
    bool emphasizeLive = false,
  }) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['users'] as Map<String, dynamic>?;
    final tracking = _trackingForBooking(booking);
    final renterName =
        renter?['full_name']?.toString().trim().isNotEmpty == true
        ? renter!['full_name'].toString().trim()
        : 'Unknown Renter';
    final vehicleTitle =
        [vehicle?['vehicle_name'], vehicle?['brand'], vehicle?['model']]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .join(' ');
    final bookingStatus = _bookingStatusLabel(booking, tracking);
    final dateRange = _formatBookingRange(
      booking['start_at']?.toString() ?? booking['start_date']?.toString(),
      booking['end_at']?.toString() ?? booking['end_date']?.toString(),
    );
    final locationLabel =
        (booking['dropoff_location']?.toString().trim().isNotEmpty == true)
        ? booking['dropoff_location'].toString().trim()
        : booking['pickup_location']?.toString().trim().isNotEmpty == true
        ? booking['pickup_location'].toString().trim()
        : 'Location not set';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF132A42),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: emphasizeLive && tracking != null
              ? const Color(0xFF204B6B)
              : const Color(0xFF1D3A58),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE8E0C0),
                child: Text(
                  _initialsForName(renterName),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      renterName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: vehicleTitle.isEmpty
                                ? 'Vehicle'
                                : vehicleTitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: ' - $bookingStatus',
                            style: TextStyle(
                              color: _bookingStatusColor(bookingStatus),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'RENTAL PERIOD',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateRange,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (emphasizeLive && tracking != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF32586F),
                    Color(0xFF3E6A85),
                    Color(0xFF173850),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.black,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          locationLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showBookingDetailModal(context, booking),
              icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
              label: const Text('View Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openTrackingScreen(booking),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Track'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: tracking != null
                          ? const Color(0xFF4172A0)
                          : const Color(0xFF2C5379),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openBookingConversation(booking),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: Color(0xFF2C5379)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _matchesBookingTab(Map<String, dynamic> booking, String tabKey) {
    final status = (booking['status']?.toString() ?? '').toLowerCase();
    switch (tabKey) {
      case 'pending':
        return status == 'pending';
      case 'active':
        return status == 'active' ||
            status == 'approved' ||
            status == 'confirmed';
      case 'past':
        return status == 'completed';
      case 'cancelled':
        return status == 'cancelled' ||
            status == 'canceled' ||
            status == 'rejected';
      default:
        return false;
    }
  }

  String _bookingTabLabel(String tabKey) {
    switch (tabKey) {
      case 'pending':
        return 'Pending';
      case 'active':
        return 'Active';
      case 'past':
        return 'Past';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Bookings';
    }
  }

  Map<String, dynamic>? _trackingForBooking(Map<String, dynamic> booking) {
    final bookingId = booking['id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return null;
    for (final location in trackingLocations) {
      if (location['booking_id']?.toString() == bookingId) {
        return location;
      }
    }
    return null;
  }

  String _bookingStatusLabel(
    Map<String, dynamic> booking,
    Map<String, dynamic>? tracking,
  ) {
    final status = (booking['status']?.toString() ?? '').toLowerCase();
    if (tracking != null) {
      final speed =
          ((tracking['speed_mps'] as num?)?.toDouble() ?? 0) * 2.23694;
      return speed > 4 ? 'In Transit' : 'Parked';
    }
    switch (status) {
      case 'approved':
      case 'confirmed':
        return 'Ongoing';
      case 'active':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Color _bookingStatusColor(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('transit') || normalized.contains('ongoing')) {
      return AppColors.primary;
    }
    if (normalized.contains('park') || normalized.contains('approved')) {
      return AppColors.success;
    }
    if (normalized.contains('cancel') || normalized.contains('reject')) {
      return AppColors.error;
    }
    return AppColors.textSecondary;
  }

  String _formatBookingRange(String? startRaw, String? endRaw) {
    final start = DateTime.tryParse(startRaw ?? '')?.toLocal();
    final end = DateTime.tryParse(endRaw ?? '')?.toLocal();
    if (start == null || end == null) return 'Dates unavailable';
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
    return '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}';
  }

  String _initialsForName(String name) {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'P';
    return parts.map((part) => part.trim()[0].toUpperCase()).join();
  }

  Future<void> _openBookingConversation(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final renter = booking['users'] as Map<String, dynamic>?;
    final renterId =
        renter?['id']?.toString() ?? booking['renter_id']?.toString() ?? '';
    final renterName = renter?['full_name']?.toString() ?? 'Booking Chat';

    if (bookingId.isEmpty) {
      _showErrorSnackBar('Booking conversation is unavailable');
      return;
    }

    try {
      final chatService = ChatService();
      var conversation = await chatService.getConversationByBookingId(
        bookingId,
      );

      if (conversation == null && partnerId != null && renterId.isNotEmpty) {
        conversation = await chatService.createGroupConversation(
          bookingId: bookingId,
          participantIds: [partnerId!, renterId],
        );
      }

      final conversationId = conversation?['id']?.toString() ?? '';
      if (conversationId.isEmpty) {
        _showErrorSnackBar('No conversation found for this booking');
        return;
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/chat-detail',
        arguments: {
          'conversationId': conversationId,
          'recipientName': renterName,
          'recipientAvatar': '',
          'isDarkMode': true,
          'isAutoGenerated': true,
        },
      );
    } catch (e) {
      _showErrorSnackBar('Failed to open booking conversation');
    }
  }

  Future<void> _openTrackingScreen(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      _showErrorSnackBar('Tracking is unavailable for this booking');
      return;
    }

    try {
      final chatService = ChatService();
      var conversation = await chatService.getConversationByBookingId(
        bookingId,
      );
      final renter = booking['users'] as Map<String, dynamic>?;
      final renterId =
          renter?['id']?.toString() ?? booking['renter_id']?.toString() ?? '';
      final renterName = renter?['full_name']?.toString() ?? 'Renter';

      if (conversation == null && partnerId != null && renterId.isNotEmpty) {
        conversation = await chatService.createGroupConversation(
          bookingId: bookingId,
          participantIds: [partnerId!, renterId],
        );
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PartnerTrackingScreen(
            booking: booking,
            conversationId: conversation?['id']?.toString() ?? '',
            recipientName: renterName,
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to open live tracker');
    }
  }

  /// 🎯 Show booking detail modal with approve/reject and driver assignment
  void _showBookingDetailModal(
    BuildContext context,
    Map<String, dynamic> booking,
  ) {
    final parentContext = context;
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['users'] as Map<String, dynamic>?;
    final withDriver = _bookingNeedsDriver(booking['with_driver']);
    final driverId = booking['driver_id'];
    final status = (booking['status'] as String? ?? 'pending').toLowerCase();
    final canAssignDriver =
        withDriver &&
        driverId == null &&
        (status == 'pending' || status == 'approved' || status == 'confirmed');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBgSecondary
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BookingDetailModal(
        booking: booking,
        vehicle: vehicle,
        renter: renter,
        onApprove: () => _handleBookingApproval(context, booking),
        onReject: () => _handleBookingRejection(context, booking),
        onAssignDriver: canAssignDriver
            ? () => _showDriverAssignmentModal(context, booking)
            : null,
        onRateTrip: status == 'completed'
            ? () async {
                try {
                  await BookingService().confirmSuccessfulTrip(
                    bookingId: booking['id'].toString(),
                    actorRole: 'partner',
                  );
                  if (!mounted) return;
                  Navigator.of(parentContext).push(
                    MaterialPageRoute(
                      builder: (_) => TripRatingFlowScreen(
                        bookingId: booking['id'].toString(),
                        reviewerRole: 'partner',
                        subtitle:
                            'Leave ratings for the renter, operator, and driver if applicable.',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            : null,
      ),
    );
  }

  /// 🚗 Show driver assignment modal for bookings with drivers
  void _showDriverAssignmentModal(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final bookingService = BookingService();

    try {
      final drivers = await bookingService.getAvailableVerifiedDrivers();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assign Driver'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: drivers.isEmpty ? 1 : drivers.length,
              itemBuilder: (context, index) {
                if (drivers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No available verified drivers found.'),
                  );
                }
                final driver = drivers[index];
                final driverUser = driver['users'] as Map<String, dynamic>?;
                return ListTile(
                  title: Text(
                    driverUser?['full_name']?.toString() ?? 'Unknown Driver',
                  ),
                  onTap: () async {
                    Navigator.pop(context);

                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      await bookingService.assignDriver(
                        booking['id'],
                        driver['id'],
                        0.0, // Trip fee - can be customized
                      );

                      Navigator.pop(context); // Close loading dialog

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Driver assigned successfully'),
                          ),
                        );

                        // Reload bookings
                        _loadPartnerData();
                        Navigator.pop(context); // Close modal
                      }
                    } catch (e) {
                      Navigator.pop(context); // Close loading dialog

                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
                      }
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading drivers: $e')));
      }
    }
  }

  /// ✅ Approve booking
  Future<void> _handleBookingApproval(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final bookingService = BookingService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await bookingService.updateBookingStatus(booking['id'], 'approved');

      Navigator.pop(context); // Close loading dialog

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Booking approved')));

        // Reload bookings
        _loadPartnerData();
        Navigator.pop(context); // Close modal
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    }
  }

  /// ❌ Reject booking
  Future<void> _handleBookingRejection(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final bookingService = BookingService();

    // Show reason dialog
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                await bookingService.rejectBooking(
                  booking['id'],
                  reasonController.text,
                );

                Navigator.pop(context); // Close loading dialog

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Booking rejected')),
                  );

                  // Reload bookings
                  _loadPartnerData();
                  Navigator.pop(context); // Close modal
                }
              } catch (e) {
                Navigator.pop(context); // Close loading dialog

                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
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
                'Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Icon(
                  Icons.settings,
                  color: Colors.black,
                  size: 22,
                ),
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
                            partnerName.isNotEmpty
                                ? partnerName[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        partnerName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isPartnerVerified ? Icons.verified : Icons.pending,
                            color: _isPartnerVerified
                                ? AppColors.success
                                : AppColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getPartnerBadge(),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getPartnerBadgeColor(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildProfileStat(
                              'Vehicles',
                              activeVehicles.toString(),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.borderColor,
                          ),
                          Expanded(
                            child: _buildProfileStat(
                              'Bookings',
                              bookingCounts['total']?.toString() ?? '0',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.borderColor,
                          ),
                          Expanded(
                            child: _buildProfileStat(
                              'Rating',
                              rating > 0 ? rating.toStringAsFixed(1) : '-',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Menu Items
                _buildProfileMenuItem(
                  Icons.person_outline,
                  'Edit Profile',
                  onTap: () {},
                ),
                _buildProfileMenuItem(
                  Icons.security,
                  'Verification',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/identity-verification-form',
                  ),
                ),
                _buildProfileMenuItem(
                  Icons.account_balance_wallet,
                  'Payment Settings',
                  onTap: () {},
                ),
                _buildProfileMenuItem(
                  Icons.help_outline,
                  'Help & Support',
                  onTap: () {},
                ),
                _buildProfileMenuItem(
                  Icons.logout,
                  'Logout',
                  iconColor: AppColors.error,
                  onTap: _handleLogout,
                ),
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildProfileMenuItem(
    IconData icon,
    String label, {
    Color? iconColor,
    required VoidCallback onTap,
  }) {
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
      case 'announcement':
        return Icons.campaign;
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
      case 'announcement':
        return AppColors.primary;
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
        title: const Text(
          'Logout',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/auth-processing',
                  (route) => false,
                  arguments: {'mode': 'logout'},
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Get remaining time for cancellation window (returns formatted string + breakdown)
  Map<String, dynamic> _getRemainingCancelTime(Map<String, dynamic> booking) {
    try {
      final createdAtStr = booking['created_at']?.toString();
      if (createdAtStr == null) {
        return {
          'canCancel': false,
          'hours': 0,
          'minutes': 0,
          'remainingTime': 'Unknown',
          'isExpired': true,
        };
      }

      final createdAt = DateTime.parse(createdAtStr);
      final now = DateTime.now();
      final difference = now.difference(createdAt);

      // 24 hours = 1440 minutes
      final totalMinutesAllowed = 24 * 60;
      final minutesElapsed = difference.inMinutes;
      final minutesRemaining = totalMinutesAllowed - minutesElapsed;

      final hoursRemaining = minutesRemaining ~/ 60;
      final minRemaining = minutesRemaining % 60;

      final canCancel = minutesRemaining > 0;
      final remainingTimeStr = canCancel
          ? '${hoursRemaining}h ${minRemaining}m remaining'
          : 'Expired';

      return {
        'canCancel': canCancel,
        'hours': hoursRemaining,
        'minutes': minRemaining,
        'remainingTime': remainingTimeStr,
        'isExpired': !canCancel,
      };
    } catch (e) {
      debugPrint('Error checking cancellation time: $e');
      return {
        'canCancel': false,
        'hours': 0,
        'minutes': 0,
        'remainingTime': 'Error',
        'isExpired': true,
      };
    }
  }
}

/// 🎯 Booking Detail Modal Widget
class BookingDetailModal extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? vehicle;
  final Map<String, dynamic>? renter;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onAssignDriver;
  final VoidCallback? onRateTrip;

  const BookingDetailModal({
    super.key,
    required this.booking,
    this.vehicle,
    this.renter,
    required this.onApprove,
    required this.onReject,
    this.onAssignDriver,
    this.onRateTrip,
  });

  @override
  Widget build(BuildContext context) {
    final startDate = booking['start_date'] ?? '';
    final endDate = booking['end_date'] ?? '';
    final totalPrice = booking['total_price'] ?? 0;
    final withDriver = _bookingNeedsDriver(booking['with_driver']);
    final driverId = booking['driver_id'];
    final status = (booking['status'] as String? ?? 'pending').toLowerCase();

    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Booking Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vehicle Info
            if (vehicle != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkBgTertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Year: ${vehicle?['year'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Renter Info
            if (renter != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkBgTertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Renter',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      renter?['full_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      renter?['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Dates
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBgTertiary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rental Period',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'From',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              startDate.split('T')[0],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'To',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              endDate.split('T')[0],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Price
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBgTertiary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Price',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '₱${totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Driver Assignment Section
            if (withDriver) ...[
              if (driverId == null &&
                  (status == 'pending' ||
                      status == 'approved' ||
                      status == 'confirmed')) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(25),
                    border: Border.all(color: AppColors.warning),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_car,
                            color: AppColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Driver Required',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onAssignDriver,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Assign Driver',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (driverId != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    border: Border.all(color: AppColors.success),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Driver Assigned',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // Action Buttons
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onReject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Approve',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'completed' && onRateTrip != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onRateTrip?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.star_rate_rounded, size: 18),
                  label: const Text(
                    'Successful Trips',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
