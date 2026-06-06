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
import '../../../services/verification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/conversation_tile.dart';
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
  bool _hasShownVerificationPrompt = false;
  DateTime? _bookingFilterFrom;
  DateTime? _bookingFilterTo;

  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filteredVehicles = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _conversations = [];

  final TextEditingController _searchController = TextEditingController();

  // 🔄 Real-time verification status listener
  RealtimeChannel? _verificationSubscription;

  // 🔔 Real-time notifications listener
  RealtimeChannel? _notificationsSubscription;

  // 📅 Real-time bookings listener
  RealtimeChannel? _bookingsSubscription;

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
    _loadBookings(); // 📅 Load renter's bookings
    _loadConversations();
    _setupVerificationListener(); // 🔄 Listen for real-time verification updates
    _loadNotifications(); // 🔔 Load notifications
    _setupNotificationsListener(); // 🔔 Listen for new notifications
    _setupBookingsListener(); // 📅 Listen for booking updates
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verificationSubscription?.unsubscribe(); // ✅ Clean up realtime listener
    _notificationsSubscription
        ?.unsubscribe(); // ✅ Clean up notifications listener
    _bookingsSubscription?.unsubscribe(); // ✅ Clean up bookings listener
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
      final record = await supabase
          .from('users')
          .select('full_name, id_verified, verification_status, created_at')
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
                final isVerified = newRecord['id_verified'] as bool? ?? false;
                if (isVerified != userVerified) {
                  if (mounted) {
                    setState(() {
                      userVerified = isVerified;
                      _hasShownVerificationPrompt = isVerified;
                    });
                  }
                  // Show verification prompt if newly unverified
                  if (!isVerified && !_hasShownVerificationPrompt && mounted) {
                    _showVerificationPromptOnce();
                  }
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
    final latestVerified = await AuthService().isUserVerified();
    if (!mounted || latestVerified) {
      if (mounted) {
        setState(() {
          userVerified = latestVerified;
          _hasShownVerificationPrompt = latestVerified;
        });
      }
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

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(notifications);
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading notifications: $e');
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

        final otherUser = await chatService.getOtherUserId(
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
      }
    } catch (e) {
      debugPrint('Error loading conversations: ');
      if (mounted) {
        setState(() {
          _conversations = [];
        });
      }
    }
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
                setState(() {
                  _notifications.insert(0, newNotification);
                });
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
              if (payload.newRecord != null) {
                final booking = payload.newRecord! as Map<String, dynamic>;
                final oldRecord = payload.oldRecord as Map<String, dynamic>?;
                final newStatus = (booking['status'] as String?)?.toLowerCase();
                final oldStatus = (oldRecord?['status'] as String?)
                    ?.toLowerCase();

                if (newStatus == 'confirmed' && oldStatus != 'confirmed') {
                  await _createBookingGroupChat(booking);
                }
              }

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

  Future<void> _createBookingGroupChat(Map<String, dynamic> booking) async {
    try {
      final authService = AuthService();
      final currentUserId = authService.currentUser?.id;
      if (currentUserId == null) return;

      final bookingId = booking['id'] as String;
      final withDriver = booking['with_driver'] as bool? ?? false;
      final assignedDriverId = booking['assigned_driver_id'] as String?;
      final operatorId = booking['operator_id'] as String?;
      final vehicle = (booking['vehicles'] as Map<String, dynamic>?) ?? {};
      final ownerId = vehicle['owner_id'] as String?;

      final participantIds = <String>{currentUserId};

      if (withDriver && assignedDriverId != null && operatorId != null) {
        participantIds.addAll([assignedDriverId, operatorId]);
      } else if (withDriver &&
          assignedDriverId != null &&
          ownerId != null &&
          operatorId != null) {
        participantIds.addAll([assignedDriverId, ownerId, operatorId]);
      } else if (!withDriver) {
        return;
      }

      if (participantIds.isEmpty) return;

      await ChatService().createGroupConversation(
        bookingId: bookingId,
        participantIds: participantIds.toList(),
      );
    } catch (e) {
      debugPrint('Error creating group chat: $e');
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

    if (!mounted) return;
    setState(() => _filteredVehicles = filtered);
  }

  Future<void> _refreshDashboard() async {
    await _loadVehicles();
    await _loadBookings();
    await _loadNotifications();
    await _loadConversations();
    _loadUserData();
  }

  Future<void> _selectBookNowDates() async {
    if (!await _checkRentalVerification()) return;
    if (!mounted) return;

    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
      initialDateRange: _bookingFilterFrom != null && _bookingFilterTo != null
          ? DateTimeRange(start: _bookingFilterFrom!, end: _bookingFilterTo!)
          : DateTimeRange(
              start: firstDate.add(const Duration(days: 1)),
              end: firstDate.add(const Duration(days: 1)),
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.darkBgSecondary,
              onSurface: AppColors.textPrimary,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppColors.darkBgSecondary,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: AppColors.darkBg,
              headerForegroundColor: AppColors.textPrimary,
              rangePickerBackgroundColor: AppColors.darkBgSecondary,
              rangePickerHeaderBackgroundColor: AppColors.darkBg,
              rangePickerHeaderForegroundColor: AppColors.textPrimary,
              rangePickerSurfaceTintColor: Colors.transparent,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.textTertiary;
                }
                if (states.contains(WidgetState.selected)) {
                  return Colors.black;
                }
                return AppColors.textPrimary;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.all(AppColors.primary),
              todayBorder: const BorderSide(color: AppColors.primary),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.textTertiary;
                }
                if (states.contains(WidgetState.selected)) {
                  return Colors.black;
                }
                return AppColors.textPrimary;
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
            ),
            scaffoldBackgroundColor: AppColors.darkBg,
            dialogBackgroundColor: AppColors.darkBgSecondary,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;

    setState(() {
      _bookingFilterFrom = picked.start;
      _bookingFilterTo = picked.end;
    });
    await _loadVehicles();

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VehicleSearchScreen(
          initialCategory: selectedCategory.isEmpty ? null : selectedCategory,
          initialAvailableFrom: picked.start,
          initialAvailableTo: picked.end,
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

  Future<bool> _checkRentalVerification() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return false;

      final verificationState =
          await VerificationService.getUserVerificationState(user.id);
      final userRole = verificationState['role']?.toString() ?? 'renter';
      final isVerifiedInDb = verificationState['is_verified'] as bool? ?? false;

      if (isVerifiedInDb != userVerified) {
        if (mounted) {
          setState(() {
            userVerified = isVerifiedInDb;
          });
        }
      }

      if (userRole == 'driver') return true;

      if (!isVerifiedInDb) {
        _showRentalVerificationModal();
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking verification: $e');
      return true;
    }
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

      final startDateRaw = booking['start_date']?.toString();
      final endDateRaw = booking['end_date']?.toString();
      final startDate = _formatDateShort(startDateRaw);
      final endDate = _formatDateShort(endDateRaw);

      int days = 1;
      try {
        if (startDateRaw != null && endDateRaw != null) {
          final start = DateTime.parse(startDateRaw);
          final end = DateTime.parse(endDateRaw);
          days = _inclusiveRentalDays(start, end);
        }
      } catch (_) {
        days = 1;
      }

      final rawStatus = (booking['status'] ?? '').toString().toLowerCase();
      String uiStatus;
      String statusGroup;
      if (rawStatus == 'active' ||
          rawStatus == 'approved' ||
          rawStatus == 'confirmed') {
        uiStatus = 'Approved';
        statusGroup = 'Approved';
      } else if (rawStatus == 'completed') {
        uiStatus = 'Completed';
        statusGroup = 'Completed';
      } else if (rawStatus == 'rejected') {
        uiStatus = 'Declined';
        statusGroup = 'Declined';
      } else if (rawStatus == 'cancelled' || rawStatus == 'canceled') {
        uiStatus = 'Cancelled';
        statusGroup = 'Declined';
      } else {
        uiStatus = 'Pending';
        statusGroup = 'Pending';
      }

      final owner = vehicle?['owner'] as Map<String, dynamic>?;
      final ownerRole = (owner?['role'] ?? '').toString().toLowerCase();
      final ownerName = (owner?['full_name'] ?? '').toString().trim();
      final rentalPartner = (ownerRole == 'partner' && ownerName.isNotEmpty)
          ? ownerName
          : 'PSDC';

      return {
        'id': booking['id']?.toString() ?? '',
        'created_at': booking['created_at'],
        'carName': _vehicleTitle(vehicle),
        'carImage': Icons.directions_car,
        'imageUrl': (vehicle?['image_url'] as String?),
        'status': uiStatus,
        'statusGroup': statusGroup,
        'rawStatus': rawStatus,
        'startDate': startDate,
        'endDate': endDate,
        'pickupLocation':
            booking['pickup_location']?.toString() ?? 'Pickup not specified',
        'dropoffLocation':
            booking['dropoff_location']?.toString() ?? 'Drop-off not specified',
        'totalCost': totalCost,
        'days': days,
        'rentalPartner': rentalPartner,
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

  List<Map<String, dynamic>> _uiConversations() {
    return _conversations.map((conversation) {
      final otherUser = conversation['other_user'] as Map<String, dynamic>?;
      final lastMessage = conversation['last_message'] as Map<String, dynamic>?;
      final unreadCount = conversation['unread_count'] as int? ?? 0;

      return {
        'conversationId': conversation['id']?.toString() ?? '',
        'recipientName':
            otherUser?['full_name']?.toString().trim().isNotEmpty == true
            ? otherUser!['full_name'].toString().trim()
            : otherUser?['email']?.toString().trim().isNotEmpty == true
            ? otherUser!['email'].toString().trim()
            : 'Conversation',
        'lastMessage':
            lastMessage?['content']?.toString().trim().isNotEmpty == true
            ? lastMessage!['content'].toString().trim()
            : 'No messages yet',
        'timestamp': _formatTimeAgo(lastMessage?['created_at']?.toString()),
        'unreadCount': unreadCount,
        'isAutoGenerated': lastMessage?['is_auto_generated'] == true,
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
            'recipientAvatar': '',
            'isAutoGenerated': conversation['isAutoGenerated'] == true,
          },
        )
        .then((_) {
          _loadConversations();
          _loadNotifications();
        });
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
        .where(
          (b) =>
              b['statusGroup'] == 'Approved' || b['statusGroup'] == 'Pending',
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectBookNowDates,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _bookingFilterFrom == null
                            ? 'Book Now!'
                            : 'Book Now! ${_formatDateRange(_bookingFilterFrom, _bookingFilterTo)}',
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

                      // ✅ FIX: Separate hour and day prices
                      final pricePerHour =
                          (car['price_per_hour'] as num?)?.toDouble() ?? 0.0;
                      final pricePerDay =
                          (car['price_per_day'] as num?)?.toDouble() ?? 0.0;

                      final rating = (car['rating'] as num?)?.toDouble() ?? 4.5;
                      final vehicleType = car['vehicle_type'] ?? 'Standard';
                      final color = car['color'] ?? 'Unknown';
                      final seats = car['seats'] ?? 5;

                      // ✅ FIX: Read transmission field instead of reusing vehicleType
                      final transmission = car['transmission'] ?? 'Manual';

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
                                'initialStartDate': _bookingFilterFrom,
                                'initialEndDate': _bookingFilterTo,
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
                                        // ✅ FIX: Show vehicleType, color, seats
                                        // then transmission on second row
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
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary,
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
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary,
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
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        // ✅ FIX: Transmission row with correct icon & value
                                        Row(
                                          children: [
                                            _buildFeatureIcon(
                                              Icons.settings_outlined,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                transmission.toString(),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
                                                              '₱${pricePerHour.toStringAsFixed(0)}',
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
                                                        const TextSpan(
                                                          text: '/hr',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: AppColors
                                                                .textSecondary,
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
                                                              '₱${pricePerDay.toStringAsFixed(0)}',
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                        const TextSpan(
                                                          text: '/day',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors
                                                                .textSecondary,
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
                                                  if (await _checkRentalVerification()) {
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
                      Tab(text: 'Pending'),
                      Tab(text: 'Approved'),
                      Tab(text: 'Completed'),
                      Tab(text: 'Declined'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBookingsList(
                        uiBookings
                            .where((b) => b['statusGroup'] == 'Pending')
                            .toList(),
                      ),
                      _buildBookingsList(
                        uiBookings
                            .where((b) => b['statusGroup'] == 'Approved')
                            .toList(),
                      ),
                      _buildBookingsList(
                        uiBookings
                            .where((b) => b['statusGroup'] == 'Completed')
                            .toList(),
                      ),
                      _buildBookingsList(
                        uiBookings
                            .where((b) => b['statusGroup'] == 'Declined')
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
      return RefreshIndicator(
        onRefresh: () async {
          await _loadBookings();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No bookings found',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
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
        await _loadBookings();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  days: (bookings[index]['days'] as num?)?.toInt() ?? 0,
                  pickupLocation: bookings[index]['pickupLocation'],
                  dropoffLocation: bookings[index]['dropoffLocation'],
                  totalCost:
                      (bookings[index]['totalCost'] as num?)?.toInt() ?? 0,
                  rating:
                      (bookings[index]['rating'] as num?)?.toDouble() ?? 0.0,
                  isActive: bookings[index]['statusGroup'] == 'Approved',
                  carImageUrl: bookings[index]['imageUrl'] as String?,
                  onTap: () => _showBookingDetails(bookings[index]),
                ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Empty State
          if (notificationItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_none,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Notifications Yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You\'ll receive notifications about bookings, messages, and updates here',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            // Notifications List
            Column(
              children: List.generate(
                notificationItems.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: notificationItems[index]['iconColor']
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            notificationItems[index]['icon'],
                            color: notificationItems[index]['iconColor'],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Messages Tab
  // ---------------------------------------------------------------------------
  Widget _buildMessagesTab() {
    final conversations = _uiConversations();

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (conversations.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    conversations
                        .fold<int>(
                          0,
                          (sum, c) => sum + (c['unreadCount'] as int? ?? 0),
                        )
                        .toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Empty State
          if (conversations.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Conversations Yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start by booking a car or get in touch with owners',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.darkBgSecondary,
                        borderRadius: BorderRadius.circular(12),
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
                            child: const Icon(
                              Icons.person_outline,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
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
                      image:
                          booking['vehicles'] != null &&
                              booking['vehicles']['image_url'] != null
                          ? DecorationImage(
                              image: NetworkImage(
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
            if (booking['statusGroup'] == 'Approved')
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
                ],
              ),
            if ((booking['statusGroup'] == 'Pending') &&
                _canCancelBooking(booking))
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
                  child: const Text('Cancel Booking'),
                ),
              ),
            if ((booking['statusGroup'] == 'Pending'))
              Builder(
                builder: (context) {
                  final timeInfo = _getRemainingCancelTime(booking);
                  final canCancel = timeInfo['canCancel'] as bool;
                  final hours = timeInfo['hours'] as int;
                  final minutes = timeInfo['minutes'] as int;

                  if (canCancel) {
                    return Container(
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
                                '${hours}h ${minutes}m',
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
                              value: (hours * 60 + minutes) / (24 * 60),
                              minHeight: 6,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFFC107),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                            'Bookings can only be cancelled within 24 hours of creation.',
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

  bool _canCancelBooking(Map<String, dynamic> booking) {
    final timeInfo = _getRemainingCancelTime(booking);
    return timeInfo['canCancel'] as bool;
  }

  Future<void> _handleBookingCancellation(Map<String, dynamic> booking) async {
    final bookingService = BookingService();
    final canCancel = _canCancelBooking(booking);

    if (!canCancel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Cancellation window has passed (24 hours limit)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: const Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Booking'),
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
                await bookingService.updateBookingStatus(
                  booking['id'],
                  'cancelled',
                );

                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Booking cancelled successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  _loadBookings();
                }
              } catch (e) {
                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error cancelling booking: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Cancel Booking',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon) {
    return Icon(icon, size: 14, color: AppColors.textTertiary);
  }
}
