import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/auth_service.dart';
import '../../../services/booking_inspection_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/partner_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/booking_receipt_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../services/tracking_service.dart';
import '../../../services/trip_rating_service.dart';
import '../../../services/user_restriction_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/conversation_tile.dart';
import '../../widgets/notification_item.dart';
import '../../widgets/restriction_ui.dart';
import '../../widgets/role_ui.dart';
import '../../widgets/optimized_network_image.dart';
import '../../widgets/relative_time_text.dart';
import '../../widgets/booking_return_countdown.dart';
import '../../widgets/vehicle_inspection_checklist_fields.dart';
import '../../widgets/vehicle_inspection_record_view.dart';
import '../profile/ratings_reviews_screen.dart';
import '../profile/trip_rating_flow_screen.dart';
import '../../../utils/booking_status.dart';
import '../../../utils/notification_target.dart';
import '../../../utils/notification_visual.dart';
import '../profile/unified_profile_screen.dart';
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
  String? partnerAvatarUrl;
  String verificationStatus = 'pending';
  String partnershipStatus = 'basic'; // 'basic', 'approved', 'certified'
  Map<String, dynamic>? partnerProfile;
  String? partnerId;

  // Stats
  double totalEarnings = 0.0;
  int activeVehicles = 0;
  double rating = 0.0;
  int ratingCount = 0;

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

  String _partnerBookingStatus = 'pending';

  // 🔔 Real-time bookings listener
  RealtimeChannel? _bookingsSubscription;
  RealtimeChannel? _notificationsSubscription;
  Timer? _notificationsAutoRefreshTimer;
  final UserRestrictionService _restrictionService = UserRestrictionService();
  UserRestrictionState _restrictionState = UserRestrictionState.empty;
  final Set<String> _shownRestrictionNotificationIds = {};

  bool isLoading = true;
  bool dismissedVerificationBanner = false;
  bool _dimCustomerServiceFab = false;
  DateTime? _lastBackPressedAt;
  StreamSubscription<Map<String, dynamic>>? _pushNotificationTapSubscription;

  String _normalizeVerificationStatus(String? status) {
    final value = (status ?? 'pending').toLowerCase();
    if (value == 'approved') return 'verified';
    return value;
  }

  bool get _isPartnerVerified =>
      verificationStatus == 'verified' || partnershipStatus == 'certified';

  bool get _isPartnerCertified => partnershipStatus == 'certified';

  int get _partnerUnreadMessageCount {
    final currentUserId = AuthService().currentUser?.id;
    if (currentUserId == null) return 0;

    return conversations.fold<int>(0, (total, conversation) {
      final messages = List<Map<String, dynamic>>.from(
        conversation['messages'] as List? ?? const [],
      );
      return total +
          messages.where((message) {
            return message['sender_id']?.toString() != currentUserId &&
                message['is_read'] != true &&
                message['is_deleted'] != true;
          }).length;
    });
  }

  int get _partnerUnreadNotificationCount => notifications
      .where((notification) => notification['is_read'] != true)
      .length;

  @override
  void initState() {
    super.initState();
    final pushService = PushNotificationService();
    _pushNotificationTapSubscription = pushService.notificationTaps.listen((
      payload,
    ) {
      if (mounted) _handlePartnerNotificationTap(payload);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = pushService.takePendingNotificationTap();
      if (pending != null && mounted) {
        _handlePartnerNotificationTap(pending);
      }
    });
    _loadPartnerData();
    _initializeConnectivity();
    _setupBookingsListener(); // 🔔 Listen for real-time bookings
    _notificationsAutoRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (mounted) _loadPartnerData();
      },
    );
  }

  @override
  void dispose() {
    _pushNotificationTapSubscription?.cancel();
    _bookingsSubscription?.unsubscribe();
    _notificationsSubscription?.unsubscribe();
    _notificationsAutoRefreshTimer?.cancel();
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
        final avatarUrl = await _loadPartnerAvatarUrl(user);
        final restrictionState = await _restrictionService.getUserRestriction(
          user.id,
        );

        if (_notificationsSubscription == null) {
          _setupNotificationsListener(user.id);
        }

        setState(() {
          partnerProfile = profile;
          partnerName = user.userMetadata?['full_name'] ?? 'Partner';
          partnerAvatarUrl = avatarUrl;
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
          ratingCount = (ratingSummary['count'] as num?)?.toInt() ?? 0;
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

  Future<String?> _loadPartnerAvatarUrl(User user) async {
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('avatar_url, profile_picture_url')
          .eq('id', user.id)
          .maybeSingle();
      final url = (row?['avatar_url'] ?? row?['profile_picture_url'])
          ?.toString()
          .trim();
      if (url != null && url.isNotEmpty) return url;
    } catch (e) {
      debugPrint('Partner avatar lookup skipped: $e');
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final metadataUrl =
        (metadata['avatar_url'] ?? metadata['profile_picture_url'])
            ?.toString()
            .trim();
    if (metadataUrl != null && metadataUrl.isNotEmpty) return metadataUrl;

    return null;
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
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              if (!mounted) return;
              _loadPartnerData();
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

  Future<void> _openCustomerServiceConversation() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final conversation = await ChatService()
          .getOrCreateCustomerServiceConversation(
            userId: user.id,
            userName: partnerName,
            userRole: 'partner',
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
          'userRole': 'partner',
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Could not open customer service chat');
    }
  }

  Future<void> _showEditPartnerProfileDialog() async {
    final nameController = TextEditingController(text: partnerName);
    final addressController = TextEditingController(
      text:
          partnerProfile?['business_address']?.toString() ??
          partnerProfile?['address']?.toString() ??
          '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Display / Business Name',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Business Address',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) {
      nameController.dispose();
      addressController.dispose();
      return;
    }

    final cleanName = nameController.text.trim();
    final cleanAddress = addressController.text.trim();
    if (cleanName.isEmpty) {
      _showErrorSnackBar('Name is required');
      return;
    }

    try {
      final user = AuthService().currentUser;
      if (user == null) throw Exception('User not authenticated');

      final supabase = Supabase.instance.client;
      await supabase
          .from('users')
          .update({'full_name': cleanName})
          .eq('id', user.id);

      final profileId = partnerProfile?['id']?.toString();
      if (profileId != null && profileId.isNotEmpty) {
        await PartnerService().updatePartnerProfile(profileId, {
          'business_name': cleanName,
          if (cleanAddress.isNotEmpty) 'business_address': cleanAddress,
          if (cleanAddress.isNotEmpty) 'address': cleanAddress,
        });
      }

      if (!mounted) return;
      setState(() => partnerName = cleanName);
      _showSuccessSnackBar('Profile updated');
      await _loadPartnerData();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Could not update profile: $e');
    } finally {
      nameController.dispose();
      addressController.dispose();
    }
  }

  void _handleApplyVehicleNavigation() {
    if (_isPartnerVerified) {
      Navigator.pushNamed(context, '/apply-vehicle');
      return;
    }

    _showErrorSnackBar(
      'Complete your verification first before applying a vehicle.',
    );
    Navigator.pushNamed(context, '/owner-verification');
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoading &&
        (_restrictionState.isAccountRestricted ||
            _restrictionState.isBlocked)) {
      return _buildRestrictedScaffold();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackPressed();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.darkBg,
        drawer: _buildDrawer(),
        body: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
              : _buildTabContent(),
        ),
        floatingActionButton: AnimatedOpacity(
          opacity: _dimCustomerServiceFab ? 0.5 : 1,
          duration: const Duration(milliseconds: 140),
          child: FloatingActionButton(
            heroTag: 'customer_service_partner',
            onPressed: _openCustomerServiceConversation,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            tooltip: 'Customer Service',
            child: const Icon(Icons.support_agent),
          ),
        ),
        bottomNavigationBar: RoleBottomNavigation(
          currentIndex: selectedNavIndex,
          badgeCounts: {
            1: bookingCounts['pending'] ?? 0,
            2: _partnerUnreadMessageCount,
            3: _partnerUnreadNotificationCount,
          },
          onTap: (index) => setState(() => selectedNavIndex = index),
        ),
      ),
    );
  }

  void _handleBackPressed() {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
      return;
    }

    if (selectedNavIndex != 0) {
      setState(() => selectedNavIndex = 0);
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

  Widget _buildCenteredTabHeader(String title, {Widget? trailing}) {
    return RolePageHeader(title: title, trailing: trailing);
  }

  Scaffold _buildRestrictedScaffold() {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      floatingActionButton: AnimatedOpacity(
        opacity: _dimCustomerServiceFab ? 0.5 : 1,
        duration: const Duration(milliseconds: 140),
        child: FloatingActionButton(
          heroTag: 'customer_service_partner_restricted',
          onPressed: _openCustomerServiceConversation,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          tooltip: 'Customer Service',
          child: const Icon(Icons.support_agent),
        ),
      ),
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
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
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5B5B).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFF5B5B).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFFF5B5B),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Policy Violations: ${_restrictionState.violationCount > 0 ? _restrictionState.violationCount : 1}',
                        style: const TextStyle(
                          color: Color(0xFFFF5B5B),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== DRAWER =====================
  Widget _buildPartnerAvatar({
    required double size,
    required double radius,
    double fontSize = 20,
  }) {
    final avatarUrl = partnerAvatarUrl?.trim() ?? '';

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: avatarUrl.isNotEmpty
          ? OptimizedNetworkImage(
              imageUrl: avatarUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorWidget: _buildPartnerInitial(fontSize),
            )
          : _buildPartnerInitial(fontSize),
    );
  }

  Widget _buildPartnerInitial(double fontSize) {
    return Center(
      child: Text(
        partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final user = AuthService().currentUser;
    final email = user?.email ?? 'partner account';

    return Drawer(
      backgroundColor: AppColors.darkBgSecondary,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 18, 16),
              child: Row(
                children: [
                  _buildPartnerAvatar(size: 46, radius: 14, fontSize: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _getPartnerBadge(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _getPartnerBadgeColor(),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
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
                    icon: Icons.home,
                    label: 'Home',
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
                    isSelected: selectedNavIndex == 1,
                    onTap: () {
                      setState(() => selectedNavIndex = 1);
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
                    icon: Icons.star_outline_rounded,
                    label: 'My Ratings',
                    onTap: () {
                      Navigator.pop(context);
                      _showRatesReviewsDialog();
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color:
              iconColor ??
              (isSelected ? Colors.black : AppColors.textSecondary),
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color:
                labelColor ??
                (isSelected ? Colors.black : AppColors.textPrimary),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
        dense: true,
        minLeadingWidth: 22,
        horizontalTitleGap: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
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
        return _buildBookingsTab();
      case 2:
        return _buildMessagesTab();
      case 3:
        return _buildNotificationsTab();
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
                  value: ratingCount > 0 ? rating.toStringAsFixed(1) : '0.0',
                  subtext: ratingCount > 0 ? 'From reviews' : 'No reviews yet',
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
            child: _buildPartnerAvatar(size: 44, radius: 12, fontSize: 20),
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
                  'Mobilis by PSDC Certified Partner',
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
                  onPressed: () =>
                      Navigator.pushNamed(context, '/owner-verification'),
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
    return GestureDetector(
      onTap: _handleApplyVehicleNavigation,
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
              child: const Icon(
                Icons.add_circle_outline,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Another Vehicle',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'List your next vehicle and send it for approval.',
                    style: TextStyle(
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
              child: const Text(
                'Add Car',
                style: TextStyle(
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
    _openCustomerServiceConversation();
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
    final currentPartnerId = partnerId;
    if (currentPartnerId == null || currentPartnerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner account is still loading.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerRevenueScreen(
          partnerId: currentPartnerId,
          partnerName: partnerName,
          bookings: bookings,
          completedTrips: bookingCounts['completed'] ?? 0,
          recordedTotalEarnings: totalEarnings,
        ),
      ),
    );
  }

  Widget _buildRecentRequestsSection() {
    final filteredBookings = _filteredBookingsForDashboard();

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
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBookingTabButton('Pending', 0),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Approved', 1),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Ongoing', 2),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Completed', 3),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Cancelled', 4),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (filteredBookings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.darkBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 40,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No ${_dashboardTabLabel(selectedBookingTab).toLowerCase()} requests yet',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filteredBookings
                    .take(3)
                    .map((booking) => _buildRecentRequestShowcaseCard(booking)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingTabButton(String label, int index) {
    final isSelected = selectedBookingTab == index;
    return SizedBox(
      width: label.length > 7 ? 92 : 82,
      child: GestureDetector(
        onTap: () => setState(() => selectedBookingTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.darkBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
    final status = (booking['status'] ?? 'pending').toString().toLowerCase();
    final statusColor = _dashboardBookingStatusColor(status);
    final statusLabel = _dashboardBookingStatusLabel(status);
    final vehicleTitle = '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}'
        .trim();
    final vehicleYear = vehicle?['year']?.toString().trim();
    final imageUrl = _bookingVehicleImageUrl(vehicle);
    final pricePerDay =
        (vehicle?['price_per_day'] as num?)?.toDouble() ??
        double.tryParse(vehicle?['price_per_day']?.toString() ?? '') ??
        0;
    final totalPrice =
        (booking['total_price'] as num?)?.toDouble() ??
        double.tryParse(booking['total_price']?.toString() ?? '') ??
        0;
    final lateReturnFee =
        (booking['late_return_fee'] as num?)?.toDouble() ??
        double.tryParse(booking['late_return_fee']?.toString() ?? '') ??
        0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
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
                      'Requested Rental Price',
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
            if (status == 'active' ||
                status == 'ongoing' ||
                status == 'return_pending_inspection') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleBookingAction(
                    booking['id']?.toString() ?? '',
                    'return_confirmed',
                  ),
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.black,
                    size: 18,
                  ),
                  label: Text(
                    status == 'return_pending_inspection'
                        ? 'Confirm Return Inspection'
                        : 'Confirm Return',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );

  }

  Widget _buildRecentRequestShowcaseCard(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['users'] as Map<String, dynamic>?;
    final status = (booking['status'] ?? 'pending').toString().toLowerCase();
    final statusColor = _dashboardBookingStatusColor(status);
    final statusLabel = _dashboardBookingStatusLabel(status);
    final vehicleTitle = '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}'
        .trim();
    final vehicleYear = vehicle?['year']?.toString().trim();
    final imageUrl = _bookingVehicleImageUrl(vehicle);
    final pricePerDay =
        (vehicle?['price_per_day'] as num?)?.toDouble() ??
        double.tryParse(vehicle?['price_per_day']?.toString() ?? '') ??
        0;
    final totalPrice =
        (booking['total_price'] as num?)?.toDouble() ??
        double.tryParse(booking['total_price']?.toString() ?? '') ??
        0;
    final lateReturnFee =
        (booking['late_return_fee'] as num?)?.toDouble() ??
        double.tryParse(booking['late_return_fee']?.toString() ?? '') ??
        0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            vehicleTitle.isEmpty
                                ? 'Vehicle Request'
                                : vehicleTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${renter?['full_name'] ?? 'Unknown renter'}${vehicleYear != null && vehicleYear.isNotEmpty ? ' • $vehicleYear' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 154,
              width: double.infinity,
              color: AppColors.darkBgSecondary,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    OptimizedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: _buildBookingImageFallback(),
                    )
                  else
                    _buildBookingImageFallback(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
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
                              const SizedBox(width: 6),
                              Text(
                                _bookingDestinationLabel(booking),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatDateRange(
                            booking['start_date']?.toString(),
                            booking['end_date']?.toString(),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildBookingMetricCard(
                title: 'Price / Day',
                value: 'PHP ${_formatMoney(pricePerDay)}',
              ),
              _buildBookingMetricCard(
                title: 'Requested Price',
                value: 'PHP ${_formatMoney(totalPrice)}',
              ),
              if (lateReturnFee > 0)
                _buildBookingMetricCard(
                  title: 'Late Return Fee',
                  value: 'PHP ${_formatMoney(lateReturnFee)}',
                ),
              _buildBookingMetricCard(
                title: 'Renter',
                value: renter?['full_name'] ?? 'Unknown',
              ),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleBookingAction(booking['id'], 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success.withValues(
                        alpha: 0.18,
                      ),
                      foregroundColor: AppColors.success,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _handleBookingAction(booking['id'], 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD96B8A),
                      side: const BorderSide(color: Color(0xFF7B3146)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildBookingImageFallback() {
    return Container(
      color: AppColors.darkBgSecondary,
      alignment: Alignment.center,
      child: const Icon(
        Icons.directions_car_filled_rounded,
        color: AppColors.textSecondary,
        size: 48,
      ),
    );
  }

  Widget _buildBookingMetricCard({
    required String title,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filteredBookingsForDashboard() {
    final statuses = switch (selectedBookingTab) {
      0 => {'pending'},
      1 => {'approved', 'confirmed'},
      2 => {
        'ongoing',
        'active',
        'in_progress',
        'in transit',
        'in_transit',
      },
      3 => {'completed', 'successful', 'done', 'finished'},
      _ => {'cancelled', 'canceled', 'declined', 'rejected'},
    };

    final filtered = bookings.where((booking) {
      final status = (booking['status'] ?? '').toString().toLowerCase().trim();
      return statuses.contains(status);
    }).toList();

    filtered.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  String _dashboardTabLabel(int index) {
    switch (index) {
      case 0:
        return 'Pending';
      case 1:
        return 'Approved';
      case 2:
        return 'Ongoing';
      case 3:
        return 'Completed';
      default:
        return 'Cancelled';
    }
  }

  String _dashboardBookingStatusLabel(String status) {
    switch (status) {
      case 'confirmed':
      case 'ongoing':
      case 'active':
      case 'in_progress':
      case 'in transit':
      case 'in_transit':
        return 'Active';
      case 'completed':
      case 'successful':
      case 'done':
      case 'finished':
        return 'Completed';
      case 'cancelled':
      case 'canceled':
      case 'declined':
      case 'rejected':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  Color _dashboardBookingStatusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'ongoing':
      case 'active':
      case 'in_progress':
      case 'in transit':
      case 'in_transit':
        return AppColors.success;
      case 'completed':
      case 'successful':
      case 'done':
      case 'finished':
        return AppColors.primary;
      case 'cancelled':
      case 'canceled':
      case 'declined':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String? _bookingVehicleImageUrl(Map<String, dynamic>? vehicle) {
    if (vehicle == null) return null;

    for (final key in const [
      'primary_image_url',
      'image_url',
      'photo_url',
      'vehicle_photo_url',
    ]) {
      final value = vehicle[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final images = vehicle['vehicle_images'];
    if (images is List) {
      for (final image in images) {
        if (image is Map<String, dynamic>) {
          final url = image['image_url']?.toString().trim();
          if (url != null && url.isNotEmpty) {
            return url;
          }
        }
      }
    }

    return null;
  }

  String _bookingDestinationLabel(Map<String, dynamic> booking) {
    for (final candidate in [
      booking['destination'],
      booking['dropoff_location'],
      booking['pickup_location'],
      booking['meeting_point'],
    ]) {
      final text = candidate?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }

    return 'Trip route pending';
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
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
      final currentPartnerId = partnerId ?? AuthService().currentUser?.id;

      if (status == 'confirmed' && currentPartnerId != null) {
        await bookingService.confirmPartnerBooking(
          bookingId: bookingId,
          partnerId: currentPartnerId,
        );
      } else if (status == 'return_confirmed' && currentPartnerId != null) {
        final booking = bookings.firstWhere(
          (b) => b['id']?.toString() == bookingId,
          orElse: () => <String, dynamic>{'id': bookingId},
        );
        await _showPartnerInspectionDialog(
          booking,
          inspectionType: 'after',
        );
        _loadPartnerData();
        return;
      }
 else if ((status == 'cancelled' || status == 'rejected') &&
          currentPartnerId != null) {
        await bookingService.rejectPartnerBooking(
          bookingId: bookingId,
          partnerId: currentPartnerId,
          reason: 'Declined by vehicle owner',
        );
      } else {
        await bookingService.updateBookingStatus(bookingId, status);
      }

      _showSuccessSnackBar(
        status == 'confirmed'
            ? 'Booking confirmed!'
            : status == 'return_confirmed'
                ? 'Vehicle return confirmed!'
                : 'Booking declined',
      );

      _loadPartnerData();
    } catch (e) {
      debugPrint('Partner booking action error: $e');
      _showErrorSnackBar('Failed to update booking: $e');
    }
  }

  // ===================== NOTIFICATIONS TAB =====================
  Future<void> _handlePartnerNotificationTap(
    Map<String, dynamic> notification,
  ) async {
    final notificationId = notification['id']?.toString();
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        notification['is_read'] != true) {
      await NotificationService().markAsRead(notificationId);
      final index = notifications.indexWhere(
        (item) => item['id']?.toString() == notificationId,
      );
      if (index >= 0) notifications[index]['is_read'] = true;
      if (mounted) setState(() {});
    }
    if (!mounted) return;

    final target = resolveNotificationTarget(notification);
    if (target.destination == NotificationDestination.messages) {
      final conversationId = target.conversationId;
      if (conversationId == null) {
        setState(() => selectedNavIndex = 2);
      } else {
        Navigator.pushNamed(
          context,
          '/chat-detail',
          arguments: {
            'conversationId': conversationId,
            'recipientName': notification['title']?.toString() ?? 'Chat',
            'recipientAvatar': '',
            'isDarkMode': true,
            'isAutoGenerated': false,
            'userRole': 'partner',
          },
        );
      }
      return;
    }

    final bookingId = target.bookingId;
    final booking = bookingId == null
        ? <String, dynamic>{}
        : bookings.firstWhere(
            (item) => item['id']?.toString() == bookingId,
            orElse: () => <String, dynamic>{},
          );
    if (target.destination == NotificationDestination.tracking &&
        booking.isNotEmpty) {
      await _openTrackingScreen(booking);
      return;
    }
    if (target.destination == NotificationDestination.booking &&
        booking.isNotEmpty) {
      setState(() => selectedNavIndex = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showBookingDetailModal(context, booking);
      });
      return;
    }

    switch (target.destination) {
      case NotificationDestination.payment:
        _openRevenuePayoutScreen();
        return;
      case NotificationDestination.ratings:
        _showRatesReviewsDialog();
        return;
      case NotificationDestination.verification:
        setState(() => selectedNavIndex = 4);
        return;
      case NotificationDestination.application:
      case NotificationDestination.vehicles:
        setState(() => selectedNavIndex = 0);
        return;
      case NotificationDestination.booking:
      case NotificationDestination.tracking:
        setState(() => selectedNavIndex = 1);
        return;
      case NotificationDestination.messages:
        setState(() => selectedNavIndex = 2);
        return;
      case NotificationDestination.announcement:
      case NotificationDestination.general:
        _showPartnerNotificationDetails(notification);
        return;
    }
  }

  void _showPartnerNotificationDetails(Map<String, dynamic> notification) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(notification['title']?.toString() ?? 'Notification'),
        content: Text(
          notification['message']?.toString().trim().isNotEmpty == true
              ? notification['message'].toString()
              : 'No additional details are available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return Column(
      children: [
        _buildCenteredTabHeader(
          'Notifications',
          trailing: notifications.isNotEmpty
              ? TextButton(
                  onPressed: _markAllNotificationsRead,
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
        ),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: RoleTabHeader(
                  title: 'Notifications',
                  subtitle: 'Fleet updates, booking activity, and reminders',
                  icon: Icons.notifications_outlined,
                  badge:
                      '${notifications.where((item) => item['is_read'] != true).length} unread',
                  action: _partnerUnreadNotificationCount > 0
                      ? TextButton.icon(
                          onPressed: _markAllNotificationsRead,
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
              ),
              const SizedBox(height: 18),
              Expanded(
                child: notifications.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: const [
                          RoleEmptyStateCard(
                            icon: Icons.notifications_none,
                            title: 'No notifications yet',
                            message:
                                'Fleet updates, booking requests, and reminders will appear here.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          final visual = notificationVisualFor(notif);
                          return NotificationItem(
                            icon: visual.icon,
                            title: notif['title'] ?? 'Notification',
                            message: notif['message'] ?? '',
                            timestamp: _formatTime(notif['created_at']),
                            iconColor: visual.color,
                            isRead: notif['is_read'] == true,
                            onTap: () => _handlePartnerNotificationTap(notif),
                            onLongPress: () => _showPartnerNotificationDetails(notif),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== MESSAGES TAB =====================
  Widget _buildMessagesTab() {
    return Column(
      children: [
        _buildCenteredTabHeader('Messages'),
        Expanded(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: RoleTabHeader(
                  title: 'Messages',
                  subtitle: 'Renter conversations and customer service',
                  icon: Icons.chat_bubble_outline,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: conversations.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: const [
                          RoleEmptyStateCard(
                            icon: Icons.chat_bubble_outline,
                            title: 'No messages yet',
                            message:
                                'Renter booking chats and customer service conversations will appear here.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conv = conversations[index];
                          final isCustomerService = conv['bookings'] is! Map;
                          final booking = conv['bookings'] as Map?;
                          final vehicle = booking?['vehicles'] as Map?;
                          final vehicleName =
                              [vehicle?['brand'], vehicle?['model']]
                                  .where(
                                    (value) =>
                                        value?.toString().trim().isNotEmpty ==
                                        true,
                                  )
                                  .join(' ');
                          final topicTitle = isCustomerService
                              ? 'Customer Service'
                              : vehicleName.isNotEmpty
                              ? '$vehicleName Booking'
                              : 'Booking Conversation';
                          final imageUrl =
                              conv['vehicle_image_url']?.toString() ?? '';
                          final messages =
                              conv['messages'] as List<dynamic>? ?? [];
                          final lastMessage = messages.isNotEmpty
                              ? messages.last['content'] ?? ''
                              : 'No messages';

                          return ConversationTile(
                            senderName: topicTitle,
                            lastMessage: lastMessage,
                            timestamp: _formatTime(conv['updated_at']),
                            unreadCount: 0,
                            imageUrl: imageUrl,
                            fallbackIcon: isCustomerService
                                ? Icons.support_agent
                                : Icons.directions_car_outlined,
                            onTap: () {
                              final conversationId = conv['id'];
                              Navigator.of(context)
                                  .pushNamed(
                                    '/chat-detail',
                                    arguments: {
                                      'conversationId': conversationId,
                                      'recipientName': topicTitle,
                                      'recipientAvatar': imageUrl,
                                      'isDarkMode': true,
                                      'isCustomerService': isCustomerService,
                                      'userRole': 'partner',
                                    },
                                  )
                                  .then((_) => _loadPartnerData());
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== BOOKINGS TAB =====================
  // ===================== BOOKINGS TAB =====================
  Widget _buildBookingsTab() {
    const statusList = ['pending', 'approved', 'ongoing', 'completed', 'cancelled'];
    final filteredBookings = bookings
        .where((booking) => _matchesBookingTab(booking, _partnerBookingStatus))
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

    return Column(
      children: [
        _buildCenteredTabHeader('My Bookings'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPartnerData,
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              children: [
                RoleTabHeader(
                  title: 'Rental Bookings',
                  subtitle:
                      'Requests, active rentals, completed trips, and tracking',
                  icon: Icons.calendar_month_outlined,
                  badge: '${bookings.length} total',
                ),
                const SizedBox(height: 12),
                _buildPartnerStatusPillTabs(statusList),
                const SizedBox(height: 14),
                if (_partnerBookingStatus == 'ongoing' && filteredBookings.isNotEmpty) ...[
                  _buildActiveBookingsHero(filteredBookings),
                  const SizedBox(height: 14),
                ],
                if (filteredBookings.isEmpty)
                  RoleEmptyStateCard(
                    icon: Icons.calendar_today_outlined,
                    title:
                        'No ${_bookingTabLabel(_partnerBookingStatus).toLowerCase()} bookings',
                    message:
                        'Booking requests and rental updates will appear here once available.',
                  )
                else
                  ...filteredBookings.map(
                    (booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPartnerBookingCard(
                        booking,
                        emphasizeLive: _partnerBookingStatus == 'ongoing',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerStatusPillTabs(List<String> statuses) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((status) {
          final selected = _partnerBookingStatus == status;
          final count = bookings
              .where((b) => _matchesBookingTab(b, status))
              .length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _partnerBookingStatus = status),
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
                  '${_bookingTabLabel(status)} ($count)',
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
    final statusGroup = bookingStatusGroup(booking['status']);
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
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E0C0),
                  borderRadius: BorderRadius.circular(14),
                ),
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
          if (statusGroup == BookingStatusGroup.ongoing) ...[
            const SizedBox(height: 14),
            BookingReturnCountdown(booking: booking),
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
              if (statusGroup == BookingStatusGroup.ongoing) ...[
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
              ],
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
    return bookingStatusGroup(booking['status']).name == tabKey;
  }

  String _bookingTabLabel(String tabKey) {
    switch (tabKey) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
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
    return bookingStatusLabel(bookingStatusGroup(status));
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

  Future<void> _openPartnerInspectionRecordOrForm(
    Map<String, dynamic> booking, {
    required String inspectionType,
    required bool allowCreate,
  }) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    try {
      final record = await BookingInspectionService().getCompletedInspection(
        bookingId: bookingId,
        inspectionType: inspectionType,
      );
      if (!mounted) return;
      await showVehicleInspectionRecordDialog(
        context,
        record: record,
        title: inspectionType == 'before'
            ? 'Submitted Pre-Trip Checklist'
            : 'Submitted Return Checklist',
      );
    } catch (_) {
      if (allowCreate) {
        await _showPartnerInspectionDialog(
          booking,
          inspectionType: inspectionType,
        );
        return;
      }
      if (!mounted) return;
      _showErrorSnackBar('No submitted checklist is available yet');
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
  Future<void> _confirmPartnerFinalPayment(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    final actorId = AuthService().currentUser?.id;
    if (bookingId.isEmpty || actorId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Full Payment'),
        content: const Text(
          'Confirm that the full rental balance and any late-return fee have been paid. You will rate the renter after this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await BookingService().confirmFinalPayment(
        bookingId: bookingId,
        actorId: actorId,
        actorRole: 'partner',
      );
      await _loadPartnerData();
      if (!mounted) return;
      _showSuccessSnackBar('Full payment confirmed. Opening renter rating...');
      await _openPartnerRenterRating(context, booking);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openPartnerRenterRating(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TripRatingFlowScreen(
          bookingId: booking['id'].toString(),
          reviewerRole: 'partner',
          title: 'Rate Renter',
          subtitle:
              'Your renter rating is required before this trip can continue to final completion.',
        ),
      ),
    );
    if (submitted == true) {
      await _loadPartnerData();
      if (!mounted) return;
      _showSuccessSnackBar(
        'Renter rating saved. Waiting for the remaining required ratings.',
      );
    }
  }

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
    final completionState = BookingService().getTripCompletionState(booking);
    final completionStage = completionState['completionStage']?.toString();
    final canAssignDriver =
        withDriver &&
        driverId == null &&
        (status == 'pending' || status == 'approved' || status == 'confirmed');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pageContext) => Scaffold(
          backgroundColor: AppColors.darkBg,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            elevation: 0,
            title: const Text(
              'Booking Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          body: SafeArea(
            child: BookingDetailModal(
              booking: booking,
              vehicle: vehicle,
              renter: renter,
              showHeader: false,
              onApprove: () => _handleBookingApproval(pageContext, booking),
              onReject: () => _handleBookingRejection(pageContext, booking),
              onAssignDriver: canAssignDriver
                  ? () => _showDriverAssignmentModal(pageContext, booking)
                  : null,
              onReviewDocs: () => _showPartnerBookingSafetyReview(booking),
              onMessage:
                  status == 'approved' ||
                      status == 'confirmed' ||
                      status == 'active' ||
                      status == 'ongoing' ||
                      status == 'return_pending_inspection'
                  ? () => _openBookingConversation(booking)
                  : null,
              onBeforeInspection: status == 'approved' || status == 'confirmed'
                  ? () => _openPartnerInspectionRecordOrForm(
                      booking,
                      inspectionType: 'before',
                      allowCreate: true,
                    )
                  : null,
              onViewBeforeInspection:
                  status == 'active' ||
                      status == 'ongoing' ||
                      status == 'return_pending_inspection'
                  ? () => _openPartnerInspectionRecordOrForm(
                      booking,
                      inspectionType: 'before',
                      allowCreate: false,
                    )
                  : null,
              onAfterInspection:
                  status == 'active' ||
                      status == 'ongoing' ||
                      status == 'return_pending_inspection'
                  ? () => _showPartnerInspectionDialog(
                      booking,
                      inspectionType: 'after',
                    )
                  : null,
              onConfirmPayment: completionStage == 'awaiting_payment'
                  ? () => _confirmPartnerFinalPayment(parentContext, booking)
                  : null,
              onRateTrip: completionStage == 'partner_rating'
                  ? () => _openPartnerRenterRating(parentContext, booking)
                  : null,
              onReceipt: () => BookingReceiptService.shareReceipt(booking),
            ),
          ),
        ),
      ),
    );
  }

  /// 🚗 Show driver assignment modal for bookings with drivers
  Future<void> _showPartnerBookingSafetyReview(
    Map<String, dynamic> booking,
  ) async {
    final files = [
      MapEntry(
        'Signature image',
        booking['renter_signature_url']?.toString() ?? '',
      ),
      MapEntry('Valid ID', booking['renter_valid_id_url']?.toString() ?? ''),
      MapEntry('Selfie', booking['renter_selfie_url']?.toString() ?? ''),
      MapEntry(
        'Co-traveler signature image',
        booking['co_traveler_signature_url']?.toString() ?? '',
      ),
      MapEntry(
        'Co-traveler valid ID',
        booking['co_traveler_valid_id_url']?.toString() ?? '',
      ),
      MapEntry(
        'Co-traveler selfie',
        booking['co_traveler_selfie_url']?.toString() ?? '',
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Renter Safety Review',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPartnerReviewLine(
                  'Digital signature',
                  booking['renter_signature_text']?.toString(),
                ),
                _buildPartnerReviewLine(
                  'Emergency contact',
                  [
                        booking['emergency_contact_name']?.toString(),
                        booking['emergency_contact_relationship']?.toString(),
                        booking['emergency_contact_phone']?.toString(),
                      ]
                      .where((part) => part != null && part.trim().isNotEmpty)
                      .join(' - '),
                ),
                _buildPartnerReviewLine(
                  'Co-traveler',
                  [
                        booking['co_traveler_name']?.toString(),
                        booking['co_traveler_phone']?.toString(),
                      ]
                      .where((part) => part != null && part.trim().isNotEmpty)
                      .join(' - '),
                ),
                _buildPartnerReviewLine(
                  'Co-traveler license',
                  booking['co_traveler_license']?.toString(),
                ),
                _buildPartnerReviewLine(
                  'Co-traveler signature',
                  booking['co_traveler_signature_text']?.toString(),
                ),
                const SizedBox(height: 12),
                ...files.map((file) {
                  final url = file.value.trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton.icon(
                      onPressed: url.isEmpty
                          ? null
                          : () => launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        url.isEmpty ? '${file.key}: missing' : file.key,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerReviewLine(String label, String? value) {
    final clean = value?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            clean == null || clean.isEmpty ? 'Not provided' : clean,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Future<void> _showPartnerInspectionDialog(
    Map<String, dynamic> booking, {
    required String inspectionType,
  }) async {
    final currentUserId = AuthService().currentUser?.id;
    final bookingId = booking['id']?.toString() ?? '';
    if (currentUserId == null || bookingId.isEmpty) return;

    final fuelController = TextEditingController();
    final tiresController = TextEditingController();
    final magsController = TextEditingController();
    final exteriorRemarksController = TextEditingController(text: 'Good');
    final interiorRemarksController = TextEditingController(text: 'Good');
    final autosweepBalanceController = TextEditingController(text: 'N/A');
    final easytripBalanceController = TextEditingController(text: 'N/A');
    final toolsRemarksController = TextEditingController(text: 'Good');
    final cleanlinessRemarksController = TextEditingController(text: 'Good');
    final otherItemsController = TextEditingController(text: 'N/A');
    final othersRemarksController = TextEditingController(text: 'Good');
    final releasedByController = TextEditingController();
    final receivedByController = TextEditingController();
    final inspectionControllers = <TextEditingController>[
      fuelController,
      tiresController,
      magsController,
      exteriorRemarksController,
      interiorRemarksController,
      autosweepBalanceController,
      easytripBalanceController,
      toolsRemarksController,
      cleanlinessRemarksController,
      otherItemsController,
      othersRemarksController,
      releasedByController,
      receivedByController,
    ];
    final checklistItems = <String, bool>{
      for (final key in BookingInspectionService.requiredChecklistKeys)
        key: false,
    };
    final selectedEvidence = <PlatformFile>[];

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.fact_check_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inspectionType == 'before'
                                  ? 'Pre-Trip Vehicle Release Inspection'
                                  : 'Post-Trip Vehicle Return Inspection',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              inspectionType == 'before'
                                  ? 'Required before this booking can move to Ongoing.'
                                  : 'Record the condition returned by the renter.',
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
                  const SizedBox(height: 16),
                  VehicleInspectionChecklistFields(
                    values: checklistItems,
                    isDark: true,
                    onChanged: (entry) => setSheetState(
                      () => checklistItems[entry.key] = entry.value,
                    ),
                    onSelectAll: (selected) => setSheetState(() {
                      for (final key in checklistItems.keys) {
                        checklistItems[key] = selected;
                      }
                    }),
                  ),
                  const SizedBox(height: 4),
                  VehicleInspectionSupplementalFields(
                    isDark: true,
                    fuelLevelController: fuelController,
                    tiresController: tiresController,
                    magsController: magsController,
                    exteriorRemarksController: exteriorRemarksController,
                    interiorRemarksController: interiorRemarksController,
                    autosweepBalanceController: autosweepBalanceController,
                    easytripBalanceController: easytripBalanceController,
                    toolsRemarksController: toolsRemarksController,
                    cleanlinessRemarksController: cleanlinessRemarksController,
                    otherItemsController: otherItemsController,
                    othersRemarksController: othersRemarksController,
                    releasedByController: releasedByController,
                    receivedByController: receivedByController,
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.media,
                        allowMultiple: true,
                        withData: true,
                      );
                      if (result == null) return;
                      final usableFiles = result.files
                          .where(
                            (file) =>
                                file.bytes != null &&
                                file.size <= 25 * 1024 * 1024,
                          )
                          .take(8)
                          .toList();
                      setSheetState(() {
                        selectedEvidence
                          ..clear()
                          ..addAll(usableFiles);
                      });
                    },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add photos or videos'),
                  ),
                  if (selectedEvidence.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedEvidence
                            .map(
                              (file) => InputChip(
                                label: Text(
                                  file.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onDeleted: () => setSheetState(
                                  () => selectedEvidence.remove(file),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final allChecked = BookingInspectionService
                            .requiredChecklistKeys
                            .every((key) => checklistItems[key] == true);
                        final requiredFieldsReady =
                            fuelController.text.trim().isNotEmpty &&
                            tiresController.text.trim().isNotEmpty &&
                            magsController.text.trim().isNotEmpty &&
                            releasedByController.text.trim().isNotEmpty &&
                            receivedByController.text.trim().isNotEmpty;
                        if (!allChecked ||
                            !requiredFieldsReady ||
                            selectedEvidence.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Complete all checklist items, handover names, and attach at least one photo or video.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(sheetContext, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(
                        inspectionType == 'before'
                            ? 'Submit and Start Trip'
                            : 'Submit Return Checklist',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (shouldSave != true) {
      for (final controller in inspectionControllers) {
        controller.dispose();
      }
      return;
    }

    final missingRequiredFields =
        fuelController.text.trim().isEmpty ||
        tiresController.text.trim().isEmpty ||
        magsController.text.trim().isEmpty ||
        releasedByController.text.trim().isEmpty ||
        receivedByController.text.trim().isEmpty;
    if (missingRequiredFields || selectedEvidence.isEmpty) {
      _showErrorSnackBar(
        selectedEvidence.isEmpty
            ? 'Please attach at least one checklist photo or video'
            : 'Please complete the required condition and handover fields',
      );
      for (final controller in inspectionControllers) {
        controller.dispose();
      }
      return;
    }

    try {
      if (selectedEvidence.isNotEmpty) {
        _showSuccessSnackBar('Uploading checklist evidence...');
      }
      final evidenceUrls = <String>[];
      for (final file in selectedEvidence) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        evidenceUrls.add(
          await BookingInspectionService().uploadEvidenceBytes(
            userId: currentUserId,
            bookingId: bookingId,
            bytes: bytes,
            extension: file.extension ?? 'jpg',
          ),
        );
      }
      await BookingInspectionService().saveInspection(
        bookingId: bookingId,
        inspectionType: inspectionType,
        inspectorId: currentUserId,
        fuelLevel: fuelController.text.trim(),
        cleanliness: cleanlinessRemarksController.text.trim(),
        scratches: exteriorRemarksController.text.trim(),
        remarks: othersRemarksController.text.trim(),
        tiresDetails: tiresController.text.trim(),
        magsDetails: magsController.text.trim(),
        autosweepBalance: autosweepBalanceController.text.trim(),
        easytripBalance: easytripBalanceController.text.trim(),
        otherItems: otherItemsController.text.trim(),
        sectionRemarks: {
          'exterior': exteriorRemarksController.text.trim(),
          'interior': interiorRemarksController.text.trim(),
          'tools_accessories': toolsRemarksController.text.trim(),
          'cleanliness': cleanlinessRemarksController.text.trim(),
          'others': othersRemarksController.text.trim(),
        },
        evidenceUrls: evidenceUrls,
        checklistItems: checklistItems,
        releasedBy: releasedByController.text,
        receivedBy: receivedByController.text,
      );
      if (inspectionType == 'before') {
        await BookingService().startBookingAfterInspection(
          bookingId: bookingId,
          inspectorId: currentUserId,
        );
        if (!mounted) return;
        _showSuccessSnackBar('Release checklist submitted. The trip is now ongoing.');
      } else {
        final currentPaymentStatus = (booking['final_payment_status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        bool confirmPaymentNow = false;

        if (currentPaymentStatus != 'paid') {
          final choice = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: AppColors.darkBgSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.borderColor),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Final Payment Unchecked',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: const Text(
                'The final payment for this booking has not been checked or confirmed yet.\n\n'
                'Approving the return now will record the vehicle checklist. Would you like to confirm the payment now, or proceed anyway?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 'cancel'),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, 'proceed_unpaid'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    foregroundColor: Colors.orange,
                  ),
                  child: const Text('Proceed Return (Stay Ongoing)'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, 'confirm_payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Confirm Payment & Complete'),
                ),
              ],
            ),
          );

          if (choice == 'cancel' || choice == null) return;
          if (choice == 'confirm_payment') {
            confirmPaymentNow = true;
          }
        }

        await BookingService().completeBookingAfterInspection(
          bookingId: bookingId,
          inspectorId: currentUserId,
          confirmPaymentIfUnpaid: confirmPaymentNow,
        );

        if (!mounted) return;
        _showSuccessSnackBar(
          (currentPaymentStatus == 'paid' || confirmPaymentNow)
              ? 'Return checklist submitted. Trip completed successfully!'
              : 'Return checklist submitted. Trip remains ongoing until final payment is confirmed.',
        );
      }
      await _loadPartnerData();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to save checklist: $e');
    } finally {
      for (final controller in inspectionControllers) {
        controller.dispose();
      }
    }
  }

  Widget _buildPartnerInspectionField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.darkBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildPartnerInspectionCondition(
    TextEditingController controller,
    String label, {
    required VoidCallback refresh,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final option in const ['Good', 'Bad']) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(option),
              selected: controller.text == option,
              onSelected: (_) {
                controller.text = option;
                refresh();
              },
              selectedColor: option == 'Good'
                  ? AppColors.success.withValues(alpha: 0.22)
                  : AppColors.error.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: controller.text == option
                    ? option == 'Good'
                          ? AppColors.success
                          : AppColors.error
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDriverAssignmentModal(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final bookingService = BookingService();

    try {
      final bookingDate = DateTime.tryParse(
        (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
      );
      final drivers = await bookingService.getAvailableVerifiedDrivers(
        bookingDate: bookingDate,
      );

      if (!mounted || !context.mounted) return;

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
    return UnifiedProfileScreen(
      role: 'partner',
      isDarkMode: widget.isDarkMode,
      onThemeToggle: widget.onThemeToggle,
      onLogout: _handleLogout,
      onOpenSupport: _openCustomerServiceConversation,
      onOpenVerification: () =>
          Navigator.pushNamed(context, '/owner-verification'),
      onProfileUpdated: _loadPartnerData,
      stats: [
        ProfileStatItem(
          label: 'Rentals',
          value: activeVehicles.toString(),
          onTap: () => setState(() => selectedNavIndex = 2),
        ),
        ProfileStatItem(
          label: 'Bookings',
          value: bookingCounts['total']?.toString() ?? '0',
          onTap: () => setState(() => selectedNavIndex = 1),
        ),
        ProfileStatItem(
          label: 'Rating',
          value: ratingCount > 0 ? rating.toStringAsFixed(1) : '0.0',
          onTap: _showRatesReviewsDialog,
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

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = parseMessageTimestamp(dateStr);
      if (date == null) return '';
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
  final VoidCallback? onReviewDocs;
  final VoidCallback? onMessage;
  final VoidCallback? onBeforeInspection;
  final VoidCallback? onViewBeforeInspection;
  final VoidCallback? onAfterInspection;
  final VoidCallback? onConfirmPayment;
  final VoidCallback? onRateTrip;
  final VoidCallback? onReceipt;
  final bool showHeader;

  const BookingDetailModal({
    super.key,
    required this.booking,
    this.vehicle,
    this.renter,
    required this.onApprove,
    required this.onReject,
    this.onAssignDriver,
    this.onReviewDocs,
    this.onMessage,
    this.onBeforeInspection,
    this.onViewBeforeInspection,
    this.onAfterInspection,
    this.onConfirmPayment,
    this.onRateTrip,
    this.onReceipt,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final startDate = booking['start_date'] ?? '';
    final endDate = booking['end_date'] ?? '';
    final totalPrice = booking['total_price'] ?? 0;
    final withDriver = _bookingNeedsDriver(booking['with_driver']);
    final driverId = booking['driver_id'];
    final status = (booking['status'] as String? ?? 'pending').toLowerCase();

    Widget detailContent({ScrollController? scrollController}) {
      return SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (showHeader) ...[
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
            ],

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

            if (onReviewDocs != null ||
                onMessage != null ||
                onBeforeInspection != null ||
                onViewBeforeInspection != null ||
                onAfterInspection != null ||
                onReceipt != null) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (onReviewDocs != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onReviewDocs?.call();
                      },
                      icon: const Icon(Icons.verified_user_outlined, size: 16),
                      label: const Text('Review Docs'),
                    ),
                  if (onMessage != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onMessage?.call();
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Message'),
                    ),
                  if (onBeforeInspection != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onBeforeInspection?.call();
                      },
                      icon: const Icon(Icons.fact_check_outlined, size: 16),
                      label: const Text('Submit Checklist & Start Trip'),
                    ),
                  if (onViewBeforeInspection != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onViewBeforeInspection?.call();
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View Pre-Trip Checklist'),
                    ),
                  if (onAfterInspection != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onAfterInspection?.call();
                      },
                      icon: const Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 16,
                      ),
                      label: const Text('After Check'),
                    ),
                  if (onReceipt != null)
                    OutlinedButton.icon(
                      onPressed: onReceipt,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download Receipt'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
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
            ] else if (onConfirmPayment != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirmPayment?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text(
                    'Confirm Full Payment',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else if (onRateTrip != null) ...[
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
                    'Rate Renter',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (!showHeader) {
      return detailContent();
    }

    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) =>
          detailContent(scrollController: scrollController),
    );
  }
}
