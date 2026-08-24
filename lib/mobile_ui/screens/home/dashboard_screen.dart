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
import '../../widgets/location_picker_modal.dart';
import '../../widgets/vehicle_image_carousel.dart';
import '../../widgets/relative_time_text.dart';
import '../../widgets/booking_return_countdown.dart';
import '../profile/settings_screen.dart';
import '../profile/payment_methods_screen.dart';
import '../profile/verification_documents_screen.dart';
import '../profile/ratings_reviews_screen.dart';
import '../profile/trip_rating_flow_screen.dart';
import '../profile/unified_profile_screen.dart';
import '../tracking/trip_navigation_screen.dart';
import '../vehicle/reservation_payment_screen.dart';
import '../../widgets/return_inspection_notice_modal.dart';
import '../../widgets/trip_route_history_dialog.dart';
import '../../../utils/booking_status.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/notification_target.dart';
import '../../../utils/notification_visual.dart';
import '../../../utils/input_validation.dart';

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
      const Duration(seconds: 15),
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

      final supabase = Supabase.instance.client;
      final notifications = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final systemNotifications = List<Map<String, dynamic>>.from(
        notifications,
      ).where((item) => !isMessageNotification(item)).toList();

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
      final hydratedConversations = <Map<String, dynamic>>[];

      for (final conversation in conversations) {
        final conversationId = conversation['id']?.toString();
        if (conversationId == null || conversationId.isEmpty) continue;

        final otherUser = await chatService.getOtherUser(
          conversationId,
          user.id,
        );
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

      hydratedConversations.sort((a, b) {
        final aLast = a['last_message'] as Map<String, dynamic>?;
        final bLast = b['last_message'] as Map<String, dynamic>?;
        final aDate = DateTime.tryParse(aLast?['created_at']?.toString() ?? '');
        final bDate = DateTime.tryParse(bLast?['created_at']?.toString() ?? '');
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

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
      final fallbackNearby = <Map<String, dynamic>>[];

      for (final vehicle in filtered) {
        final copy = Map<String, dynamic>.from(vehicle);
        final distance = _vehicleDistanceKm(copy);
        if (distance != null) {
          copy['distance_km'] = distance;
          // Keep only vehicles within the nearby search radius when coordinates
          // are available.
          if (distance <= 75) {
            nearby.add(copy);
          }
          continue;
        }

        if (_vehicleMatchesNearbyText(copy)) {
          fallbackNearby.add(copy);
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
        ..addAll(fallbackNearby);
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
    if (picked == null) return;
    if (!mounted) return;

    setState(() {
      _bookingFilterFrom = picked.start;
      _bookingFilterTo = picked.end;
    });
    await _loadVehicles();

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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
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
                                  : () => Navigator.pop(
                                      dialogContext,
                                      DateTimeRange(
                                        start: rangeStart!,
                                        end: rangeEnd!,
                                      ),
                                    ),
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
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
      final paymentStatus =
          booking['payment_status']?.toString().trim().isNotEmpty == true
          ? booking['payment_status'].toString().trim()
          : booking['reservation_payment_status']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
          ? booking['reservation_payment_status'].toString().trim()
          : 'Reservation pending';
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
      final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
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
        'imageUrl': conversation['vehicle_image_url']?.toString() ?? '',
      };
    }).toList();
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
        final supabase = Supabase.instance.client;
        final conversation = await supabase
            .from('conversations')
            .select('id')
            .eq('booking_id', bookingId)
            .maybeSingle();
        conversationId = conversation?['id']?.toString();
      }

      if (conversationId == null || conversationId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group chat is initializing. Please refresh in a moment.'),
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
  Widget _buildHomeTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? AppColors.darkBgSecondary
        : AppColors.lightBgSecondary;
    final mutedCardColor = isDark
        ? AppColors.darkBgTertiary
        : AppColors.lightBgTertiary;
    final borderColor = isDark
        ? AppColors.borderColor
        : AppColors.lightBorderColor;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    final tertiaryTextColor = isDark
        ? AppColors.textTertiary
        : AppColors.lightTextTertiary;
    final uiBookings = _uiBookings();
    final homeTrips = uiBookings
        .where(
          (b) =>
              b['statusGroup'] == 'Pending' ||
              b['statusGroup'] == 'Approved' ||
              b['statusGroup'] == 'Ongoing',
        )
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
                      GestureDetector(
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        child: Container(
                          width: 48,
                          height: 48,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: userAvatarUrl?.trim().isNotEmpty == true
                              ? OptimizedNetworkImage(
                                  imageUrl: userAvatarUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  isThumbnail: true,
                                  errorWidget: const Icon(
                                    Icons.person,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.person, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome,',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  status: userVerified
                                      ? 'Verified'
                                      : 'Basic Renter',
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  borderRadius: 6,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Compact location field; the map opens only when needed.
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openCurrentLocationPicker,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(28),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CURRENT LOCATION',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    userLocation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchVehiclesByLocation(),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Search city, location, brand, or model...',
                        hintStyle: TextStyle(color: tertiaryTextColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: tertiaryTextColor,
                        ),
                        suffixIcon: Tooltip(
                          message: 'Search location',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _isSearchingVehicles
                                ? null
                                : _searchVehiclesByLocation,
                            child: Container(
                              width: 42,
                              height: 42,
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _isSearchingVehicles
                                  ? const Padding(
                                      padding: EdgeInsets.all(11),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.search,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_nearbyLatitude != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(28),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.success.withAlpha(120),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.success,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Showing cars near ${_nearbyLocationLabel ?? 'you'}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearNearbyVehicleFilter,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_bookingFilterFrom == null && _bookingFilterTo == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectBookNowDates,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Book Now!'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isLoadingVehicles
                              ? null
                              : _resetBookNowDateFilter,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectBookNowDates,
                            icon: const Icon(Icons.calendar_month, size: 19),
                            label: Text(
                              _formatDateRange(
                                _bookingFilterFrom,
                                _bookingFilterTo,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                  Text(
                    'Your Trips',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
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
                height: 200,
                child: homeTrips.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Center(
                          child: Text(
                            'No trips yet',
                            style: TextStyle(
                              color: secondaryTextColor,
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
                          final imageUrl = booking['imageUrl']
                              ?.toString()
                              .trim();
                          final hasImage =
                              imageUrl != null && imageUrl.isNotEmpty;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 260,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 100,
                                      width: double.infinity,
                                      child: _buildFastVehicleImage(
                                        imageUrl: hasImage ? imageUrl : null,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        backgroundColor: mutedCardColor,
                                        iconColor: tertiaryTextColor,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            booking['carName'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            booking['rentalPartner'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 9),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 12,
                                                color: tertiaryTextColor,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${booking['days']} days',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: secondaryTextColor,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              if (((booking['rating'] as num?)
                                                          ?.toDouble() ??
                                                      0) >
                                                  0) ...[
                                                const Icon(
                                                  Icons.star,
                                                  size: 12,
                                                  color: AppColors.ratingGold,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  (booking['rating'] as num)
                                                      .toStringAsFixed(1),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: secondaryTextColor,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
                  Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VehicleSearchScreen(
                            initialCategory: selectedCategory.isEmpty
                                ? null
                                : selectedCategory,
                            initialAvailableFrom: _bookingFilterFrom,
                            initialAvailableTo: _bookingFilterTo,
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
                                    : cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : borderColor,
                                ),
                              ),
                              child: Icon(
                                category['icon'] as IconData,
                                color: isSelected
                                    ? Colors.black
                                    : secondaryTextColor,
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
                                    : secondaryTextColor,
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

            // Keep partner vehicles visible immediately below categories.
            _buildPartnersNearYouSection(
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Cars',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${_filteredVehicles.length} cars',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
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
                                initialAvailableFrom: _bookingFilterFrom,
                                initialAvailableTo: _bookingFilterTo,
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
                : _vehicles.isEmpty || _filteredVehicles.isEmpty
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
                          Text(
                            _vehicles.isEmpty
                                ? 'No vehicles available'
                                : _nearbyLatitude != null
                                ? 'No cars found near ${_nearbyLocationLabel ?? 'you'}'
                                : 'No cars match your search',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_filteredVehicles.isEmpty &&
                              _vehicles.isNotEmpty &&
                              _nearbyLatitude != null) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _clearNearbyVehicleFilter,
                              icon: const Icon(Icons.location_off_outlined),
                              label: const Text('Show all cars'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
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
                      final carName = toProfessionalTitleCase(
                        '${car['brand'] ?? 'Unknown'} ${car['model'] ?? 'Model'}',
                      );
                      final category =
                          (car['vehicle_type'] ?? car['category'] ?? 'Standard')
                              .toString()
                              .toUpperCase();

                      // ✅ FIX: Separate hour and day prices
                      final pricePerHour =
                          (car['price_per_hour'] as num?)?.toDouble() ?? 0.0;
                      final pricePerDay =
                          (car['price_per_day'] as num?)?.toDouble() ?? 0.0;

                      final rawRating =
                          (car['rating'] as num?)?.toDouble() ?? 0.0;
                      final rawCount =
                          (car['rating_count'] as num?)?.toInt() ?? 0;
                      // Only show a real rating when there are actual reviews.
                      // Never fabricate a count.
                      final rating = rawRating;
                      final ratingCount = rawCount;
                      final vehicleType = toProfessionalTitleCase(
                        (car['vehicle_type'] ?? 'Standard').toString(),
                      );
                      final color = toProfessionalTitleCase(
                        (car['color'] ?? 'Unknown').toString(),
                      );
                      final seats = car['seats'] ?? 5;

                      // ✅ FIX: Read transmission field instead of reusing vehicleType
                      final transmission = toProfessionalTitleCase(
                        (car['transmission'] ?? 'Manual').toString(),
                      );

                      final isPartnerVehicle =
                          car['source']?.toString().toLowerCase() ==
                              'partner' ||
                          car['is_partner_vehicle'] == true ||
                          car['owner_role']?.toString().toLowerCase() ==
                              'partner' ||
                          car['partner_vehicle_id'] != null;
                      final partnerName =
                          car['partner_name']?.toString().trim().isNotEmpty ==
                              true
                          ? toProfessionalTitleCase(
                              car['partner_name'].toString(),
                            )
                          : 'Mobilis Partner';
                      final providerName = isPartnerVehicle
                          ? 'PSDC Partner'
                          : 'PSDC';
                      final vehicleId = car['id']?.toString() ?? '';
                      final isFavorite = _favoriteVehicleIds.contains(
                        vehicleId,
                      );
                      final distanceKm = (car['distance_km'] as num?)
                          ?.toDouble();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/vehicle-detail',
                              arguments: {
                                'vehicleId': car['id']?.toString() ?? '',
                                'vehicleData': car,
                                'initialStartDate': _bookingFilterFrom,
                                'initialEndDate': _bookingFilterTo,
                              },
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        height: 200,
                                        color: mutedCardColor,
                                        child: VehicleImageCarousel(
                                          key: ValueKey(
                                            'renter-car-$vehicleId',
                                          ),
                                          vehicle: car,
                                          height: 200,
                                          backgroundColor: mutedCardColor,
                                          iconColor: tertiaryTextColor,
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
                                            color: cardColor,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: borderColor,
                                            ),
                                          ),
                                          child: Text(
                                            providerName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
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
                                            color: cardColor,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: borderColor,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              if (ratingCount > 0) ...
                                                [
                                                  const Icon(
                                                    Icons.star,
                                                    color: AppColors.ratingGold,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${rating.toStringAsFixed(1)} ($ratingCount)',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                ]
                                              else ...
                                                [
                                                  Text(
                                                    'New',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: GestureDetector(
                                          onTap: () =>
                                              _toggleFavoriteVehicle(car),
                                          child: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isFavorite
                                                    ? AppColors.error
                                                    : borderColor,
                                              ),
                                            ),
                                            child: Icon(
                                              isFavorite
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isFavorite
                                                  ? AppColors.error
                                                  : secondaryTextColor,
                                              size: 20,
                                            ),
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
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        if (isPartnerVehicle) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withOpacity(0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: const Text(
                                                  'FROM PARTNERS',
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  partnerName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: secondaryTextColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: tertiaryTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Keep all primary specs in one row.
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildFeatureIcon(
                                                    Icons.directions_car,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    vehicleType.toString(),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: secondaryTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildFeatureIcon(
                                                    Icons.palette_outlined,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    color.toString(),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: secondaryTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildFeatureIcon(
                                                    Icons.person,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$seats Seats',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: secondaryTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildFeatureIcon(
                                                    Icons.settings_outlined,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    transmission,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: secondaryTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (distanceKm != null) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              _buildFeatureIcon(
                                                Icons.location_on_outlined,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${distanceKm.toStringAsFixed(distanceKm < 10 ? 1 : 0)} km away',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: secondaryTextColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // ✅ FIX: Show both per hour and per day prices
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (pricePerHour > 0)
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              '₱${formatAmount(pricePerHour, decimalDigits: 0)}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: AppColors
                                                                    .primary,
                                                              ),
                                                        ),
                                                        TextSpan(
                                                          text: '/hr',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                secondaryTextColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (pricePerDay > 0)
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              '₱${formatAmount(pricePerDay, decimalDigits: 0)}',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                secondaryTextColor,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: '/day',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                secondaryTextColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: 44,
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  if (await _checkRentalVerification() &&
                                                      await _canOpenVehicleBooking(
                                                        car,
                                                      )) {
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
                                                        'initialStartDate':
                                                            _bookingFilterFrom,
                                                        'initialEndDate':
                                                            _bookingFilterTo,
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
          ],
        ),
      ),
    );
  }

  Widget _buildPartnersNearYouSection({
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    bool isPartnerVehicle(Map<String, dynamic> vehicle) {
      final source = vehicle['source']?.toString().toLowerCase();
      final ownerRole = vehicle['owner_role']?.toString().toLowerCase();
      final owner = vehicle['owner'];
      final relatedOwnerRole = owner is Map
          ? owner['role']?.toString().toLowerCase()
          : null;
      return source == 'partner' ||
          ownerRole == 'partner' ||
          relatedOwnerRole == 'partner' ||
          vehicle['is_partner_vehicle'] == true;
    }

    final allPartnerVehicles = _vehicles.where(isPartnerVehicle).toList();
    final nearbyPartnerIds = _filteredVehicles
        .where(isPartnerVehicle)
        .map((vehicle) => vehicle['id']?.toString())
        .whereType<String>()
        .toSet();
    final nearbyPartnerVehicles = allPartnerVehicles
        .where(
          (vehicle) => nearbyPartnerIds.contains(vehicle['id']?.toString()),
        )
        .toList();
    final partnerVehicles =
        _nearbyLatitude != null && nearbyPartnerVehicles.isNotEmpty
        ? nearbyPartnerVehicles
        : allPartnerVehicles;

    if (partnerVehicles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Partners Near You',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                '${partnerVehicles.length} car${partnerVehicles.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 218,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: partnerVehicles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final vehicle = partnerVehicles[index];
                final vehicleId = vehicle['id']?.toString() ?? '';
                final title = toProfessionalTitleCase(
                  '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}',
                );
                final partnerName =
                    vehicle['partner_name']?.toString().trim().isNotEmpty ==
                        true
                    ? toProfessionalTitleCase(
                        vehicle['partner_name'].toString(),
                      )
                    : toProfessionalTitleCase(
                        vehicle['owner_name']?.toString() ?? 'Mobilis Partner',
                      );
                final dailyPrice =
                    (vehicle['price_per_day'] as num?)?.toDouble() ?? 0;
                final hourlyPrice =
                    (vehicle['price_per_hour'] as num?)?.toDouble() ?? 0;

                return GestureDetector(
                  onTap: vehicleId.isEmpty
                      ? null
                      : () => Navigator.of(context).pushNamed(
                          '/vehicle-detail',
                          arguments: {
                            'vehicleId': vehicleId,
                            'vehicleData': vehicle,
                            'initialStartDate': _bookingFilterFrom,
                            'initialEndDate': _bookingFilterTo,
                          },
                        ),
                  child: Container(
                    width: 232,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 112,
                          width: double.infinity,
                          child: VehicleImageCarousel(
                            key: ValueKey('partner-car-$vehicleId'),
                            vehicle: vehicle,
                            height: 112,
                            backgroundColor: cardColor,
                            iconColor: secondaryTextColor,
                            showArrows: false,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? 'Partner Vehicle' : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                partnerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.payments_outlined,
                                    color: AppColors.primary,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dailyPrice > 0
                                          ? 'PHP ${formatAmount(dailyPrice, decimalDigits: 0)} / day'
                                          : 'PHP ${formatAmount(hourlyPrice, decimalDigits: 0)} / hour',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bookings Tab
  // ---------------------------------------------------------------------------
  Widget _buildBookingsTab() {
    final uiBookings = _uiBookings();
    final visibleBookings = uiBookings
        .where((booking) => booking['statusGroup'] == _selectedBookingStatus)
        .toList();

    return Column(
      children: [
        _buildCenteredTabHeader('My Bookings'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBookings,
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              children: [
                RoleTabHeader(
                  title: 'Rental Bookings',
                  subtitle:
                      'Requests, ongoing rentals, completed trips, and tracking',
                  icon: Icons.calendar_month_outlined,
                  badge: '${uiBookings.length} total',
                ),
                const SizedBox(height: 12),
                _buildRenterBookingStatusTabs(uiBookings),
                const SizedBox(height: 14),
                _buildBookingsList(visibleBookings),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRenterBookingStatusTabs(List<Map<String, dynamic>> bookings) {
    const statuses = [
      'Pending',
      'Approved',
      'Ongoing',
      'Completed',
      'Cancelled',
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((status) {
          final selected = _selectedBookingStatus == status;
          final count = bookings
              .where((booking) => booking['statusGroup'] == status)
              .length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _selectedBookingStatus = status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: status == 'Cancelled' ? 108 : 96,
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
                  '$status ($count)',
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

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return RoleEmptyStateCard(
        icon: Icons.route_outlined,
        title: 'No ${_selectedBookingStatus.toLowerCase()} bookings',
        message:
            'Bookings with this status will appear here once available. Pull down to refresh.',
      );
    }

    return Column(
      children: List.generate(
        bookings.length,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () {
              setState(() => selectedBookingIndex = index);
              final booking = bookings[index];
              _isCancelledBooking(booking)
                  ? _showCancellationDetails(booking)
                  : _showBookingDetails(booking);
            },
            child: Builder(
              builder: (context) {
                final booking = bookings[index];
                final isCompleted = booking['statusGroup'] == 'Completed';
                final isCancelled = _isCancelledBooking(booking);
                final rawStatus =
                    booking['rawStatus']?.toString().toLowerCase() ?? '';
                final isNavigable =
                    booking['statusGroup'] == 'Ongoing' &&
                    {'active', 'ongoing'}.contains(rawStatus);

                final bookingIdStr = booking['id'].toString();
                final isReturnSubmitted =
                    rawStatus == 'return_pending_inspection' ||
                    rawStatus == 'awaiting_completion' ||
                    rawStatus == 'completed' ||
                    rawStatus == 'returned' ||
                    rawStatus == 'successful' ||
                    rawStatus == 'success' ||
                    rawStatus == 'awaiting_ratings' ||
                    booking['returned_at'] != null ||
                    booking['returnedAt'] != null;
                final isRated = _isRenterBookingFullyRated(booking);

                final isPaidInFull = booking['reservationPaymentCoversTotal'] == true ||
                    booking['reservationPaymentType'] == 'full_payment' ||
                    booking['payment_status'] == 'paid_in_full' ||
                    booking['is_full_payment'] == true ||
                    booking['pre_trip_settlement_paid'] == true;
                final isApprovedOrReady = booking['statusGroup'] == 'Approved' ||
                    rawStatus == 'approved' ||
                    rawStatus == 'confirmed' ||
                    rawStatus == 'pending_release';
                final showPayNow = isApprovedOrReady && !isPaidInFull;

                return BookingCard(
                  carName: booking['carName'],
                  rentalPartner: booking['rentalPartner'],
                  status: booking['status'],
                  days: (booking['days'] as num?)?.toInt() ?? 0,
                  pickupLocation: booking['pickupLocation'],
                  dropoffLocation: booking['dropoffLocation'],
                  totalCost: (booking['totalCost'] as num?)?.toInt() ?? 0,
                  rating: (booking['rating'] as num?)?.toDouble() ?? 0.0,
                  isActive: booking['statusGroup'] == 'Ongoing',
                  ongoingSummary: booking['statusGroup'] == 'Ongoing'
                      ? BookingReturnCountdown(booking: booking, compact: true)
                      : null,
                  carImageUrl: booking['imageUrl'] as String?,
                  showRating:
                      booking['statusGroup'] == 'Completed' &&
                      ((booking['rating'] as num?)?.toDouble() ?? 0) > 0,
                  showRateButton: isReturnSubmitted,
                  isAlreadyRated: isRated,
                  isPaidInFull: isPaidInFull,
                  showPayNowButton: showPayNow,
                  onPayNow: () => _handlePreTripReleasePayment(booking),
                  onRateTrip: () async {
                    final submitted = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => TripRatingFlowScreen(
                          bookingId: bookingIdStr,
                          reviewerRole: 'renter',
                          title: 'Rate Trip',
                          subtitle: 'Leave your ratings and reviews for this trip.',
                        ),
                      ),
                    );
                    if (submitted == true) {
                      await TripRatingService().reconcileCompletedBooking(bookingIdStr);
                      _loadBookings();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Rating saved successfully! Thank you.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  },
                  showTrackButton: isNavigable,
                  trackButtonLabel: 'Navigate',
                  onTrack: isNavigable
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TripNavigationScreen(
                              bookingId: booking['id'].toString(),
                              participantRole: 'renter',
                            ),
                          ),
                        )
                      : null,
                  detailsButtonLabel: isCompleted
                      ? 'View Receipt'
                      : isCancelled
                      ? 'Details'
                      : 'View Details',
                  onTap: () => isCancelled
                      ? _showCancellationDetails(booking)
                      : _showBookingDetails(booking),
                  onViewDetails: () => isCompleted
                      ? _showTripReceipt(booking)
                      : isCancelled
                      ? _showCancellationDetails(booking)
                      : _showBookingDetails(booking),
                  showMessageButton: _canOpenBookingConversation(booking),
                  isMessageLocked:
                      !BookingService().isEligibleForBookingChat(booking),
                  messageLockedReason:
                      'Group chat will automatically unlock 72 hours (3 days) before your trip starts.',
                  onMessage: () => _openBookingConversation(booking),
                  showCancelButton:
                      booking['statusGroup'] == 'Pending' &&
                      _canCancelBooking(booking),
                  onCancel: () => _handleBookingCancellation(booking),
                );
              },
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

    return Column(
      children: [
        _buildCenteredTabHeader('Notifications'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadNotifications,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoleTabHeader(
                    title: 'Notifications',
                    subtitle: 'Booking updates, approvals, and trip reminders',
                    icon: Icons.notifications_outlined,
                    badge: '$_unreadNotificationCount unread',
                    action: _unreadNotificationCount > 0
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
                  const SizedBox(height: 18),
                  // Empty State
                  if (notificationItems.isEmpty)
                    const RoleEmptyStateCard(
                      icon: Icons.notifications_none,
                      title: 'No notifications yet',
                      message:
                          'Booking updates, approvals, and trip reminders will appear here.',
                    )
                  else
                    Column(
                      children: List.generate(
                        notificationItems.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _handleNotificationTap(
                              notificationItems[index],
                            ),
                            onLongPress: () => _showNotificationDetails(
                              notificationItems[index],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color:
                                    notificationItems[index]['isRead'] == true
                                    ? const Color(0xFF2A3548)
                                    : const Color(0xFF354156),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      notificationItems[index]['isRead'] == true
                                      ? AppColors.borderColor
                                      : Colors.white70,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color:
                                          notificationItems[index]['iconColor']
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child:
                                        notificationItems[index]['imageUrl']
                                                ?.toString()
                                                .trim()
                                                .isNotEmpty ==
                                            true
                                        ? OptimizedNetworkImage(
                                            imageUrl:
                                                notificationItems[index]['imageUrl']
                                                    .toString(),
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            errorWidget: Icon(
                                              notificationItems[index]['icon'],
                                              color:
                                                  notificationItems[index]['iconColor'],
                                              size: 24,
                                            ),
                                          )
                                        : Icon(
                                            notificationItems[index]['icon'],
                                            color:
                                                notificationItems[index]['iconColor'],
                                            size: 24,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notificationItems[index]['title'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notificationItems[index]['message'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          notificationItems[index]['timestamp'],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (notificationItems[index]['isRead'] !=
                                      true) ...[
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
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Messages Tab
  // ---------------------------------------------------------------------------
  Widget _buildMessagesTab() {
    final conversations = _uiConversations();
    final unreadCount = conversations.fold<int>(
      0,
      (sum, conversation) => sum + (conversation['unreadCount'] as int? ?? 0),
    );

    return Column(
      children: [
        _buildCenteredTabHeader(
          'Messages',
          trailing: unreadCount > 0
              ? TextButton(
                  onPressed: _markAllMessagesRead,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoleTabHeader(
                  title: 'Messages',
                  subtitle: 'Booking conversations and customer service',
                  icon: Icons.chat_bubble_outline,
                  badge: unreadCount > 0 ? '$unreadCount unread' : null,
                ),
                const SizedBox(height: 18),
                // Empty State
                if (conversations.isEmpty)
                  const RoleEmptyStateCard(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    message:
                        'Booking group chats and customer service conversations will appear here.',
                  )
                else
                  // Conversations List
                  Column(
                    children: List.generate(
                      conversations.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => _openConversation(conversations[index]),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A3548),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.borderColor),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child:
                                      conversations[index]['imageUrl']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? OptimizedNetworkImage(
                                          imageUrl:
                                              conversations[index]['imageUrl']
                                                  .toString(),
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          errorWidget: const Icon(
                                            Icons.directions_car_outlined,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : Icon(
                                          conversations[index]['isCustomerService'] ==
                                                  true
                                              ? Icons.support_agent
                                              : Icons.directions_car_outlined,
                                          color: AppColors.primary,
                                          size: 24,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              conversations[index]['recipientName'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            conversations[index]['timestamp'],
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              conversations[index]['lastMessage'],
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if ((conversations[index]['unreadCount']
                                                      as int? ??
                                                  0) >
                                              0)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  (conversations[index]['unreadCount']
                                                              as int?)
                                                          ?.toString() ??
                                                      '0',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: AppColors.textTertiary,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
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

  // ---------------------------------------------------------------------------
  // Profile Tab
  // ---------------------------------------------------------------------------
  Widget _buildProfileTab() {
    if (selectedProfilePage == 'settings') {
      return SettingsScreen(
        onThemeToggle: widget.onThemeToggle,
        isDarkMode: widget.isDarkMode,
        onBack: () => setState(() => selectedProfilePage = null),
        onOpenSupport: _openCustomerServiceConversation,
        onProfileUpdated: _loadUserData,
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
    } else if (selectedProfilePage == 'favorites') {
      return _buildFavoriteVehiclesPage();
    }

    return UnifiedProfileScreen(
      role: 'renter',
      isDarkMode: widget.isDarkMode,
      onThemeToggle: widget.onThemeToggle,
      onProfileUpdated: _loadUserData,
      onOpenSupport: _openCustomerServiceConversation,
      onOpenVerification: () =>
          setState(() => selectedProfilePage = 'verification'),
      onOpenFavorites: () => setState(() => selectedProfilePage = 'favorites'),
      stats: [
        ProfileStatItem(
          label: 'Trips',
          value: '$_totalTrips',
          onTap: () => setState(() => selectedNavIndex = 1),
        ),
        ProfileStatItem(
          label: 'Loyalty',
          value: userVerified ? 'Verified' : 'Basic',
        ),
        ProfileStatItem(
          label: 'Rating',
          value: _userRating > 0 ? _userRating.toStringAsFixed(1) : '0.0',
          onTap: () {
            final userId = AuthService().currentUser?.id;
            if (userId == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RatingsReviewsScreen(
                  userId: userId,
                  title: 'My Ratings & Reviews',
                ),
              ),
            );
          },
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

  Widget _buildFavoriteVehiclesPage() {
    final user = AuthService().currentUser;

    return Column(
      children: [
        Container(
          color: AppColors.darkBg,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            12,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => selectedProfilePage = null),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
              ),
              const Expanded(
                child: Text(
                  'Liked Cars',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: user == null
              ? const Center(
                  child: Text(
                    'Sign in to see liked cars',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : FutureBuilder<List<Map<String, dynamic>>>(
                  future: FavoriteVehicleService().getFavoriteVehicles(user.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final vehicles = snapshot.data ?? [];
                    if (vehicles.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.favorite_border,
                                size: 54,
                                color: AppColors.textTertiary,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No liked cars yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Tap the heart on a car to save it here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _loadFavoriteVehicleIds,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: vehicles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final vehicle = vehicles[index];
                          return _buildLikedVehicleTile(vehicle);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLikedVehicleTile(Map<String, dynamic> vehicle) {
    final name =
        '${vehicle['brand'] ?? 'Unknown'} ${vehicle['model'] ?? 'Vehicle'}';
    final category =
        (vehicle['vehicle_type'] ?? vehicle['category'] ?? 'Standard')
            .toString();
    final price = (vehicle['price_per_day'] as num?)?.toDouble() ?? 0;

    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          '/vehicle-detail',
          arguments: {
            'vehicleId': vehicle['id']?.toString() ?? '',
            'vehicleData': vehicle,
          },
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                height: 64,
                child: VehicleImageCarousel(
                  key: ValueKey('favorite-car-${vehicle['id']}'),
                  vehicle: vehicle,
                  height: 64,
                  backgroundColor: AppColors.darkBgTertiary,
                  iconColor: AppColors.textTertiary,
                  showArrows: false,
                  showIndicator: false,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₱${formatAmount(price, decimalDigits: 0)} / day',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _toggleFavoriteVehicle(vehicle),
              icon: const Icon(Icons.favorite, color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  bool _isBookingWithDriver(Map<String, dynamic> booking) {
    final withDriver = booking['withDriver'] == true ||
        booking['with_driver'] == true ||
        booking['with_driver'] == 1 ||
        booking['with_driver']?.toString().toLowerCase() == 'true';
    final driverId = booking['driver_id']?.toString().trim();
    final driverName = booking['driverName']?.toString().trim() ??
        booking['driver_name']?.toString().trim();
    final hasDriverAssigned = (driverId != null && driverId.isNotEmpty && driverId != 'null') ||
        (driverName != null &&
            driverName.isNotEmpty &&
            driverName != 'To be assigned' &&
            driverName != 'Not requested');
    return withDriver || hasDriverAssigned;
  }

  // ---------------------------------------------------------------------------
  // Booking detail modal
  // ---------------------------------------------------------------------------
  void _showBookingDetails(Map<String, dynamic> booking) {
    final isApprovedTrip = booking['statusGroup'] == 'Ongoing';
    final isPendingTrip = booking['statusGroup'] == 'Pending';
    final completionState = BookingService().getTripCompletionState(booking);
    final pendingRoles =
        (completionState['pendingRoles'] as List<dynamic>? ?? const [])
            .map((role) => role.toString())
            .toList();
    final completionStage =
        completionState['completionStage']?.toString() ?? 'not_started';
    final rawStatus = (booking['rawStatus'] ?? booking['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    const completedStatuses = {
      'completed',
      'returned',
      'successful',
      'success',
      'awaiting_ratings',
    };
    final isCompletedTrip =
        completionStage == 'completed' ||
        completedStatuses.contains(rawStatus) ||
        completionState['status'] == 'completed';
    final effectiveCompletionStage =
        completionStage == 'not_started' &&
            completedStatuses.contains(rawStatus)
        ? 'completed'
        : completionStage;

    if (isPendingTrip) {
      _showPendingBookingDetails(booking);
      return;
    }

    final isPaidInFull = booking['reservationPaymentCoversTotal'] == true ||
        booking['reservationPaymentType'] == 'full_payment' ||
        booking['payment_status'] == 'paid_in_full' ||
        booking['is_full_payment'] == true ||
        booking['pre_trip_settlement_paid'] == true;
    final isApprovedOrReady = booking['statusGroup'] == 'Approved' ||
        rawStatus == 'approved' ||
        rawStatus == 'confirmed' ||
        rawStatus == 'pending_release';
    final showPayNow = isApprovedOrReady && !isPaidInFull;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RenterBookingDetailsPage(
          booking: booking,
          isApprovedTrip: isApprovedTrip,
          isCompletedTrip: isCompletedTrip,
          completionStage: effectiveCompletionStage,
          pendingRoles: pendingRoles,
          paymentTypeLabel: _bookingPaymentTypeLabel(booking),
          amountPaidLabel: _bookingAmountPaidLabel(booking),
          isPaidInFull: isPaidInFull,
          onPayRemainingBalance: showPayNow
              ? () => _handlePreTripReleasePayment(booking)
              : null,
          onMessage: _canOpenBookingConversation(booking)
              ? () => _openBookingConversation(booking)
              : null,
          onNavigate:
              {
                'active',
                'ongoing',
              }.contains(booking['rawStatus']?.toString().toLowerCase())
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripNavigationScreen(
                      bookingId: booking['id'].toString(),
                      participantRole: 'renter',
                    ),
                  ),
                )
              : null,
          onCancel: _isCancellableStatusForUi(booking)
              ? () => _handleBookingCancellation(booking)
              : null,
          onExtend: (isApprovedTrip && !_isBookingWithDriver(booking))
              ? () => _showTripExtensionDialog(booking)
              : null,
          onReturn: isApprovedTrip
              ? () => _handleRenterReturnVehicle(booking)
              : null,
          onSuccessfulTrip:
              ({
                    'renter_rating',
                    'completed',
                    'awaiting_completion',
                    'awaiting_ratings',
                  }.contains(effectiveCompletionStage) ||
                  completedStatuses.contains(rawStatus))
              ? () => _handleSuccessfulTripFromDetails(
                  booking: booking,
                  completionStage: effectiveCompletionStage,
                  pendingRoles: pendingRoles,
                )
              : null,
          onReceipt: () => _showTripReceipt(booking),
          isAlreadyRated: _isRenterBookingFullyRated(booking),
          onRateTrip: () async {
            final bookingId = booking['id']?.toString() ?? '';
            final submitted = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => TripRatingFlowScreen(
                  bookingId: bookingId,
                  reviewerRole: 'renter',
                  title: 'Rate Trip',
                  subtitle: 'Leave your ratings and reviews for this trip.',
                ),
              ),
            );
            if (submitted == true) {
              await TripRatingService().reconcileCompletedBooking(bookingId);
              _loadBookings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Rating saved successfully! Thank you.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            }
          },
        ),
      ),
    );

    return;

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
            if (isApprovedTrip) ...[
              _buildActiveTripHero(booking),
              const SizedBox(height: 16),
            ],
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
                      image:
                          booking['vehicles'] != null &&
                              booking['vehicles']['image_url'] != null
                          ? DecorationImage(
                              image: OptimizedNetworkImageProvider(
                                booking['vehicles']['image_url'] as String,
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child:
                        booking['vehicles'] == null ||
                            booking['vehicles']['image_url'] == null
                        ? const Icon(
                            Icons.directions_car,
                            color: AppColors.textSecondary,
                          )
                        : null,
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
              'Booking Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  _buildBookingDetailRow(
                    icon: Icons.directions_car,
                    label: 'Car',
                    value: booking['carName']?.toString() ?? 'Vehicle',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.person_pin_circle_outlined,
                    label: 'Driver',
                    value: booking['driverName']?.toString() ?? 'Not requested',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.flag_circle_outlined,
                    label: 'Status',
                    value: booking['status']?.toString() ?? 'Pending',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.payment,
                    label: 'Reservation Payment',
                    value:
                        booking['paymentStatus']?.toString() ??
                        'Reservation pending',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Payment Type',
                    value: _bookingPaymentTypeLabel(booking),
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.payments,
                    label: 'Amount Paid',
                    value: _bookingAmountPaidLabel(booking),
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.payments_outlined,
                    label: 'Booking Cost',
                    value:
                        '₱${formatAmount(booking['totalCost'] as num, decimalDigits: 0)}',
                  ),
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
              time: booking['startTime'] ?? 'N/A',
              icon: Icons.location_on,
              isActive: true,
            ),
            const SizedBox(height: 16),
            TripTimelineStep(
              label: 'Dropoff',
              date: booking['endDate'],
              time: booking['endTime'] ?? 'N/A',
              icon: Icons.location_on,
              isCompleted: booking['statusGroup'] == 'Completed',
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
                  '${booking['days']} days × ₱${formatAmount(booking['totalCost'] ~/ booking['days'], decimalDigits: 0)}/day',
              amount:
                  '₱${formatAmount(booking['totalCost'] as num, decimalDigits: 0)}',
            ),
            const CostBreakdownRow(label: 'Insurance', amount: '₱50'),
            CostBreakdownRow(
              label: 'Tax (10%)',
              amount:
                  '₱${formatAmount((booking['totalCost'] + 50) * 0.1, decimalDigits: 0)}',
            ),
            const Divider(color: AppColors.borderColor),
            CostBreakdownRow(
              label: 'Total',
              amount:
                  '₱${formatAmount(booking['totalCost'] + 50 + ((booking['totalCost'] + 50) * 0.1), decimalDigits: 0)}',
              isBold: true,
              amountColor: AppColors.primary,
            ),
            const SizedBox(height: 20),
            if (isCompletedTrip && pendingRoles.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                ),
                child: Text(
                  'Waiting for ${_formatRoleList(pendingRoles)} to confirm this trip as successful before you can finish it.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isApprovedTrip || isCompletedTrip) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final bookingId = booking['id']?.toString() ?? '';
                    if (bookingId.isEmpty) return;

                    await _handleSuccessfulTripFromDetails(
                      booking: booking,
                      completionStage: completionStage,
                      pendingRoles: pendingRoles,
                    );
                  },
                  icon: const Icon(Icons.star_rate_rounded, size: 18),
                  label: Text(
                    isCompletedTrip ? 'Successful Trip' : 'View Trip Status',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final bookingId = booking['id']?.toString() ?? '';
                    if (bookingId.isNotEmpty) {
                      TripRouteHistoryDialog.show(
                        context: context,
                        bookingId: bookingId,
                        vehicleName: booking['vehicleName']?.toString(),
                        plateNumber: booking['plateNumber']?.toString(),
                      );
                    }
                  },
                  icon: const Icon(Icons.route_rounded, size: 18, color: AppColors.primary),
                  label: const Text('View Traveled Route & Destination Audit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isApprovedTrip || _isCancellableStatusForUi(booking)) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showRescheduleTripDialog(booking);
                  },
                  icon: const Icon(Icons.event_repeat_rounded, size: 18, color: Color(0xFFE5A93C)),
                  label: const Text('Reschedule Trip Dates (Keep Deposit)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE5A93C),
                    side: const BorderSide(color: Color(0xFFE5A93C)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isApprovedTrip && !_isBookingWithDriver(booking))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTripExtensionDialog(booking),
                  icon: const Icon(Icons.more_time, size: 18),
                  label: const Text('Check for Extend Trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            if (_isCancellableStatusForUi(booking))
              StreamBuilder<int>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (tick) => tick,
                ),
                initialData: 0,
                builder: (context, snapshot) {
                  final timeInfo = _getRemainingCancelTime(booking);
                  final canCancel = timeInfo['canCancel'] as bool;
                  final hours = timeInfo['hours'] as int;
                  final minutes = timeInfo['minutes'] as int;
                  final seconds = timeInfo['seconds'] as int;
                  final progress =
                      (timeInfo['totalSecondsRemaining'] as int) /
                      (24 * 60 * 60);

                  if (canCancel) {
                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _handleBookingCancellation(booking);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              booking['statusGroup'] == 'Pending'
                                  ? 'Cancel Request'
                                  : 'Cancel Booking',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD).withAlpha(230),
                            border: Border.all(
                              color: const Color(0xFFFFC107),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '⏱️ Cancel within: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8B6914),
                                    ),
                                  ),
                                  Text(
                                    '${hours}h ${minutes}m ${seconds}s',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8B6914),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: Colors.grey[300],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFFC107),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(25),
                        border: Border.all(color: AppColors.error),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⏰ Cancellation Window Closed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Bookings can only be cancelled within 24 hours after request.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSuccessfulTripFromDetails({
    required Map<String, dynamic> booking,
    required String completionStage,
    required List<String> pendingRoles,
  }) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    if ({
      'renter_rating',
      'completed',
      'awaiting_completion',
      'awaiting_ratings',
    }.contains(completionStage)) {
      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TripRatingFlowScreen(
            bookingId: bookingId,
            reviewerRole: 'renter',
            title: 'Complete Trip Ratings',
            subtitle:
                'Rate every required trip participant to complete this booking.',
          ),
        ),
      );
      if (submitted == true) {
        await TripRatingService().reconcileCompletedBooking(bookingId);
        await _loadBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ratings saved successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
      return;
    }

    if (completionStage == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This trip is already completed successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }

    final waitingFor = pendingRoles.isEmpty
        ? 'the required return steps'
        : _formatRoleList(pendingRoles);
    final message = switch (completionStage) {
      'awaiting_after_checklist' =>
        'Waiting for the vehicle owner to submit the after-return checklist and evidence.',
      'awaiting_payment' =>
        'Waiting for the vehicle owner to confirm the full payment and any late fees.',
      'operator_rating' =>
        'Waiting for the PSDC operator to submit the required renter rating.',
      'partner_rating' =>
        'Waiting for the vehicle partner to submit the required renter rating.',
      'driver_rating' =>
        'Waiting for the driver to submit the required renter rating.',
      _ =>
        'This trip is still ongoing. Complete the return before final ratings. Pending: $waitingFor.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.warning),
    );
  }

  void _showPendingBookingDetails(Map<String, dynamic> booking) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RenterBookingDetailsPage(
          booking: booking,
          isApprovedTrip: false,
          isCompletedTrip: false,
          completionStage: 'not_started',
          pendingRoles: const [],
          paymentTypeLabel: _bookingPaymentTypeLabel(booking),
          amountPaidLabel: _bookingAmountPaidLabel(booking),
          onCancel: _isCancellableStatusForUi(booking)
              ? () => _handleBookingCancellation(booking)
              : null,
          onReceipt: () => _showTripReceipt(booking),
          isAlreadyRated: false,
          onRateTrip: null,
        ),
      ),
    );
    return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pending Approval',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPendingApprovalCard(booking),
              const SizedBox(height: 14),
              _buildPendingVehicleCard(booking),
              const SizedBox(height: 18),
              const Text(
                'Trip Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildPendingSummaryTile(
                icon: Icons.calendar_today_outlined,
                title: '${booking['startDate']} - ${booking['endDate']}',
                subtitle:
                    'RENTAL DATES • ${booking['days']} DAY${booking['days'] == 1 ? '' : 'S'}',
              ),
              const SizedBox(height: 10),
              _buildPendingSummaryTile(
                icon: booking['withDriver'] == true
                    ? Icons.support_agent
                    : Icons.drive_eta_outlined,
                title: booking['withDriver'] == true
                    ? booking['driverName']?.toString() ?? 'With Driver'
                    : 'Self Drive',
                subtitle: 'SERVICE TYPE',
              ),
              const SizedBox(height: 10),
              _buildPendingSummaryTile(
                icon: Icons.location_on_outlined,
                title: booking['pickupLocation']?.toString() ?? 'N/A',
                subtitle: 'PICKUP & DROP-OFF',
              ),
              const SizedBox(height: 14),
              _buildPendingAgreementNotes(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.hourglass_empty, size: 18),
                  label: const Text("Waiting for Owner's Approval"),
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: AppColors.darkBgTertiary,
                    disabledForegroundColor: AppColors.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<int>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (tick) => tick,
                ),
                initialData: 0,
                builder: (context, snapshot) {
                  final timeInfo = _getRemainingCancelTime(booking);
                  final canCancel = timeInfo['canCancel'] as bool;
                  final remaining = timeInfo['remainingTime']?.toString() ?? '';

                  return Column(
                    children: [
                      TextButton(
                        onPressed: canCancel
                            ? () {
                                Navigator.pop(context);
                                _handleBookingCancellation(booking);
                              }
                            : null,
                        child: Text(
                          canCancel ? 'Cancel Request' : 'Cancel Window Closed',
                          style: TextStyle(
                            color: canCancel
                                ? AppColors.textSecondary
                                : AppColors.textTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        canCancel
                            ? 'Cancellation available for $remaining'
                            : 'Bookings can only be cancelled within 24 hours after request.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTripReceipt(Map<String, dynamic> booking) {
    final days = (booking['days'] as num?)?.toInt() ?? 1;
    final safeDays = days < 1 ? 1 : days;
    final recordedTotal = (booking['totalCost'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (booking['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final driverFee = (booking['driverFee'] as num?)?.toDouble() ?? 0.0;
    final lateReturnFee = (booking['lateReturnFee'] as num?)?.toDouble() ?? 0.0;
    final rentalSubtotal =
        (booking['rentalSubtotal'] as num?)?.toDouble() ??
        (recordedTotal - deliveryFee).clamp(0.0, double.infinity).toDouble();
    final dailyRate = rentalSubtotal / safeDays;
    final total = rentalSubtotal + deliveryFee + driverFee + lateReturnFee;
    final reservationFee =
        (booking['reservationFeeAmount'] as num?)?.toDouble() ?? 1000.0;
    final totalBalance = (total - reservationFee)
        .clamp(0.0, double.infinity)
        .toDouble();
    final securityDeposit =
        (booking['securityDeposit'] as num?)?.toDouble() ?? 0.0;
    final reference = booking['reservationPaymentReference']?.toString().trim();
    final method = booking['reservationPaymentMethod']?.toString().trim();
    final finalMethod =
        booking['final_payment_method']?.toString() ??
        booking['finalPaymentMethod']?.toString();
    final finalRef =
        booking['final_payment_reference']?.toString() ??
        booking['finalPaymentReference']?.toString();
    final finalAmount =
        (booking['renter_return_payment_amount'] as num?)?.toDouble() ??
        (booking['renterReturnPaymentAmount'] as num?)?.toDouble() ??
        0.0;

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
              children: [
                const Expanded(
                  child: Text(
                    'Trip Receipt',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.darkBgTertiary,
                          borderRadius: BorderRadius.circular(12),
                          image:
                              booking['imageUrl']?.toString().isNotEmpty == true
                              ? DecorationImage(
                                  image: OptimizedNetworkImageProvider(
                                    booking['imageUrl'].toString(),
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            booking['imageUrl']?.toString().isNotEmpty == true
                            ? null
                            : const Icon(
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
                              booking['carName']?.toString() ?? 'Vehicle',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${booking['startDate']} - ${booking['endDate']}',
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
                  const SizedBox(height: 14),
                  _buildBookingDetailRow(
                    icon: Icons.person_pin_circle_outlined,
                    label: 'Driver',
                    value: booking['driverName']?.toString() ?? 'Not requested',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.payment,
                    label: 'Reservation Payment',
                    value:
                        booking['paymentStatus']?.toString() ??
                        'Reservation pending',
                  ),
                  if (reference != null && reference.isNotEmpty) ...[
                    const Divider(color: AppColors.borderColor),
                    _buildBookingDetailRow(
                      icon: Icons.numbers_rounded,
                      label: 'Reservation Reference',
                      value: reference,
                    ),
                  ],
                  if (method != null && method.isNotEmpty) ...[
                    const Divider(color: AppColors.borderColor),
                    _buildBookingDetailRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Reservation Method',
                      value: (method == 'psdc_desk_counter' ||
                              method.toLowerCase().contains('desk'))
                          ? 'The payment has been paid in desk (Authorized by ${(reference != null && reference.startsWith('DESK-')) ? reference.substring(5) : (booking['operator_name'] ?? 'Desk Operator')})'
                          : toProfessionalTitleCase(method),
                    ),
                  ],
                  if (finalMethod != null ||
                      finalRef != null ||
                      finalAmount > 0) ...[
                    const Divider(color: AppColors.borderColor),
                    _buildBookingDetailRow(
                      icon: Icons.receipt_long_rounded,
                      label: 'Final Payment Settlement',
                      value:
                          '₱${formatAmount(finalAmount, decimalDigits: 0)} (${(finalMethod ?? 'PSDC QR').toUpperCase()})',
                    ),
                    if (finalRef != null && finalRef.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildBookingDetailRow(
                        icon: Icons.tag_rounded,
                        label: 'Settlement Reference No.',
                        value: finalRef,
                      ),
                    ],
                  ],
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.schedule,
                    label: 'Pickup / Return',
                    value:
                        '${booking['startTime'] ?? 'N/A'} - ${booking['endTime'] ?? 'N/A'}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cost Receipt',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  CostBreakdownRow(
                    label:
                        '$safeDays day${safeDays == 1 ? '' : 's'} x PHP ${formatAmount(dailyRate)}/day',
                    amount: 'PHP ${formatAmount(rentalSubtotal)}',
                  ),
                  if (deliveryFee > 0)
                    CostBreakdownRow(
                      label: 'Delivery / Pickup Charge',
                      amount: 'PHP ${formatAmount(deliveryFee)}',
                    ),
                  if (driverFee > 0)
                    CostBreakdownRow(
                      label: 'Driver Fee',
                      amount: 'PHP ${formatAmount(driverFee)}',
                    ),
                  if (lateReturnFee > 0)
                    CostBreakdownRow(
                      label: 'Late Return Fee',
                      amount: 'PHP ${formatAmount(lateReturnFee)}',
                    ),
                  const Divider(color: AppColors.borderColor),
                  CostBreakdownRow(
                    label: 'Total',
                    amount: 'PHP ${formatAmount(total)}',
                    isBold: true,
                    amountColor: AppColors.primary,
                  ),
                  CostBreakdownRow(
                    label: 'Less Reservation Fee',
                    amount: '- PHP ${formatAmount(reservationFee)}',
                  ),
                  CostBreakdownRow(
                    label: 'Total Balance',
                    amount: 'PHP ${formatAmount(totalBalance)}',
                    isBold: true,
                  ),
                  CostBreakdownRow(
                    label: 'Security Deposit (Refundable)',
                    amount: 'PHP ${formatAmount(securityDeposit)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadTripReceipt(booking),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadTripReceipt(Map<String, dynamic> booking) async {
    try {
      await BookingReceiptService.shareReceipt(booking);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not download receipt: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCancellationDetails(Map<String, dynamic> booking) {
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
              children: [
                const Expanded(
                  child: Text(
                    'Cancellation Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORIGINAL BOOKING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking['carName']?.toString() ?? 'Vehicle',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${booking['startDate']} - ${booking['endDate']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 82,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.darkBgTertiary,
                      borderRadius: BorderRadius.circular(10),
                      image: booking['imageUrl']?.toString().isNotEmpty == true
                          ? DecorationImage(
                              image: OptimizedNetworkImageProvider(
                                booking['imageUrl'].toString(),
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: booking['imageUrl']?.toString().isNotEmpty == true
                        ? null
                        : const Icon(
                            Icons.directions_car,
                            color: AppColors.textSecondary,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withAlpha(120)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Booking Status: Cancelled',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This reservation is no longer active and has been removed from upcoming trips.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Reason for Cancellation',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildCancellationInfoCard(
              icon: Icons.info_outline,
              title:
                  booking['cancellationReason']?.toString() ??
                  'Booking was cancelled.',
              subtitle:
                  'Cancelled ${_formatTimeAgo(booking['cancelledAt']?.toString())}',
            ),
            const SizedBox(height: 18),
            const Text(
              'Refund Information',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withAlpha(70)),
              ),
              child: Column(
                children: [
                  _buildBookingDetailRow(
                    icon: Icons.receipt_long,
                    label: 'Reservation Fee',
                    value:
                        '₱${formatAmount(booking['totalCost'] as num, decimalDigits: 0)}',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.payments_outlined,
                    label: 'Refund Status',
                    value:
                        booking['paymentStatus']?.toString() ??
                        'Contact support for refund status',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Original Trip Route',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  _buildBookingDetailRow(
                    icon: Icons.radio_button_checked,
                    label: 'Pickup',
                    value: booking['pickupLocation']?.toString() ?? 'N/A',
                  ),
                  const Divider(color: AppColors.borderColor),
                  _buildBookingDetailRow(
                    icon: Icons.location_on,
                    label: 'Destination',
                    value: booking['dropoffLocation']?.toString() ?? 'N/A',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _contactCancellationSupport(booking),
                icon: const Icon(Icons.support_agent, size: 18),
                label: const Text('Contact Support'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getRemainingCancelTime(Map<String, dynamic> booking) {
    try {
      final createdAtStr = booking['created_at']?.toString();
      if (createdAtStr == null) {
        return {
          'canCancel': false,
          'hours': 0,
          'minutes': 0,
          'seconds': 0,
          'totalSecondsRemaining': 0,
          'remainingTime': 'Unknown',
          'isExpired': true,
        };
      }

      final createdAt = DateTime.parse(createdAtStr);
      final now = DateTime.now();
      final cancelUntil = createdAt.add(const Duration(hours: 24));
      final remaining = cancelUntil.difference(now);
      final totalSecondsRemaining = remaining.inSeconds.clamp(0, 24 * 60 * 60);
      final hoursRemaining = totalSecondsRemaining ~/ 3600;
      final minRemaining = (totalSecondsRemaining % 3600) ~/ 60;
      final secondsRemaining = totalSecondsRemaining % 60;

      final canCancel = totalSecondsRemaining > 0;
      final remainingTimeStr = canCancel
          ? '${hoursRemaining}h ${minRemaining}m ${secondsRemaining}s remaining'
          : 'Expired';

      return {
        'canCancel': canCancel,
        'hours': hoursRemaining,
        'minutes': minRemaining,
        'seconds': secondsRemaining,
        'totalSecondsRemaining': totalSecondsRemaining,
        'remainingTime': remainingTimeStr,
        'isExpired': !canCancel,
      };
    } catch (e) {
      debugPrint('Error checking cancellation time: $e');
      return {
        'canCancel': false,
        'hours': 0,
        'minutes': 0,
        'seconds': 0,
        'totalSecondsRemaining': 0,
        'remainingTime': 'Error',
        'isExpired': true,
      };
    }
  }

  Widget _buildActiveTripHero(Map<String, dynamic> booking) {
    final imageUrl = booking['imageUrl']?.toString().trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: _buildFastVehicleImage(
                imageUrl: hasImage ? imageUrl : null,
                fit: BoxFit.cover,
                width: double.infinity,
                backgroundColor: AppColors.darkBgTertiary,
                iconColor: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            booking['carName']?.toString() ?? 'Active Trip',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${booking['startDate']} - ${booking['endDate']}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primary.withAlpha(120)),
            ),
            child: Text(
              booking['status']?.toString() ?? 'Approved',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTripMetric(
                  label: 'Start',
                  value: booking['startTime']?.toString() ?? 'N/A',
                ),
              ),
              Expanded(
                child: _buildTripMetric(
                  label: 'Duration',
                  value:
                      '${booking['days']} day${booking['days'] == 1 ? '' : 's'}',
                  highlight: true,
                ),
              ),
              Expanded(
                child: _buildTripMetric(
                  label: 'Return',
                  value: booking['endTime']?.toString() ?? 'N/A',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildRentalAgreementCard(),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalCard(Map<String, dynamic> booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    final createdAt = DateTime.tryParse(
      booking['created_at']?.toString() ?? '',
    )?.toLocal();
    final elapsed = createdAt == null
        ? const Duration(hours: 1)
        : DateTime.now().difference(createdAt);
    final approvalProgress = (elapsed.inMinutes / 120).clamp(0.05, 0.95);
    final percent = (approvalProgress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        boxShadow: isDark ? null : AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PENDING APPROVAL',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    color: primaryText,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.primary : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: approvalProgress.toDouble(),
              minHeight: 6,
              backgroundColor: isDark ? AppColors.darkBgTertiary : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.primary : AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting for owner to confirm your request.',
            style: TextStyle(fontSize: 12, color: secondaryText),
          ),
          const SizedBox(height: 2),
          Text(
            'Usually takes less than 2 hours.',
            style: TextStyle(fontSize: 12, color: secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingVehicleCard(Map<String, dynamic> booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    final imageUrl = booking['imageUrl']?.toString().trim() ?? '';
    final totalCost = (booking['totalCost'] as num?)?.toDouble() ?? 0;
    final days = ((booking['days'] as num?)?.toInt() ?? 1).clamp(1, 365);
    final dailyRate = totalCost / days;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        boxShadow: isDark ? null : AppColors.cardShadowOf(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REQUESTED VEHICLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: tertiaryText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  booking['carName']?.toString() ?? 'Vehicle',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '₱${formatAmount(dailyRate, decimalDigits: 0)} / day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.primary : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 112,
              height: 70,
              child: _buildFastVehicleImage(
                imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
                fit: BoxFit.cover,
                backgroundColor: isDark ? AppColors.darkBgTertiary : const Color(0xFFE2E8F0),
                iconColor: tertiaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSummaryTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        boxShadow: isDark ? null : AppColors.cardShadowOf(context),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: tertiaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAgreementNotes() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : AppColors.lightBorderColor,
          width: 1.2,
        ),
        boxShadow: isDark ? null : AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gavel_outlined,
                size: 15,
                color: isDark ? AppColors.primary : AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                'Rental Agreement Notes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _AgreementNote('Late penalty: ₱300/hr after scheduled return.'),
          const SizedBox(height: 7),
          const _AgreementNote(
            'Fuel Policy: Same-to-same. Return with the same fuel level.',
          ),
          const SizedBox(height: 7),
          const _AgreementNote(
            'Cleanliness: Please return the car in the same clean state.',
          ),
        ],
      ),
    );
  }

  Widget _buildTripMetric({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary.withAlpha(18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 9, color: tertiaryText),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: highlight
                  ? (isDark ? AppColors.primary : const Color(0xFFD97706))
                  : primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalAgreementCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        boxShadow: isDark ? null : AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: isDark ? AppColors.primary : AppColors.primaryDark,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Rental Agreement',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Keep vehicle clean and return it on schedule.',
            style: TextStyle(fontSize: 11, color: secondaryText),
          ),
          SizedBox(height: 4),
          Text(
            '• Extension is allowed only when the next booking slot is available.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          SizedBox(height: 4),
          Text(
            '• Late returns may include penalties after the grace period.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePreTripReleasePayment(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final renterId = AuthService().currentUser?.id ?? '';
    if (bookingId.isEmpty || renterId.isEmpty) return;

    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final seats = (vehicle['seats'] as num?)?.toInt() ??
        (booking['seats'] as num?)?.toInt() ??
        5;
    final totalCost =
        (booking['totalCost'] as num?)?.toDouble() ??
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final rentalSubtotal =
        (booking['rentalSubtotal'] as num?)?.toDouble() ?? totalCost;
    final deliveryFee =
        (booking['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final reservationFee =
        (booking['reservationFeeAmount'] as num?)?.toDouble() ??
        (booking['reservation_fee_amount'] as num?)?.toDouble() ??
        1000.0;

    final proof = await Navigator.of(context).push<ReservationPaymentProof>(
      MaterialPageRoute(
        builder: (_) => ReservationPaymentScreen(
          userId: renterId,
          vehicleData: vehicle.isNotEmpty
              ? vehicle
              : {
                  'id': booking['vehicle_id'],
                  'vehicle_name': booking['carName'],
                  'brand': booking['carName'],
                  'seats': seats,
                  'image_url': booking['imageUrl'],
                },
          rentalTotal: totalCost,
          rentalSubtotal: rentalSubtotal,
          deliveryFee: deliveryFee,
          discountAmount: (booking['discount_amount'] as num?)?.toDouble() ?? 0.0,
          reservationFeeAmount: reservationFee,
          requiresLongBookingReservation: false,
          paymentPurpose: PaymentPurpose.releaseSettlement,
          paidReservationFee: reservationFee,
          bookingId: bookingId,
        ),
      ),
    );

    if (proof == null) return;

    try {
      await Supabase.instance.client.from('bookings').update({
        'reservation_payment_covers_total': true,
        'reservation_payment_type': 'full_payment',
        'payment_status': 'paid_in_full',
        'pre_trip_settlement_paid': true,
        'pre_trip_settlement_amount': proof.amount,
        'pre_trip_settlement_method': proof.method,
        'pre_trip_settlement_reference': proof.referenceNumber,
        'pre_trip_settlement_proof_url': proof.proofUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bookingId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Remaining balance payment submitted! You are ready for vehicle release.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording payment: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleRenterReturnVehicle(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final renterId = AuthService().currentUser?.id ?? '';
    if (bookingId.isEmpty || renterId.isEmpty) return;

    final endRaw =
        booking['end_at']?.toString() ??
        booking['end_date']?.toString() ??
        booking['end_date_raw']?.toString();
    final scheduledEnd = endRaw != null
        ? DateTime.tryParse(endRaw)?.toLocal()
        : null;
    final now = DateTime.now();

    int lateHours = 0;
    if (scheduledEnd != null && now.isAfter(scheduledEnd)) {
      final lateMinutes = now.difference(scheduledEnd).inMinutes;
      lateHours = (lateMinutes / 60.0).ceil();
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final seats = (vehicle['seats'] as num?)?.toInt() ??
        (booking['seats'] as num?)?.toInt() ??
        5;
    final dailyRate = (vehicle['price_per_day'] as num?)?.toDouble() ??
        (booking['totalCost'] as num?)?.toDouble() ??
        1500.0;

    ReservationPaymentSettings? settings;
    try {
      settings = await ReservationPaymentService().getSettings();
    } catch (_) {}
    final latePenaltyFee = (settings ?? const ReservationPaymentSettings()).calculateLateFee(
      seats: seats,
      lateHours: lateHours,
      dailyRate: dailyRate,
    );

    final totalCost =
        (booking['totalCost'] as num?)?.toDouble() ??
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;

    final coversTotal =
        booking['reservationPaymentCoversTotal'] == true ||
        booking['reservation_payment_covers_total'] == true ||
        booking['reservationPaymentType'] == 'full_payment' ||
        booking['payment_status'] == 'paid_in_full';
    final reservationFee =
        (booking['reservationFeeAmount'] as num?)?.toDouble() ??
        (booking['reservation_fee_amount'] as num?)?.toDouble() ??
        0.0;
    final amountPaid = coversTotal
        ? totalCost
        : reservationFee > 0
        ? reservationFee
        : (booking['amount_paid'] as num?)?.toDouble() ?? 0.0;

    final remainingRentalBalance = (totalCost - amountPaid).clamp(
      0.0,
      double.infinity,
    );

    // If late, open ReservationPaymentScreen in lateReturnPenalty mode
    if (lateHours > 0) {
      final proof = await Navigator.of(context).push<ReservationPaymentProof>(
        MaterialPageRoute(
          builder: (_) => ReservationPaymentScreen(
            userId: renterId,
            vehicleData: vehicle.isNotEmpty
                ? vehicle
                : {
                    'id': booking['vehicle_id'],
                    'vehicle_name': booking['carName'],
                    'brand': booking['carName'],
                    'seats': seats,
                    'price_per_day': dailyRate,
                    'image_url': booking['imageUrl'],
                  },
            rentalTotal: totalCost,
            rentalSubtotal: (booking['rentalSubtotal'] as num?)?.toDouble() ?? totalCost,
            deliveryFee: (booking['deliveryFee'] as num?)?.toDouble() ?? 0.0,
            discountAmount: 0.0,
            reservationFeeAmount: 0.0,
            requiresLongBookingReservation: false,
            paymentPurpose: PaymentPurpose.lateReturnPenalty,
            lateFeeAmount: latePenaltyFee,
            lateHours: lateHours,
            returnTimestamp: now,
            bookingId: bookingId,
          ),
        ),
      );

      if (proof == null) return; // Renter cancelled or went back

      try {
        await BookingService().renterInitiateReturn(
          bookingId: bookingId,
          renterId: renterId,
          paymentMethod: proof.method,
          paymentReference: proof.referenceNumber,
          proofUrl: proof.proofUrl,
          lateHours: lateHours,
          lateFee: latePenaltyFee,
          settledAmount: proof.amount,
        );

        if (!mounted) return;

        await ReturnInspectionNoticeModal.show(
          context,
          vehicleTitle: booking['carName']?.toString() ?? 'Vehicle',
        );

        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripRatingFlowScreen(
              bookingId: bookingId,
              reviewerRole: 'renter',
            ),
          ),
        );

        _loadBookings();
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating vehicle return: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // If remaining rental balance > 0 (not late, but unsettled remaining rental balance)
    if (remainingRentalBalance > 0) {
      final proof = await Navigator.of(context).push<ReservationPaymentProof>(
        MaterialPageRoute(
          builder: (_) => ReservationPaymentScreen(
            userId: renterId,
            vehicleData: vehicle.isNotEmpty
                ? vehicle
                : {
                    'id': booking['vehicle_id'],
                    'vehicle_name': booking['carName'],
                    'brand': booking['carName'],
                    'seats': seats,
                    'price_per_day': dailyRate,
                    'image_url': booking['imageUrl'],
                  },
            rentalTotal: totalCost,
            rentalSubtotal: (booking['rentalSubtotal'] as num?)?.toDouble() ?? totalCost,
            deliveryFee: (booking['deliveryFee'] as num?)?.toDouble() ?? 0.0,
            discountAmount: (booking['discount_amount'] as num?)?.toDouble() ?? 0.0,
            reservationFeeAmount: reservationFee,
            requiresLongBookingReservation: false,
            paymentPurpose: PaymentPurpose.releaseSettlement,
            paidReservationFee: reservationFee,
            bookingId: bookingId,
          ),
        ),
      );

      if (proof == null) return;

      try {
        await BookingService().renterInitiateReturn(
          bookingId: bookingId,
          renterId: renterId,
          paymentMethod: proof.method,
          paymentReference: proof.referenceNumber,
          proofUrl: proof.proofUrl,
          lateHours: 0,
          lateFee: 0.0,
          settledAmount: proof.amount,
        );

        if (!mounted) return;

        await ReturnInspectionNoticeModal.show(
          context,
          vehicleTitle: booking['carName']?.toString() ?? 'Vehicle',
        );

        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripRatingFlowScreen(
              bookingId: bookingId,
              reviewerRole: 'renter',
            ),
          ),
        );

        _loadBookings();
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating vehicle return: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Fully paid on-time return
    try {
      await BookingService().renterInitiateReturn(
        bookingId: bookingId,
        renterId: renterId,
        paymentMethod: 'none',
        paymentReference: '',
        proofUrl: null,
        lateHours: 0,
        lateFee: 0.0,
        settledAmount: 0.0,
      );

      if (!mounted) return;

      await ReturnInspectionNoticeModal.show(
        context,
        vehicleTitle: booking['carName']?.toString() ?? 'Vehicle',
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TripRatingFlowScreen(
            bookingId: bookingId,
            reviewerRole: 'renter',
          ),
        ),
      );

      _loadBookings();
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating vehicle return: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
  }

  Future<void> _showTripExtensionDialog(Map<String, dynamic> booking) async {
    if (_isBookingWithDriver(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Trip extension is only applicable for Self Drive rentals. Bookings with an assigned driver cannot be extended.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final vehicleId = booking['vehicle_id']?.toString() ??
        (booking['vehicles'] as Map<String, dynamic>?)?['id']?.toString() ??
        '';
    final bookingId = booking['id']?.toString() ?? '';
    final endRaw = booking['end_at']?.toString() ??
        booking['end_date_raw']?.toString() ??
        booking['endDate']?.toString() ??
        booking['end_date']?.toString();

    if (vehicleId.isEmpty || bookingId.isEmpty || endRaw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read booking details for trip extension.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final currentEndAt = DateTime.tryParse(endRaw)?.toLocal();
    if (currentEndAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not parse the current trip end date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final availability = await BookingService().getTripExtensionAvailability(
      bookingId: bookingId,
    );

    if (!availability.canExtend) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            availability.blockingReason ??
                'This vehicle cannot be extended because another customer has reserved it.',
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final explicitDailyRate =
        (vehicle?['daily_rate'] as num?)?.toDouble() ??
        (vehicle?['price_per_day'] as num?)?.toDouble();
    final totalCost =
        (booking['totalCost'] as num?)?.toDouble() ??
        (booking['total_price'] as num?)?.toDouble() ??
        1000.0;
    final days = (booking['days'] as num?)?.toInt() ?? 1;
    final dailyRate = explicitDailyRate ?? (totalCost / (days > 0 ? days : 1));

    // Extension must strictly start contiguous from the current booking's last day
    final currentEndDay = DateTime(currentEndAt.year, currentEndAt.month, currentEndAt.day);
    final initialFirstDate = currentEndDay.add(const Duration(days: 1));
    final maxLastDate = availability.maxAllowedExtensionDate ??
        initialFirstDate.add(const Duration(days: 30));

    final hasNextBooking = availability.nextBookingStart != null;
    final formattedMaxDate =
        '${maxLastDate.month}/${maxLastDate.day}/${maxLastDate.year}';

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialFirstDate,
      firstDate: initialFirstDate,
      lastDate: maxLastDate,
      selectableDayPredicate: (day) {
        if (day.isAfter(maxLastDate) || day.isBefore(initialFirstDate)) {
          return false;
        }
        return true;
      },
      helpText: hasNextBooking
          ? 'SELECT RETURN DATE (AVAILABLE UNTIL $formattedMaxDate)'
          : 'SELECT NEW EXTENDED RETURN DATE',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.darkCard,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final selectedNewEndAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      currentEndAt.hour,
      currentEndAt.minute,
    );

    final extensionDays = pickedDate
        .difference(
          DateTime(currentEndAt.year, currentEndAt.month, currentEndAt.day),
        )
        .inDays;
    if (extensionDays <= 0) return;

    final additionalPrice = extensionDays * dailyRate;
    final destinationController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.cardBorderOf(context)),
        ),
        title: Row(
          children: [
            const Icon(Icons.av_timer_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Confirm Trip Extension',
              style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorderOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Extension Start (Locked):',
                        style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 12),
                      ),
                      Text(
                        _formatDateShort(currentEndAt.toIso8601String()),
                        style: TextStyle(color: AppColors.textPrimaryOf(context), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'New Extended Return:',
                        style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 12),
                      ),
                      Text(
                        _formatDateShort(selectedNewEndAt.toIso8601String()),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Extension Duration:',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Text(
                        '+$extensionDays day${extensionDays == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daily Unit Rate:',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Text(
                        'PHP ${formatAmount(dailyRate, decimalDigits: 0)} / day',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Additional Price Due:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '+PHP ${formatAmount(additionalPrice, decimalDigits: 0)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasNextBooking) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy_rounded, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Another renter has booked this car starting ${_formatDateShort(availability.nextBookingStart!.toIso8601String())}. The latest allowed extension date is ${_formatDateShort(maxLastDate.toIso8601String())}.',
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: destinationController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'New Destination (Optional)',
                labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                hintText: 'e.g. Baguio City or same as current',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trip extensions are paid immediately online (GCash/Maya/QR Ph) for instant confirmation.',
                      style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Proceed to Online Payment',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      destinationController.dispose();
      return;
    }

    final requestedDestination = destinationController.text.trim();
    destinationController.dispose();

    if (!mounted) return;
    await _showInstantExtensionPaymentModal(
      context: context,
      bookingId: bookingId,
      newEndAt: selectedNewEndAt,
      additionalPrice: additionalPrice,
      extensionDays: extensionDays,
      newDestination: requestedDestination.isNotEmpty ? requestedDestination : null,
    );
  }

  Future<void> _showInstantExtensionPaymentModal({
    required BuildContext context,
    required String bookingId,
    required DateTime newEndAt,
    required double additionalPrice,
    required int extensionDays,
    String? newDestination,
  }) async {
    final referenceController = TextEditingController();
    String selectedMethod = 'GCash';
    XFile? pickedReceipt;
    bool isSubmitting = false;

    ReservationPaymentSettings? settings;
    try {
      settings = await ReservationPaymentService().getSettings();
    } catch (_) {}

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final qrUrl = settings?.qrUrl ?? '';
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pay Extension Online',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Instant Schedule Confirmation',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'PHP ${formatAmount(additionalPrice, decimalDigits: 0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (qrUrl.isNotEmpty) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            qrUrl,
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Scan QR to Pay with GCash, Maya, or any Banking App',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings?.accountName.isNotEmpty == true
                              ? 'Account: ${settings!.accountName}'
                              : 'PSDC Payment Accounts',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• GCash / Maya / QR Ph: 0917-123-4567\n• BDO / Bank Transfer: 0012-3456-7890',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Payment Method Used',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    dropdownColor: AppColors.darkBg,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.darkBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                      DropdownMenuItem(value: 'Maya', child: Text('Maya / PayMaya')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (BDO/BPI/QR Ph)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: referenceController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Payment Reference Number / Transaction ID *',
                      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      hintText: 'e.g. 10023458921',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: AppColors.darkBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (image != null) {
                        setModalState(() => pickedReceipt = image);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.darkBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pickedReceipt != null
                              ? AppColors.primary
                              : AppColors.borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            pickedReceipt != null
                                ? Icons.check_circle_rounded
                                : Icons.upload_file_rounded,
                            color: pickedReceipt != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              pickedReceipt != null
                                  ? 'Receipt: ${pickedReceipt!.name}'
                                  : 'Upload Payment Receipt (Screenshot)',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: pickedReceipt != null
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final ref = referenceController.text.trim();
                              if (ref.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter your online payment reference number.'),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                String proofUrl = '';
                                if (pickedReceipt != null) {
                                  final bytes = await pickedReceipt!.readAsBytes();
                                  final fileExt = pickedReceipt!.name.split('.').last;
                                  final fileName =
                                      'ext_instant_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
                                  final supabase = Supabase.instance.client;
                                  await supabase.storage
                                      .from('booking-payments')
                                      .uploadBinary(
                                        fileName,
                                        bytes,
                                        fileOptions: const FileOptions(upsert: true),
                                      );
                                  proofUrl = supabase.storage
                                      .from('booking-payments')
                                      .getPublicUrl(fileName);
                                }

                                await BookingService().submitInstantTripExtensionWithPayment(
                                  bookingId: bookingId,
                                  newEndAt: newEndAt,
                                  additionalPrice: additionalPrice,
                                  extensionDays: extensionDays,
                                  paymentMethod: selectedMethod,
                                  paymentReference: ref,
                                  proofUrl: proofUrl.isNotEmpty ? proofUrl : null,
                                  newDestination: newDestination,
                                );

                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Trip Extension Confirmed & Paid! Your new return schedule is updated.',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                                _loadBookings();
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to extend trip: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Pay & Confirm Extension',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCancellationInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
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

  Future<void> _contactCancellationSupport(Map<String, dynamic> booking) async {
    final authService = AuthService();
    final currentUser = authService.currentUser;
    final bookingId = booking['id']?.toString() ?? '';
    if (currentUser == null || bookingId.isEmpty) return;

    try {
      final operatorId = await _resolveBookingOperatorId(booking);
      if (operatorId == null || operatorId.isEmpty) {
        throw Exception('No operator is assigned to this booking yet');
      }

      final conversation = await ChatService().createGroupConversation(
        bookingId: bookingId,
        participantIds: [currentUser.id, operatorId],
      );
      final conversationId = conversation['id']?.toString();
      if (conversationId == null || conversationId.isEmpty) {
        throw Exception('Could not create support conversation');
      }

      await Supabase.instance.client
          .from('conversations')
          .update({
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);

      final supportMessage =
          'Cancellation support request\n'
          'Booking: ${booking['carName'] ?? 'Vehicle'} ($bookingId)\n'
          'Status: ${booking['status'] ?? 'Cancelled'}\n'
          'Reason: ${booking['cancellationReason'] ?? 'N/A'}\n'
          'Refund status: ${booking['paymentStatus'] ?? 'N/A'}';

      await ChatService().sendMessage(
        conversationId: conversationId,
        senderId: currentUser.id,
        content: supportMessage,
      );

      await Supabase.instance.client.from('notifications').insert({
        'user_id': operatorId,
        'title': 'Cancellation Support Request',
        'message':
            'A renter needs help with cancelled booking ${booking['carName'] ?? bookingId}.',
        'type': 'booking_support',
        'data': {
          'booking_id': bookingId,
          'conversation_id': conversationId,
          'status': 'cancelled',
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.of(context)
          .pushNamed(
            '/chat-detail',
            arguments: {
              'conversationId': conversationId,
              'recipientName': 'Cancellation Support',
              'recipientAvatar': '',
              'isAutoGenerated': true,
            },
          )
          .then((_) {
            _loadConversations();
            _loadNotifications();
          });
    } catch (e) {
      debugPrint('Error contacting cancellation support: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not contact support: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatRoleList(List<String> roles) {
    final labels = roles
        .map((role) {
          switch (role.trim().toLowerCase()) {
            case 'operator':
              return 'operator';
            case 'partner':
              return 'partner';
            case 'driver':
              return 'driver';
            case 'renter':
              return 'renter';
            default:
              return role;
          }
        })
        .where((label) => label.isNotEmpty)
        .toList();

    if (labels.isEmpty) return 'the trip participants';
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels.first} and ${labels.last}';
    return '${labels.sublist(0, labels.length - 1).join(', ')}, and ${labels.last}';
  }

  Future<String?> _resolveBookingOperatorId(
    Map<String, dynamic> booking,
  ) async {
    final directOperatorId = booking['operator_id']?.toString();
    if (directOperatorId != null && directOperatorId.isNotEmpty) {
      return directOperatorId;
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleOperatorId = vehicle?['operator_id']?.toString();
    if (vehicleOperatorId != null && vehicleOperatorId.isNotEmpty) {
      return vehicleOperatorId;
    }

    final operator = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('role', 'operator')
        .limit(1)
        .maybeSingle();
    return operator?['id']?.toString();
  }

  bool _isCancelledBooking(Map<String, dynamic> booking) {
    final rawStatus = booking['rawStatus']?.toString().toLowerCase() ?? '';
    return rawStatus == 'cancelled' || rawStatus == 'canceled';
  }

  bool _isCancellableStatusForUi(Map<String, dynamic> booking) {
    final rawStatus = booking['rawStatus']?.toString().toLowerCase();
    return rawStatus == 'pending';
  }

  bool _canCancelBooking(Map<String, dynamic> booking) {
    final rawStatus = booking['rawStatus']?.toString().toLowerCase();
    if (rawStatus != 'pending') return false;

    final timeInfo = _getRemainingCancelTime(booking);
    return timeInfo['canCancel'] as bool;
  }

  Future<void> _showRescheduleTripDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    DateTime? currentStart = booking['startDateObj'] as DateTime? ??
        (booking['start_at'] != null ? DateTime.tryParse(booking['start_at']) : null);
    DateTime? currentEnd = booking['endDateObj'] as DateTime? ??
        (booking['end_at'] != null ? DateTime.tryParse(booking['end_at']) : null);

    final durationDays = (currentStart != null && currentEnd != null)
        ? currentEnd.difference(currentStart).inDays.clamp(1, 30)
        : 1;

    DateTime selectedStartDate = DateTime.now().add(const Duration(days: 2));
    DateTime selectedEndDate = selectedStartDate.add(Duration(days: durationDays));

    final initialDestination = booking['dropoff_location']?.toString().trim() ??
        booking['dropoffLocation']?.toString().trim() ??
        booking['destination']?.toString().trim() ??
        '';
    final initialDropoffLat = (booking['dropoff_latitude'] ??
            booking['dropoffLatitude'] as num?)
        ?.toDouble();
    final initialDropoffLng = (booking['dropoff_longitude'] ??
            booking['dropoffLongitude'] as num?)
        ?.toDouble();

    final destinationController = TextEditingController(text: initialDestination);
    double? selectedDropoffLat = initialDropoffLat;
    double? selectedDropoffLng = initialDropoffLng;

    final reasonController = TextEditingController(text: 'Change of schedule');
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.darkBgSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_repeat_rounded,
                      color: Color(0xFFE5A93C),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reschedule Trip',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '100% of your ₱1,000 deposit is transferred',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.darkBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['carName']?.toString() ?? 'Selected Vehicle',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Current Dates: ${booking['startDate'] ?? 'N/A'} - ${booking['endDate'] ?? 'N/A'}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (initialDestination.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Current Destination: $initialDestination',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Select New Trip Dates',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Unified Date Range Picker Button
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.borderColor),
                      ),
                      tileColor: AppColors.darkBg,
                      leading: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFFE5A93C),
                        size: 22,
                      ),
                      title: const Text(
                        'New Trip Dates',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      subtitle: Text(
                        '${DateFormat('EEE, MMM d, yyyy').format(selectedStartDate)} – ${DateFormat('EEE, MMM d, yyyy').format(selectedEndDate)} (${selectedEndDate.difference(selectedStartDate).inDays} day${selectedEndDate.difference(selectedStartDate).inDays > 1 ? 's' : ''})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.edit_calendar_rounded,
                        color: Color(0xFFE5A93C),
                        size: 20,
                      ),
                      onTap: isSubmitting
                          ? null
                          : () async {
                              final vehicleId = booking['vehicle_id']?.toString() ??
                                  booking['vehicleId']?.toString() ??
                                  booking['vehicles']?['id']?.toString() ??
                                  '';
                              final unavailableDays = await _fetchUnavailableDatesForReschedule(
                                vehicleId: vehicleId,
                                bookingId: bookingId,
                              );

                              final picked = await _showRescheduleCalendarDialog(
                                firstDate: DateTime.now().add(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                                initialStart: selectedStartDate,
                                initialEnd: selectedEndDate,
                                previousStart: currentStart,
                                previousEnd: currentEnd,
                                unavailableDays: unavailableDays,
                                carName: booking['carName']?.toString() ?? 'Selected Vehicle',
                              );

                              if (picked != null) {
                                setModalState(() {
                                  selectedStartDate = DateTime(
                                    picked.start.year,
                                    picked.start.month,
                                    picked.start.day,
                                    currentStart?.hour ?? 9,
                                    currentStart?.minute ?? 0,
                                  );
                                  selectedEndDate = DateTime(
                                    picked.end.year,
                                    picked.end.month,
                                    picked.end.day,
                                    currentEnd?.hour ?? 18,
                                    currentEnd?.minute ?? 0,
                                  );
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Trip Destination',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Leave as is or pin a new destination on map',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Destination Text Field with Pin Destination Map Picker
                    TextField(
                      controller: destinationController,
                      maxLines: 2,
                      minLines: 1,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Destination Address',
                        hintText: 'Enter destination or pin on map',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        prefixIcon: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Pin destination on map',
                          icon: const Icon(
                            Icons.map_outlined,
                            color: Color(0xFFE5A93C),
                            size: 22,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final selection = await MobilisLocationPickerModal.show(
                                    context,
                                    title: 'Pin trip destination',
                                    subtitle:
                                        'Search an address or place a pin for your rescheduled trip destination.',
                                    confirmLabel: 'Use this destination',
                                    initialAddress: destinationController.text.trim().isNotEmpty
                                        ? destinationController.text.trim()
                                        : initialDestination,
                                    initialLatitude: selectedDropoffLat,
                                    initialLongitude: selectedDropoffLng,
                                  );
                                  if (selection != null) {
                                    setModalState(() {
                                      destinationController.text = selection.address;
                                      selectedDropoffLat = selection.latitude;
                                      selectedDropoffLng = selection.longitude;
                                    });
                                  }
                                },
                        ),
                        filled: true,
                        fillColor: AppColors.darkBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5A93C)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Reason for Date / Destination Change',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: AppColors.darkBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.borderColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);
                          try {
                            await BookingService().rescheduleBooking(
                              bookingId: bookingId,
                              newStartAt: selectedStartDate.toUtc(),
                              newEndAt: selectedEndDate.toUtc(),
                              newDropoffLocation: destinationController.text.trim().isNotEmpty
                                  ? destinationController.text.trim()
                                  : null,
                              newDropoffLatitude: selectedDropoffLat,
                              newDropoffLongitude: selectedDropoffLng,
                              reason: reasonController.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Trip rescheduled successfully! 100% of your ₱1,000 deposit has been transferred.',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              await _loadBookings();
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Reschedule error: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(
                    isSubmitting ? 'Rescheduling...' : 'Confirm Reschedule',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A93C),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Set<DateTime>> _fetchUnavailableDatesForReschedule({
    required String vehicleId,
    required String bookingId,
  }) async {
    final unavailable = <DateTime>{};
    if (vehicleId.isEmpty) return unavailable;

    try {
      final bookingsResp = await Supabase.instance.client
          .from('bookings')
          .select('id, start_at, end_at, start_date, end_date, status')
          .eq('vehicle_id', vehicleId)
          .neq('id', bookingId)
          .inFilter('status', ['pending', 'approved', 'ongoing', 'confirmed']);

      for (final row in List<Map<String, dynamic>>.from(bookingsResp)) {
        final start = DateTime.tryParse(row['start_at']?.toString() ?? '') ??
            DateTime.tryParse(row['start_date']?.toString() ?? '');
        final end = DateTime.tryParse(row['end_at']?.toString() ?? '') ??
            DateTime.tryParse(row['end_date']?.toString() ?? '');
        if (start == null || end == null) continue;

        var cur = _dateOnly(start);
        final last = _dateOnly(end);
        while (!cur.isAfter(last)) {
          unavailable.add(cur);
          cur = cur.add(const Duration(days: 1));
        }
      }

      final explicitUnavailable =
          await VehicleService().getUnavailableDates(vehicleId);
      for (final d in explicitUnavailable) {
        unavailable.add(_dateOnly(d));
      }
    } catch (e) {
      debugPrint('Error fetching reschedule unavailable dates: $e');
    }

    return unavailable;
  }

  Future<DateTimeRange?> _showRescheduleCalendarDialog({
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime initialStart,
    required DateTime initialEnd,
    required DateTime? previousStart,
    required DateTime? previousEnd,
    required Set<DateTime> unavailableDays,
    required String carName,
  }) {
    var focusedDay = initialStart;
    DateTime? rangeStart = initialStart;
    DateTime? rangeEnd = initialEnd;
    final unavailable = unavailableDays.map(_dateOnly).toSet();

    final previousDays = <DateTime>{};
    if (previousStart != null && previousEnd != null) {
      var cur = _dateOnly(previousStart);
      final last = _dateOnly(previousEnd);
      while (!cur.isAfter(last)) {
        previousDays.add(cur);
        cur = cur.add(const Duration(days: 1));
      }
    }

    return showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasInvalidRange = rangeStart != null &&
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Reschedule Dates',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  carName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE5A93C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: const [
                          _CalendarLegendDot(
                            color: Color(0xFFE5A93C),
                            label: 'Selected',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: AppColors.error,
                            label: 'Booked / Unavailable',
                            textColor: AppColors.textPrimary,
                          ),
                          _CalendarLegendDot(
                            color: Color(0xFF3B82F6),
                            label: 'Your Previous Dates',
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
                          final startDay = start == null ? null : _dateOnly(start);
                          final endDay = end == null ? null : _dateOnly(end);
                          if ((startDay != null && unavailable.contains(startDay)) ||
                              (endDay != null && unavailable.contains(endDay))) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('That date is already booked / unavailable for this car.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          if (start != null &&
                              end != null &&
                              _rangeContainsBlockedDate(start, end, unavailable)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Selected date range includes booked / unavailable dates.'),
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
                                content: Text('This date is already reserved by another booking.'),
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
                                    content: Text('Selected range contains unavailable dates.'),
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
                            color: Color(0xFFE5A93C),
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right,
                            color: Color(0xFFE5A93C),
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
                          rangeHighlightColor: const Color(0xFFE5A93C).withAlpha(55),
                          defaultTextStyle: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          weekendTextStyle: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            return _buildRescheduleDayCell(
                              day,
                              unavailable,
                              previousDays,
                            );
                          },
                          todayBuilder: (context, day, focusedDay) {
                            return _buildRescheduleDayCell(
                              day,
                              unavailable,
                              previousDays,
                              isToday: true,
                            );
                          },
                          selectedBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: const Color(0xFFE5A93C),
                              textColor: Colors.black,
                            );
                          },
                          rangeStartBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: const Color(0xFFE5A93C),
                              textColor: Colors.black,
                            );
                          },
                          rangeEndBuilder: (context, day, focusedDay) {
                            return _buildCalendarDayCell(
                              day: day,
                              backgroundColor: const Color(0xFFE5A93C),
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
                          'Selected range includes booked / unavailable dates.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
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
                              onPressed: rangeStart == null ||
                                      rangeEnd == null ||
                                      hasInvalidRange
                                  ? null
                                  : () => Navigator.pop(
                                      dialogContext,
                                      DateTimeRange(
                                        start: rangeStart!,
                                        end: rangeEnd!,
                                      ),
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE5A93C),
                                foregroundColor: Colors.black,
                              ),
                              child: const Text(
                                'Apply Dates',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
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

  Widget _buildRescheduleDayCell(
    DateTime day,
    Set<DateTime> unavailable,
    Set<DateTime> previousDays, {
    bool isToday = false,
  }) {
    final date = _dateOnly(day);
    if (unavailable.contains(date)) {
      return _buildCalendarDayCell(
        day: day,
        backgroundColor: AppColors.error,
        borderColor: isToday ? const Color(0xFFE5A93C) : null,
        textColor: Colors.white,
        strikethrough: true,
      );
    }
    if (previousDays.contains(date)) {
      return _buildCalendarDayCell(
        day: day,
        backgroundColor: const Color(0xFF3B82F6).withAlpha(50),
        borderColor: const Color(0xFF3B82F6),
        textColor: const Color(0xFF93C5FD),
      );
    }
    return _buildCalendarDayCell(
      day: day,
      backgroundColor: AppColors.success.withAlpha(45),
      borderColor: isToday ? const Color(0xFFE5A93C) : AppColors.success,
      textColor: isToday ? const Color(0xFFE5A93C) : AppColors.textPrimary,
    );
  }

  Future<void> _handleBookingCancellation(Map<String, dynamic> booking) async {
    final reasonController = TextEditingController();

    final actionChoice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cancel or Reschedule Trip',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // STRICT NON-REFUNDABLE NOTICE BANNER
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE53935).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFE53935), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Deposit Policy Notice',
                            style: TextStyle(
                              color: Color(0xFFE53935),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Per platform policy, the ₱1,000 security deposit / reservation fee is NON-REFUNDABLE upon cancellation. However, you can Reschedule your trip to new dates and keep 100% of your deposit!',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Vehicle: ${booking['carName'] ?? 'Selected vehicle'}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Scheduled: ${booking['startDate'] ?? ''} - ${booking['endDate'] ?? ''}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              // OPTION 1 (RECOMMENDED): RESCHEDULE TRIP
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, 'reschedule'),
                  icon: const Icon(Icons.event_repeat_rounded, size: 18),
                  label: const Text(
                    'Reschedule Trip (Keep ₱1,000 Deposit)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A93C),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // OPTION 2: OUTRIGHT CANCELLATION (FORFEIT DEPOSIT)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, 'cancel_forfeit'),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                  label: const Text(
                    'Proceed to Cancel & Forfeit Deposit',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'keep'),
            child: const Text('Keep Booking', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );

    if (actionChoice == 'reschedule') {
      await _showRescheduleTripDialog(booking);
      return;
    }

    if (actionChoice != 'cancel_forfeit') {
      return;
    }

    // Prompt for cancellation reason before forfeiting
    final reasonConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Cancellation & Deposit Forfeiture',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for cancelling. Note that the ₱1,000 deposit is retained per non-refundable policy.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 3,
              maxLength: 160,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cancellation reason',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a cancellation reason.'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (reasonConfirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    try {
      await BookingService().cancelBookingWithDepositForfeit(
        bookingId: booking['id'].toString(),
        cancellationReason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled. Deposit retained per policy.'),
            backgroundColor: AppColors.warning,
          ),
        );
        await _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling booking: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildTripImageFallback(Color backgroundColor, Color iconColor) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Icon(Icons.directions_car, size: 38, color: iconColor),
    );
  }

  Widget _buildVehicleImageLoading(Color backgroundColor, Color iconColor) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
              backgroundColor: iconColor.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Loading image...',
            style: TextStyle(
              color: iconColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastVehicleImage({
    required String? imageUrl,
    required BoxFit fit,
    required Color backgroundColor,
    required Color iconColor,
    double? width,
    double? height,
  }) {
    final cleanUrl = imageUrl?.trim();
    if (cleanUrl == null || cleanUrl.isEmpty) {
      return _buildTripImageFallback(backgroundColor, iconColor);
    }

    return OptimizedNetworkImage(
      imageUrl: cleanUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: _buildVehicleImageLoading(backgroundColor, iconColor),
      errorWidget: _buildTripImageFallback(backgroundColor, iconColor),
    );
  }

  Widget _buildFeatureIcon(IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Icon(
      icon,
      size: 14,
      color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
    );
  }
}

class _AgreementNote extends StatelessWidget {
  final String text;

  const _AgreementNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 13,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _RenterBookingDetailsPage extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isApprovedTrip;
  final bool isCompletedTrip;
  final String completionStage;
  final List<String> pendingRoles;
  final String paymentTypeLabel;
  final String amountPaidLabel;
  final VoidCallback? onMessage;
  final VoidCallback? onNavigate;
  final VoidCallback? onCancel;
  final VoidCallback? onExtend;
  final VoidCallback? onReturn;
  final VoidCallback? onSuccessfulTrip;
  final VoidCallback? onReceipt;
  final bool isAlreadyRated;
  final VoidCallback? onRateTrip;
  final VoidCallback? onPayRemainingBalance;
  final bool isPaidInFull;

  const _RenterBookingDetailsPage({
    required this.booking,
    required this.isApprovedTrip,
    required this.isCompletedTrip,
    required this.completionStage,
    required this.pendingRoles,
    required this.paymentTypeLabel,
    required this.amountPaidLabel,
    this.onMessage,
    this.onNavigate,
    this.onCancel,
    this.onExtend,
    this.onReturn,
    this.onSuccessfulTrip,
    this.onReceipt,
    this.isAlreadyRated = false,
    this.onRateTrip,
    this.onPayRemainingBalance,
    this.isPaidInFull = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = booking['status']?.toString() ?? 'Pending';
    final days = (booking['days'] as num?)?.toInt() ?? 1;
    final totalCost = (booking['totalCost'] as num?)?.toDouble() ?? 0;
    final lateReturnFee =
        (booking['lateReturnFee'] as num?)?.toDouble() ??
        (booking['late_return_fee'] as num?)?.toDouble() ??
        0.0;
    final lateHours = (booking['late_return_hours'] as num?)?.toInt() ?? 0;
    final finalReturnAmount =
        (booking['renter_return_payment_amount'] as num?)?.toDouble() ??
        (booking['renterReturnPaymentAmount'] as num?)?.toDouble() ??
        0.0;
    final finalPaymentMethod =
        booking['final_payment_method']?.toString() ??
        booking['finalPaymentMethod']?.toString();
    final finalPaymentRef =
        booking['final_payment_reference']?.toString() ??
        booking['finalPaymentReference']?.toString();
    final withDriver = booking['withDriver'] == true ||
        booking['with_driver'] == true ||
        booking['with_driver'] == 1 ||
        booking['with_driver']?.toString().toLowerCase() == 'true';
    const completionActionLabel = 'Rate Your Trip';
    const completionActionIcon = Icons.star_rate_rounded;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVehicleSummary(status),
              const SizedBox(height: 14),
              if (isPaidInFull && !isApprovedTrip && !isCompletedTrip) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have already paid for this trip and it is ready for release.',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (onPayRemainingBalance != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.payment_rounded, color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payment required before vehicle release (1 day prior).',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildPrimaryButton(
                        icon: Icons.payment_rounded,
                        label: 'Pay Now (Remaining Balance)',
                        onPressed: onPayRemainingBalance!,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // Dedicated Rental Service & Driver Details Section
              _buildRentalServiceAndDriverSection(context),
              const SizedBox(height: 14),
              if (booking['extension_status'] != null &&
                  booking['extension_status'].toString().isNotEmpty &&
                  booking['extension_status'] != 'none') ...[
                _buildRenterTripExtensionCard(context),
                const SizedBox(height: 14),
              ],
              if (isApprovedTrip) ...[
                _buildOngoingTripPanel(),
                const SizedBox(height: 14),
              ] else if (onNavigate != null) ...[
                _buildPrimaryButton(
                  icon: Icons.navigation_rounded,
                  label: 'Navigate',
                  onPressed: onNavigate!,
                ),
                const SizedBox(height: 12),
              ],
              if (pendingRoles.isNotEmpty &&
                  completionStage != 'not_started') ...[
                _buildNotice(
                  'Required ratings remaining: ${pendingRoles.join(', ')}.',
                ),
                const SizedBox(height: 12),
              ],
              _buildSection(
                title: 'Trip Timeline',
                children: [
                  _detailRow(
                    Icons.calendar_today_outlined,
                    'Pickup Schedule',
                    '${booking['startDate'] ?? 'N/A'} ${booking['startTime'] ?? ''}',
                  ),
                  _detailRow(
                    Icons.event_available_outlined,
                    'Drop-off Schedule',
                    '${booking['endDate'] ?? 'N/A'} ${booking['endTime'] ?? ''}',
                  ),
                  _detailRow(
                    Icons.trip_origin_rounded,
                    'Pickup Location',
                    booking['pickupLocation']?.toString() ?? 'Not specified',
                  ),
                  _detailRow(
                    Icons.location_on_rounded,
                    'Drop-off Location',
                    booking['dropoffLocation']?.toString() ?? 'Not specified',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSection(
                title: 'Payment Summary',
                children: [
                  _detailRow(Icons.timer_outlined, 'Duration', '$days day(s)'),
                  _detailRow(
                    withDriver ? Icons.drive_eta_rounded : Icons.key_rounded,
                    'Rental Service',
                    withDriver ? 'With Professional Driver' : 'Self-Drive',
                  ),
                  _detailRow(
                    Icons.receipt_long_outlined,
                    'Payment Type',
                    paymentTypeLabel,
                  ),
                  _detailRow(
                    Icons.payments_outlined,
                    'Amount Paid',
                    amountPaidLabel,
                  ),
                  _detailRow(
                    Icons.account_balance_wallet_outlined,
                    'Total Cost',
                    'PHP ${formatAmount(totalCost, decimalDigits: 0)}',
                  ),
                  if (lateReturnFee > 0 || lateHours > 0)
                    _detailRow(
                      Icons.warning_amber_rounded,
                      'Late Return Penalty',
                      'PHP ${formatAmount(lateReturnFee > 0 ? lateReturnFee : (lateHours * 300.0), decimalDigits: 0)}${lateHours > 0 ? ' ($lateHours hrs late)' : ''}',
                    ),
                  if (finalReturnAmount > 0 || finalPaymentMethod != null)
                    _detailRow(
                      Icons.check_circle_outline_rounded,
                      'Final Settlement Paid',
                      'PHP ${formatAmount(finalReturnAmount > 0 ? finalReturnAmount : (totalCost - 1000.0).clamp(0, double.infinity), decimalDigits: 0)}${finalPaymentMethod != null ? ' via ${(finalPaymentMethod ?? '').toUpperCase()}' : ''}',
                    ),
                  if (finalPaymentRef != null && finalPaymentRef.isNotEmpty)
                    _detailRow(
                      Icons.tag_rounded,
                      'Settlement Reference',
                      finalPaymentRef,
                    ),
                  if (onReceipt != null) ...[
                    const SizedBox(height: 6),
                    _buildInlineAction(
                      icon: Icons.download_rounded,
                      label: 'View and Download Receipt',
                      onPressed: onReceipt!,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              if (onSuccessfulTrip != null)
                _buildPrimaryButton(
                  icon: completionActionIcon,
                  label: completionActionLabel,
                  onPressed: onSuccessfulTrip!,
                ),
              if (onSuccessfulTrip != null) const SizedBox(height: 12),
              if (onExtend != null)
                _buildSecondaryButton(
                  icon: Icons.more_time,
                  label: 'Check for Extend Trip',
                  onPressed: onExtend!,
                ),
              if (onExtend != null) const SizedBox(height: 12),
              if (onMessage != null && !isApprovedTrip)
                Builder(
                  builder: (context) {
                    final isChatEligible =
                        BookingService().isEligibleForBookingChat(booking);
                    return _buildSecondaryButton(
                      icon: isChatEligible
                          ? Icons.chat_bubble_outline
                          : Icons.lock_clock,
                      label: isChatEligible
                          ? 'Open Conversation'
                          : 'Conversation (Unlocks 72h Prior)',
                      onPressed: onMessage!,
                    );
                  },
                ),
              if (onMessage != null && !isApprovedTrip)
                const SizedBox(height: 12),
              if (onCancel != null)
                _buildDangerButton(
                  icon: Icons.cancel_outlined,
                  label: booking['statusGroup'] == 'Pending'
                      ? 'Cancel Request'
                      : 'Cancel Booking',
                  onPressed: onCancel!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callPhone(BuildContext context, String? phone) async {
    final clean = phone?.trim() ?? '';
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open phone dialer: $clean')),
      );
    }
  }

  /// 🚗 Dedicated Rental Service & Driver Details Section
  Widget _buildRentalServiceAndDriverSection(BuildContext context) {
    final withDriver = booking['withDriver'] == true ||
        booking['with_driver'] == true ||
        booking['with_driver'] == 1 ||
        booking['with_driver']?.toString().toLowerCase() == 'true';
    final rawDriverName = booking['driverName']?.toString().trim();
    final hasAssignedDriver = rawDriverName != null &&
        rawDriverName.isNotEmpty &&
        rawDriverName != 'To be assigned' &&
        rawDriverName != 'Not requested';
    final driverPhone = booking['driverPhone']?.toString().trim() ?? '';
    final driverEmail = booking['driverEmail']?.toString().trim() ?? '';

    if (!withDriver) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.key_rounded, size: 16, color: Colors.blueAccent),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Rental Service',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    '🔑 SELF-DRIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'You will be driving the vehicle. Please present your valid Driver\'s License and required government ID upon vehicle pickup.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    // With Professional Driver
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasAssignedDriver
              ? Colors.cyan.withValues(alpha: 0.45)
              : Colors.amber.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (hasAssignedDriver ? Colors.cyan : Colors.amber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.airline_seat_recline_normal_rounded,
                  size: 16,
                  color: hasAssignedDriver ? Colors.cyan : Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Rental Service',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (hasAssignedDriver ? Colors.cyan : Colors.amber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (hasAssignedDriver ? Colors.cyan : Colors.amber).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '🚗 WITH DRIVER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: hasAssignedDriver ? Colors.cyan : Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasAssignedDriver) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBgTertiary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                        child: Text(
                          rawDriverName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.cyan,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    rawDriverName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'CERTIFIED DRIVER',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (driverEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                driverEmail,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (driverPhone.isNotEmpty)
                        IconButton.filledTonal(
                          onPressed: () => _callPhone(context, driverPhone),
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.withValues(alpha: 0.2),
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.all(8),
                          ),
                          tooltip: 'Call Driver',
                        ),
                    ],
                  ),
                  if (driverPhone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 46),
                      child: Text(
                        'Phone: $driverPhone',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your assigned professional driver will meet you at the designated pickup location and operate the vehicle for your trip.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 18, color: Colors.amber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver Allocation in Progress',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'You booked this trip with a designated professional driver. Our dispatch team is assigning a certified driver. Contact details will appear here once confirmed.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleSummary(String status) {
    final imageUrl = booking['imageUrl']?.toString();
    final plate = booking['plateNumber']?.toString().trim() ?? '';
    final transmission = booking['transmission']?.toString().trim() ?? '';
    final fuel = booking['fuelType']?.toString().trim() ?? '';
    final seats = booking['seats'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.darkBgTertiary,
                  borderRadius: BorderRadius.circular(16),
                  image: imageUrl == null || imageUrl.isEmpty
                      ? null
                      : DecorationImage(
                          image: OptimizedNetworkImageProvider(imageUrl),
                          fit: BoxFit.cover,
                        ),
                ),
                child: imageUrl == null || imageUrl.isEmpty
                    ? const Icon(
                        Icons.directions_car,
                        color: AppColors.textSecondary,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking['carName']?.toString() ?? 'Vehicle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      booking['rentalPartner']?.toString() ?? 'Mobilis',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (plate.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Plate: $plate',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(status: status),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (transmission.isNotEmpty || fuel.isNotEmpty || seats != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (transmission.isNotEmpty)
                  _specChip(transmission),
                if (fuel.isNotEmpty)
                  _specChip(fuel),
                if (seats != null)
                  _specChip('$seats Seats'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _specChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.darkBgTertiary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildOngoingTripPanel() {
    final rawStatus = (booking['status'] ?? booking['rawStatus'] ?? '')
        .toString()
        .toLowerCase();
    final isReturnSubmitted =
        rawStatus == 'return_pending_inspection' ||
        rawStatus == 'awaiting_completion' ||
        rawStatus == 'completed' ||
        rawStatus == 'returned' ||
        rawStatus == 'successful' ||
        rawStatus == 'success' ||
        rawStatus == 'awaiting_ratings' ||
        booking['returned_at'] != null ||
        booking['returnedAt'] != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route_rounded, color: AppColors.primary, size: 21),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Ongoing Trip',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _LiveTripBadge(),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Follow the return schedule and keep trip coordination in the booking conversation.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          BookingReturnCountdown(booking: booking),
          const SizedBox(height: 14),
          if (isReturnSubmitted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_clock_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vehicle Return Submitted — Waiting for Operator Verification & Inspection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: isAlreadyRated
                  ? OutlinedButton.icon(
                      onPressed: onRateTrip,
                      icon: const Icon(
                        Icons.star_rounded,
                        color: AppColors.ratingGold,
                        size: 18,
                      ),
                      label: const Text(
                        'Rating Submitted • View',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onRateTrip,
                      icon: const Icon(
                        Icons.star_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      label: const Text(
                        'Rate Trip',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ] else if (onReturn != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReturn,
                icon: const Icon(
                  Icons.assignment_return_rounded,
                  color: Colors.black,
                  size: 20,
                ),
                label: const Text(
                  'Return Vehicle',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (onNavigate != null)
                Expanded(
                  child: _buildCompactTripAction(
                    icon: Icons.navigation_rounded,
                    label: 'Navigate',
                    filled: false,
                    onPressed: onNavigate!,
                  ),
                ),
              if (onNavigate != null && onMessage != null)
                const SizedBox(width: 10),
              if (onMessage != null)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final isChatEligible =
                          BookingService().isEligibleForBookingChat(booking);
                      return _buildCompactTripAction(
                        icon: isChatEligible
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.lock_clock,
                        label: isChatEligible ? 'Message' : 'Chat (72h Prior)',
                        filled: false,
                        onPressed: onMessage!,
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTripAction({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
    );
    return SizedBox(
      height: 48,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: shape,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: shape,
              ),
              child: child,
            ),
    );
  }

  Widget _buildInlineAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildDangerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildRenterTripExtensionCard(BuildContext context) {
    final extStatus =
        booking['extension_status']?.toString().toLowerCase().trim() ?? 'pending';
    final requestedEndAt = DateTime.tryParse(
      booking['extension_requested_end_at']?.toString() ?? '',
    );
    final days = (booking['extension_days'] as num?)?.toInt() ?? 1;
    final additionalPrice =
        (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;
    final newDest =
        booking['extension_requested_destination']?.toString().trim();
    final payStatus =
        booking['extension_payment_status']?.toString().toLowerCase().trim() ??
        'unpaid';

    String statusText;
    Color statusColor;
    switch (extStatus) {
      case 'pending':
      case 'pending_operator':
      case 'pending_partner':
        statusText = 'Under Review';
        statusColor = Colors.amber;
        break;
      case 'accepted':
      case 'payment_pending':
        statusText = 'Accepted • Payment Due';
        statusColor = const Color(0xFF38BDF8);
        break;
      case 'payment_completed':
        statusText = 'Payment Submitted • Verifying';
        statusColor = Colors.purpleAccent;
        break;
      case 'pending_final_confirmation':
        statusText = 'Payment Verified • Confirming';
        statusColor = const Color(0xFF6366F1);
        break;
      case 'finalized':
      case 'approved':
        statusText = 'Extension Finalized';
        statusColor = Colors.greenAccent;
        break;
      case 'rejected':
      case 'cancelled':
        statusText = 'Extension Declined';
        statusColor = AppColors.error;
        break;
      default:
        statusText = extStatus.toUpperCase();
        statusColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.update_rounded, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Trip Extension Request',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow(
            Icons.event_repeat_rounded,
            'Requested Return Date',
            requestedEndAt != null
                ? '${requestedEndAt.year}-${requestedEndAt.month.toString().padLeft(2, '0')}-${requestedEndAt.day.toString().padLeft(2, '0')} (+$days days)'
                : 'N/A',
          ),
          if (newDest != null && newDest.isNotEmpty)
            _detailRow(Icons.flag_outlined, 'Requested Destination', newDest),
          _detailRow(
            Icons.payments_outlined,
            'Additional Extension Fee',
            '+PHP ${formatAmount(additionalPrice, decimalDigits: 0)}',
          ),
          if (extStatus == 'accepted' || extStatus == 'payment_pending') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRenterExtensionPaymentModal(context),
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: Text(
                  'Pay Extension Fee (PHP ${formatAmount(additionalPrice, decimalDigits: 0)})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ] else if (extStatus == 'payment_completed') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.purpleAccent, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment receipt submitted! Waiting for manager to verify proof and confirm your dates.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (extStatus == 'pending_final_confirmation') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF818CF8), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment verified! Vehicle manager is performing final calendar confirmation.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (extStatus == 'finalized') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trip extension successfully confirmed! New return schedule and destinations are committed.',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
  }

  Future<void> _showRenterExtensionPaymentModal(BuildContext context) async {
    final bookingId = booking['id']?.toString() ?? '';
    final additionalPrice =
        (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;
    final referenceController = TextEditingController();
    String selectedMethod = 'GCash';
    XFile? pickedReceipt;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pay Trip Extension Fee',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'PHP ${formatAmount(additionalPrice, decimalDigits: 0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'PSDC Payment Accounts',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '• GCash: 0917-123-4567 (Mobilis PSDC Main)\n• Maya: 0917-123-4567\n• BDO Bank Transfer: 0012-3456-7890',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Select Payment Method',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    dropdownColor: AppColors.darkBg,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.darkBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                      DropdownMenuItem(value: 'Maya', child: Text('Maya / PayMaya')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (BDO/BPI)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedMethod = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: referenceController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Payment Reference Number / Transaction ID',
                      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      hintText: 'e.g. 10023458921',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: AppColors.darkBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (image != null) {
                        setModalState(() => pickedReceipt = image);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.darkBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pickedReceipt != null
                              ? AppColors.primary
                              : AppColors.borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            pickedReceipt != null
                                ? Icons.check_circle_rounded
                                : Icons.upload_file_rounded,
                            color: pickedReceipt != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            pickedReceipt != null
                                ? 'Receipt Attached: ${pickedReceipt!.name}'
                                : 'Upload Payment Receipt Proof (Screenshot)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: pickedReceipt != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final ref = referenceController.text.trim();
                              if (ref.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a payment reference number.'),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                String proofUrl = '';
                                if (pickedReceipt != null) {
                                  final bytes = await pickedReceipt!.readAsBytes();
                                  final fileExt = pickedReceipt!.name.split('.').last;
                                  final fileName =
                                      'ext_payment_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
                                  final supabase = Supabase.instance.client;
                                  await supabase.storage
                                      .from('booking-payments')
                                      .uploadBinary(
                                        fileName,
                                        bytes,
                                        fileOptions: const FileOptions(upsert: true),
                                      );
                                  proofUrl = supabase.storage
                                      .from('booking-payments')
                                      .getPublicUrl(fileName);
                                }

                                await BookingService().submitExtensionPayment(
                                  bookingId: bookingId,
                                  paymentMethod: selectedMethod,
                                  paymentReference: ref,
                                  proofUrl: proofUrl.isNotEmpty ? proofUrl : null,
                                );

                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Extension payment submitted successfully!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to submit payment: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Submit Payment Proof',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const _CalendarLegendDot({
    required this.color,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }
}

class _LiveTripBadge extends StatelessWidget {
  const _LiveTripBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.45)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: AppColors.success, size: 7),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
