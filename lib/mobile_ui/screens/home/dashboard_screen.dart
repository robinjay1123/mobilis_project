import 'dart:async';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/reservation_payment_service.dart';
import '../../../services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../renter/vehicle_search_screen.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/favorite_vehicle_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/notification_permission_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../services/renter_marketing_notification_service.dart';
import '../../../services/verification_service.dart';
import '../../../services/trip_rating_service.dart';
import '../../../services/booking_receipt_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/cost_breakdown_row.dart';
import '../../widgets/trip_timeline_step.dart';
import '../../widgets/role_ui.dart';
import '../../widgets/optimized_network_image.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/location_picker_modal.dart';
import '../../widgets/vehicle_image_carousel.dart';
import '../../widgets/relative_time_text.dart';
import '../../widgets/booking_return_countdown.dart';
import '../profile/settings_screen.dart';
import '../profile/payment_methods_screen.dart';
import '../profile/verification_documents_screen.dart';
import '../../widgets/digital_handover_pass_modal.dart';
import '../profile/ratings_reviews_screen.dart';
import '../profile/trip_rating_flow_screen.dart';
import '../profile/unified_profile_screen.dart';
import '../tracking/trip_navigation_screen.dart';
import '../vehicle/reservation_payment_screen.dart';
import '../../widgets/return_inspection_notice_modal.dart';
import '../../widgets/trip_route_history_dialog.dart';
import '../../widgets/trip_location_map_dialog.dart';
import '../../../utils/booking_status.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/notification_target.dart';
import '../../../utils/notification_visual.dart';
import '../../../utils/input_validation.dart';

part 'tabs/dashboard_home_tab.dart';
part 'tabs/dashboard_bookings_tab.dart';
part 'tabs/dashboard_notifications_tab.dart';
part 'tabs/dashboard_messages_tab.dart';
part 'tabs/dashboard_profile_tab.dart';
part 'sheets/renter_booking_details_sheet.dart';
part 'widgets/dashboard_helper_widgets.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // ---------------------------------------------------------------------------
  // State fields
  // ---------------------------------------------------------------------------
  String userName = 'User';
  String userLocation = 'Not specified';
  String? userAvatarUrl;
  bool emailConfirmed = true;
  bool userVerified = false;
  String userVerificationStatus = 'unverified';
  int _userCreatedYear = DateTime.now().year;
  int _totalTrips = 0;
  double _userRating = 0.0;

  int selectedNavIndex = 0;
  int? selectedBookingIndex;
  String _selectedBookingStatus = 'Pending';
  String? selectedProfilePage;
  String selectedCategory = '';

  bool _isLoadingVehicles = false;
  bool _hasShownVerificationPrompt = false;
  bool _dimCustomerServiceFab = false;
  DateTime? _lastBackPressedAt;
  DateTime? _bookingFilterFrom;
  DateTime? _bookingFilterTo;
  double? _nearbyLatitude;
  double? _nearbyLongitude;
  String? _nearbyLocationLabel;
  List<String> _nearbyLocationTokens = [];
  String _committedVehicleSearch = '';
  bool _isSearchingVehicles = false;
  bool _isOpeningBookNowCalendar = false;
  String? _navigatingVehicleId;

  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filteredVehicles = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _conversations = [];
  Set<String> _favoriteVehicleIds = {};

  final TextEditingController _searchController = TextEditingController();

  // 🔄 Real-time verification status listener
  RealtimeChannel? _verificationSubscription;

  // 🔔 Real-time notifications listener
  RealtimeChannel? _notificationsSubscription;
  Timer? _notificationsAutoRefreshTimer;

  // 📅 Real-time bookings listener
  RealtimeChannel? _bookingsSubscription;
  RealtimeChannel? _conversationMembershipSubscription;
  RealtimeChannel? _messagesSubscription;
  Set<String> _messageConversationIds = const {};
  Timer? _conversationReloadDebounce;
  StreamSubscription<Map<String, dynamic>>? _pushNotificationTapSubscription;

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
    final pushService = PushNotificationService();
    _pushNotificationTapSubscription = pushService.notificationTaps.listen((
      payload,
    ) {
      if (mounted) _handleNotificationTap({'raw': payload});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = pushService.takePendingNotificationTap();
      if (pending != null && mounted) {
        _handleNotificationTap({'raw': pending});
      }
    });
    _checkAuth();
    _loadUserData();
    _initializeConnectivity();
    _loadVehicles();
    _loadBookings(); // 📅 Load renter's bookings
    _loadConversations();
    _setupVerificationListener(); // 🔄 Listen for real-time verification updates
    _loadNotifications(); // 🔔 Load notifications
    _setupNotificationsListener(); // 🔔 Listen for new notifications
    RenterMarketingNotificationService()
        .checkAndTriggerDailyRenterNotification();
    _notificationsAutoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (mounted) _loadNotifications();
      },
    );
    _setupBookingsListener(); // 📅 Listen for booking updates
    _setupConversationMembershipListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pushNotificationTapSubscription?.cancel();
    _verificationSubscription?.unsubscribe(); // ✅ Clean up realtime listener
    _notificationsSubscription
        ?.unsubscribe(); // ✅ Clean up notifications listener
    _notificationsAutoRefreshTimer?.cancel();
    _bookingsSubscription?.unsubscribe(); // ✅ Clean up bookings listener
    _conversationMembershipSubscription?.unsubscribe();
    _messagesSubscription?.unsubscribe();
    _conversationReloadDebounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Auth / data helpers (stubs — keep your existing implementations)
  // ---------------------------------------------------------------------------
  void _checkAuth() {}

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
      final avatarUrl =
          (resp?['avatar_url'] ??
                  resp?['profile_picture_url'] ??
                  metadata['avatar_url'] ??
                  metadata['profile_picture_url'] ??
                  metadata['picture'])
              ?.toString()
              .trim();

      final hasSavedLocation = location != null && location.isNotEmpty;

      if (resp != null) {
        setState(() {
          userName = (fullName != null && fullName.isNotEmpty)
              ? toProfessionalTitleCase(fullName)
              : toProfessionalTitleCase(
                  user.email?.split('@').first ?? userName,
                );
          userLocation = (location != null && location.isNotEmpty)
              ? location
              : userLocation;
          userAvatarUrl = avatarUrl != null && avatarUrl.isNotEmpty
              ? avatarUrl
              : userAvatarUrl;
          userVerified =
              resp['is_verified'] as bool? ??
              (resp['id_verified'] as bool?) ??
              userVerified;
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
                ? toProfessionalTitleCase(fullName)
                : toProfessionalTitleCase(
                    user.email?.split('@').first ?? userName,
                  );
            if (location != null && location.isNotEmpty) {
              userLocation = location;
            }
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              userAvatarUrl = avatarUrl;
            }
          });
        }
        if (!hasSavedLocation) {
          await _getDeviceLocation();
        }
      }

      try {
        final bookingsResp = await Supabase.instance.client
            .from('bookings')
            .select('id,status')
            .eq('renter_id', user.id);
        final list = List<Map<String, dynamic>>.from(bookingsResp);
        final completedCount = list.where((b) {
          final s = b['status']?.toString().toLowerCase().trim() ?? '';
          return s == 'completed' || s == 'returned' || s == 'settled';
        }).length;
        final ratingSummary = await TripRatingService().getRatingSummary(user.id);
        final ratingAvg = (ratingSummary['average'] as num?)?.toDouble() ?? 0.0;
        if (mounted) {
          setState(() {
            _totalTrips = completedCount;
            _userRating = ratingAvg;
          });
        }
      } catch (e) {
        debugPrint('Error fetching renter trips & ratings: $e');
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
      final record = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (record == null) return null;

      final verificationState =
          await VerificationService.getUserVerificationState(userId);
      return {
        ...record,
        'is_verified': verificationState['is_verified'] as bool? ?? false,
      };
    } catch (e) {
      debugPrint('Profile lookup skipped for users: $e');
      return null;
    }
  }

  void _setupVerificationListener() {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) {
        debugPrint('⚠️ No user found for real-time listener');
        return;
      }

      final supabase = Supabase.instance.client;

      _verificationSubscription = supabase.realtime.channel(
        'public:users:id=eq.${user.id}',
      );

      _verificationSubscription!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: user.id,
            ),
            callback: (payload) {
              debugPrint('✅ Real-time update received: ${payload.eventType}');
              final newRecord = payload.newRecord as Map<String, dynamic>?;
              if (newRecord != null) {
                final updatedAvatar =
                    (newRecord['avatar_url'] ??
                            newRecord['profile_picture_url'])
                        ?.toString()
                        .trim();
                final status = newRecord['verification_status']
                    ?.toString()
                    .trim()
                    .toLowerCase();
                final isVerified =
                    (newRecord['id_verified'] as bool? ?? false) ||
                    VerificationService.isVerifiedStatus(status);
                final hasPendingApplication =
                    status == 'pending' || status == 'submitted';
                if (isVerified != userVerified) {
                  if (mounted) {
                    setState(() {
                      userVerified = isVerified;
                      _hasShownVerificationPrompt =
                          isVerified || hasPendingApplication;
                    });
                  }
                  // Show verification prompt if newly unverified
                  if (!isVerified &&
                      !hasPendingApplication &&
                      !_hasShownVerificationPrompt &&
                      mounted) {
                    _showVerificationPromptOnce();
                  }
                }
                if (updatedAvatar != null &&
                    updatedAvatar.isNotEmpty &&
                    updatedAvatar != userAvatarUrl &&
                    mounted) {
                  setState(() => userAvatarUrl = updatedAvatar);
                }
              }
            },
          )
          .subscribe();

      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted) return;
        await _showVerificationPromptOnce();
      });
    } catch (e) {
      debugPrint('⚠️ Error setting up verification listener: $e');
    }
  }

  Future<void> _showVerificationPromptOnce() async {
    if (_hasShownVerificationPrompt) return;
    final user = AuthService().currentUser;
    if (user == null) return;

    final verificationState =
        await VerificationService.getUserVerificationState(user.id);
    final isVerified = verificationState['is_verified'] as bool? ?? false;
    final status = verificationState['verification_status']
        ?.toString()
        .trim()
        .toLowerCase();
    final hasPendingApplication = status == 'pending' || status == 'submitted';

    if (!mounted) return;

    setState(() {
      userVerified = isVerified;
      userVerificationStatus = status ?? 'unverified';
      if (isVerified || hasPendingApplication) {
        _hasShownVerificationPrompt = true;
      }
    });

    if (isVerified || hasPendingApplication) {
      return;
    }

    _hasShownVerificationPrompt = true;
    _showRentalVerificationModal();
  }

  Future<void> _loadNotifications() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return;

      final systemNotifications =
          await NotificationService().getNotifications(user.id);

      if (mounted) {
        setState(() {
          _notifications = systemNotifications;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading notifications: $e');
    }
  }

  Future<void> _markAllNotificationsRead() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      await NotificationService().markAllAsRead(user.id);
      await _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error marking all notifications read: $e');
    }
  }

  Future<void> _markAllMessagesRead() async {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return;

    final conversationIds = _uiConversations()
        .map((conversation) => conversation['conversationId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (conversationIds.isEmpty) return;

    try {
      final chatService = ChatService();
      await Future.wait(
        conversationIds.map(
          (conversationId) =>
              chatService.markMessagesAsRead(conversationId, userId),
        ),
      );
      await _loadConversations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All messages marked as read')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark messages as read: $error')),
      );
    }
  }

  Future<void> _loadConversations() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return;

      final chatService = ChatService();
      final conversations = await chatService.getConversations(user.id);
      
      final otherUserFutures = conversations.map((c) {
        final cId = c['id']?.toString() ?? '';
        if (cId.isEmpty) return Future<Map<String, dynamic>?>.value(null);
        return chatService.getOtherUser(cId, user.id).catchError((err) {
          debugPrint('Single otherUser fetch note: $err');
          return null;
        });
      }).toList();
      final otherUsers = await Future.wait(otherUserFutures);

      final hydratedConversations = <Map<String, dynamic>>[];
      for (int i = 0; i < conversations.length; i++) {
        final conversation = conversations[i];
        final otherUser = otherUsers[i];
        final messages = List<Map<String, dynamic>>.from(
          conversation['messages'] as List? ?? const [],
        );

        messages.sort((a, b) {
          final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
          final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        final lastMessage = messages.isNotEmpty ? messages.first : null;
        final unreadCount = messages.where((message) {
          final senderId = message['sender_id']?.toString();
          final isRead = message['is_read'] == true;
          return senderId != user.id && !isRead;
        }).length;

        hydratedConversations.add({
          ...Map<String, dynamic>.from(conversation),
          'other_user': otherUser,
          'last_message': lastMessage,
          'unread_count': unreadCount,
        });
      }

      ChatService.sortConversationsByPriority(hydratedConversations);

      if (mounted) {
        setState(() {
          _conversations = hydratedConversations;
        });
        unawaited(
          _refreshMessageSubscription(
            hydratedConversations
                .map((conversation) => conversation['id']?.toString())
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toSet(),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading renter conversations: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _conversations = [];
        });
      }
    }
  }

  void _setupConversationMembershipListener() {
    final user = AuthService().currentUser;
    if (user == null) return;

    _conversationMembershipSubscription = Supabase.instance.client
        .channel('renter-conversation-membership-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (_) => _scheduleConversationReload(),
        )
        .subscribe();
  }

  Future<void> _refreshMessageSubscription(Set<String> conversationIds) async {
    if (_messageConversationIds.length == conversationIds.length &&
        _messageConversationIds.containsAll(conversationIds)) {
      return;
    }

    await _messagesSubscription?.unsubscribe();
    _messagesSubscription = null;
    _messageConversationIds = Set<String>.unmodifiable(conversationIds);
    if (conversationIds.isEmpty || !mounted) return;

    var channel = Supabase.instance.client.channel(
      'renter-messages-${AuthService().currentUser?.id ?? 'anonymous'}',
    );
    for (final conversationId in conversationIds) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (_) => _scheduleConversationReload(),
      );
    }
    _messagesSubscription = channel.subscribe();
  }

  void _scheduleConversationReload() {
    _conversationReloadDebounce?.cancel();
    _conversationReloadDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_loadConversations());
    });
  }

  void _setupNotificationsListener() {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return;

      final supabase = Supabase.instance.client;

      _notificationsSubscription = supabase.realtime.channel(
        'public:notifications:user_id=eq.${user.id}',
      );

      _notificationsSubscription!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) {
              if (!mounted) return;
              _loadNotifications();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ Error setting up notifications listener: $e');
    }
  }

  // Ratings are submitted per booking target (vehicle, partner/operator, and
  // driver). Keeping only booking IDs here caused one completed target to
  // hide the remaining ratings for the same trip.
  Set<String> _ratedTargetKeys = {};

  String _ratingTargetKey(
    String bookingId,
    String targetUserId,
    String targetRole,
  ) => '$bookingId|${targetRole.trim().toLowerCase()}|$targetUserId';

  Set<String> _renterRatingTargetKeys(Map<String, dynamic> booking) {
    final bookingId = booking['id']?.toString().trim() ?? '';
    if (bookingId.isEmpty) return {};

    final keys = <String>{};
    final vehicleValue = booking['vehicles'];
    final vehicle = vehicleValue is Map
        ? Map<String, dynamic>.from(vehicleValue)
        : <String, dynamic>{};
    final ownerValue = vehicle['owner'];
    final owner = ownerValue is Map
        ? Map<String, dynamic>.from(ownerValue)
        : <String, dynamic>{};

    void addTarget(dynamic userId, String role) {
      final id = userId?.toString().trim() ?? '';
      if (id.isNotEmpty) {
        keys.add(_ratingTargetKey(bookingId, id, role));
      }
    }

    addTarget(vehicle['id'] ?? booking['vehicle_id'], 'vehicle');

    final ownerRole = (vehicle['owner_role'] ?? owner['role'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (ownerRole == 'partner') {
      addTarget(
        owner['id'] ?? owner['user_id'] ?? vehicle['owner_id'],
        'partner',
      );
    }

    addTarget(booking['operator_id'] ?? vehicle['operator_id'], 'operator');

    final driverValue = booking['driver'];
    final driver = driverValue is Map
        ? Map<String, dynamic>.from(driverValue)
        : <String, dynamic>{};
    final driverUserValue = driver['users'] ?? driver['user'];
    final driverUser = driverUserValue is Map
        ? Map<String, dynamic>.from(driverUserValue)
        : <String, dynamic>{};
    addTarget(
      driverUser['id'] ??
          driverUser['user_id'] ??
          driver['user_id'] ??
          booking['driver_user_id'] ??
          booking['driver_id'],
      'driver',
    );

    return keys;
  }

  bool _isRenterBookingFullyRated(Map<String, dynamic> booking) {
    final targetKeys = _renterRatingTargetKeys(booking);
    // If the booking payload is incomplete, keep the rate action available.
    // This prevents a missing relationship from becoming a false
    // "Rating Submitted" state.
    return targetKeys.isNotEmpty && targetKeys.every(_ratedTargetKeys.contains);
  }

  Future<void> _loadBookings() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return;

      final bookings = await BookingService().getRenterBookings(user.id);

      Set<String> ratedSet = {};
      try {
        final ratings = await Supabase.instance.client
            .from('trip_ratings')
            .select('booking_id,target_user_id,target_role')
            .eq('reviewer_user_id', user.id);
        ratedSet = ratings.map((r) {
          final row = Map<String, dynamic>.from(r);
          return _ratingTargetKey(
            row['booking_id']?.toString() ?? '',
            row['target_user_id']?.toString() ?? '',
            row['target_role']?.toString() ?? '',
          );
        }).toSet();
      } catch (ratingErr) {
        debugPrint('Could not fetch user rated bookings: $ratingErr');
      }

      final hydratedBookings = List<Map<String, dynamic>>.from(bookings).map((
        booking,
      ) {
        final normalizedBooking = Map<String, dynamic>.from(booking);
        final vehicle = booking['vehicles'];
        if (vehicle is Map<String, dynamic>) {
          final normalizedVehicle = Map<String, dynamic>.from(vehicle);
          normalizedVehicle['image_url'] = _bookingVehicleImageUrl(
            normalizedVehicle,
          );
          normalizedBooking['vehicles'] = normalizedVehicle;
        }
        return normalizedBooking;
      }).toList();

      final completedCount = hydratedBookings.where((b) {
        final s = b['status']?.toString().toLowerCase().trim() ?? '';
        return s == 'completed' || s == 'returned' || s == 'settled';
      }).length;

      if (mounted) {
        setState(() {
          _bookings = hydratedBookings;
          _ratedTargetKeys = ratedSet;
          _totalTrips = completedCount;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading bookings: $e');
    }
  }

  void _setupBookingsListener() {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return;

      final supabase = Supabase.instance.client;

      _bookingsSubscription = supabase.realtime.channel(
        'public:bookings:renter_id=eq.${user.id}',
      );

      _bookingsSubscription!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bookings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'renter_id',
              value: user.id,
            ),
            callback: (payload) async {
              if (mounted) {
                _loadBookings();
                _loadConversations();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ Error setting up bookings listener: $e');
    }
  }

  Future<void> _getDeviceLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
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
      await _loadFavoriteVehicleIds();
      final vehicles = await VehicleService().getAvailableVehicles(
        category: selectedCategory.isEmpty ? null : selectedCategory,
        availableFrom: _bookingFilterFrom,
        availableTo: _bookingFilterTo,
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
    final search = _committedVehicleSearch;
    final hasLocationFilter =
        _nearbyLatitude != null && _nearbyLongitude != null;
    final searchTerms = search
        .split(RegExp(r'[,\s]+'))
        .where((term) => term.length >= 2)
        .toList();
    final filtered = _vehicles.where((vehicle) {
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
      final location = (vehicle['location'] ?? '').toString().toLowerCase();
      final city = (vehicle['city'] ?? '').toString().toLowerCase();
      final province = (vehicle['province'] ?? '').toString().toLowerCase();
      final address = (vehicle['address'] ?? vehicle['pickup_location'] ?? '')
          .toString()
          .toLowerCase();
      final description = (vehicle['description'] ?? '')
          .toString()
          .toLowerCase();
      final transmission = (vehicle['transmission'] ?? '')
          .toString()
          .toLowerCase();
      final fuelType = (vehicle['fuel_type'] ?? '').toString().toLowerCase();

      final distance = _vehicleDistanceKm(vehicle);
      if (search.isEmpty) return true;

      final searchable = [
        brand,
        model,
        vehicleName,
        vehicleType,
        category,
        source,
        location,
        city,
        province,
        address,
        description,
        transmission,
        fuelType,
      ].join(' ');
      final matchesSearch =
          searchable.contains(search) ||
          (searchTerms.isNotEmpty && searchTerms.every(searchable.contains));

      if (!hasLocationFilter) return matchesSearch;
      return matchesSearch ||
          (distance != null
              ? distance <= 75
              : _vehicleMatchesNearbyText(vehicle));
    }).toList();

    if (_nearbyLatitude != null && _nearbyLongitude != null) {
      final nearby = <Map<String, dynamic>>[];
      final others = <Map<String, dynamic>>[];

      for (final vehicle in filtered) {
        final copy = Map<String, dynamic>.from(vehicle);
        final distance = _vehicleDistanceKm(copy);
        if (distance != null) {
          copy['distance_km'] = distance;
          if (distance <= 75) {
            nearby.add(copy);
          } else {
            others.add(copy);
          }
          continue;
        }

        if (_vehicleMatchesNearbyText(copy)) {
          nearby.add(copy);
        } else {
          others.add(copy);
        }
      }

      nearby.sort((a, b) {
        final aDistance = (a['distance_km'] as num?)?.toDouble() ?? 999999;
        final bDistance = (b['distance_km'] as num?)?.toDouble() ?? 999999;
        return aDistance.compareTo(bDistance);
      });

      filtered
        ..clear()
        ..addAll(nearby)
        ..addAll(search.isEmpty ? others : []);
    }

    if (!mounted) return;
    setState(() => _filteredVehicles = filtered);
  }

  double? _vehicleDistanceKm(Map<String, dynamic> vehicle) {
    final userLat = _nearbyLatitude;
    final userLng = _nearbyLongitude;
    final vehicleLat = _toDouble(vehicle['latitude']);
    final vehicleLng = _toDouble(vehicle['longitude']);
    if (userLat == null ||
        userLng == null ||
        vehicleLat == null ||
        vehicleLng == null) {
      return null;
    }
    return Geolocator.distanceBetween(
          userLat,
          userLng,
          vehicleLat,
          vehicleLng,
        ) /
        1000;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool _vehicleMatchesNearbyText(Map<String, dynamic> vehicle) {
    if (_nearbyLocationTokens.isEmpty) return false;
    final location = [
      vehicle['location'],
      vehicle['city'],
      vehicle['province'],
      vehicle['address'],
    ].where((part) => part != null).join(' ').toLowerCase();
    if (location.trim().isEmpty) return false;
    return _nearbyLocationTokens.any(location.contains);
  }

  Future<void> _openCurrentLocationPicker() async {
    final selection = await MobilisLocationPickerModal.show(
      context,
      title: 'Pin trip destination',
      subtitle:
          'Search an address or use your current location to set the exact pin.',
      confirmLabel: 'Use this location',
      initialAddress: userLocation == 'Not specified' ? '' : userLocation,
      initialLatitude: _nearbyLatitude,
      initialLongitude: _nearbyLongitude,
    );
    if (!mounted || selection == null) return;

    final tokens = selection.address
        .split(RegExp(r'[,\s]+'))
        .where((part) => part.trim().length >= 3)
        .map((part) => part.trim().toLowerCase())
        .toSet()
        .toList();
    setState(() {
      _searchController.clear();
      _committedVehicleSearch = '';
      _nearbyLatitude = selection.latitude;
      _nearbyLongitude = selection.longitude;
      _nearbyLocationLabel = selection.address;
      _nearbyLocationTokens = tokens;
      userLocation = selection.address;
    });
    _applyVehicleFilters();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing available cars near ${selection.address}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _searchVehiclesByLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _isSearchingVehicles) return;

    setState(() {
      _isSearchingVehicles = true;
    });

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        throw Exception('No matching location found.');
      }

      final location = locations.first;
      var label = query;
      final tokens = query
          .split(RegExp(r'[,\s]+'))
          .where((part) => part.trim().length >= 3)
          .map((part) => part.trim().toLowerCase())
          .toSet();
      try {
        final placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final labelParts =
              [
                    place.subLocality,
                    place.locality,
                    place.subAdministrativeArea,
                    place.administrativeArea,
                  ]
                  .whereType<String>()
                  .where((part) => part.trim().isNotEmpty)
                  .toList();
          if (labelParts.isNotEmpty) {
            label = labelParts.take(2).join(', ');
            tokens.addAll(
              labelParts
                  .expand((part) => part.split(RegExp(r'[,\s]+')))
                  .where((part) => part.trim().length >= 3)
                  .map((part) => part.trim().toLowerCase()),
            );
          }
        }
      } catch (e) {
        debugPrint('Search reverse geocoding failed: $e');
      }

      if (!mounted) return;
      setState(() {
        _committedVehicleSearch = query.toLowerCase();
        _nearbyLatitude = location.latitude;
        _nearbyLongitude = location.longitude;
        _nearbyLocationLabel = label;
        _nearbyLocationTokens = tokens.toList();
        userLocation = label;
      });
      _applyVehicleFilters();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Showing available cars near $label'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSearchingVehicles = false);
    }
  }

  void _clearNearbyVehicleFilter() {
    if (_nearbyLatitude == null && _nearbyLongitude == null) return;
    setState(() {
      _searchController.clear();
      _committedVehicleSearch = '';
      _nearbyLatitude = null;
      _nearbyLongitude = null;
      _nearbyLocationLabel = null;
      _nearbyLocationTokens = [];
    });
    _applyVehicleFilters();
  }

  Future<void> _loadFavoriteVehicleIds() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    final ids = await FavoriteVehicleService().getFavoriteVehicleIds(user.id);
    if (!mounted) return;
    setState(() => _favoriteVehicleIds = ids);
  }

  Future<void> _toggleFavoriteVehicle(Map<String, dynamic> vehicle) async {
    final user = AuthService().currentUser;
    final vehicleId = vehicle['id']?.toString() ?? '';
    if (user == null || vehicleId.isEmpty) return;

    final isFavorite = _favoriteVehicleIds.contains(vehicleId);
    setState(() {
      if (isFavorite) {
        _favoriteVehicleIds.remove(vehicleId);
      } else {
        _favoriteVehicleIds.add(vehicleId);
      }
    });

    try {
      final nowFavorite = await FavoriteVehicleService().toggleFavorite(
        userId: user.id,
        vehicleId: vehicleId,
      );
      if (!mounted) return;
      setState(() {
        if (nowFavorite) {
          _favoriteVehicleIds.add(vehicleId);
        } else {
          _favoriteVehicleIds.remove(vehicleId);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isFavorite) {
          _favoriteVehicleIds.add(vehicleId);
        } else {
          _favoriteVehicleIds.remove(vehicleId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update favorites: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadVehicles();
    await _loadBookings();
    await _loadNotifications();
    await _loadConversations();
    _loadUserData();
  }

  Future<void> _clearBookNowDateFilter() async {
    if (!mounted) return;
    if (_bookingFilterFrom == null && _bookingFilterTo == null) return;

    setState(() {
      _bookingFilterFrom = null;
      _bookingFilterTo = null;
    });
    await _loadVehicles();
  }

  Future<void> _resetBookNowDateFilter() async {
    if (_bookingFilterFrom == null && _bookingFilterTo == null) return;
    setState(() {
      _bookingFilterFrom = null;
      _bookingFilterTo = null;
      selectedCategory = '';
      _searchController.clear();
      _committedVehicleSearch = '';
      _nearbyLatitude = null;
      _nearbyLongitude = null;
      _nearbyLocationLabel = null;
      _nearbyLocationTokens = [];
    });
    await _loadVehicles();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking dates reset. Showing all available cars.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _selectBookNowDates() async {
    if (_isOpeningBookNowCalendar || !mounted) return;
    setState(() => _isOpeningBookNowCalendar = true);

    try {
      if (!await _checkRentalVerification()) return;
      if (!mounted) return;

      final now = DateTime.now();
      final firstDate = DateTime(now.year, now.month, now.day);
      final visibleVehicleIds =
          (_filteredVehicles.isNotEmpty ? _filteredVehicles : _vehicles)
              .map((vehicle) => vehicle['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
      final unavailableDays = await VehicleService()
          .getFullyUnavailableDatesForVehicles(visibleVehicleIds);
      if (!mounted) return;

      final picked = await _showBookNowCalendarDialog(
        firstDate: firstDate,
        lastDate: firstDate.add(const Duration(days: 365)),
        initialStart:
            _bookingFilterFrom ?? firstDate.add(const Duration(days: 1)),
        initialEnd:
            _bookingFilterTo ??
            _bookingFilterFrom ??
            firstDate.add(const Duration(days: 1)),
        unavailableDays: unavailableDays,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _bookingFilterFrom = picked.start;
        _bookingFilterTo = picked.end;
      });
      unawaited(_loadVehicles());

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VehicleSearchScreen(
            initialCategory: selectedCategory.isEmpty ? null : selectedCategory,
            initialAvailableFrom: picked.start,
            initialAvailableTo: picked.end,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningBookNowCalendar = false);
      }
    }
  }

  Future<DateTimeRange?> _showBookNowCalendarDialog({
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime initialStart,
    required DateTime initialEnd,
    required Set<DateTime> unavailableDays,
  }) {
    var focusedDay = initialStart;
    DateTime? rangeStart = initialStart;
    DateTime? rangeEnd = initialEnd;
    final unavailable = unavailableDays.map(_dateOnly).toSet();
    final myBookedDetails = _bookingDetailsByDay(_bookings);
    final myBookedDays = myBookedDetails.keys.toSet();

    return showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) {
        bool isApplying = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasInvalidRange =
                rangeStart != null &&
                rangeEnd != null &&
                _rangeContainsBlockedDate(rangeStart!, rangeEnd!, unavailable);

            return Dialog(
              backgroundColor: AppColors.darkBgSecondary,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderColor),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Select Booking Dates',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: const [
                          _CalendarLegendDot(
                            color: AppColors.primary,
                            label: 'Selected',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.error,
                            label: 'Unavailable',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.warning,
                            label: 'Your booking',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.success,
                            label: 'Available',
                            textColor: AppColors.textPrimary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TableCalendar(
                        firstDay: firstDate,
                        lastDay: lastDate,
                        focusedDay: focusedDay,
                        rangeStartDay: rangeStart,
                        rangeEndDay: rangeEnd,
                        rangeSelectionMode: RangeSelectionMode.toggledOn,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        onRangeSelected: (start, end, focused) {
                          final startDay = start == null
                              ? null
                              : _dateOnly(start);
                          final endDay = end == null ? null : _dateOnly(end);
                          if ((startDay != null &&
                                  unavailable.contains(startDay)) ||
                              (endDay != null &&
                                  unavailable.contains(endDay))) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('That date is unavailable'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          if (start != null &&
                              end != null &&
                              _rangeContainsBlockedDate(
                                start,
                                end,
                                unavailable,
                              )) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selected range includes unavailable dates',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            rangeStart = start;
                            rangeEnd = end ?? start;
                            focusedDay = focused;
                          });
                        },
                        onDaySelected: (selectedDay, focused) {
                          final selectedDate = _dateOnly(selectedDay);
                          if (unavailable.contains(selectedDate)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('That date is unavailable'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            if (rangeStart == null ||
                                (rangeStart != null && rangeEnd != null)) {
                              rangeStart = selectedDay;
                              rangeEnd = null;
                            } else if (selectedDay.isBefore(rangeStart!)) {
                              rangeEnd = rangeStart;
                              rangeStart = selectedDay;
                            } else {
                              if (_rangeContainsBlockedDate(
                                rangeStart!,
                                selectedDay,
                                unavailable,
                              )) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Selected range includes unavailable dates',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }
                              rangeEnd = selectedDay;
                            }
                            focusedDay = focused;
                          });
                        },
                        onDayLongPressed: (selectedDay, focused) {
                          final selectedDate = _dateOnly(selectedDay);
                          if (myBookedDays.contains(selectedDate)) {
                            _showBookedDateDetails(
                              selectedDate,
                              myBookedDetails,
                            );
                          }
                        },
                        headerStyle: const HeaderStyle(
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          formatButtonVisible: false,
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
                            fontWeight: FontWeight.w600,
                          ),
                          weekendStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          rangeHighlightColor: AppColors.primary.withAlpha(55),
                          defaultTextStyle: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          weekendTextStyle: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            return _buildBookNowDayCell(
                              day,
                              unavailable,
                              myBookedDays,
                            );
                          },
                          todayBuilder: (context, day, focusedDay) {
                            return _buildBookNowDayCell(
                              day,
                              unavailable,
                              myBookedDays,
                              isToday: true,
                            );
                          },
                          selectedBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: AppColors.primary,
                              textColor: Colors.black,
                            );
                          },
                          rangeStartBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: AppColors.primary,
                              textColor: Colors.black,
                            );
                          },
                          rangeEndBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: AppColors.primary,
                              textColor: Colors.black,
                            );
                          },
                          disabledBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: Colors.transparent,
                              textColor: AppColors.textTertiary,
                            );
                          },
                        ),
                      ),
                      if (hasInvalidRange) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Selected range includes unavailable dates.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      Builder(
                        builder: (context) {
                          final selectedDaysCount = (rangeStart != null && rangeEnd != null)
                              ? _dateOnly(rangeEnd!).difference(_dateOnly(rangeStart!)).inDays + 1
                              : (rangeStart != null ? 1 : 0);
                          final isLongBooking = selectedDaysCount > 7;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              if (isLongBooking)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withAlpha(28),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.warning.withAlpha(140),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        size: 18,
                                        color: AppColors.warning,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                              height: 1.3,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: '$selectedDaysCount Days Selected: ',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const TextSpan(
                                                text: 'Extended Booking Policy — Rentals exceeding 7 days require a ',
                                              ),
                                              const TextSpan(
                                                text: '20% reservation fee deposit',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.warning,
                                                ),
                                              ),
                                              const TextSpan(text: ' instead of standard ₱1,000.'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (selectedDaysCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.primary.withAlpha(80),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textPrimary,
                                              height: 1.3,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: '$selectedDaysCount ${selectedDaysCount == 1 ? "Day" : "Days"} Selected: ',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const TextSpan(
                                                text: 'Standard ₱1,000 Reservation Fee (Note: Bookings over 7 days require 20%).',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Policy: Standard ₱1,000 reservation fee applies for 1–7 days. Rentals over 7 days require a 20% reservation fee.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                if (isApplying) return;
                                isApplying = true;
                                Navigator.pop(dialogContext);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  rangeStart == null ||
                                      rangeEnd == null ||
                                      hasInvalidRange
                                  ? null
                                  : () {
                                      if (isApplying) return;
                                      isApplying = true;
                                      Navigator.pop(
                                        dialogContext,
                                        DateTimeRange(
                                          start: rangeStart!,
                                          end: rangeEnd!,
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Apply'),
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
  }

  Widget _buildBookNowDayCell(
    DateTime day,
    Set<DateTime> unavailable,
    Set<DateTime> myBookedDays, {
    bool isToday = false,
  }) {
    final date = _dateOnly(day);
    if (unavailable.contains(date)) {
      return _buildCalendarDayCell(
        day: day,
        backgroundColor: AppColors.error,
        borderColor: isToday ? AppColors.primary : null,
        textColor: Colors.white,
        strikethrough: true,
      );
    }
    if (myBookedDays.contains(date)) {
      return _buildCalendarDayCell(
        day: day,
        backgroundColor: AppColors.warning,
        borderColor: isToday ? AppColors.primary : null,
        textColor: Colors.black,
      );
    }
    return _buildCalendarDayCell(
      day: day,
      backgroundColor: AppColors.success.withAlpha(45),
      borderColor: isToday ? AppColors.primary : AppColors.success,
      textColor: isToday ? AppColors.primary : AppColors.textPrimary,
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _rangeContainsBlockedDate(
    DateTime start,
    DateTime end,
    Set<DateTime> blockedDays,
  ) {
    final startDay = _dateOnly(start);
    final endDay = _dateOnly(end);
    final orderedStart = startDay.isAfter(endDay) ? endDay : startDay;
    final orderedEnd = startDay.isAfter(endDay) ? startDay : endDay;

    for (
      var day = orderedStart;
      !day.isAfter(orderedEnd);
      day = day.add(const Duration(days: 1))
    ) {
      if (blockedDays.contains(day)) return true;
    }
    return false;
  }

  Map<DateTime, List<Map<String, dynamic>>> _bookingDetailsByDay(
    List<Map<String, dynamic>> bookings,
  ) {
    final details = <DateTime, List<Map<String, dynamic>>>{};
    for (final booking in bookings) {
      final status =
          (booking['rawStatus'] ?? booking['status'])
              ?.toString()
              .toLowerCase() ??
          '';
      if (!{'pending', 'approved', 'confirmed', 'active'}.contains(status)) {
        continue;
      }

      final start = _parseBookingCalendarDate(
        booking['start_at'] ??
            booking['start_date_raw'] ??
            booking['start_date'] ??
            booking['startDate'],
      );
      final end = _parseBookingCalendarDate(
        booking['end_at'] ??
            booking['end_date_raw'] ??
            booking['end_date'] ??
            booking['endDate'],
      );
      if (start == null || end == null) continue;

      var current = _dateOnly(start);
      final last = _dateOnly(end);
      while (!current.isAfter(last)) {
        details.putIfAbsent(current, () => []).add(booking);
        current = current.add(const Duration(days: 1));
      }
    }
    return details;
  }

  DateTime? _parseBookingCalendarDate(Object? value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty || raw == 'N/A') return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toLocal();

    final parts = raw.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;

    final day = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
    if (day == null) return null;

    final monthLookup = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final monthText = parts[1].toLowerCase();
    if (monthText.length < 3) return null;
    final monthKey = monthText.substring(0, 3);
    final month = monthLookup[monthKey];
    if (month == null) return null;

    final year = parts.length >= 3
        ? int.tryParse(parts[2])
        : DateTime.now().year;
    if (year == null) return null;

    return DateTime(year, month, day);
  }

  String _bookingVehicleTitle(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'];
    if (vehicle is Map<String, dynamic>) {
      return _vehicleTitle(vehicle);
    }
    return 'Booked vehicle';
  }

  void _showBookedDateDetails(
    DateTime date,
    Map<DateTime, List<Map<String, dynamic>>> detailsByDay,
  ) {
    final bookings = detailsByDay[_dateOnly(date)] ?? [];
    if (bookings.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your booking on ${_shortDate(date)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...bookings.map((booking) {
                  final status = booking['status']?.toString() ?? 'pending';
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgTertiary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.directions_car,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _bookingVehicleTitle(booking),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarDayCell({
    required DateTime day,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    bool strikethrough = false,
  }) {
    return Container(
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
          decorationColor: textColor,
          decorationThickness: 2,
        ),
      ),
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '';
    return '${_shortDate(start)} - ${_shortDate(end)}';
  }

  String _shortDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}';
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

  void _showVerificationPendingModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(43),
                ),
                child: const Icon(
                  Icons.hourglass_top,
                  color: AppColors.primary,
                  size: 46,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Verification Under Review',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your verification request is already submitted. We will notify you once admin approval is complete.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed('/account-verification');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Check Status',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed('/id-verification');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Edit Details & Missing Documents',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkRentalVerification() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return false;

      final verificationState =
          await VerificationService.getUserVerificationState(user.id);
      final userRole = verificationState['role']?.toString() ?? 'renter';
      final isVerifiedInDb = verificationState['is_verified'] as bool? ?? false;
      final status = verificationState['verification_status']
          ?.toString()
          .trim()
          .toLowerCase();
      final hasPendingApplication =
          status == 'pending' || status == 'submitted';

      if (isVerifiedInDb != userVerified) {
        if (mounted) {
          setState(() {
            userVerified = isVerifiedInDb;
          });
        }
      }

      if (userRole == 'driver') return true;

      if (!isVerifiedInDb) {
        if (hasPendingApplication) {
          _showVerificationPendingModal();
        } else {
          _showRentalVerificationModal();
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking verification: $e');
      return true;
    }
  }

  Future<void> _openVehicleDetail({
    required String vehicleId,
    required Map<String, dynamic> vehicleData,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_navigatingVehicleId != null || !mounted || vehicleId.isEmpty) return;
    setState(() => _navigatingVehicleId = vehicleId);
    try {
      await Navigator.of(context).pushNamed(
        '/vehicle-detail',
        arguments: {
          'vehicleId': vehicleId,
          'vehicleData': vehicleData,
          'initialStartDate': startDate,
          'initialEndDate': endDate,
        },
      );
    } finally {
      if (mounted) {
        setState(() => _navigatingVehicleId = null);
      }
    }
  }

  Future<bool> _canOpenVehicleBooking(Map<String, dynamic> vehicle) async {
    final vehicleId = vehicle['id']?.toString() ?? '';
    final listed = vehicle['is_posted'] != false;
    final enabled = vehicle['is_available'] != false;
    final status = vehicle['status']?.toString().trim().toLowerCase() ?? '';
    if (vehicleId.isEmpty || !listed || !enabled || status == 'rejected') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This vehicle is currently unavailable.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return false;
    }

    final isBookable = await VehicleService().isVehicleBookable(vehicleId);
    if (!isBookable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This vehicle is not approved or listed for rental.'),
            backgroundColor: AppColors.warning,
          ),
        );
        await _loadVehicles();
      }
      return false;
    }

    // The regular Book Now action opens the calendar, so there is no selected
    // rental period to validate yet. Checking today here incorrectly blocks a
    // vehicle that is booked today but available on the renter's intended date.
    if (_bookingFilterFrom == null && _bookingFilterTo == null) return true;

    final start = _bookingFilterFrom ?? _bookingFilterTo!;
    final end = _bookingFilterTo ?? _bookingFilterFrom!;
    late final bool available;
    try {
      available = await VehicleService().isVehicleAvailable(
        vehicleId,
        start,
        end,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not check vehicle availability: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
    if (!available && mounted) {
      final selectedRange = _formatDateRange(start, end);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This vehicle is unavailable for $selectedRange. Choose another vehicle or date.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
    }
    return available;
  }

  // ---------------------------------------------------------------------------
  // Data mappers
  // ---------------------------------------------------------------------------
  int _inclusiveRentalDays(DateTime startDate, DateTime endDate) {
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final calendarDays = endDay.difference(startDay).inDays.abs() + 1;

    return calendarDays < 1 ? 1 : calendarDays;
  }

  String _vehicleTitle(Map<String, dynamic>? vehicle) {
    if (vehicle == null) return 'Unknown Vehicle';

    final vehicleName = vehicle['vehicle_name']?.toString().trim() ?? '';
    if (vehicleName.isNotEmpty) return vehicleName;

    final brand = vehicle['brand']?.toString().trim() ?? '';
    final model = vehicle['model']?.toString().trim() ?? '';
    final name = [brand, model].where((part) => part.isNotEmpty).join(' ');

    return name.isEmpty ? 'Unknown Vehicle' : name;
  }

  String? _bookingVehicleImageUrl(Map<String, dynamic> vehicle) {
    final directUrl = vehicle['image_url']?.toString().trim();
    if (directUrl != null && directUrl.isNotEmpty) {
      return directUrl;
    }

    final images = vehicle['vehicle_images'];
    if (images is! List) return null;

    for (final image in images) {
      if (image is! Map) continue;
      final imageUrl = image['image_url']?.toString().trim();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        return imageUrl;
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _uiBookings() {
    return _bookings.map((booking) {
      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final totalCost =
          (booking['total_price'] as num?)?.toDouble() ??
          (booking['total_cost'] as num?)?.toDouble() ??
          0.0;

      final startAtRaw = booking['start_at']?.toString();
      final endAtRaw = booking['end_at']?.toString();
      final startDateRaw = booking['start_date']?.toString();
      final endDateRaw = booking['end_date']?.toString();
      final startDateTimeRaw = startAtRaw ?? startDateRaw;
      final endDateTimeRaw = endAtRaw ?? endDateRaw;
      final startDate = _formatDateShort(startDateTimeRaw);
      final endDate = _formatDateShort(endDateTimeRaw);
      final startTime = _formatTimeShort(startAtRaw);
      final endTime = _formatTimeShort(endAtRaw);

      int days = 1;
      try {
        if (startDateTimeRaw != null && endDateTimeRaw != null) {
          final start = DateTime.parse(startDateTimeRaw).toLocal();
          final end = DateTime.parse(endDateTimeRaw).toLocal();
          days = _inclusiveRentalDays(start, end);
        }
      } catch (_) {
        days = 1;
      }

      final rawStatus = (booking['status'] ?? '').toString().toLowerCase();
      final groupedStatus = bookingStatusGroup(rawStatus);
      final uiStatus = bookingStatusLabel(groupedStatus);
      final statusGroup = uiStatus;

      final owner = vehicle?['owner'] as Map<String, dynamic>?;
      final ownerRole = (owner?['role'] ?? '').toString().toLowerCase();
      final ownerName = (owner?['full_name'] ?? '').toString().trim();
      final rentalPartner = (ownerRole == 'partner' && ownerName.isNotEmpty)
          ? ownerName
          : 'PSDC';
      final driver = booking['driver'] as Map<String, dynamic>?;
      final driverUser = driver?['users'] as Map<String, dynamic>?;
      final withDriver = booking['with_driver'] == true ||
          booking['withDriver'] == true ||
          booking['with_driver'] == 1 ||
          booking['with_driver']?.toString().toLowerCase() == 'true';
      final driverName = driverUser?['full_name']?.toString().trim();
      final driverPhone = driverUser?['phone']?.toString().trim() ?? '';
      final driverEmail = driverUser?['email']?.toString().trim() ?? '';
      final payState = resolveBookingPaymentState(booking);
      final isFullyPaidBooking = payState == BookingPaymentState.paid;
      final paymentStatus = bookingPaymentStateLabel(payState);
      final tripRatings = (booking['trip_ratings'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => (row['rating'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      final actualTripRating = tripRatings.isEmpty
          ? 0.0
          : tripRatings.reduce((total, value) => total + value) /
                tripRatings.length;
      final assignments = (booking['job_assignments'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      Map<String, dynamic>? acceptedAssignment;
      for (final assignment in assignments.reversed) {
        final assignmentStatus = assignment['status']
            ?.toString()
            .trim()
            .toLowerCase();
        if (const {
          'accepted',
          'ongoing',
          'awaiting_completion',
          'completed',
        }.contains(assignmentStatus)) {
          acceptedAssignment = assignment;
          break;
        }
      }
      final rentalSubtotal =
          (booking['rental_subtotal'] as num?)?.toDouble() ?? totalCost;
      final deliveryFee = (booking['delivery_fee'] as num?)?.toDouble() ?? 0.0;
      final driverFee =
          (acceptedAssignment?['trip_fee'] as num?)?.toDouble() ?? 0.0;
      final lateReturnFee =
          (booking['late_return_fee'] as num?)?.toDouble() ?? 0.0;

      return {
        'id': booking['id']?.toString() ?? '',
        'created_at': booking['created_at'],
        'updated_at': booking['updated_at'],
        'vehicle_id': booking['vehicle_id'],
        'operator_id': booking['operator_id'],
        'completion_stage': booking['completion_stage'],
        'start_at': booking['start_at'],
        'end_at': booking['end_at'],
        'start_date_raw': booking['start_date'],
        'end_date_raw': booking['end_date'],
        'vehicles': vehicle,
        'driver': driver,
        'driver_user': driverUser,
        'driverPhone': driverPhone,
        'driverEmail': driverEmail,
        'driver_id': booking['driver_id'],
        'job_assignments': assignments,
        'withDriver': withDriver,
        'with_driver': withDriver,
        'plateNumber': vehicle?['plate_number']?.toString().trim() ?? '',
        'transmission': vehicle?['transmission']?.toString().trim() ?? '',
        'fuelType': vehicle?['fuel_type']?.toString().trim() ?? '',
        'seats': vehicle?['seats'],
        'driverName': driverName == null || driverName.isEmpty
            ? (withDriver ? 'To be assigned' : 'Not requested')
            : toProfessionalTitleCase(driverName),
        'paymentStatus': paymentStatus,
        'final_payment_status': booking['final_payment_status']?.toString().trim(),
        'reservationPaymentType': booking['reservation_payment_type']
            ?.toString()
            .trim(),
        'reservationPaymentCoversTotal':
            booking['reservation_payment_covers_total'] == true,
        'reservationFeeAmount': (booking['reservation_fee_amount'] as num?)
            ?.toDouble(),
        'reservationPaymentReference': booking['reservation_payment_reference']
            ?.toString()
            .trim(),
        'reservationPaymentMethod': booking['reservation_payment_method']
            ?.toString()
            .trim(),
        'reservationPaymentProofUrl': booking['reservation_payment_proof_url']
            ?.toString()
            .trim(),
        'final_payment_method': booking['final_payment_method']
            ?.toString()
            .trim(),
        'final_payment_reference': booking['final_payment_reference']
            ?.toString()
            .trim(),
        'final_payment_proof_url': booking['final_payment_proof_url']
            ?.toString()
            .trim(),
        'renter_return_payment_submitted':
            booking['renter_return_payment_submitted'] == true,
        'renter_return_payment_amount':
            (booking['renter_return_payment_amount'] as num?)?.toDouble() ??
            0.0,
        'returned_at': booking['returned_at'],
        'completed_at': booking['completed_at'],
        'cancellationReason':
            booking['cancellation_reason']?.toString().trim().isNotEmpty == true
            ? booking['cancellation_reason'].toString().trim()
            : booking['rejection_reason']?.toString().trim().isNotEmpty == true
            ? booking['rejection_reason'].toString().trim()
            : 'Booking was cancelled.',
        'cancelledAt': booking['cancelled_at'] ?? booking['updated_at'],
        'conversationCreated': booking['conversation_created'] == true,
        'operator_trip_confirmed_at': booking['operator_trip_confirmed_at'],
        'partner_trip_confirmed_at': booking['partner_trip_confirmed_at'],
        'driver_trip_confirmed_at': booking['driver_trip_confirmed_at'],
        'renter_trip_confirmed_at': booking['renter_trip_confirmed_at'],
        'carName': toProfessionalTitleCase(_vehicleTitle(vehicle)),
        'carImage': Icons.directions_car,
        'imageUrl': vehicle == null ? null : _bookingVehicleImageUrl(vehicle),
        'status': uiStatus,
        'statusGroup': statusGroup,
        'rawStatus': rawStatus,
        'startDate': startDate,
        'startTime': startTime,
        'endDate': endDate,
        'endTime': endTime,
        'pickupLocation':
            booking['pickup_location']?.toString() ?? 'Pickup not specified',
        'dropoffLocation':
            booking['dropoff_location']?.toString() ?? 'Drop-off not specified',
        'pickupLatitude': booking['pickup_latitude'],
        'pickupLongitude': booking['pickup_longitude'],
        'dropoffLatitude': booking['dropoff_latitude'],
        'dropoffLongitude': booking['dropoff_longitude'],
        'totalCost': totalCost,
        'rentalSubtotal': rentalSubtotal,
        'deliveryFee': deliveryFee,
        'deliveryDistanceKm': (booking['delivery_distance_km'] as num?)
            ?.toDouble(),
        'deliveryRatePerKm': (booking['delivery_rate_per_km'] as num?)
            ?.toDouble(),
        'driverFee': driverFee,
        'lateReturnFee': lateReturnFee,
        'securityDeposit':
            (booking['security_deposit'] as num?)?.toDouble() ?? 0.0,
        'days': days,
        'rentalPartner': toProfessionalTitleCase(rentalPartner),
        'rating': actualTripRating,
      };
    }).toList();
  }

  String _bookingPaymentTypeLabel(Map<String, dynamic> booking) {
    final coversTotal = booking['reservationPaymentCoversTotal'] == true;
    final type = booking['reservationPaymentType']?.toString().trim() ?? '';
    if (coversTotal || type == 'full_payment') {
      return 'Full payment';
    }
    if (type.isNotEmpty) {
      return type.replaceAll('_', ' ');
    }
    return 'Reservation fee only';
  }

  String _bookingAmountPaidLabel(Map<String, dynamic> booking) {
    final coversTotal = booking['reservationPaymentCoversTotal'] == true;
    final totalCost = (booking['totalCost'] as num?)?.toDouble() ?? 0;
    final reservationFee =
        (booking['reservationFeeAmount'] as num?)?.toDouble() ?? 0;
    final amountPaid = coversTotal
        ? totalCost
        : reservationFee > 0
        ? reservationFee
        : 0;
    final suffix = coversTotal ? 'full amount' : 'reservation fee';
    return 'PHP ${formatAmount(amountPaid, decimalDigits: 0)} ($suffix)';
  }

  List<Map<String, dynamic>> _uiNotifications() {
    return _notifications.where((n) => !isMessageNotification(n)).map((n) {
      final visual = notificationVisualFor(n);
      final target = resolveNotificationTarget(n);
      var imageUrl =
          target.data['vehicle_image_url']?.toString().trim() ??
          target.data['image_url']?.toString().trim() ??
          '';
      if (imageUrl.isEmpty && target.bookingId != null) {
        final booking = _bookings.firstWhere(
          (item) => item['id']?.toString() == target.bookingId,
          orElse: () => const <String, dynamic>{},
        );
        final vehicle = booking['vehicles'];
        if (vehicle is Map<String, dynamic>) {
          imageUrl = _bookingVehicleImageUrl(vehicle) ?? '';
        }
      }

      return {
        'raw': n,
        'isRead': n['is_read'] == true,
        'title': n['title']?.toString() ?? 'Notification',
        'message': n['message']?.toString() ?? '',
        'timestamp': _formatTimeAgo(n['created_at']?.toString()),
        'icon': visual.icon,
        'iconColor': visual.color,
        'imageUrl': imageUrl,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _uiConversations() {
    return _conversations.map((conversation) {
      final otherUser = conversation['other_user'] as Map<String, dynamic>?;
      final lastMessage = conversation['last_message'] as Map<String, dynamic>?;
      final unreadCount = conversation['unread_count'] as int? ?? 0;
      final booking = conversation['bookings'] as Map<String, dynamic>?;
      final isCustomerService = booking == null;
      final vehicle = (booking?['vehicles'] ??
              booking?['partner_vehicles'] ??
              booking?['partner_vehicle'] ??
              booking?['vehicle']) as Map<String, dynamic>?;
      final vehicleName = _vehicleTitle(vehicle).trim();
      final participantName =
          otherUser?['full_name']?.toString().trim().isNotEmpty == true
          ? otherUser!['full_name'].toString().trim()
          : otherUser?['email']?.toString().trim().isNotEmpty == true
          ? otherUser!['email'].toString().trim()
          : '';
      final recipientName = isCustomerService
          ? 'Customer Service'
          : vehicleName != 'Unknown Vehicle'
          ? '$vehicleName Booking'
          : participantName.isNotEmpty
          ? participantName
          : 'Booking Group Chat';

      final statusRaw = (booking?['status'] ?? '').toString().toLowerCase().trim();
      final statusGrp = bookingStatusGroup(statusRaw);
      final String statusBadge;
      if (isCustomerService) {
        statusBadge = 'Support';
      } else if (statusGrp == BookingStatusGroup.ongoing) {
        statusBadge = 'Ongoing Trip';
      } else if (statusGrp == BookingStatusGroup.approved) {
        statusBadge = 'Approved Booking';
      } else if (statusGrp == BookingStatusGroup.completed) {
        statusBadge = 'Completed • Read-Only';
      } else if (statusGrp == BookingStatusGroup.cancelled) {
        statusBadge = 'Cancelled • Read-Only';
      } else if (statusGrp == BookingStatusGroup.frozen) {
        statusBadge = 'Frozen';
      } else if (statusRaw.isNotEmpty) {
        statusBadge = '${bookingStatusLabel(statusGrp)} Booking';
      } else {
        statusBadge = 'Active';
      }

      var convImage = conversation['vehicle_image_url']?.toString() ?? '';
      if (convImage.isEmpty) {
        convImage = (booking?['vehicle_image_url'] ??
                vehicle?['image_url'] ??
                vehicle?['imageUrl'] ??
                vehicle?['photo_url'] ??
                vehicle?['vehicle_image_url'])
            ?.toString() ??
            '';
      }

      return {
        'conversationId': conversation['id']?.toString() ?? '',
        'recipientName': recipientName,
        'lastMessage':
            (lastMessage?['content'] ?? lastMessage?['message'])
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? (lastMessage?['content'] ?? lastMessage?['message'])
                  .toString()
                  .trim()
            : 'No messages yet',
        'timestamp': _formatTimeAgo(lastMessage?['created_at']?.toString()),
        'unreadCount': unreadCount,
        'isAutoGenerated': lastMessage?['is_auto_generated'] == true,
        'isCustomerService': isCustomerService,
        'imageUrl': convImage,
        'statusBadge': statusBadge,
      };
    }).toList();
  }

  Widget _buildConversationStatusChip(String label) {
    final bool isOngoing = label.contains('Ongoing') || label.contains('Active');
    final bool isApproved = label.contains('Approved') || label.contains('Confirmed');
    final bool isReadOnly = label.contains('Completed') ||
        label.contains('Read-Only') ||
        label.contains('Cancelled');
    final bool isSupport = label.contains('Support');
    final Color chipColor = isOngoing
        ? AppColors.success
        : (isApproved
            ? AppColors.primary
            : (isSupport
                ? Colors.amber.shade700
                : (isReadOnly ? Colors.purple.shade300 : Colors.blue.shade400)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOngoing
                ? Icons.directions_car_rounded
                : (isApproved
                    ? Icons.verified_rounded
                    : (isReadOnly
                        ? Icons.lock_outline_rounded
                        : (isSupport
                            ? Icons.support_agent
                            : Icons.check_circle_outline_rounded))),
            size: 11,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  int _totalUnreadMessages() {
    return _conversations.fold<int>(
      0,
      (sum, conversation) =>
          sum + ((conversation['unread_count'] as int?) ?? 0),
    );
  }

  int get _pendingBookingActionCount {
    const actionableStatuses = {
      'pending',
      'payment_pending',
      'pending_payment',
      'action_required',
    };
    return _bookings.where((booking) {
      final status = (booking['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase()
          .replaceAll(' ', '_');
      return actionableStatuses.contains(status);
    }).length;
  }

  int get _unreadNotificationCount => _notifications
      .where(
        (notification) =>
            !isMessageNotification(notification) &&
            notification['is_read'] != true,
      )
      .length;

  void _openConversation(Map<String, dynamic> conversation) {
    final conversationId = conversation['conversationId']?.toString() ?? '';
    if (conversationId.isEmpty) return;

    Navigator.of(context)
        .pushNamed(
          '/chat-detail',
          arguments: {
            'conversationId': conversationId,
            'recipientName':
                conversation['recipientName']?.toString() ?? 'Chat',
            'recipientAvatar': conversation['imageUrl']?.toString() ?? '',
            'isAutoGenerated':
                conversation['isCustomerService'] != true &&
                conversation['isAutoGenerated'] == true,
            'isCustomerService': conversation['isCustomerService'] == true,
            'userRole': 'renter',
          },
        )
        .then((_) {
          _loadConversations();
          _loadNotifications();
        });
  }

  Future<void> _handleNotificationTap(
    Map<String, dynamic> notificationItem,
  ) async {
    final raw = Map<String, dynamic>.from(
      notificationItem['raw'] as Map? ?? const <String, dynamic>{},
    );
    final notificationId = raw['id']?.toString();
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        raw['is_read'] != true) {
      await NotificationService().markAsRead(notificationId);
      raw['is_read'] = true;
      final index = _notifications.indexWhere(
        (item) => item['id']?.toString() == notificationId,
      );
      if (index >= 0) _notifications[index]['is_read'] = true;
      if (mounted) setState(() {});
    }
    if (!mounted) return;

    final target = resolveNotificationTarget(raw);
    if (target.destination == NotificationDestination.messages) {
      final conversationId = target.conversationId;
      if (conversationId != null) {
        final conversation = _uiConversations().firstWhere(
          (item) => item['conversationId']?.toString() == conversationId,
          orElse: () => <String, dynamic>{
            'conversationId': conversationId,
            'recipientName': raw['title']?.toString() ?? 'Conversation',
            'isCustomerService': raw['type']?.toString() == 'customer_service',
          },
        );
        _openConversation(conversation);
      } else {
        setState(() => selectedNavIndex = 2);
      }
      return;
    }

    final bookingId = target.bookingId;
    final booking = bookingId == null
        ? <String, dynamic>{}
        : _uiBookings().firstWhere(
            (item) => item['id']?.toString() == bookingId,
            orElse: () => <String, dynamic>{},
          );
    if (target.destination == NotificationDestination.tracking &&
        booking.isNotEmpty) {
      setState(() => selectedNavIndex = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showBookingDetails(booking);
      });
      return;
    }
    if ((target.destination == NotificationDestination.booking ||
            target.destination == NotificationDestination.payment) &&
        booking.isNotEmpty) {
      setState(() => selectedNavIndex = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showBookingDetails(booking);
      });
      return;
    }

    switch (target.destination) {
      case NotificationDestination.verification:
      case NotificationDestination.application:
        setState(() {
          selectedNavIndex = 4;
          selectedProfilePage = 'verification';
        });
        return;
      case NotificationDestination.payment:
        setState(() {
          selectedNavIndex = 4;
          selectedProfilePage = 'payment';
        });
        return;
      case NotificationDestination.ratings:
        setState(() {
          selectedNavIndex = 4;
          selectedProfilePage = null;
        });
        return;
      case NotificationDestination.booking:
      case NotificationDestination.tracking:
        setState(() => selectedNavIndex = 1);
        return;
      case NotificationDestination.vehicles:
        setState(() => selectedNavIndex = 0);
        return;
      case NotificationDestination.messages:
        setState(() => selectedNavIndex = 2);
        return;
      case NotificationDestination.announcement:
      case NotificationDestination.general:
        _showNotificationDetails(raw);
        return;
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    final title = notification['title']?.toString().trim();
    final message = notification['message']?.toString().trim();
    final timestamp = notification['timestamp']?.toString().trim();
    final imageUrl = notification['imageUrl']?.toString().trim();
    final icon = notification['icon'] is IconData
        ? notification['icon'] as IconData
        : Icons.notifications_outlined;
    final iconColor = notification['iconColor'] is Color
        ? notification['iconColor'] as Color
        : AppColors.primary;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.modalBgOf(sheetContext),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.modalBorderOf(sheetContext)),
            boxShadow: AppColors.cardShadowOf(sheetContext),
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
                    color: AppColors.subtleBorderOf(sheetContext),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: imageUrl?.isNotEmpty == true
                        ? OptimizedNetworkImage(
                            imageUrl: imageUrl!,
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                          )
                        : Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title?.isNotEmpty == true ? title! : 'Notification',
                          style: TextStyle(
                            color: AppColors.textPrimaryOf(sheetContext),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (timestamp?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            timestamp!,
                            style: TextStyle(
                              color: AppColors.textTertiaryOf(sheetContext),
                              fontSize: 12,
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
                message?.isNotEmpty == true
                    ? message!
                    : 'No additional details are available.',
                style: TextStyle(
                  color: AppColors.textPrimaryOf(sheetContext),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canOpenBookingConversation(Map<String, dynamic> booking) {
    final rawStatus = booking['rawStatus']?.toString().toLowerCase() ?? '';
    return rawStatus == 'approved' ||
        rawStatus == 'confirmed' ||
        rawStatus == 'active' ||
        rawStatus == 'ongoing' ||
        rawStatus == 'return_pending_inspection';
  }

  Future<void> _openBookingConversation(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final isEligible = BookingService().isEligibleForBookingChat(booking);
    if (!isEligible) {
      if (mounted) {
        final startRaw = booking['start_at'] ?? booking['start_date'] ?? booking['startDate'];
        final start = startRaw != null ? DateTime.tryParse(startRaw.toString()) : null;
        final formattedDate = start != null
            ? '${start.month}/${start.day}/${start.year} at ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
            : 'the scheduled trip start';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.darkCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.lock_clock, color: Color(0xFFF59E0B)),
                SizedBox(width: 10),
                Text(
                  'Chat Unlocks 72h Prior',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'Group conversation with the operator and partner will automatically unlock 72 hours (3 days) before your trip starts ($formattedDate).',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Understood',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final existingConversation = _conversations.firstWhere(
        (conversation) => conversation['booking_id']?.toString() == bookingId,
        orElse: () => {},
      );
      var conversationId = existingConversation['id']?.toString();

      if (conversationId == null || conversationId.isEmpty) {
        final conversation =
            await ChatService().getConversationByBookingId(bookingId);
        conversationId = conversation?['id']?.toString();
      }

      if (conversationId == null || conversationId.isEmpty) {
        final currentUser = AuthService().currentUser;
        final conversation =
            await ChatService().getOrCreateBookingConversation(
          bookingId,
          initialParticipantIds: [
            if (currentUser != null) currentUser.id,
            if (booking['renter_id'] != null) booking['renter_id'].toString(),
            if (booking['driver_id'] != null) booking['driver_id'].toString(),
            if (booking['operator_id'] != null)
              booking['operator_id'].toString(),
          ],
        );
        conversationId = conversation['id']?.toString();
      }

      if (conversationId == null || conversationId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Group chat is initializing. Please refresh in a moment.',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      Navigator.of(context)
          .pushNamed(
            '/chat-detail',
            arguments: {
              'conversationId': conversationId,
              'recipientName': '${booking['carName']} Booking',
              'recipientAvatar': '',
              'isAutoGenerated': true,
            },
          )
          .then((_) {
            _loadConversations();
            _loadNotifications();
          });
    } catch (e) {
      debugPrint('Error opening booking conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open group chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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

  String _formatTimeShort(String? date) {
    if (date == null || date.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(date).toLocal();
      final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final minute = d.minute.toString().padLeft(2, '0');
      final suffix = d.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    } catch (_) {
      return 'N/A';
    }
  }

  String _formatTimeAgo(String? date) {
    if (date == null || date.isEmpty) return 'just now';
    try {
      final d = parseMessageTimestamp(date);
      if (d == null) return date;
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

  void _openRenterRatings() {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingsReviewsScreen(
          userId: userId,
          title: 'Renter Ratings & Reviews',
        ),
      ),
    );
  }

  Widget _buildRenterDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final secondary = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;

    void selectTab(int index) {
      Navigator.pop(context);
      setState(() {
        selectedNavIndex = index;
        selectedBookingIndex = null;
        selectedProfilePage = null;
      });
    }

    Widget item(IconData icon, String label, int index) {
      final selected = selectedNavIndex == index;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => selectTab(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.black : foreground,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.black : foreground,
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
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: userAvatarUrl?.trim().isNotEmpty == true
                        ? OptimizedNetworkImage(
                            imageUrl: userAvatarUrl!,
                            fit: BoxFit.cover,
                            isThumbnail: true,
                            errorWidget: Center(
                              child: Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'R',
                                style: const TextStyle(
                                  color: Color(0xFF062A44),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'R',
                              style: const TextStyle(
                                color: Color(0xFF062A44),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
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
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          userLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondary,
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
                    item(Icons.home_rounded, 'Home', 0),
                    item(Icons.calendar_month_outlined, 'My Bookings', 1),
                    item(Icons.chat_bubble_outline, 'Messages', 2),
                    item(Icons.notifications_outlined, 'Notifications', 3),
                    item(Icons.person_outline, 'Profile', 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Divider(
                        color: isDark
                            ? AppColors.borderColor
                            : AppColors.lightBorderColor,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 33,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.dark_mode, color: secondary, size: 20),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Dark Mode',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.pop(context);
                          _openRenterRatings();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: foreground,
                                size: 20,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Reviews & Ratings',
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            selectedNavIndex = 4;
                            selectedBookingIndex = null;
                            selectedProfilePage = 'settings';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.settings_outlined,
                                color: foreground,
                                size: 20,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Settings',
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () =>
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/auth-processing',
                              (route) => false,
                              arguments: {'mode': 'logout'},
                            ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 11,
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.logout,
                                color: Color(0xFFFF6B77),
                                size: 20,
                              ),
                              SizedBox(width: 14),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  color: Color(0xFFFF6B77),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackPressed();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildRenterDrawer(),
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: _buildTabContent(),
        ),
        floatingActionButton: AnimatedOpacity(
          opacity: _dimCustomerServiceFab ? 0.5 : 1,
          duration: const Duration(milliseconds: 140),
          child: FloatingActionButton(
            heroTag: 'customer_service_dashboard',
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
            1: _pendingBookingActionCount,
            2: _totalUnreadMessages(),
            3: _unreadNotificationCount,
          },
          onTap: (index) {
            setState(() {
              if (index == 4 || selectedNavIndex == 4) {
                selectedProfilePage = null;
              }
              selectedNavIndex = index;
              selectedBookingIndex = null;
            });
          },
        ),
      ),
    );
  }

  void _handleBackPressed() {
    if (selectedProfilePage != null) {
      setState(() => selectedProfilePage = null);
      return;
    }

    if (selectedBookingIndex != null) {
      setState(() => selectedBookingIndex = null);
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

  Future<void> _openCustomerServiceConversation() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final conversation = await ChatService()
          .getOrCreateCustomerServiceConversation(
            userId: user.id,
            userName: userName,
            userRole: 'renter',
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
          'userRole': 'renter',
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
  // -- Tab implementations extracted to tabs/ and sheets/ --
}

// -- Standalone helper widgets extracted to widgets/dashboard_helper_widgets.dart --

