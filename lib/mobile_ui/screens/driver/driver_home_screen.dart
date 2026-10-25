import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/auth_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/booking_receipt_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/driver_service.dart';
import '../../../services/notification_permission_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/payout_method_service.dart';
import '../../../services/booking_settlement_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../services/tracking_service.dart';
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/role_ui.dart';
import '../../widgets/optimized_network_image.dart';
import '../../widgets/dialog_status_indicator.dart';
import '../../widgets/relative_time_text.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/booking_return_countdown.dart';
import '../profile/ratings_reviews_screen.dart';
import '../profile/trip_rating_flow_screen.dart';
import '../profile/unified_profile_screen.dart';
import '../tracking/trip_navigation_screen.dart';
import '../../../services/trip_rating_service.dart';
import '../../../utils/notification_target.dart';
import '../../../utils/notification_visual.dart';
import '../../widgets/handover_pin_verifier_modal.dart';
import '../../widgets/inspection_damage_comparison_dialog.dart';
import '../../widgets/trip_route_history_dialog.dart';
import '../../widgets/trip_location_map_dialog.dart';
import '../../../utils/booking_status.dart';
import '../../../utils/currency_formatter.dart';

part 'tabs/driver_dashboard_tab.dart';
part 'tabs/driver_jobs_tab.dart';
part 'tabs/driver_messages_tab.dart';
part 'tabs/driver_notifications_tab.dart';
part 'tabs/driver_earnings_tab.dart';
part 'tabs/driver_availability_tab.dart';
part 'tabs/driver_profile_tab.dart';

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
        return _JobsTab(
          onOpenAvailability: () => setState(() => _selectedTab = 6),
        );
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

