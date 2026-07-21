import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/conversation_tile.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/notification_item.dart';
import '../../widgets/cost_breakdown_row.dart';
import '../../widgets/trip_timeline_step.dart';
import '../../widgets/role_ui.dart';
import '../../widgets/optimized_network_image.dart';
import '../../widgets/vehicle_image_carousel.dart';
import '../../widgets/relative_time_text.dart';
import '../../widgets/booking_return_countdown.dart';
import '../profile/settings_screen.dart';
import '../profile/payment_methods_screen.dart';
import '../profile/verification_documents_screen.dart';
import '../profile/trip_rating_flow_screen.dart';
import '../profile/unified_profile_screen.dart';
import '../partner/partner_tracking_screen.dart';
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
  int _userCreatedYear = DateTime.now().year;
  int _totalTrips = 0;

  int selectedNavIndex = 0;
  int? selectedBookingIndex;
  String _selectedBookingStatus = 'Pending';
  String? selectedProfilePage;
  String selectedCategory = '';

  bool _isLoadingVehicles = false;
  bool _isLocatingNearbyVehicles = false;
  bool _hasShownVerificationPrompt = false;
  bool _dimCustomerServiceFab = false;
  DateTime? _lastBackPressedAt;
  DateTime? _bookingFilterFrom;
  DateTime? _bookingFilterTo;
  double? _nearbyLatitude;
  double? _nearbyLongitude;
  String? _nearbyLocationLabel;
  List<String> _nearbyLocationTokens = [];

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
    _searchController.addListener(_applyVehicleFilters);
    _loadVehicles();
    _loadBookings(); // 📅 Load renter's bookings
    _loadConversations();
    _setupVerificationListener(); // 🔄 Listen for real-time verification updates
    _loadNotifications(); // 🔔 Load notifications
    _setupNotificationsListener(); // 🔔 Listen for new notifications
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
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) {
              final newNotification =
                  payload.newRecord as Map<String, dynamic>?;
              if (newNotification != null && mounted) {
                if (isMessageNotification(newNotification)) return;
                final title =
                    newNotification['title']?.toString() ?? 'Notification';
                final message = newNotification['message']?.toString() ?? '';
                setState(() {
                  _notifications.insert(0, newNotification);
                });
                NotificationPermissionService().showBrowserNotification(
                  title: title,
                  body: message,
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ Error setting up notifications listener: $e');
    }
  }

  Future<void> _loadBookings() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return;

      final bookings = await BookingService().getRenterBookings(user.id);

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

      if (mounted) {
        setState(() {
          _bookings = hydratedBookings;
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

    if (_nearbyLatitude != null && _nearbyLongitude != null) {
      final nearby = <Map<String, dynamic>>[];
      final fallbackNearby = <Map<String, dynamic>>[];

      for (final vehicle in filtered) {
        final copy = Map<String, dynamic>.from(vehicle);
        final distance = _vehicleDistanceKm(copy);
        if (distance != null) {
          copy['distance_km'] = distance;
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

  Future<void> _filterVehiclesNearMe() async {
    if (_isLocatingNearbyVehicles) return;

    setState(() => _isLocatingNearbyVehicles = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please turn on location services first.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission is required to find nearby cars.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      var label = 'your location';
      final tokens = <String>{};
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final labelParts = [
            p.subLocality,
            p.locality,
            p.subAdministrativeArea,
            p.administrativeArea,
          ].where((part) => part != null && part.trim().isNotEmpty).toList();
          if (labelParts.isNotEmpty) {
            label = labelParts.take(2).join(', ');
          }
          for (final part in labelParts) {
            final token = part!.trim().toLowerCase();
            if (token.length >= 3) tokens.add(token);
          }
        }
      } catch (e) {
        debugPrint('Nearby reverse geocoding failed: $e');
      }

      if (!mounted) return;
      setState(() {
        _nearbyLatitude = position.latitude;
        _nearbyLongitude = position.longitude;
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
      if (mounted) {
        setState(() => _isLocatingNearbyVehicles = false);
      }
    }
  }

  void _clearNearbyVehicleFilter() {
    if (_nearbyLatitude == null && _nearbyLongitude == null) return;
    setState(() {
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
      final withDriver = booking['with_driver'] == true;
      final driverName = driverUser?['full_name']?.toString().trim();
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

      return {
        'id': booking['id']?.toString() ?? '',
        'created_at': booking['created_at'],
        'updated_at': booking['updated_at'],
        'operator_id': booking['operator_id'],
        'start_at': booking['start_at'],
        'end_at': booking['end_at'],
        'start_date_raw': booking['start_date'],
        'end_date_raw': booking['end_date'],
        'vehicles': vehicle,
        'driver': driver,
        'withDriver': withDriver,
        'driverName': driverName == null || driverName.isEmpty
            ? (withDriver ? 'To be assigned' : 'Not requested')
            : driverName,
        'paymentStatus': paymentStatus,
        'reservationPaymentType': booking['reservation_payment_type']
            ?.toString()
            .trim(),
        'reservationPaymentCoversTotal':
            booking['reservation_payment_covers_total'] == true,
        'reservationFeeAmount': (booking['reservation_fee_amount'] as num?)
            ?.toDouble(),
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
        'carName': _vehicleTitle(vehicle),
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
        'totalCost': totalCost,
        'days': days,
        'rentalPartner': rentalPartner,
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
      _openBookingTracking(booking);
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

  bool _canOpenBookingConversation(Map<String, dynamic> booking) {
    final rawStatus = booking['rawStatus']?.toString().toLowerCase() ?? '';
    return rawStatus == 'approved' ||
        rawStatus == 'confirmed' ||
        rawStatus == 'active';
  }

  Future<void> _openBookingConversation(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

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
              content: Text('Group chat is not ready yet. Please refresh.'),
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

  Future<void> _openBookingTracking(Map<String, dynamic> booking) async {
    final rawStatus = booking['rawStatus']?.toString().toLowerCase() ?? '';
    if (rawStatus != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tracking is available once the trip is ongoing.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final conversationId = await _findBookingConversationId(booking);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartnerTrackingScreen(
          booking: booking,
          conversationId: conversationId ?? '',
          recipientName: '${booking['carName']} Booking',
        ),
      ),
    );
  }

  Future<String?> _findBookingConversationId(
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return null;

    final existingConversation = _conversations.firstWhere(
      (conversation) => conversation['booking_id']?.toString() == bookingId,
      orElse: () => {},
    );
    final existingId = existingConversation['id']?.toString();
    if (existingId != null && existingId.isNotEmpty) return existingId;

    final conversation = await Supabase.instance.client
        .from('conversations')
        .select('id')
        .eq('booking_id', bookingId)
        .maybeSingle();
    return conversation?['id']?.toString();
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
        backgroundColor: selectedNavIndex == 0
            ? (isDark ? AppColors.darkBg : AppColors.lightBg)
            : AppColors.darkBg,
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
                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'CURRENT LOCATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userLocation,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
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
                      onChanged: (_) => _applyVehicleFilters(),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Find a car near you...',
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
                          message: _nearbyLatitude != null
                              ? 'Show all cars'
                              : 'Find cars near me',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _isLocatingNearbyVehicles
                                ? null
                                : _nearbyLatitude != null
                                ? _clearNearbyVehicleFilter
                                : _filterVehiclesNearMe,
                            child: Container(
                              width: 42,
                              height: 42,
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _nearbyLatitude != null
                                    ? AppColors.success
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _isLocatingNearbyVehicles
                                  ? const Padding(
                                      padding: EdgeInsets.all(11),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Icon(
                                      _nearbyLatitude != null
                                          ? Icons.location_off
                                          : Icons.my_location,
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

                      final ratingCount =
                          (car['rating_count'] as num?)?.toInt() ?? 0;
                      final rating = ratingCount > 0
                          ? ((car['rating'] as num?)?.toDouble() ?? 0.0)
                          : 0.0;
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
                                              const Icon(
                                                Icons.star,
                                                color: AppColors.ratingGold,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                ),
                                              ),
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
                      ? BookingReturnCountdown(booking: booking)
                      : null,
                  carImageUrl: booking['imageUrl'] as String?,
                  showRating:
                      booking['statusGroup'] == 'Completed' &&
                      ((booking['rating'] as num?)?.toDouble() ?? 0) > 0,
                  showTrackButton: booking['statusGroup'] == 'Ongoing',
                  onTrack: () => _openBookingTracking(booking),
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
        const ProfileStatItem(label: 'Rating', value: '0.0'),
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
    final isCompletedTrip =
        completionStage == 'completed' ||
        completionState['status'] == 'completed';

    if (isPendingTrip) {
      _showPendingBookingDetails(booking);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RenterBookingDetailsPage(
          booking: booking,
          isApprovedTrip: isApprovedTrip,
          isCompletedTrip: isCompletedTrip,
          completionStage: completionStage,
          pendingRoles: pendingRoles,
          paymentTypeLabel: _bookingPaymentTypeLabel(booking),
          amountPaidLabel: _bookingAmountPaidLabel(booking),
          onTrack: booking['rawStatus'] == 'active'
              ? () => _openBookingTracking(booking)
              : null,
          onMessage: _canOpenBookingConversation(booking)
              ? () => _openBookingConversation(booking)
              : null,
          onCancel: _isCancellableStatusForUi(booking)
              ? () => _handleBookingCancellation(booking)
              : null,
          onExtend: isApprovedTrip ? () => _checkForExtendTrip(booking) : null,
          onSuccessfulTrip: isApprovedTrip || isCompletedTrip
              ? () => _handleSuccessfulTripFromDetails(
                  booking: booking,
                  completionStage: completionStage,
                  pendingRoles: pendingRoles,
                )
              : null,
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
              if (booking['rawStatus'] == 'active') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openBookingTracking(booking);
                    },
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: const Text('Track Ongoing Trip'),
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
                const SizedBox(height: 16),
              ],
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
                    isCompletedTrip ? 'Successful Trip' : 'Trip Ongoing',
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
            ],
            if (isApprovedTrip)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _checkForExtendTrip(booking),
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

    if (completionStage == 'renter_rating') {
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
        await _loadBookings();
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
    final totalCost = (booking['totalCost'] as num?)?.toDouble() ?? 0.0;
    final dailyRate = totalCost / safeDays;

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
                        '$safeDays day${safeDays == 1 ? '' : 's'} x ₱${formatAmount(dailyRate, decimalDigits: 0)}/day',
                    amount: '₱${formatAmount(totalCost, decimalDigits: 0)}',
                  ),
                  const CostBreakdownRow(label: 'Insurance', amount: '₱50'),
                  CostBreakdownRow(
                    label: 'Tax (10%)',
                    amount:
                        '₱${formatAmount((totalCost + 50) * 0.1, decimalDigits: 0)}',
                  ),
                  const Divider(color: AppColors.borderColor),
                  CostBreakdownRow(
                    label: 'Total Paid',
                    amount:
                        '₱${formatAmount(totalCost + 50 + ((totalCost + 50) * 0.1), decimalDigits: 0)}',
                    isBold: true,
                    amountColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PENDING APPROVAL',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
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
              backgroundColor: AppColors.darkBgTertiary,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Waiting for owner to confirm your request.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          const Text(
            'Usually takes less than 2 hours.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingVehicleCard(Map<String, dynamic> booking) {
    final imageUrl = booking['imageUrl']?.toString().trim() ?? '';
    final totalCost = (booking['totalCost'] as num?)?.toDouble() ?? 0;
    final days = ((booking['days'] as num?)?.toInt() ?? 1).clamp(1, 365);
    final dailyRate = totalCost / days;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REQUESTED VEHICLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  booking['carName']?.toString() ?? 'Vehicle',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '₱${formatAmount(dailyRate, decimalDigits: 0)} / day',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
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
                backgroundColor: AppColors.darkBgTertiary,
                iconColor: AppColors.textTertiary,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gavel_outlined,
                size: 15,
                color: AppColors.textPrimary,
              ),
              SizedBox(width: 8),
              Text(
                'Rental Agreement Notes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _AgreementNote('Late penalty: ₱300/hr after scheduled return.'),
          SizedBox(height: 7),
          _AgreementNote(
            'Fuel Policy: Same-to-same. Return with the same fuel level.',
          ),
          SizedBox(height: 7),
          _AgreementNote(
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
            style: const TextStyle(fontSize: 9, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalAgreementCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: AppColors.primary,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'Rental Agreement',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Keep vehicle clean and return it on schedule.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

  Future<void> _checkForExtendTrip(Map<String, dynamic> booking) async {
    final vehicleId = booking['vehicle_id']?.toString();
    final endRaw =
        booking['end_at']?.toString() ?? booking['end_date_raw']?.toString();

    if (vehicleId == null || vehicleId.isEmpty || endRaw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check extension availability.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final endAt = DateTime.tryParse(endRaw)?.toLocal();
    if (endAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read the booking return date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final nextDay = DateTime(
      endAt.year,
      endAt.month,
      endAt.day,
    ).add(const Duration(days: 1));
    final unavailableDates = await VehicleService().getUnavailableDates(
      vehicleId,
    );
    final isUnavailable = unavailableDates.any(
      (date) =>
          date.year == nextDay.year &&
          date.month == nextDay.month &&
          date.day == nextDay.day,
    );

    if (!mounted) return;

    final formattedNextDay = _formatDateShort(nextDay.toIso8601String());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isUnavailable
              ? 'Extension unavailable for $formattedNextDay due to another booking.'
              : 'Extension slot available for $formattedNextDay. Contact operator to proceed.',
        ),
        backgroundColor: isUnavailable ? AppColors.error : AppColors.success,
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

  Future<void> _handleBookingCancellation(Map<String, dynamic> booking) async {
    final bookingService = BookingService();
    final canCancel = _canCancelBooking(booking);
    final reasonController = TextEditingController();

    if (!canCancel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancellation window has passed (24 hours limit)'),
          backgroundColor: AppColors.error,
        ),
      );
      reasonController.dispose();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cancel Request',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
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
              Container(
                width: double.infinity,
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
                      booking['carName']?.toString() ?? 'Selected vehicle',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${booking['startDate'] ?? 'Start'} - ${booking['endDate'] ?? 'End'}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tell us why you are cancelling. This helps the operator and partner review the request.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                minLines: 3,
                maxLines: 5,
                maxLength: 180,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cancellation reason',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.darkBg,
                  counterStyle: const TextStyle(color: AppColors.textTertiary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.borderColor),
            ),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please add a cancellation reason.'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }
    final cancellationReason = reasonController.text.trim();
    reasonController.dispose();

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Cancelling booking...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      await bookingService.updateBookingStatus(booking['id'], 'cancelled');
      await Supabase.instance.client
          .from('bookings')
          .update({
            'cancellation_reason': cancellationReason,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', booking['id']);

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
  final VoidCallback? onTrack;
  final VoidCallback? onMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onExtend;
  final VoidCallback? onSuccessfulTrip;

  const _RenterBookingDetailsPage({
    required this.booking,
    required this.isApprovedTrip,
    required this.isCompletedTrip,
    required this.completionStage,
    required this.pendingRoles,
    required this.paymentTypeLabel,
    required this.amountPaidLabel,
    this.onTrack,
    this.onMessage,
    this.onCancel,
    this.onExtend,
    this.onSuccessfulTrip,
  });

  @override
  Widget build(BuildContext context) {
    final status = booking['status']?.toString() ?? 'Pending';
    final days = (booking['days'] as num?)?.toInt() ?? 1;
    final totalCost = (booking['totalCost'] as num?)?.toDouble() ?? 0;
    final completionActionLabel = switch (completionStage) {
      'renter_rating' => 'Rate Your Trip',
      'completed' => 'Trip Completed',
      'awaiting_after_checklist' => 'Waiting for After Checklist',
      'awaiting_payment' => 'Waiting for Full Payment',
      'operator_rating' ||
      'partner_rating' ||
      'driver_rating' => 'Trip Ratings Pending',
      _ => 'Trip Ongoing',
    };
    final completionActionIcon = switch (completionStage) {
      'renter_rating' => Icons.star_rate_rounded,
      'completed' => Icons.check_circle_outline_rounded,
      _ => Icons.hourglass_bottom_rounded,
    };

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
              const SizedBox(height: 16),
              if (isApprovedTrip) ...[
                BookingReturnCountdown(booking: booking),
                const SizedBox(height: 12),
              ],
              if (onTrack != null) ...[
                _buildPrimaryButton(
                  icon: Icons.near_me_outlined,
                  label: 'Track Ongoing Trip',
                  onPressed: onTrack!,
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
                    'Pickup',
                    '${booking['startDate'] ?? 'N/A'} ${booking['startTime'] ?? ''}',
                  ),
                  _detailRow(
                    Icons.event_available_outlined,
                    'Drop-off',
                    '${booking['endDate'] ?? 'N/A'} ${booking['endTime'] ?? ''}',
                  ),
                  _detailRow(
                    Icons.location_on_outlined,
                    'Pickup Location',
                    booking['pickupLocation']?.toString() ?? 'Not specified',
                  ),
                  _detailRow(
                    Icons.flag_outlined,
                    'Drop-off Location',
                    booking['dropoffLocation']?.toString() ?? 'Not specified',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Payment Summary',
                children: [
                  _detailRow(Icons.timer_outlined, 'Duration', '$days day(s)'),
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
              if (onMessage != null)
                _buildSecondaryButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Open Conversation',
                  onPressed: onMessage!,
                ),
              if (onMessage != null) const SizedBox(height: 12),
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

  Widget _buildVehicleSummary(String status) {
    final imageUrl = booking['imageUrl']?.toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
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
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  booking['rentalPartner']?.toString() ?? 'Mobilis',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(status: status),
                ),
              ],
            ),
          ),
        ],
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
