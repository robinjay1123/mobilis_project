import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../services/auth_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/booking_receipt_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/driver_service.dart';
import '../../../services/notification_permission_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../services/tracking_service.dart';
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/role_ui.dart';
import '../../widgets/optimized_network_image.dart';
import '../../widgets/dialog_status_indicator.dart';
import '../../widgets/relative_time_text.dart';
import '../../widgets/booking_return_countdown.dart';
import '../profile/ratings_reviews_screen.dart';
import '../profile/trip_rating_flow_screen.dart';
import '../profile/unified_profile_screen.dart';
import '../tracking/trip_navigation_screen.dart';
import '../../../services/trip_rating_service.dart';
import '../../../utils/notification_target.dart';
import '../../../utils/notification_visual.dart';

class DriverHomeScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const DriverHomeScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

bool _driverIsDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _driverPageColor(BuildContext context) =>
    _driverIsDark(context) ? const Color(0xFF07111D) : const Color(0xFFF4F7FB);

Color _driverCardColor(BuildContext context) =>
    _driverIsDark(context) ? const Color(0xFF0C1B2A) : Colors.white;

Color _driverBorderColor(BuildContext context) =>
    _driverIsDark(context) ? const Color(0xFF173651) : const Color(0xFFD8E0EA);

Color _driverPrimaryText(BuildContext context) =>
    _driverIsDark(context) ? AppColors.textPrimary : AppColors.lightTextPrimary;

Color _driverSecondaryText(BuildContext context) => _driverIsDark(context)
    ? const Color(0xFF9DAEC4)
    : AppColors.lightTextSecondary;

Future<String?> _loadDriverAvatarUrl(String? userId) async {
  if (userId == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('users')
        .select('avatar_url, profile_picture_url')
        .eq('id', userId)
        .maybeSingle();
    final url = (row?['avatar_url'] ?? row?['profile_picture_url'])
        ?.toString()
        .trim();
    return url == null || url.isEmpty ? null : url;
  } catch (e) {
    debugPrint('Driver avatar lookup skipped: $e');
  }

  final metadata = AuthService().currentUser?.userMetadata ?? {};
  final metadataUrl =
      (metadata['avatar_url'] ?? metadata['profile_picture_url'] ?? '')
          .toString()
          .trim();
  return metadataUrl.isEmpty ? null : metadataUrl;
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<_NotificationsTabState> _notificationsKey =
      GlobalKey<_NotificationsTabState>();
  int _selectedTab = 0;
  bool _dimCustomerServiceFab = false;
  int _bookingActionCount = 0;
  int _unreadMessageCount = 0;
  int _unreadNotificationCount = 0;
  DateTime? _lastBackPressedAt;
  late Future<String?> _drawerAvatarFuture;
  StreamSubscription<Map<String, dynamic>>? _pushNotificationTapSubscription;

  @override
  void initState() {
    super.initState();
    _drawerAvatarFuture = _loadDriverAvatarUrl(AuthService().currentUser?.id);
    _loadDriverActivityCounts();
    final pushService = PushNotificationService();
    _pushNotificationTapSubscription = pushService.notificationTaps.listen(
      _handlePushNotificationTap,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = pushService.takePendingNotificationTap();
      if (pending != null && mounted) _handlePushNotificationTap(pending);
    });
  }

  @override
  void dispose() {
    _pushNotificationTapSubscription?.cancel();
    super.dispose();
  }

  void _handlePushNotificationTap(Map<String, dynamic> notification) {
    if (!mounted) return;
    final target = resolveNotificationTarget(notification);
    switch (target.destination) {
      case NotificationDestination.messages:
        final conversationId = target.conversationId;
        if (conversationId == null) {
          setState(() => _selectedTab = 2);
        } else {
          Navigator.pushNamed(
            context,
            '/chat-detail',
            arguments: {
              'conversationId': conversationId,
              'recipientName':
                  notification['title']?.toString() ?? 'Conversation',
              'recipientAvatar': '',
              'isAutoGenerated': false,
              'userRole': 'driver',
            },
          );
        }
        return;
      case NotificationDestination.booking:
      case NotificationDestination.tracking:
        setState(() => _selectedTab = 1);
        return;
      case NotificationDestination.application:
      case NotificationDestination.vehicles:
        _openDriverApplication();
        return;
      case NotificationDestination.verification:
        Navigator.pushNamed(
          context,
          '/driver-identity-verification',
          arguments: {
            if (target.data['document_type']?.toString() == 'driver_license')
              'mode': 'renewal',
          },
        );
        return;
      case NotificationDestination.ratings:
        _openDriverRatings();
        return;
      case NotificationDestination.payment:
        setState(() => _selectedTab = 5);
        return;
      case NotificationDestination.announcement:
      case NotificationDestination.general:
        setState(() => _selectedTab = 3);
        return;
    }
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/auth-processing',
        (route) => false,
        arguments: {'mode': 'logout'},
      );
    }
  }

  void _refreshDriverAvatar() {
    setState(() {
      _drawerAvatarFuture = _loadDriverAvatarUrl(AuthService().currentUser?.id);
    });
  }

  Future<void> _loadDriverActivityCounts() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        DriverService().getPendingOffers(user.id),
        ChatService().getConversations(user.id),
        NotificationService().getNotifications(user.id),
      ]);
      final offers = results[0];
      final conversations = results[1];
      final notifications = results[2];
      final unreadMessages = conversations.fold<int>(0, (total, conversation) {
        final messages = List<Map<String, dynamic>>.from(
          conversation['messages'] as List? ?? const [],
        );
        return total +
            messages.where((message) {
              return message['sender_id']?.toString() != user.id &&
                  message['is_read'] != true &&
                  message['is_deleted'] != true;
            }).length;
      });

      if (!mounted) return;
      setState(() {
        _bookingActionCount = offers.length;
        _unreadMessageCount = unreadMessages;
        _unreadNotificationCount = notifications
            .where((notification) => notification['is_read'] != true)
            .length;
      });
    } catch (error) {
      debugPrint('Could not load driver navigation activity: $error');
    }
  }

  Future<void> _openCustomerServiceConversation() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final conversation = await ChatService()
          .getOrCreateCustomerServiceConversation(
            userId: user.id,
            userName: user.userMetadata?['full_name']?.toString(),
            userRole: 'driver',
          );

      final conversationId = conversation['id']?.toString() ?? '';
      if (conversationId.isEmpty || !mounted) return;

      Navigator.pushNamed(
        context,
        '/chat-detail',
        arguments: {
          'conversationId': conversationId,
          'recipientName': 'Customer Service',
          'isAutoGenerated': false,
          'isCustomerService': true,
          'userRole': 'driver',
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open customer service chat: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openDriverApplication() {
    Navigator.pushNamed(context, '/driver-identity-verification');
  }

  void _openDriverRatings() {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingsReviewsScreen(
          userId: userId,
          title: 'Driver Ratings & Reviews',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _driverPageColor(context),
        drawer: _buildDriverDrawer(context),
        floatingActionButton: AnimatedOpacity(
          opacity: _dimCustomerServiceFab ? 0.5 : 1,
          duration: const Duration(milliseconds: 140),
          child: FloatingActionButton(
            heroTag: 'customer_service_driver',
            onPressed: _openCustomerServiceConversation,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            tooltip: 'Customer Service',
            child: const Icon(Icons.support_agent),
          ),
        ),
        body: Column(
          children: [
            if (_selectedTab != 0 && _selectedTab != 4)
              RolePageHeader(
                title: _appBarTitle,
                trailing: _selectedTab == 3
                    ? TextButton(
                        onPressed: () =>
                            _notificationsKey.currentState?.markAllAsRead(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : null,
              ),
            Expanded(
              child: _selectedTab == 0
                  ? SafeArea(
                      bottom: false,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: _buildSelectedContent(),
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: _handleScrollNotification,
                      child: _buildSelectedContent(),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: RoleBottomNavigation(
          currentIndex: _bottomNavIndex,
          badgeCounts: {
            1: _bookingActionCount,
            2: _unreadMessageCount,
            3: _unreadNotificationCount,
          },
          onTap: (index) {
            setState(() => _selectedTab = index);
            _loadDriverActivityCounts();
          },
        ),
      ),
    );
  }

  void _handleBackPressed() {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
      return;
    }

    if (_selectedTab != 0) {
      setState(() => _selectedTab = 0);
      return;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);

    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  int get _bottomNavIndex =>
      _selectedTab >= 0 && _selectedTab <= 4 ? _selectedTab : 0;

  String get _appBarTitle {
    switch (_selectedTab) {
      case 1:
        return 'My Bookings';
      case 2:
        return 'Messages';
      case 3:
        return 'Notifications';
      case 4:
        return 'Profile';
      case 5:
        return 'Earnings';
      case 6:
        return 'Availability';
      default:
        return 'Home';
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final shouldDim =
        notification is OverscrollNotification ||
        (notification.metrics.outOfRange &&
            notification is! ScrollEndNotification);
    if (_dimCustomerServiceFab != shouldDim) {
      setState(() => _dimCustomerServiceFab = shouldDim);
    }
    if (notification is ScrollEndNotification && _dimCustomerServiceFab) {
      setState(() => _dimCustomerServiceFab = false);
    }
    return false;
  }

  Widget _buildSelectedContent() {
    switch (_selectedTab) {
      case 1:
        return const _JobsTab();
      case 2:
        return const _DriverMessagesTab();
      case 3:
        return _NotificationsTab(
          key: _notificationsKey,
          onOpenBookings: () => setState(() => _selectedTab = 1),
          onOpenMessages: () => setState(() => _selectedTab = 2),
          onOpenEarnings: () => setState(() => _selectedTab = 5),
          onOpenApplication: _openDriverApplication,
          onOpenRatings: _openDriverRatings,
        );
      case 4:
        return _ProfileTab(
          onThemeToggle: widget.onThemeToggle,
          isDarkMode: widget.isDarkMode,
          onLogout: _handleLogout,
          onOpenSupport: _openCustomerServiceConversation,
          onOpenBookings: () => setState(() => _selectedTab = 1),
          onProfileUpdated: _refreshDriverAvatar,
        );
      case 5:
        return const _EarningsTab();
      case 6:
        return const _AvailabilityTab();
      default:
        return _DashboardTab(
          onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
          onOpenBookings: () => setState(() => _selectedTab = 1),
          onOpenMessages: () => setState(() => _selectedTab = 2),
          onOpenEarnings: () => setState(() => _selectedTab = 5),
          onOpenAvailability: () => setState(() => _selectedTab = 6),
          onOpenApplication: _openDriverApplication,
          onOpenRatings: _openDriverRatings,
        );
    }
  }

  Widget _buildDriverDrawer(BuildContext context) {
    final isDark = _driverIsDark(context);
    final user = AuthService().currentUser;
    final displayName =
        user?.userMetadata?['full_name']?.toString().trim().isNotEmpty == true
        ? user!.userMetadata!['full_name'].toString().trim()
        : user?.email?.split('@').first ?? 'Driver';
    final email = user?.email ?? 'driver account';

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF062A44) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 18, 18),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    child: FutureBuilder<String?>(
                      future: _drawerAvatarFuture,
                      builder: (context, snapshot) {
                        final avatarUrl = snapshot.data ?? '';
                        if (avatarUrl.isNotEmpty) {
                          return OptimizedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorWidget: _DriverInitial(
                              displayName: displayName,
                            ),
                          );
                        }
                        return _DriverInitial(displayName: displayName);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _driverPrimaryText(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _driverSecondaryText(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    _DriverDrawerItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      selected: _selectedTab == 0,
                      onTap: () => _selectDrawerTab(context, 0),
                    ),
                    _DriverDrawerItem(
                      icon: Icons.calendar_month_outlined,
                      label: 'Bookings',
                      selected: _selectedTab == 1,
                      onTap: () => _selectDrawerTab(context, 1),
                    ),
                    _DriverDrawerItem(
                      icon: Icons.assignment_turned_in_outlined,
                      label: 'Application',
                      selected: false,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/driver-identity-verification',
                        );
                      },
                    ),
                    _DriverDrawerItem(
                      icon: Icons.chat_bubble_outline,
                      label: 'Messages',
                      selected: _selectedTab == 2,
                      onTap: () => _selectDrawerTab(context, 2),
                    ),
                    _DriverDrawerItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      selected: _selectedTab == 3,
                      onTap: () => _selectDrawerTab(context, 3),
                    ),
                    _DriverDrawerItem(
                      icon: Icons.handshake_outlined,
                      label: 'Availability',
                      selected: _selectedTab == 6,
                      onTap: () => _selectDrawerTab(context, 6),
                    ),
                    _DriverDrawerItem(
                      icon: Icons.payments_outlined,
                      label: 'Revenue & Earnings',
                      selected: _selectedTab == 5,
                      onTap: () => _selectDrawerTab(context, 5),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Divider(color: _driverBorderColor(context)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 33,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.dark_mode,
                            color: _driverSecondaryText(context),
                            size: 20,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Dark Mode',
                              style: TextStyle(
                                color: _driverPrimaryText(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Switch(
                            value: widget.isDarkMode,
                            activeColor: AppColors.primary,
                            onChanged: (value) =>
                                widget.onThemeToggle?.call(value),
                          ),
                        ],
                      ),
                    ),
                    _DriverDrawerItem(
                      icon: Icons.star_rounded,
                      label: 'Reviews & Ratings',
                      selected: false,
                      onTap: () {
                        Navigator.pop(context);
                        final userId = AuthService().currentUser?.id;
                        if (userId == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RatingsReviewsScreen(
                              userId: userId,
                              title: 'Driver Ratings & Reviews',
                            ),
                          ),
                        );
                      },
                    ),
                    _DriverDrawerItem(
                      icon: Icons.settings,
                      label: 'Settings',
                      selected: _selectedTab == 4,
                      onTap: () => _selectDrawerTab(context, 4),
                    ),
                    _DriverDrawerItem(
                      icon: Icons.logout,
                      label: 'Logout',
                      color: const Color(0xFFFF6B77),
                      selected: false,
                      onTap: () {
                        Navigator.pop(context);
                        _handleLogout();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDrawerTab(BuildContext context, int tab) {
    Navigator.pop(context);
    setState(() => _selectedTab = tab);
  }
}

class _DriverDrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _DriverDrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor =
        color ?? (selected ? Colors.black : _driverPrimaryText(context));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, color: itemColor, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: itemColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverInitial extends StatelessWidget {
  final String displayName;
  final double fontSize;

  const _DriverInitial({required this.displayName, this.fontSize = 18});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
        style: TextStyle(
          color: const Color(0xFF062A44),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// DASHBOARD TAB
class _DashboardTab extends StatefulWidget {
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenEarnings;
  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenApplication;
  final VoidCallback onOpenRatings;

  const _DashboardTab({
    required this.onOpenMenu,
    required this.onOpenBookings,
    required this.onOpenMessages,
    required this.onOpenEarnings,
    required this.onOpenAvailability,
    required this.onOpenApplication,
    required this.onOpenRatings,
  });

  @override
  State<_DashboardTab> createState() => __DashboardTabState();
}

class __DashboardTabState extends State<_DashboardTab> {
  late Future<Map<String, dynamic>> driverStatsFuture;
  late Future<List<Map<String, dynamic>>> pendingOffersFuture;
  late Future<List<Map<String, dynamic>>> assignedBookingsFuture;
  late Future<String?> avatarUrlFuture;
  String verificationStatus = 'pending';
  String certificationStatus = 'basic'; // 'basic', 'approved', 'certified'
  bool hasPendingVerification = false;
  bool hasLoadedDriverStatus = false;
  bool dismissedVerificationBanner = false;
  int verificationSkipCount = 0; // Track how many times skipped
  RealtimeChannel? _jobFlowChannel;
  Timer? _jobFlowRefreshDebounce;

  @override
  void initState() {
    super.initState();
    final authService = AuthService();
    final driverService = DriverService();
    if (authService.currentUser != null) {
      driverStatsFuture = _loadDriverStats(
        driverService,
        authService.currentUser!.id,
      );
      pendingOffersFuture = driverService.getPendingOffers(
        authService.currentUser!.id,
      );
      assignedBookingsFuture = driverService.getAssignedBookings(
        authService.currentUser!.id,
      );
      avatarUrlFuture = _loadDriverAvatarUrl(authService.currentUser!.id);
      _setupJobFlowListener(authService.currentUser!.id);
    } else {
      driverStatsFuture = Future.value({});
      pendingOffersFuture = Future.value([]);
      assignedBookingsFuture = Future.value([]);
      avatarUrlFuture = Future.value(null);
    }
  }

  @override
  void dispose() {
    _jobFlowRefreshDebounce?.cancel();
    _jobFlowChannel?.unsubscribe();
    super.dispose();
  }

  void _setupJobFlowListener(String userId) {
    _jobFlowChannel = Supabase.instance.client.realtime.channel(
      'driver-job-flow-$userId',
    );
    void refreshFlow(PostgresChangePayload payload) {
      if (!mounted) return;
      _jobFlowRefreshDebounce?.cancel();
      _jobFlowRefreshDebounce = Timer(
        const Duration(milliseconds: 350),
        _refreshDriverData,
      );
    }

    _jobFlowChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_job_assignments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: userId,
          ),
          callback: refreshFlow,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: userId,
          ),
          callback: refreshFlow,
        )
        .subscribe();
  }

  void _refreshDriverData() {
    final userId = AuthService().currentUser?.id;
    setState(() {
      final driverService = DriverService();
      if (userId == null) {
        driverStatsFuture = Future.value({});
        pendingOffersFuture = Future.value([]);
        assignedBookingsFuture = Future.value([]);
        avatarUrlFuture = Future.value(null);
        hasLoadedDriverStatus = false;
      } else {
        hasLoadedDriverStatus = false;
        driverStatsFuture = _loadDriverStats(driverService, userId);
        pendingOffersFuture = driverService.getPendingOffers(userId);
        assignedBookingsFuture = driverService.getAssignedBookings(userId);
        avatarUrlFuture = _loadDriverAvatarUrl(userId);
      }
    });
  }

  Future<Map<String, dynamic>> _loadDriverStats(
    DriverService driverService,
    String userId,
  ) async {
    NotificationService()
        .checkAndNotifyExpiringDocuments(daysThreshold: 90)
        .catchError((error) {
          debugPrint('Driver expiry notification check skipped: $error');
          return 0;
        });
    final stats = await driverService.getDriverStats(userId);
    final verification = await VerificationService.getUserVerification(userId);
    final verificationRecordStatus =
        (verification?['verification_status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final nextVerificationStatus = _normalizeStatus(
      verificationRecordStatus.isNotEmpty
          ? verificationRecordStatus
          : (stats['verification_status'] ??
                stats['verification'] ??
                'pending'),
    );
    final certificationApplicationStatus = await driverService
        .getCertificationApplicationStatus(userId);
    final nextCertificationStatus = _normalizeStatus(
      certificationApplicationStatus.isNotEmpty
          ? certificationApplicationStatus
          : (stats['application_status'] ??
                stats['driver_application_status'] ??
                stats['driver_tier'] ??
                stats['tier'] ??
                'basic'),
      fallback: 'basic',
    );

    if (mounted) {
      setState(() {
        verificationStatus = nextVerificationStatus;
        certificationStatus = nextCertificationStatus;
        hasPendingVerification = verificationRecordStatus == 'pending';
        hasLoadedDriverStatus = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showVerificationPopupIfNeeded();
      });
    }

    return stats;
  }

  void _showVerificationPopupIfNeeded() {
    // Only show popup if not yet verified and skip count is less than 3
    // (shows popup every 3 times they skip)
    if (!_isVerified &&
        !hasPendingVerification &&
        verificationSkipCount % 3 == 0) {
      _showVerificationPopup();
    }
  }

  String _normalizeStatus(dynamic value, {String fallback = 'pending'}) {
    final status = value?.toString().trim().toLowerCase() ?? '';
    return status.isEmpty || status == 'null' ? fallback : status;
  }

  bool get _isVerified {
    return verificationStatus == 'verified' ||
        verificationStatus == 'approved' ||
        verificationStatus == 'certified';
  }

  bool get _isCertifiedDriver {
    return certificationStatus == 'certified' ||
        certificationStatus == 'approved';
  }

  void _showVerificationPopup() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.verified_user,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verify Your Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DialogStatusIndicator(
              isComplete: false,
              completeLabel: 'Verification complete',
              incompleteLabel: 'Verification required',
              incompleteDetail:
                  'Complete your identity verification to unlock driver features.',
            ),
            const SizedBox(height: 12),
            Text(
              'Get verified to unlock:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildVerificationBenefit(
              icon: Icons.trending_up,
              text: 'Higher visibility to customers',
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildVerificationBenefit(
              icon: Icons.shield,
              text: 'Build trust and credibility',
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildVerificationBenefit(
              icon: Icons.star,
              text: 'Access premium features',
              isDark: isDark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => verificationSkipCount++);
              Navigator.pop(context);
            },
            child: Text(
              'Skip for Now',
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver-identity-verification');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Verify Now',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBenefit({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String _displayName() {
    final user = AuthService().currentUser;
    final metadataName = user?.userMetadata?['full_name']?.toString().trim();
    if (metadataName != null && metadataName.isNotEmpty) return metadataName;
    return user?.email?.split('@').first ?? 'Driver';
  }

  double _numValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  Map<String, dynamic>? _activeBooking(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) return null;
    final preferredStatuses = {'active', 'ongoing', 'approved', 'confirmed'};
    for (final booking in bookings) {
      final status = booking['status']?.toString().toLowerCase();
      if (preferredStatuses.contains(status)) return booking;
    }
    return bookings.first;
  }

  String _bookingRenterName(Map<String, dynamic> booking) {
    final renter = booking['renter'];
    if (renter is Map) {
      final name = renter['full_name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      final email = renter['email']?.toString();
      if (email != null && email.isNotEmpty) return email.split('@').first;
    }
    return booking['renter_name']?.toString() ?? 'Renter';
  }

  String _bookingVehicleName(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'];
    if (vehicle is Map) {
      final vehicleName = vehicle['vehicle_name']?.toString().trim();
      if (vehicleName != null && vehicleName.isNotEmpty) return vehicleName;
      final brand = vehicle['brand']?.toString().trim() ?? '';
      final model = vehicle['model']?.toString().trim() ?? '';
      final combined = '$brand $model'.trim();
      if (combined.isNotEmpty) return combined;
    }
    return booking['vehicle_name']?.toString() ?? 'Assigned Vehicle';
  }

  String _bookingPickupLocation(Map<String, dynamic> booking) {
    final pickup = booking['pickup_location'] ?? booking['pickupLocation'];
    final value = pickup?.toString().trim();
    return value == null || value.isEmpty ? 'Pickup location pending' : value;
  }

  String _bookingStartLabel(Map<String, dynamic> booking) {
    final raw = booking['start_at'] ?? booking['start_date'];
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return 'Schedule pending';
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
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${months[parsed.month - 1]} ${parsed.day} • $hour:$minute $suffix';
  }

  Widget _buildHeader(Map<String, dynamic> stats) {
    final displayName = _displayName();
    final badge = _getDriverBadge();
    final badgeColor = _getDriverBadgeColor();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: widget.onOpenMenu,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFFFEDD6),
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<String?>(
                future: avatarUrlFuture,
                builder: (context, snapshot) {
                  final avatarUrl = snapshot.data ?? '';
                  if (avatarUrl.isNotEmpty) {
                    return OptimizedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorWidget: _DriverInitial(
                        displayName: displayName,
                        fontSize: 20,
                      ),
                    );
                  }
                  return _DriverInitial(displayName: displayName, fontSize: 20);
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _driverPrimaryText(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> stats) {
    final earnings = _numValue(stats, ['earnings', 'total_earnings']);
    final rating = _numValue(stats, ['rating', 'average_rating']);

    return Row(
      children: [
        Expanded(
          child: _DriverMetricCard(
            label: 'Earnings',
            value: earnings.toStringAsFixed(0),
            footer: 'EARNED',
            footerColor: const Color(0xFF48E0B5),
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DriverMetricCard(
            label: 'Rating',
            value: rating <= 0 ? '0.0' : rating.toStringAsFixed(1),
            footer: rating >= 4.7 ? 'TOP RATED' : 'BUILDING',
            footerColor: AppColors.primary,
            icon: Icons.star,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DriverMetricCard(
            label: 'Identity',
            value: '',
            footer: _isVerified ? 'VERIFIED' : 'PENDING',
            footerColor: _isVerified
                ? const Color(0xFF48E0B5)
                : AppColors.primary,
            icon: Icons.verified_user,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveBookingSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: assignedBookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _DriverLoadingCard(label: 'Loading active booking...');
        }

        final booking = _activeBooking(snapshot.data ?? []);
        if (booking == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _driverCardColor(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _driverBorderColor(context)),
            ),
            child: Text(
              'No active booking yet. New assigned trips will appear here.',
              style: TextStyle(
                color: _driverSecondaryText(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _driverCardColor(context),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _driverBorderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Next Pickup',
                          style: TextStyle(
                            color: Color(0xFF9DAEC4),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _bookingRenterName(booking),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Vehicle',
                        style: TextStyle(
                          color: Color(0xFF9DAEC4),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          _bookingVehicleName(booking),
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFF1B3047)),
              const SizedBox(height: 16),
              _DriverInfoLine(
                icon: Icons.calendar_month,
                text: _bookingStartLabel(booking),
              ),
              const SizedBox(height: 16),
              _DriverInfoLine(
                icon: Icons.location_on,
                text: _bookingPickupLocation(booking),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onOpenBookings,
                      icon: const Icon(Icons.navigation, color: Colors.black),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Navigate'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenMessages,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Message'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: Color(0xFF2F5D86)),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _DriverQuickActionCard(
          icon: Icons.calendar_month,
          label: 'Booking',
          onTap: widget.onOpenBookings,
        ),
        _DriverQuickActionCard(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Application',
          onTap: widget.onOpenApplication,
        ),
        _DriverQuickActionCard(
          icon: Icons.payments,
          label: 'Revenue',
          onTap: widget.onOpenEarnings,
        ),
        _DriverQuickActionCard(
          icon: Icons.star_outline_rounded,
          label: 'Review & Ratings',
          onTap: widget.onOpenRatings,
        ),
      ],
    );
  }

  bool _isCertifiedFromStats(Map<String, dynamic> stats) {
    final status = _normalizeStatus(
      stats['application_status'] ??
          stats['driver_application_status'] ??
          stats['driver_tier'] ??
          stats['tier'] ??
          certificationStatus,
      fallback: 'basic',
    );

    return status == 'approved' ||
        status == 'certified' ||
        status == 'verified';
  }

  bool _isVerifiedFromStats(Map<String, dynamic> stats) {
    final status = _normalizeStatus(
      stats['verification_status'] ??
          stats['verification'] ??
          verificationStatus,
    );

    return status == 'verified' ||
        status == 'approved' ||
        status == 'certified';
  }

  Widget _buildDriverApplicationCta(Map<String, dynamic> stats) {
    final isCertified = _isCertifiedFromStats(stats);
    final isVerified = _isVerifiedFromStats(stats);
    final title = isCertified
        ? 'Availability'
        : isVerified
        ? 'Apply as a Driver'
        : 'Start Driver Application';
    final subtitle = isCertified
        ? 'Set dates to receive trip offers.'
        : isVerified
        ? 'Submit your driver requirements and documents for final review.'
        : 'Complete identity verification and submit the documents needed to become a Mobilis driver.';
    final buttonLabel = isCertified ? 'Set' : 'Apply';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF082E49),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isCertified
                  ? Icons.handshake_outlined
                  : Icons.assignment_turned_in_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: isCertified
                ? widget.onOpenAvailability
                : widget.onOpenApplication,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondaryText = _driverSecondaryText(context);
    return RefreshIndicator(
      onRefresh: () async => _refreshDriverData(),
      color: AppColors.primary,
      backgroundColor: _driverCardColor(context),
      child: FutureBuilder<Map<String, dynamic>>(
        future: driverStatsFuture,
        builder: (context, snapshot) {
          final stats = snapshot.data ?? {};
          final statusLoaded =
              snapshot.connectionState == ConnectionState.done &&
              hasLoadedDriverStatus;
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            children: [
              _buildHeader(stats),
              const SizedBox(height: 16),
              _buildStats(stats),
              if (statusLoaded) ...[
                const SizedBox(height: 24),
                _buildDriverApplicationCta(stats),
                const SizedBox(height: 28),
              ] else
                const SizedBox(height: 24),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: pendingOffersFuture,
                builder: (context, offersSnapshot) {
                  final offers = offersSnapshot.data ?? const [];
                  if (offers.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JOB REQUESTS',
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 14,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...offers.map(
                        (offer) => _DriverOfferCard(
                          offer: offer,
                          onChanged: _refreshDriverData,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ACTIVE BOOKING',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 14,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: pendingOffersFuture,
                    builder: (context, offersSnapshot) {
                      final count = offersSnapshot.data?.length ?? 0;
                      return Container(
                        width: count > 0 ? null : 12,
                        height: count > 0 ? null : 12,
                        padding: count > 0
                            ? const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              )
                            : EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: count > 0
                              ? AppColors.primary
                              : const Color(0xFF12A37C),
                          borderRadius: count > 0
                              ? BorderRadius.circular(18)
                              : null,
                          shape: count > 0
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                        ),
                        child: count > 0
                            ? Text(
                                '$count requests',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildActiveBookingSection(),
              const SizedBox(height: 34),
              Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _buildQuickActions(),
            ],
          );
        },
      ),
    );
  }

  String? _getDriverBadge() {
    if (_isCertifiedDriver) {
      return 'Mobilis Certified Driver';
    }
    if (_isVerified) {
      return 'Basic Driver';
    }
    return null;
  }

  Color _getDriverBadgeColor() {
    if (_isCertifiedDriver) {
      return const Color.fromRGBO(16, 185, 129, 1); // Indigo for certified
    }
    if (_isVerified) {
      return AppColors.success;
    }
    return AppColors.primary;
  }
}

class _DriverMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String footer;
  final Color footerColor;
  final IconData icon;

  const _DriverMetricCard({
    required this.label,
    required this.value,
    required this.footer,
    required this.footerColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _driverBorderColor(context), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _driverSecondaryText(context),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (value.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: _driverPrimaryText(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            Icon(icon, color: footerColor, size: 18),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              footer,
              maxLines: 1,
              style: TextStyle(
                color: footerColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DriverInfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 26),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _driverPrimaryText(context),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverQuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DriverQuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _driverCardColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _driverBorderColor(context), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _driverIsDark(context)
                    ? const Color(0xFF071A2C)
                    : const Color(0xFFFFF6CC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _driverPrimaryText(context),
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverLoadingCard extends StatelessWidget {
  final String label;

  const _DriverLoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _driverBorderColor(context)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              color: _driverSecondaryText(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverTabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;

  const _DriverTabHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _driverBorderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.black, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _driverPrimaryText(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _driverSecondaryText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.45)),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverEmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _DriverEmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = _driverIsDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
          width: 1.2,
        ),
        boxShadow: isDark ? null : AppColors.cardShadowOf(context),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _driverPrimaryText(context),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _driverSecondaryText(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverConversationCard extends StatelessWidget {
  final String title;
  final String message;
  final String timestamp;
  final int unreadCount;
  final VoidCallback onTap;
  final String imageUrl;
  final bool isCustomerService;

  const _DriverConversationCard({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.unreadCount,
    required this.onTap,
    this.imageUrl = '',
    this.isCustomerService = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unreadCount > 0
                  ? AppColors.primary
                  : AppColors.borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.trim().isNotEmpty
                    ? OptimizedNetworkImage(
                        imageUrl: imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(16),
                        errorWidget: const Icon(
                          Icons.directions_car_outlined,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(
                        isCustomerService
                            ? Icons.support_agent
                            : Icons.directions_car_outlined,
                        color: AppColors.primary,
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (timestamp.isNotEmpty)
                          Text(
                            timestamp,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// JOBS TAB
class _JobsTab extends StatefulWidget {
  const _JobsTab();

  @override
  State<_JobsTab> createState() => __JobsTabState();
}

class __JobsTabState extends State<_JobsTab> {
  late Future<List<Map<String, dynamic>>> jobsFuture;
  String _selectedStatus = 'pending';
  RealtimeChannel? _jobsChannel;
  Timer? _jobsRefreshDebounce;
  static const List<String> _statusTabs = [
    'pending',
    'approved',
    'ongoing',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadJobs();
    final userId = AuthService().currentUser?.id;
    if (userId != null) _setupJobsListener(userId);
  }

  @override
  void dispose() {
    _jobsRefreshDebounce?.cancel();
    _jobsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupJobsListener(String userId) {
    _jobsChannel = Supabase.instance.client.realtime.channel(
      'driver-bookings-tab-$userId',
    );
    _jobsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: userId,
          ),
          callback: (payload) {
            if (!mounted) return;
            _jobsRefreshDebounce?.cancel();
            _jobsRefreshDebounce = Timer(const Duration(milliseconds: 350), () {
              if (mounted) setState(_loadJobs);
            });
          },
        )
        .subscribe();
  }

  void _loadJobs() {
    final authService = AuthService();
    final driverService = DriverService();
    if (authService.currentUser != null) {
      jobsFuture = driverService.getAssignedBookings(
        authService.currentUser!.id,
      );
    } else {
      jobsFuture = Future.value([]);
    }
  }

  Future<void> _refreshJobs() async {
    setState(() => _loadJobs());
    await jobsFuture;
  }

  String _statusGroup(Map<String, dynamic> trip) {
    final status = (trip['status']?.toString() ?? '').trim().toLowerCase();
    if (['completed', 'returned', 'successful', 'success'].contains(status)) {
      return 'completed';
    }
    if (['cancelled', 'canceled', 'rejected', 'declined'].contains(status)) {
      return 'cancelled';
    }
    if ([
      'active',
      'ongoing',
      'picked_up',
      'in_progress',
      'return_pending_inspection',
      'awaiting_completion',
      'awaiting_ratings',
    ].contains(status)) {
      return 'ongoing';
    }
    if (['approved', 'confirmed', 'assigned'].contains(status)) {
      return 'approved';
    }
    return 'pending';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  Widget _buildStatusTabs(List<Map<String, dynamic>> trips) {
    final isDark = _driverIsDark(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusTabs.map((status) {
          final selected = _selectedStatus == status;
          final count = trips
              .where((trip) => _statusGroup(trip) == status)
              .length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _selectedStatus = status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: status == 'cancelled' ? 108 : 96,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBg : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.borderColor
                              : AppColors.lightBorderColor),
                  ),
                ),
                child: Text(
                  '${_statusLabel(status)} ($count)',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.black
                        : (isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshJobs,
      color: AppColors.primary,
      backgroundColor: _driverCardColor(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          const RoleTabHeader(
            title: 'Assigned Trips',
            subtitle: 'Accepted trips, pickups, and vehicle returns',
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: jobsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _DriverLoadingCard(
                  label: 'Loading assigned trips...',
                );
              }

              final trips = snapshot.data ?? [];
              final visibleTrips = trips
                  .where((trip) => _statusGroup(trip) == _selectedStatus)
                  .toList();

              if (trips.isEmpty) {
                return Column(
                  children: [
                    _buildStatusTabs(trips),
                    const SizedBox(height: 14),
                    const RoleEmptyStateCard(
                      icon: Icons.route_outlined,
                      title: 'No assigned trips yet',
                      message:
                          'When an operator assigns you to a booking, it will show here.',
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  _buildStatusTabs(trips),
                  const SizedBox(height: 14),
                  if (visibleTrips.isEmpty)
                    RoleEmptyStateCard(
                      icon: Icons.inbox_outlined,
                      title:
                          'No ${_statusLabel(_selectedStatus).toLowerCase()} trips',
                      message:
                          'Trips with this status will appear here once available.',
                    )
                  else
                    ...visibleTrips.map((trip) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TripCard(
                          trip: trip,
                          onChanged: () {
                            setState(() => _loadJobs());
                          },
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onChanged;

  const _TripCard({required this.trip, required this.onChanged});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  Map<String, dynamic> get trip => widget.trip;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startActiveTracking());
  }

  @override
  void didUpdateWidget(covariant _TripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip['status'] != widget.trip['status']) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startActiveTracking(),
      );
    }
  }

  Future<void> _startActiveTracking() async {
    final status = trip['status']?.toString().trim().toLowerCase() ?? '';
    if (!mounted || !{'active', 'ongoing'}.contains(status)) return;
    final bookingId = trip['id']?.toString() ?? '';
    final vehicleId = trip['vehicle_id']?.toString() ?? '';
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (bookingId.isEmpty || vehicleId.isEmpty || userId.isEmpty) return;
    final tracker = TrackingService();
    if (tracker.activeBookingId == bookingId) return;
    try {
      await tracker.startBookingTracking(
        bookingId: bookingId,
        vehicleId: vehicleId,
        trackedUserId: userId,
        source: 'driver_active_trip',
      );
    } catch (error) {
      debugPrint('Unable to start active-trip GPS evidence: $error');
    }
  }

  String _displayTripStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
      case 'confirmed':
        return 'Approved';
      case 'active':
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  Future<void> _markReturned(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text(
          'Confirm Vehicle Return',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Mark this vehicle as returned now? This will notify the operator and vehicle owner to conduct the post-trip inspection and finalize billing.',
          style: TextStyle(
            color: isDark ? AppColors.textSecondary : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final total = await DriverService().completeAssignedBookingReturn(
        bookingId: trip['id'].toString(),
        returnedAt: now,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vehicle return recorded. Final total: PHP ${total.toStringAsFixed(0)}. Waiting for the after checklist, payment, and required ratings.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await TrackingService().stopTracking();
      widget.onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rateRenter(BuildContext context) async {
    final bookingId = trip['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TripRatingFlowScreen(
          bookingId: bookingId,
          reviewerRole: 'driver',
          title: 'Rate Renter',
          subtitle:
              'Rate the renter and operator for this completed trip.',
        ),
      ),
    );
    if (submitted == true) {
      final actorId = AuthService().currentUser?.id;
      final reconciled = await TripRatingService().reconcileCompletedBooking(
        bookingId,
        operatorFallbackUserId: actorId,
      );
      widget.onChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reconciled
                ? 'Rating saved. Trip successfully completed!'
                : 'Rating saved. Waiting for remaining reviews.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _openConversation(BuildContext context) async {
    try {
      final conversation = await ChatService().getConversationByBookingId(
        trip['id'].toString(),
      );
      final conversationId = conversation?['id']?.toString() ?? '';
      if (conversationId.isEmpty) {
        throw Exception('The booking conversation is not ready yet.');
      }
      if (!context.mounted) return;
      await Navigator.of(context).pushNamed(
        '/chat-detail',
        arguments: {
          'conversationId': conversationId,
          'recipientName': 'Booking Conversation',
          'isAutoGenerated': false,
          'userRole': 'driver',
        },
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openNavigation(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripNavigationScreen(
          bookingId: trip['id'].toString(),
          participantRole: 'driver',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildLegacyRevenueView(context);
  }

  Widget _buildLegacyRevenueView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = (trip['status']?.toString() ?? 'assigned').toLowerCase();
    final completionState = BookingService().getTripCompletionState(trip);
    final completionStage = completionState['completionStage']?.toString();
    final vehicle = trip['vehicles'] as Map<String, dynamic>?;
    final renter = trip['renter'] as Map<String, dynamic>?;
    final renterName = renter?['full_name']?.toString().trim();
    final renterPhone = renter?['phone']?.toString().trim();
    final renterId = trip['renter_id']?.toString() ?? '';
    final startLabel =
        trip['start_at']?.toString() ?? trip['start_date']?.toString() ?? 'N/A';
    final endLabel =
        trip['end_at']?.toString() ?? trip['end_date']?.toString() ?? 'N/A';
    final total =
        (trip['total_price'] as num?)?.toDouble() ??
        (trip['total_cost'] as num?)?.toDouble();
    final vehicleName = vehicle == null
        ? 'Assigned vehicle'
        : [vehicle['vehicle_name'], vehicle['brand'], vehicle['model']]
              .where(
                (part) => part != null && part.toString().trim().isNotEmpty,
              )
              .map((part) => part.toString().trim())
              .take(2)
              .join(' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vehicleName.isEmpty ? 'Assigned vehicle' : vehicleName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _displayTripStatus(trip['status']?.toString() ?? 'assigned'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${trip['pickup_location'] ?? 'Pickup'} to '
            '${trip['dropoff_location'] ?? 'Destination'}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Renter: ${renterName?.isNotEmpty == true ? renterName : 'Unknown'}'
            '${renterPhone != null && renterPhone.isNotEmpty ? ' • $renterPhone' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Renter ID: ${renterId.isNotEmpty ? renterId : 'N/A'}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Schedule: $startLabel -> $endLabel',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          if (total != null) ...[
            const SizedBox(height: 4),
            Text(
              'Booking total: PHP ${total.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await BookingReceiptService.shareReceipt(trip);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not download receipt: $error'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.download_rounded, size: 17),
              label: const Text('Download Trip Receipt'),
            ),
          ),
          const SizedBox(height: 12),
          if (status == 'confirmed' || status == 'approved')
            const _DriverWaitingAction(
              icon: Icons.fact_check_outlined,
              message:
                  'Waiting for the vehicle owner to submit the pre-trip checklist and start the trip.',
            ),
          if ({
            'approved',
            'confirmed',
            'active',
            'ongoing',
            'return_pending_inspection',
          }.contains(status)) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openConversation(context),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                label: const Text('Message'),
              ),
            ),
          ],
          if (status == 'active' || status == 'ongoing') ...[
            const SizedBox(height: 10),
            Column(
              children: [
                BookingReturnCountdown(booking: trip),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openNavigation(context),
                    icon: const Icon(Icons.navigation_rounded, size: 17),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markReturned(context),
                    icon: const Icon(Icons.assignment_turned_in, size: 16),
                    label: const Text('Mark Returned'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'return_pending_inspection')
            const _DriverWaitingAction(
              icon: Icons.fact_check_outlined,
              message:
                  'Waiting for the vehicle owner to submit the after checklist.',
            ),
          if (status == 'awaiting_completion' &&
              completionStage != 'driver_rating')
            const _DriverWaitingAction(
              icon: Icons.hourglass_bottom_rounded,
              message: 'Waiting for payment or the previous required rating.',
            ),
          if (completionStage == 'driver_rating' ||
              status == 'completed' ||
              status == 'returned')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _rateRenter(context),
                icon: const Icon(Icons.star_rate_rounded, size: 17),
                label: const Text('Rate Renter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DriverWaitingAction extends StatelessWidget {
  final IconData icon;
  final String message;

  const _DriverWaitingAction({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondary : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverOfferCard extends StatefulWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onChanged;

  const _DriverOfferCard({required this.offer, required this.onChanged});

  @override
  State<_DriverOfferCard> createState() => _DriverOfferCardState();
}

class _DriverOfferCardState extends State<_DriverOfferCard> {
  bool _isResponding = false;

  Map<String, dynamic> get offer => widget.offer;

  Future<void> _respondToOffer(bool accept) async {
    final assignmentId = offer['id']?.toString() ?? '';
    if (assignmentId.isEmpty || _isResponding) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: Text(
          accept ? 'Accept job offer?' : 'Decline job offer?',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          accept
              ? 'The operator will be notified and can finalize the booking.'
              : 'The operator will be notified to select another driver.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: accept ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(accept ? 'Accept' : 'Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isResponding = true);
    try {
      if (accept) {
        await DriverService().acceptJobOffer(assignmentId);
      } else {
        await DriverService().declineJobOffer(assignmentId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Job accepted. Waiting for operator finalization.'
                : 'Job declined. The operator will select another driver.',
          ),
          backgroundColor: accept ? AppColors.success : AppColors.warning,
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update job offer: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildLegacyRevenueView(context);
  }

  Widget _buildLegacyRevenueView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final booking = offer['bookings'] as Map<String, dynamic>?;
    final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
    final renter = booking?['renter'] as Map<String, dynamic>?;
    final assignmentStatus =
        offer['status']?.toString().replaceAll('_', ' ') ?? 'assigned';
    final renterName = renter?['full_name']?.toString().trim();
    final renterPhone = renter?['phone']?.toString().trim();
    final renterId =
        booking?['renter_id']?.toString() ?? renter?['id']?.toString() ?? 'N/A';
    final vehicleName = vehicle == null
        ? 'Assigned vehicle'
        : [vehicle['vehicle_name'], vehicle['brand'], vehicle['model']]
              .where(
                (part) => part != null && part.toString().trim().isNotEmpty,
              )
              .map((part) => part.toString().trim())
              .take(2)
              .join(' ');
    final scheduleStart =
        booking?['start_at']?.toString() ??
        booking?['start_date']?.toString() ??
        'N/A';
    final scheduleEnd =
        booking?['end_at']?.toString() ??
        booking?['end_date']?.toString() ??
        'N/A';
    final total =
        (booking?['total_price'] as num?)?.toDouble() ??
        (booking?['total_cost'] as num?)?.toDouble();
    final tripFee = (offer['trip_fee'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  vehicleName.isEmpty ? 'Assigned vehicle' : vehicleName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  assignmentStatus.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if ((vehicle?['plate_number']?.toString().trim().isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Plate: ${vehicle!['plate_number']}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '${booking?['pickup_location'] ?? 'Pickup'} to '
            '${booking?['dropoff_location'] ?? 'Destination'}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Renter: ${renterName?.isNotEmpty == true ? renterName : 'Unknown'}'
            '${renterPhone != null && renterPhone.isNotEmpty ? ' • $renterPhone' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Renter ID: $renterId',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Schedule: $scheduleStart -> $scheduleEnd',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          if (total != null) ...[
            const SizedBox(height: 4),
            Text(
              'Booking total: PHP ${total.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
          ],
          if (tripFee != null) ...[
            const SizedBox(height: 4),
            Text(
              'Driver fee: PHP ${tripFee.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isResponding
                      ? null
                      : () => _respondToOffer(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _isResponding ? null : () => _respondToOffer(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isResponding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverMessagesTab extends StatefulWidget {
  const _DriverMessagesTab();

  @override
  State<_DriverMessagesTab> createState() => _DriverMessagesTabState();
}

class _DriverMessagesTabState extends State<_DriverMessagesTab> {
  late Future<List<Map<String, dynamic>>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _loadConversations();
  }

  Future<List<Map<String, dynamic>>> _loadConversations() async {
    final user = AuthService().currentUser;
    if (user == null) return [];

    final conversations = await ChatService().getConversations(user.id);
    return conversations.map((conversation) {
      final messages = List<Map<String, dynamic>>.from(
        conversation['messages'] as List? ?? const [],
      );
      messages.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
        return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
      });

      final lastMessage = messages.isNotEmpty ? messages.first : null;
      final unreadCount = messages.where((message) {
        final senderId = message['sender_id']?.toString();
        final isRead = message['is_read'] == true;
        return senderId != user.id && !isRead;
      }).length;

      return {
        ...conversation,
        'last_message': lastMessage,
        'unread_count': unreadCount,
      };
    }).toList();
  }

  Future<void> _refresh() async {
    final future = _loadConversations();
    setState(() => _conversationsFuture = future);
    await future;
  }

  String _conversationTitle(Map<String, dynamic> conversation) {
    if (_isCustomerServiceConversation(conversation)) {
      return 'Customer Service';
    }

    final booking = conversation['bookings'];
    if (booking is Map) {
      final vehicle = booking['vehicles'];
      if (vehicle is Map) {
        final name = vehicle['vehicle_name']?.toString().trim();
        final brand = vehicle['brand']?.toString().trim() ?? '';
        final model = vehicle['model']?.toString().trim() ?? '';
        final vehicleName = name?.isNotEmpty == true
            ? name!
            : '$brand $model'.trim();
        if (vehicleName.isNotEmpty) return '$vehicleName Booking';
      }
    }
    return 'Booking Group Chat';
  }

  bool _isCustomerServiceConversation(Map<String, dynamic> conversation) {
    return conversation['bookings'] is! Map;
  }

  String _lastMessage(Map<String, dynamic> conversation) {
    final last = conversation['last_message'];
    if (last is Map) {
      final text = (last['content'] ?? last['message'])?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return 'No messages yet';
  }

  String _formatTimeAgo(String? raw) {
    final date = parseMessageTimestamp(raw);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}/${date.year}';
  }

  void _openConversation(Map<String, dynamic> conversation) {
    final conversationId = conversation['id']?.toString() ?? '';
    if (conversationId.isEmpty) return;
    final isCustomerService = _isCustomerServiceConversation(conversation);

    Navigator.of(context)
        .pushNamed(
          '/chat-detail',
          arguments: {
            'conversationId': conversationId,
            'recipientName': _conversationTitle(conversation),
            'recipientAvatar':
                conversation['vehicle_image_url']?.toString() ?? '',
            'isAutoGenerated':
                !isCustomerService &&
                (conversation['last_message'] as Map?)?['is_auto_generated'] ==
                    true,
            'isCustomerService': isCustomerService,
            'userRole': 'driver',
          },
        )
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      backgroundColor: _driverCardColor(context),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          final conversations = snapshot.data ?? [];
          final unreadTotal = conversations.fold<int>(
            0,
            (sum, item) => sum + ((item['unread_count'] as int?) ?? 0),
          );

          if (snapshot.connectionState == ConnectionState.waiting &&
              conversations.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              RoleTabHeader(
                title: 'Messages',
                subtitle: 'Booking conversations and customer service',
                icon: Icons.chat_bubble_outline,
                badge: unreadTotal > 0 ? '$unreadTotal unread' : null,
              ),
              const SizedBox(height: 18),
              if (conversations.isEmpty)
                const RoleEmptyStateCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'No messages yet',
                  message:
                      'Booking group chats and support conversations will appear here.',
                )
              else
                ...conversations.map((conversation) {
                  final last = conversation['last_message'] as Map?;
                  final unreadCount =
                      (conversation['unread_count'] as int?) ?? 0;
                  return _DriverConversationCard(
                    title: _conversationTitle(conversation),
                    message: _lastMessage(conversation),
                    timestamp: _formatTimeAgo(last?['created_at']?.toString()),
                    unreadCount: unreadCount,
                    imageUrl:
                        conversation['vehicle_image_url']?.toString() ?? '',
                    isCustomerService: _isCustomerServiceConversation(
                      conversation,
                    ),
                    onTap: () => _openConversation(conversation),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab({
    super.key,
    required this.onOpenBookings,
    required this.onOpenMessages,
    required this.onOpenEarnings,
    required this.onOpenApplication,
    required this.onOpenRatings,
  });

  final VoidCallback onOpenBookings;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenEarnings;
  final VoidCallback onOpenApplication;
  final VoidCallback onOpenRatings;

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  final Set<String> _shownBrowserNotificationIds = {};
  Timer? _autoRefreshTimer;
  RealtimeChannel? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _refresh();
    });
    _setupNotificationsListener();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _notificationsSubscription?.unsubscribe();
    super.dispose();
  }

  void _setupNotificationsListener() {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return;
    try {
      final supabase = Supabase.instance.client;
      _notificationsSubscription = supabase.realtime.channel(
        'public:notifications:user_id=eq.$userId',
      );
      _notificationsSubscription!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              if (mounted) _refresh();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ Error setting up driver notifications listener: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return [];
    return NotificationService().getNotifications(userId);
  }

  Future<void> _refresh() async {
    final future = _loadNotifications();
    setState(() => _notificationsFuture = future);
    await future;
  }

  Future<void> markAllAsRead() async {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return;
    await NotificationService().markAllAsRead(userId);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  Future<void> _openNotificationModal(Map<String, dynamic> notification) async {
    final id = notification['id']?.toString();
    if (id != null && id.isNotEmpty && notification['is_read'] != true) {
      await NotificationService().markAsRead(id);
      await _refresh();
    }

    if (!mounted) return;
    final target = resolveNotificationTarget(notification);
    switch (target.destination) {
      case NotificationDestination.messages:
        final conversationId = target.conversationId;
        if (conversationId == null) {
          widget.onOpenMessages();
        } else {
          Navigator.pushNamed(
            context,
            '/chat-detail',
            arguments: {
              'conversationId': conversationId,
              'recipientName':
                  notification['title']?.toString() ?? 'Conversation',
              'recipientAvatar': '',
              'isAutoGenerated': false,
              'userRole': 'driver',
            },
          );
        }
        return;
      case NotificationDestination.booking:
      case NotificationDestination.tracking:
        widget.onOpenBookings();
        return;
      case NotificationDestination.application:
        widget.onOpenApplication();
        return;
      case NotificationDestination.verification:
        Navigator.pushNamed(
          context,
          '/driver-identity-verification',
          arguments: {
            if (target.data['document_type']?.toString() == 'driver_license')
              'mode': 'renewal',
          },
        );
        return;
      case NotificationDestination.ratings:
        widget.onOpenRatings();
        return;
      case NotificationDestination.payment:
        widget.onOpenEarnings();
        return;
      case NotificationDestination.vehicles:
        widget.onOpenApplication();
        return;
      case NotificationDestination.announcement:
      case NotificationDestination.general:
        break;
    }

    final title = notification['title']?.toString() ?? 'Notification';
    final message = notification['message']?.toString() ?? '';
    final createdAt = notification['created_at']?.toString() ?? '';
    final rawData = notification['data'];
    final data = rawData is Map ? Map<String, dynamic>.from(rawData) : {};
    final isDriverLicenseRenewal =
        data['event']?.toString() == 'driver_license_renewal_due' ||
        data['document_type']?.toString() == 'driver_license';
    final actionLabel =
        data['action_label']?.toString().trim().isNotEmpty == true
        ? data['action_label'].toString()
        : 'Update';
    final visual = notificationVisualFor(notification);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = _driverIsDark(sheetContext);
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A3548) : Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark ? Colors.white12 : AppColors.lightBorderColor,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: visual.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(visual.icon, color: visual.color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.lightTextPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (createdAt.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              createdAt,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  message.isEmpty ? 'No message content.' : message,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                if (isDriverLicenseRenewal) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.pushNamed(
                          context,
                          '/driver-identity-verification',
                          arguments: {'mode': 'renewal'},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.update_outlined),
                      label: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? const <Map<String, dynamic>>[];

          if (snapshot.connectionState == ConnectionState.waiting &&
              notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (notifications.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              children: const [
                RoleTabHeader(
                  title: 'Notifications',
                  subtitle: 'Driver updates, approvals, and trip reminders',
                  icon: Icons.notifications_outlined,
                ),
                SizedBox(height: 18),
                RoleEmptyStateCard(
                  icon: Icons.notifications_none_outlined,
                  title: 'No notifications yet',
                  message:
                      'Important trip and account notifications will appear here.',
                ),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              RoleTabHeader(
                title: 'Notifications',
                subtitle: 'Driver updates, approvals, and trip reminders',
                icon: Icons.notifications_outlined,
                badge:
                    '${notifications.where((item) => item['is_read'] != true).length} unread',
                action: notifications.any((item) => item['is_read'] != true)
                    ? TextButton.icon(
                        onPressed: markAllAsRead,
                        icon: const Icon(
                          Icons.done_all,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              ...notifications.map((notification) {
                final title =
                    notification['title']?.toString() ?? 'Notification';
                final message = notification['message']?.toString() ?? '';
                final createdAt = notification['created_at']?.toString() ?? '';
                final isRead = notification['is_read'] == true;
                final notificationId = notification['id']?.toString() ?? '';
                final visual = notificationVisualFor(notification);

                return InkWell(
                  onTap: () => _openNotificationModal(notification),
                  onLongPress: () => _openNotificationModal(notification),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isRead
                            ? AppColors.borderColor
                            : AppColors.primary,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(visual.icon, color: visual.color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (!isRead) ...[
                              const SizedBox(width: 10),
                              Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          createdAt,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// EARNINGS TAB
class _EarningsTab extends StatefulWidget {
  const _EarningsTab();

  @override
  State<_EarningsTab> createState() => __EarningsTabState();
}

class __EarningsTabState extends State<_EarningsTab> {
  late Future<double> earningsFuture;
  String _selectedPeriod = 'Month';
  static const List<String> _periodOptions = ['Day', 'Week', 'Month', 'Year'];

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  DateTime _periodStart() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Day':
        return DateTime(now.year, now.month, now.day);
      case 'Week':
        return now.subtract(const Duration(days: 7));
      case 'Year':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  void _loadEarnings() {
    final authService = AuthService();
    final driverService = DriverService();
    if (authService.currentUser != null) {
      earningsFuture = driverService
          .getEarnings(
            authService.currentUser!.id,
            fromDate: _periodStart(),
            toDate: DateTime.now(),
          )
          .catchError((_) => 0.0);
    } else {
      earningsFuture = Future.value(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildRevenueView();
  }

  Widget _buildLegacyRevenueView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<double>(
            future: earningsFuture,
            builder: (context, snapshot) {
              final earnings = snapshot.data ?? 0.0;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earnings (Last 30 Days)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₱${earnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Earnings History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                'No earnings history available',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Revenue & Earnings',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _buildPeriodDropdown(),
          ],
        ),
        const SizedBox(height: 22),
        FutureBuilder<double>(
          future: earningsFuture,
          builder: (context, snapshot) {
            final earnings = snapshot.data ?? 0.0;
            return Column(
              children: [
                _buildMetricCard(
                  label: 'Total Revenue',
                  value: _currency(earnings),
                  subtext: earnings <= 0
                      ? 'No revenue for this ${_selectedPeriod.toLowerCase()}'
                      : 'Driver earnings this ${_selectedPeriod.toLowerCase()}',
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallMetricCard(
                        label: 'Completed Jobs',
                        value: '0',
                        icon: Icons.route_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSmallMetricCard(
                        label: 'Avg / Job',
                        value: _currency(0),
                        icon: Icons.analytics_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        _buildSectionHeader('Linked Payout Methods', action: 'Manage'),
        const SizedBox(height: 12),
        _buildEmptyPanel(
          icon: Icons.account_balance_wallet_outlined,
          text: 'No linked payout methods yet.',
        ),
        const SizedBox(height: 18),
        _buildSectionHeader('Earnings Breakdown', action: 'View All'),
        const SizedBox(height: 12),
        _buildEmptyPanel(
          icon: Icons.receipt_long_outlined,
          text: 'Completed trip earnings will appear here.',
        ),
      ],
    );
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _driverBorderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          dropdownColor: _driverCardColor(context),
          iconEnabledColor: AppColors.primary,
          style: TextStyle(
            color: _driverPrimaryText(context),
            fontWeight: FontWeight.w800,
          ),
          items: _periodOptions
              .map(
                (period) =>
                    DropdownMenuItem(value: period, child: Text(period)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedPeriod = value;
              _loadEarnings();
            });
          },
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _driverBorderColor(context)),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: _driverSecondaryText(context)),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    color: _driverPrimaryText(context),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtext,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: AppColors.primary, size: 26),
        ],
      ),
    );
  }

  Widget _buildSmallMetricCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _driverBorderColor(context)),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: _driverSecondaryText(context),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _driverPrimaryText(context),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _driverPrimaryText(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (action != null)
          Text(
            action,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyPanel({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _driverCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _driverBorderColor(context)),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _driverSecondaryText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _currency(num value) => 'PHP ${value.toStringAsFixed(2)}';
}

// AVAILABILITY TAB
class _AvailabilityTab extends StatefulWidget {
  const _AvailabilityTab();

  @override
  State<_AvailabilityTab> createState() => __AvailabilityTabState();
}

class __AvailabilityTabState extends State<_AvailabilityTab> {
  final DriverService _driverService = DriverService();
  bool isAvailable = false;
  bool isLoading = true;
  bool isSaving = false;
  final Set<DateTime> selectedDates = {};
  DateTime _availabilityFocusedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final userId = AuthService().currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      final stats = await _driverService.getDriverStats(userId);
      final schedule = await _driverService.getSchedule(userId);
      final dates = schedule
          .map((row) => DateTime.tryParse(row['date']?.toString() ?? ''))
          .whereType<DateTime>()
          .map(_dateOnly)
          .toSet();
      if (!mounted) return;
      final sortedDates = dates.toList()..sort();
      setState(() {
        isAvailable = stats['is_available'] == true;
        selectedDates
          ..clear()
          ..addAll(dates);
        if (sortedDates.isNotEmpty) {
          _availabilityFocusedDay = DateTime(
            sortedDates.first.year,
            sortedDates.first.month,
            1,
          );
        }
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    final userId = AuthService().currentUser?.id;
    if (userId == null || isSaving) return;
    if (value && selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one available date first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final previous = isAvailable;
    setState(() {
      isAvailable = value;
      isSaving = true;
    });

    try {
      await _driverService.setAvailability(userId, value);
      await _driverService.replaceDateSchedule(
        driverId: userId,
        dates: value ? selectedDates : const [],
        isAvailable: value,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Schedule saved. You will show as available on selected dates.'
                : 'You are now unavailable for driver assignments',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isAvailable = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update availability: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _saveSelectedDates() async {
    final userId = AuthService().currentUser?.id;
    if (userId == null || isSaving) return;
    if (isAvailable && selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one available date first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await _driverService.replaceDateSchedule(
        driverId: userId,
        dates: isAvailable ? selectedDates : const [],
        isAvailable: isAvailable,
      );
      await _driverService.setAvailability(userId, isAvailable);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability dates saved'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save availability dates: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _pickAvailabilityDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = firstDate.add(const Duration(days: 180));
    final pickedDates = await showDialog<Set<DateTime>>(
      context: context,
      builder: (dialogContext) {
        var focusedDay = selectedDates.isNotEmpty ? selectedDates.last : now;
        final tempDates = selectedDates.map(_dateOnly).toSet();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1826),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pick Available Dates',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${tempDates.length} selected',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF07111D),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: TableCalendar(
                              firstDay: firstDate,
                              lastDay: lastDate,
                              focusedDay: focusedDay,
                              calendarFormat: CalendarFormat.month,
                              rowHeight: 44,
                              availableCalendarFormats: const {
                                CalendarFormat.month: 'Month',
                              },
                              selectedDayPredicate: (day) =>
                                  tempDates.contains(_dateOnly(day)),
                              onDaySelected: (selectedDay, newFocusedDay) {
                                final normalized = _dateOnly(selectedDay);
                                setDialogState(() {
                                  focusedDay = newFocusedDay;
                                  if (tempDates.contains(normalized)) {
                                    tempDates.remove(normalized);
                                  } else {
                                    tempDates.add(normalized);
                                  }
                                });
                              },
                              onPageChanged: (newFocusedDay) {
                                focusedDay = newFocusedDay;
                              },
                              headerStyle: const HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                                titleTextStyle: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                                leftChevronIcon: Icon(
                                  Icons.chevron_left,
                                  color: AppColors.primary,
                                ),
                                rightChevronIcon: Icon(
                                  Icons.chevron_right,
                                  color: AppColors.primary,
                                ),
                              ),
                              daysOfWeekStyle: const DaysOfWeekStyle(
                                weekdayStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                                weekendStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              calendarStyle: CalendarStyle(
                                cellMargin: const EdgeInsets.all(5),
                                defaultTextStyle: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                weekendTextStyle: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                outsideTextStyle: TextStyle(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                todayDecoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  border: Border.all(color: AppColors.primary),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                todayTextStyle: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                                selectedDecoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                selectedTextStyle: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setDialogState(tempDates.clear),
                            child: const Text('Clear'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, tempDates),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                              child: Text('Apply (${tempDates.length})'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (pickedDates == null) return;
    setState(() {
      selectedDates
        ..clear()
        ..addAll(pickedDates);
    });
  }

  String _formatMonthYear(DateTime date) {
    const fullMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${fullMonths[date.month - 1]} ${date.year}';
  }

  void _changeAvailabilityMonth(int offset) {
    setState(() {
      _availabilityFocusedDay = DateTime(
        _availabilityFocusedDay.year,
        _availabilityFocusedDay.month + offset,
        1,
      );
    });
  }

  Future<void> _confirmRemoveAvailabilityDate(DateTime date) async {
    final formatted = _formatDate(date);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Remove Date',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to remove this availability date?',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatted,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _removeAvailabilityDate(date);
    }
  }

  void _removeAvailabilityDate(DateTime date) {
    setState(() => selectedDates.remove(_dateOnly(date)));
  }

  Widget _buildAvailableDatesSection(bool isDark) {
    final calendarText = isDark ? Colors.white : Colors.black87;
    final mutedText = isDark ? Colors.white54 : Colors.grey.shade600;
    final sortedDates = selectedDates.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF07111D) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: isSaving
                        ? null
                        : () => _changeAvailabilityMonth(-1),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: isSaving ? mutedText : AppColors.primary,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatMonthYear(_availabilityFocusedDay),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: calendarText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: isSaving
                        ? null
                        : () => _changeAvailabilityMonth(1),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: isSaving ? mutedText : AppColors.primary,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TableCalendar<void>(
                firstDay: DateTime(2000, 1, 1),
                lastDay: DateTime(2100, 12, 31),
                focusedDay: _availabilityFocusedDay,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                headerVisible: false,
                rowHeight: 42,
                daysOfWeekHeight: 24,
                selectedDayPredicate: (day) =>
                    selectedDates.contains(_dateOnly(day)),
                onPageChanged: (focusedDay) {
                  setState(() {
                    _availabilityFocusedDay = DateTime(
                      focusedDay.year,
                      focusedDay.month,
                      1,
                    );
                  });
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  cellMargin: const EdgeInsets.all(4),
                  defaultTextStyle: TextStyle(
                    color: mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  weekendTextStyle: TextStyle(
                    color: mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  todayTextStyle: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  weekendStyle: TextStyle(
                    color: mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                calendarBuilders: CalendarBuilders<void>(
                  defaultBuilder: (context, day, focusedDay) {
                    if (!selectedDates.contains(_dateOnly(day))) return null;
                    return _buildAvailableCalendarDay(
                      day,
                      isDark,
                      isToday: false,
                    );
                  },
                  todayBuilder: (context, day, focusedDay) {
                    if (selectedDates.contains(_dateOnly(day))) {
                      return _buildAvailableCalendarDay(
                        day,
                        isDark,
                        isToday: true,
                      );
                    }
                    return _buildCalendarDay(day, isDark, isToday: true);
                  },
                  selectedBuilder: (context, day, focusedDay) =>
                      _buildAvailableCalendarDay(
                        day,
                        isDark,
                        isToday: DateUtils.isSameDay(day, DateTime.now()),
                      ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildCalendarLegend(
                    color: AppColors.primary,
                    label: 'Available',
                    isDark: isDark,
                  ),
                  _buildCalendarLegend(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    label: 'Not selected',
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (sortedDates.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'No dates selected yet. Use Pick Dates to add availability.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedText, fontSize: 12.5),
            ),
          )
        else ...[
          Text(
            '${sortedDates.length} available date${sortedDates.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: calendarText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedDates.map((date) {
              return InputChip(
                avatar: const Icon(
                  Icons.event_available_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text(_formatDate(date)),
                onDeleted: isSaving
                    ? null
                    : () => _confirmRemoveAvailabilityDate(date),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  color: calendarText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAvailableCalendarDay(
    DateTime day,
    bool isDark, {
    required bool isToday,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(
                color: isDark ? Colors.white : Colors.black87,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildCalendarDay(DateTime day, bool isDark, {required bool isToday}) {
    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.12)
            : (isDark ? Colors.white.withValues(alpha: 0.035) : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday
              ? AppColors.primary
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: isToday
              ? AppColors.primary
              : (isDark ? Colors.white54 : Colors.grey.shade600),
          fontSize: 13,
          fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCalendarLegend({
    required Color color,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Availability Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isAvailable ? Icons.check_circle : Icons.pause_circle,
                    color: isAvailable ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are ${isAvailable ? 'Available' : 'Unavailable'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        isAvailable
                            ? 'Receiving job offers'
                            : 'Not receiving jobs',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isAvailable,
                  onChanged: isLoading || isSaving
                      ? null
                      : (value) => _toggleAvailability(value),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ),
          if (isLoading || isSaving) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  isLoading
                      ? 'Loading availability...'
                      : 'Saving availability...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Work Schedule',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Available Dates',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: isSaving ? null : _pickAvailabilityDate,
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('Pick Dates'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isAvailable
                      ? 'You will only show as available on the selected dates.'
                      : 'Pick dates first, then turn availability on.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
                _buildAvailableDatesSection(isDark),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : _saveSelectedDates,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Selected Dates'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
}

// PROFILE TAB
class _ProfileTab extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;
  final VoidCallback onLogout;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenBookings;
  final VoidCallback onProfileUpdated;

  const _ProfileTab({
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.onLogout,
    required this.onOpenSupport,
    required this.onOpenBookings,
    required this.onProfileUpdated,
  });

  @override
  State<_ProfileTab> createState() => __ProfileTabState();
}

class __ProfileTabState extends State<_ProfileTab> {
  late Future<Map<String, dynamic>> _driverStatsFuture;

  @override
  void initState() {
    super.initState();
    final userId = AuthService().currentUser?.id;
    _driverStatsFuture = userId == null
        ? Future.value(<String, dynamic>{})
        : DriverService()
              .getDriverStats(userId)
              .catchError((_) => <String, dynamic>{});
  }

  Widget _buildDriverInitial(String displayName) {
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _driverStatsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final totalTrips =
            int.tryParse(
              (stats['total_trips'] ?? stats['trips'] ?? 0).toString(),
            ) ??
            0;
        final assignments =
            int.tryParse(
              (stats['assignments'] ?? stats['bookings'] ?? 0).toString(),
            ) ??
            0;
        final rating =
            (stats['rating'] as num?)?.toDouble() ??
            double.tryParse(stats['rating']?.toString() ?? '') ??
            0.0;

        return UnifiedProfileScreen(
          role: 'driver',
          isDarkMode: widget.isDarkMode,
          onThemeToggle: widget.onThemeToggle,
          onLogout: widget.onLogout,
          onOpenSupport: widget.onOpenSupport,
          onOpenVerification: () =>
              Navigator.pushNamed(context, '/driver-identity-verification'),
          onProfileUpdated: widget.onProfileUpdated,
          stats: [
            ProfileStatItem(
              label: 'Trips',
              value: totalTrips.toString(),
              onTap: widget.onOpenBookings,
            ),
            ProfileStatItem(
              label: 'Assignments',
              value: assignments.toString(),
              onTap: widget.onOpenBookings,
            ),
            ProfileStatItem(
              label: 'Rating',
              value: rating <= 0 ? '0.0' : rating.toStringAsFixed(1),
              onTap: () {
                final userId = AuthService().currentUser?.id;
                if (userId == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RatingsReviewsScreen(
                      userId: userId,
                      title: 'Driver Ratings & Reviews',
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey : Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _DriverProfileStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _DriverProfileDivider extends StatelessWidget {
  const _DriverProfileDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: AppColors.borderColor);
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isDark;
  final Color? textColor;
  final bool isLast;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.isDark,
    this.textColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.2),
          boxShadow: isDark ? null : AppColors.cardShadowOf(context),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: textColor ?? (isDark ? AppColors.primary : AppColors.primaryDark),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? primaryText,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(fontSize: 13, color: secondaryText),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: tertiaryText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
