import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
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
import '../../../services/payout_method_service.dart';
import '../../widgets/optimized_network_image.dart';
import '../../widgets/dialog_status_indicator.dart';
import '../../widgets/relative_time_text.dart';
import '../../widgets/booking_return_countdown.dart';
import '../../widgets/vehicle_inspection_checklist_fields.dart';
import '../../widgets/vehicle_inspection_record_view.dart';
import '../../widgets/partner_vehicle_maintenance_modal.dart';
import '../../widgets/trip_route_history_dialog.dart';
import '../../widgets/trip_location_map_dialog.dart';
import '../profile/ratings_reviews_screen.dart';
import '../profile/trip_rating_flow_screen.dart';
import '../profile/settings_screen.dart';
import '../../../utils/booking_status.dart';
import '../../../utils/notification_target.dart';
import '../../../utils/notification_visual.dart';
import '../profile/unified_profile_screen.dart';
import 'partner_tracking_screen.dart';
import 'partner_revenue_screen.dart';
import 'partner_safety_review_screen.dart';
import '../../widgets/leaflet_map.dart';
import '../../../utils/philippine_geocoding.dart';
import '../../../utils/currency_formatter.dart';

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
  int selectedBookingTab = -1; // -1: All, 0: Pending, 1: Approved, 2: Ongoing, 3: Completed, 4: Cancelled, 5: Extensions
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
  String? _focusedTrackingBookingId;
  String _partnerTrackingFilter = 'all'; // 'all', 'active', 'idle'
  final TextEditingController _partnerTrackingSearchController =
      TextEditingController();
  RealtimeChannel? _partnerTrackingChannel;
  Timer? _partnerTrackingPeriodicTimer;

  String _partnerBookingStatus = 'pending';
  String _partnerBookingSubSection = 'bookings'; // 'bookings' or 'extensions'
  String _partnerExtensionFilter = 'all';
  String _partnerExtensionSearchQuery = '';
  final TextEditingController _partnerExtensionSearchController =
      TextEditingController();

  int get _partnerPendingExtensionRequestsCount {
    return bookings.where((b) {
      final ext = b['extension_status']?.toString().toLowerCase().trim();
      return ext == 'pending' ||
          ext == 'pending_partner' ||
          ext == 'payment_completed' ||
          ext == 'pending_final_confirmation';
    }).length;
  }

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

  int get _partnerPendingBookingsCount {
    final pendingListCount = bookings.where((b) {
      if (_matchesBookingTab(b, 'pending')) return true;
      final ext = b['extension_status']?.toString().toLowerCase().trim();
      if (ext == 'pending' ||
          ext == 'pending_partner' ||
          ext == 'payment_completed' ||
          ext == 'pending_final_confirmation') {
        return true;
      }
      return false;
    }).length;

    final fallbackCount = bookingCounts['pending'] ?? 0;
    return pendingListCount > 0 ? pendingListCount : fallbackCount;
  }

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

  bool _isFetchingPartnerData = false;
  bool _pendingPartnerDataRefresh = false; // queued refresh if one was skipped while busy

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
    // Gentle 60s backup sync; live updates are pushed immediately via Supabase Realtime
    _notificationsAutoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (mounted) _loadPartnerData(silent: true);
      },
    );
    // 15s live tracking GPS refresh timer
    _partnerTrackingPeriodicTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (mounted && selectedNavIndex == 2) {
          _refreshPartnerTracking(silent: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _pushNotificationTapSubscription?.cancel();
    _bookingsSubscription?.unsubscribe();
    _notificationsSubscription?.unsubscribe();
    _notificationsAutoRefreshTimer?.cancel();
    _partnerTrackingPeriodicTimer?.cancel();
    _partnerTrackingChannel?.unsubscribe();
    _partnerTrackingSearchController.dispose();
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

  Future<void> _loadPartnerData({bool silent = false}) async {
    if (_isFetchingPartnerData) {
      // A fetch is already running; queue a follow-up so the next refresh
      // picks up any bookings/changes that were created in the meantime.
      _pendingPartnerDataRefresh = true;
      return;
    }
    _isFetchingPartnerData = true;
    _pendingPartnerDataRefresh = false;

    try {
      final authService = AuthService();
      final partnerService = PartnerService();
      final user = authService.currentUser;

      if (user != null) {
        // Partner-centric records use users.id as partner_id/owner_id.
        partnerId = user.id;

        // Fetch independent data sets concurrently
        final results = await Future.wait([
          partnerService.getPartnerProfile(user.id).catchError((_) => null),
          partnerService.getApplicationCounts(partnerId!),
          partnerService.getVehicleApplications(partnerId!),
          BookingService().getPartnerBookings(partnerId!),
          ChatService().getConversations(user.id),
          NotificationService().getNotifications(user.id, limit: 30),
          TrackingService().getPartnerActiveTrackingLocations(partnerId!),
          TripRatingService().getRatingSummary(user.id),
          _loadPartnerAvatarUrl(user),
          _restrictionService.getUserRestriction(user.id),
        ]);

        final profile = results[0] as Map<String, dynamic>?;
        final appCounts = results[1] as Map<String, int>;
        final apps = results[2] as List<Map<String, dynamic>>;
        final bList = results[3] as List<Map<String, dynamic>>;
        final convs = results[4] as List<Map<String, dynamic>>;
        final notifs = results[5] as List<Map<String, dynamic>>;
        final liveTracking = results[6] as List<Map<String, dynamic>>;
        final ratingSummary = results[7] as Map<String, dynamic>;
        final avatarUrl = results[8] as String?;
        final restrictionState = results[9] as UserRestrictionState;

        // Compute booking counts from already-loaded bList without extra query
        final bCounts = await BookingService().getPartnerBookingCounts(
          partnerId!,
          existingBookings: bList,
        );

        if (_bookingsSubscription == null) {
          _setupBookingsListener(user.id);
        }

        if (_notificationsSubscription == null) {
          _setupNotificationsListener(user.id);
        }

        if (_partnerTrackingChannel == null) {
          _setupPartnerTrackingListener(user.id);
        }

        if (mounted) {
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
            ChatService.sortConversationsByPriority(convs);
            conversations = convs;
            notifications = notifs;
            trackingLocations = liveTracking;
            activeVehicles = appCounts['approved'] ?? 0;
            rating = (ratingSummary['average'] as num?)?.toDouble() ?? 0.0;
            ratingCount = (ratingSummary['count'] as num?)?.toInt() ?? 0;
            _restrictionState = restrictionState;
            isLoading = false;
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowRestrictionNotification();
        });
      }
    } catch (e) {
      debugPrint('Error loading partner data: $e');
    } finally {
      _isFetchingPartnerData = false;
      // If a realtime event was received while we were fetching, re-run now
      // so we don't miss any booking that was created during the last fetch.
      if (_pendingPartnerDataRefresh && mounted) {
        _pendingPartnerDataRefresh = false;
        _loadPartnerData(silent: true);
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

  /// 🔔 Set up real-time listener for new bookings and partner fleet events
  void _setupBookingsListener([String? currentPartnerId]) {
    try {
      final targetId = currentPartnerId ?? partnerId ?? AuthService().currentUser?.id;
      if (targetId == null) {
        debugPrint('⚠️ No partner ID for bookings listener');
        return;
      }

      _bookingsSubscription?.unsubscribe();

      final supabase = Supabase.instance.client;

      _bookingsSubscription = supabase.realtime.channel('partner_fleet_events_$targetId');

      _bookingsSubscription!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bookings',
            callback: (payload) {
              debugPrint('🔔 Realtime booking event received: ${payload.eventType}');
              if (mounted) {
                _loadPartnerData(silent: true);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'driver_job_assignments',
            callback: (_) {
              if (mounted) _loadPartnerData(silent: true);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'vehicles',
            callback: (_) {
              if (mounted) _loadPartnerData(silent: true);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'partner_vehicles',
            callback: (_) {
              if (mounted) _loadPartnerData(silent: true);
            },
          )
          .subscribe();

      debugPrint('✅ Real-time bookings listener active for partner $targetId');
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
              _loadPartnerData(silent: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ Error setting up notifications listener: $e');
    }
  }

  void _setupPartnerTrackingListener(String targetPartnerId) {
    try {
      _partnerTrackingChannel?.unsubscribe();
      final supabase = Supabase.instance.client;
      _partnerTrackingChannel = supabase.realtime.channel('partner_live_tracking_fleet_$targetPartnerId');
      _partnerTrackingChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tracking_locations',
            callback: (_) {
              if (mounted) _refreshPartnerTracking(silent: true);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'vehicle_trackers',
            callback: (_) {
              if (mounted) _refreshPartnerTracking(silent: true);
            },
          )
          .subscribe();
      debugPrint('✅ Real-time partner live tracking listener active for $targetPartnerId');
    } catch (e) {
      debugPrint('⚠️ Error setting up partner tracking listener: $e');
    }
  }

  Future<void> _refreshPartnerTracking({bool silent = true}) async {
    final pid = partnerId ?? AuthService().currentUser?.id;
    if (pid == null || pid.isEmpty) return;
    try {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Syncing live GPS telemetry...'),
              ],
            ),
            duration: Duration(seconds: 1),
          ),
        );
      }
      final liveLocations = await TrackingService().getPartnerActiveTrackingLocations(pid);
      if (mounted) {
        setState(() {
          trackingLocations = liveLocations;
        });
        if (!silent) {
          _showSuccessSnackBar(
            liveLocations.isNotEmpty
                ? 'GPS updated: ${liveLocations.length} vehicle(s) tracked'
                : 'GPS refreshed. Awaiting live signal from tracker.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error refreshing partner live tracking: $e');
      if (!silent && mounted) {
        _showErrorSnackBar('Failed to refresh GPS telemetry');
      }
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBg
            : AppColors.lightBg,
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
            1: _partnerPendingBookingsCount,
            2: _partnerUnreadMessageCount,
            3: _partnerUnreadNotificationCount,
          },
          customItems: [
            BottomNavigationBarItem(
              icon: RoleBottomNavigationIcon(
                icon: Icons.home_rounded,
                count: 0,
                backgroundColor: widget.isDarkMode ? const Color(0xFF07111D) : Colors.white,
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: RoleBottomNavigationIcon(
                icon: Icons.calendar_month_outlined,
                count: _partnerPendingBookingsCount,
                backgroundColor: widget.isDarkMode ? const Color(0xFF07111D) : Colors.white,
              ),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: RoleBottomNavigationIcon(
                icon: Icons.chat_bubble_outline,
                count: _partnerUnreadMessageCount,
                backgroundColor: widget.isDarkMode ? const Color(0xFF07111D) : Colors.white,
              ),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: RoleBottomNavigationIcon(
                icon: Icons.notifications_outlined,
                count: _partnerUnreadNotificationCount,
                backgroundColor: widget.isDarkMode ? const Color(0xFF07111D) : Colors.white,
              ),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              icon: RoleBottomNavigationIcon(
                icon: Icons.person_outline,
                count: 0,
                backgroundColor: widget.isDarkMode ? const Color(0xFF07111D) : Colors.white,
              ),
              label: 'Profile',
            ),
          ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
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
                    icon: Icons.add_circle_outline,
                    label: 'Add Car',
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
                    icon: Icons.radar_rounded,
                    label: 'Live Fleet Tracking',
                    onTap: () {
                      Navigator.pop(context);
                      _openLiveTracking();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.account_balance_wallet,
                    label: 'Revenue & Earnings',
                    onTap: () {
                      Navigator.pop(context);
                      _openRevenuePayoutScreen();
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
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      _openPartnerSettings();
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
                  value: '₱${formatAmount(totalEarnings, decimalDigits: 0)}',
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      _buildQuickAction(
                        icon: Icons.add_circle_outline,
                        label: 'Add Vehicle',
                        width: 86,
                        onTap: _handleApplyVehicleNavigation,
                      ),
                      const SizedBox(width: 10),
                      _buildQuickAction(
                        icon: Icons.radar_rounded,
                        label: 'Live Tracking',
                        width: 86,
                        onTap: _openLiveTracking,
                      ),
                      const SizedBox(width: 10),
                      _buildQuickAction(
                        icon: Icons.directions_car,
                        label: 'Manage Fleet',
                        width: 86,
                        onTap: () =>
                            Navigator.pushNamed(context, '/vehicle-availability'),
                      ),
                      const SizedBox(width: 10),
                      _buildQuickAction(
                        icon: Icons.bar_chart,
                        label: 'View Revenue',
                        width: 86,
                        onTap: _openRevenuePayoutScreen,
                      ),
                      const SizedBox(width: 10),
                      _buildQuickAction(
                        icon: Icons.star_rate,
                        label: 'Rates & Reviews',
                        width: 86,
                        onTap: _showRatesReviewsDialog,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Partner value proposition
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildWhyPartnerWithPsdcSection(),
          ),
          const SizedBox(height: 24),

          // Live Tracking shortcut
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildLiveTrackingSection(),
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
        MediaQuery.of(context).padding.top + 8,
        20,
        12,
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
                  'Mobilis Certified Partner',
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
    final isPending =
        verificationStatus == 'pending' || verificationStatus == 'submitted';

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
                child: Icon(
                  isPending ? Icons.hourglass_top : Icons.pending,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPending
                          ? 'Verification Under Review'
                          : 'Complete Verification',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                    Text(
                      isPending
                          ? 'Your verification documents have been submitted and are under review.'
                          : 'Unlock full features and build trust with renters',
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    isPending
                        ? '/account-verification'
                        : '/owner-verification',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    isPending ? 'Check Status' : 'Verify Now',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    return Expanded(
      child: Container(
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
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: tertiaryText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: subtextColor ?? (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
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
    double? width,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;

    final card = GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: 86,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.2),
            boxShadow: isDark ? null : AppColors.cardShadowOf(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isDark ? AppColors.primary : AppColors.primaryDark, size: 24),
              const SizedBox(height: 10),
              SizedBox(
                height: 14,
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (width != null) {
      return card;
    }
    return Expanded(child: card);
  }

  Widget _buildWhyPartnerWithPsdcSection() {
    const benefits = [
      (
        icon: Icons.verified_user_outlined,
        title: 'Trusted Platform',
        description: 'Connect with renters through a trusted rental platform.',
      ),
      (
        icon: Icons.trending_up_rounded,
        title: 'More Income',
        description: 'Unlock more booking opportunities for your vehicles.',
      ),
      (
        icon: Icons.visibility_outlined,
        title: 'More Visibility',
        description: 'Help more potential renters discover your fleet.',
      ),
      (
        icon: Icons.event_available_outlined,
        title: 'Easy Management',
        description: 'Manage bookings and availability in one place.',
      ),
      (
        icon: Icons.lock_outline_rounded,
        title: 'Secure Transactions',
        description: 'Keep rental activity organized and easy to follow.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102E45), Color(0xFF17374F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.handshake_outlined,
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
                      'Why Partner with PSDC?',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Grow your fleet with tools built for confident, organized rentals.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            itemCount: benefits.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 88,
            ),
            itemBuilder: (context, index) {
              final benefit = benefits[index];
              return Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(benefit.icon, color: AppColors.primary, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            benefit.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            benefit.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingSection() {
    final activeBookings = bookings
        .where(
          (booking) =>
              bookingStatusGroup(booking['status']) ==
              BookingStatusGroup.ongoing,
        )
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF102A3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF24516D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_searching_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Tracking',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Monitor vehicles on an active trip',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: activeBookings.isEmpty
                      ? AppColors.darkBgSecondary
                      : AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${activeBookings.length} active',
                  style: TextStyle(
                    color: activeBookings.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (activeBookings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.darkBg.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No active trips right now. Live vehicle updates will appear here.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...activeBookings.take(3).map(_buildLiveTrackingBookingTile),
          if (activeBookings.length > 3) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _openLiveTracking(),
                child: const Text('View all active trips'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveTrackingBookingTile(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['users'] as Map<String, dynamic>?;
    final tracking = _trackingForBooking(booking);
    final vehicleName =
        [vehicle?['vehicle_name'], vehicle?['brand'], vehicle?['model']]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .join(' ');
    final status = _bookingStatusLabel(booking, tracking);
    final renterName = renter?['full_name']?.toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.darkBg.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF24516D)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car_filled_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicleName.isEmpty ? 'Active vehicle' : vehicleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${renterName?.isNotEmpty == true ? renterName : 'Renter'} • $status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _bookingStatusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _openLiveTracking(
              focusBookingId: booking['id']?.toString(),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Track',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
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

  void _openPartnerSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (settingsContext) => SettingsScreen(
          isDarkMode: widget.isDarkMode,
          onThemeToggle: widget.onThemeToggle,
          onBack: () => Navigator.of(settingsContext).pop(),
          onOpenSupport: _openCustomerServiceConversation,
          onProfileUpdated: _loadPartnerData,
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
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildBookingTabButton('All', -1, badgeCount: _countBookingsForTab(-1)),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Pending', 0, badgeCount: _countBookingsForTab(0)),
                    const SizedBox(width: 8),
                    _buildBookingTabButton(
                      'Extensions',
                      5,
                      badgeCount: _countBookingsForTab(5),
                    ),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Ongoing', 2, badgeCount: _countBookingsForTab(2)),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Approved', 1, badgeCount: _countBookingsForTab(1)),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Completed', 3, badgeCount: _countBookingsForTab(3)),
                    const SizedBox(width: 8),
                    _buildBookingTabButton('Cancelled', 4, badgeCount: _countBookingsForTab(4)),
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

  int _countBookingsForTab(int tabIndex) {
    if (tabIndex == -1) return bookings.length;
    if (tabIndex == 5) return _partnerPendingExtensionRequestsCount;
    final tabKey = switch (tabIndex) {
      0 => 'pending',
      1 => 'approved',
      2 => 'ongoing',
      3 => 'completed',
      _ => 'cancelled',
    };
    final fallbackStatuses = switch (tabIndex) {
      0 => {'pending'},
      1 => {'approved', 'confirmed'},
      2 => {'ongoing', 'active', 'in_progress', 'in transit', 'in_transit'},
      3 => {'completed', 'successful', 'done', 'finished'},
      _ => {'cancelled', 'canceled', 'declined', 'rejected'},
    };
    return bookings.where((b) {
      if (_matchesBookingTab(b, tabKey)) return true;
      final s = (b['status'] ?? '').toString().toLowerCase().trim();
      return fallbackStatuses.contains(s);
    }).length;
  }

  Widget _buildBookingTabButton(String label, int index, {int badgeCount = 0}) {
    final isSelected = selectedBookingTab == index;
    return SizedBox(
      width: label.length > 8 ? 104 : (label.length > 6 ? 94 : (label.length <= 3 ? 68 : 84)),
      child: GestureDetector(
        onTap: () => setState(() => selectedBookingTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.darkBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.black : AppColors.textSecondary,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingRequestCard(Map<String, dynamic> booking) {
    final vehicle = (booking['vehicles'] ??
            booking['partner_vehicles'] ??
            booking['partner_vehicle'] ??
            booking['vehicle']) as Map<String, dynamic>?;
    final renter = (booking['users'] ?? booking['renter']) as Map<String, dynamic>?;
    final status = (booking['status'] ?? 'pending').toString().toLowerCase();
    final statusColor = _dashboardBookingStatusColor(status);
    final statusLabel = _dashboardBookingStatusLabel(status);
    final brand = vehicle?['brand']?.toString().trim() ?? '';
    final model = vehicle?['model']?.toString().trim() ?? '';
    final rawName = vehicle?['vehicle_name']?.toString().trim() ?? '';
    final combo = [brand, model].where((part) => part.isNotEmpty).join(' ');
    final vehicleTitle = rawName.isNotEmpty && rawName.toLowerCase() != 'partner vehicle'
        ? rawName
        : (combo.isNotEmpty ? combo : (rawName.isNotEmpty ? rawName : 'Vehicle Request'));
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
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? OptimizedNetworkImage(
                        imageUrl: imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: Image.asset(
                          'assets/icon/logo1.png',
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.asset(
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
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPaymentStateBadge(booking),
            ],
          ),
          if (resolveBookingPaymentState(booking) == BookingPaymentState.paymentReview) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showVerifyPaymentProofDialog(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.verified_user_rounded, size: 16),
                label: const Text('Verify Renter Payment Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showPartnerDeclineDialog(booking),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
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
                    child: Text(
                      resolveBookingPaymentState(booking) == BookingPaymentState.pendingConfirmation
                          ? 'Confirm & Accept'
                          : 'Accept',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'cancelled' || status == 'rejected') ...[
            Builder(
              builder: (_) {
                final payState = resolveBookingPaymentState(booking);
                final refundNeeded = payState == BookingPaymentState.refundRequired ||
                    booking['refund_status'] == 'refund_needed' ||
                    booking['refund_status'] == 'refund_required' ||
                    booking['refund_required'] == true;
                final refundComplete = payState == BookingPaymentState.refunded ||
                    booking['refund_status'] == 'refunded' ||
                    booking['refund_completed'] == true;

                if (refundNeeded && !refundComplete) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPartnerBookingRefundDialog(booking),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                        label: const Text('Process Booking Refund', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  );
                } else if (refundComplete) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showPartnerBookingRefundDialog(booking),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA855F7),
                          side: const BorderSide(color: Color(0xFFA855F7)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const Text('Refund Completed ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ] else if (status == 'active' ||
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
          if (status == 'active' ||
              status == 'ongoing' ||
              status == 'return_pending_inspection' ||
              status == 'completed' ||
              status == 'returned') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final bId = booking['id']?.toString() ?? '';
                  if (bId.isNotEmpty) {
                    TripRouteHistoryDialog.show(
                      context: context,
                      bookingId: bId,
                      vehicleName: vehicleTitle,
                      plateNumber: vehicle?['plate_number']?.toString(),
                      renterName: renter?['full_name']?.toString(),
                    );
                  }
                },
                icon: const Icon(Icons.route_rounded, size: 16, color: AppColors.primary),
                label: const Text('Audit Traveled Route & GPS Playback'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentRequestShowcaseCard(Map<String, dynamic> booking) {
    final vehicle = (booking['vehicles'] ??
            booking['partner_vehicles'] ??
            booking['partner_vehicle'] ??
            booking['vehicle']) as Map<String, dynamic>?;
    final renter = (booking['users'] ?? booking['renter']) as Map<String, dynamic>?;
    final status = (booking['status'] ?? 'pending').toString().toLowerCase();
    final statusColor = _dashboardBookingStatusColor(status);
    final statusLabel = _dashboardBookingStatusLabel(status);
    final brand = vehicle?['brand']?.toString().trim() ?? '';
    final model = vehicle?['model']?.toString().trim() ?? '';
    final rawName = vehicle?['vehicle_name']?.toString().trim() ?? '';
    final combo = [brand, model].where((part) => part.isNotEmpty).join(' ');
    final vehicleTitle = rawName.isNotEmpty && rawName.toLowerCase() != 'partner vehicle'
        ? rawName
        : (combo.isNotEmpty ? combo : (rawName.isNotEmpty ? rawName : 'Vehicle Request'));
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
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildPaymentStateBadge(booking),
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
          if (booking['extension_status'] != null &&
              booking['extension_status'].toString().isNotEmpty &&
              booking['extension_status'].toString() != 'none') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5A93C).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.update_rounded,
                        color: Color(0xFFE5A93C),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Trip Extension Request',
                          style: TextStyle(
                            color: Color(0xFFE5A93C),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          booking['extension_status'].toString().toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFE5A93C),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+${booking['extension_days'] ?? 1} Extra Days (Fee: PHP ${_formatMoney((booking['extension_additional_price'] as num?)?.toDouble() ?? 0)})',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (booking['extension_requested_end_at'] != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Requested Return: ${_formatDateShort(booking['extension_requested_end_at']?.toString())}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedNavIndex = 1;
                          _partnerBookingSubSection = 'extensions';
                        });
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Review Extension in Bookings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A93C),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (resolveBookingPaymentState(booking) == BookingPaymentState.paymentReview) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showVerifyPaymentProofDialog(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.verified_user_rounded, size: 16),
                label: const Text('Verify Renter Payment Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
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
                    child: Text(
                      resolveBookingPaymentState(booking) == BookingPaymentState.pendingConfirmation
                          ? 'Confirm & Accept'
                          : 'Accept',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showPartnerDeclineDialog(booking),
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
          ] else if (status == 'cancelled' || status == 'rejected') ...[
            Builder(
              builder: (_) {
                final payState = resolveBookingPaymentState(booking);
                final refundNeeded = payState == BookingPaymentState.refundRequired ||
                    booking['refund_status'] == 'refund_needed' ||
                    booking['refund_status'] == 'refund_required' ||
                    booking['refund_required'] == true;
                final refundComplete = payState == BookingPaymentState.refunded ||
                    booking['refund_status'] == 'refunded' ||
                    booking['refund_completed'] == true;

                if (refundNeeded && !refundComplete) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPartnerBookingRefundDialog(booking),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                        label: const Text('Process Booking Refund', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  );
                } else if (refundComplete) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showPartnerBookingRefundDialog(booking),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA855F7),
                          side: const BorderSide(color: Color(0xFFA855F7)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const Text('Refund Completed ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
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
    if (selectedBookingTab == -1) {
      final list = List<Map<String, dynamic>>.from(bookings);
      list.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return list;
    }

    if (selectedBookingTab == 5) {
      final extList = bookings.where((booking) {
        final ext =
            booking['extension_status']?.toString().toLowerCase().trim();
        return ext != null && ext.isNotEmpty && ext != 'none';
      }).toList();
      extList.sort((a, b) {
        final aDate = DateTime.tryParse(
              a['extension_requested_at']?.toString() ??
                  a['created_at']?.toString() ??
                  '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(
              b['extension_requested_at']?.toString() ??
                  b['created_at']?.toString() ??
                  '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return extList;
    }

    final tabKey = switch (selectedBookingTab) {
      0 => 'pending',
      1 => 'approved',
      2 => 'ongoing',
      3 => 'completed',
      _ => 'cancelled',
    };
    final fallbackStatuses = switch (selectedBookingTab) {
      0 => {'pending'},
      1 => {'approved', 'confirmed'},
      2 => {'ongoing', 'active', 'in_progress', 'in transit', 'in_transit'},
      3 => {'completed', 'successful', 'done', 'finished'},
      _ => {'cancelled', 'canceled', 'declined', 'rejected'},
    };

    final filtered = bookings.where((booking) {
      if (_matchesBookingTab(booking, tabKey)) return true;
      final status = (booking['status'] ?? '').toString().toLowerCase().trim();
      return fallbackStatuses.contains(status);
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
      case -1:
        return 'Recent';
      case 0:
        return 'Pending';
      case 1:
        return 'Approved';
      case 2:
        return 'Ongoing';
      case 3:
        return 'Completed';
      case 5:
        return 'Extension';
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

    String normalize(dynamic val) {
      if (val is List && val.isNotEmpty) return normalize(val.first);
      var raw = val?.toString().trim() ?? '';
      if (raw.isEmpty || raw == 'null') return '';
      if (raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('data:')) return raw;
      raw = raw.replaceFirst(RegExp(r'^/+'), '');
      const knownBuckets = [
        'vehicle_images',
        'vehicle-images',
        'partner_documents',
        'vehicle_documents',
        'cars',
        'vehicles',
        'avatars',
        'profiles',
      ];
      try {
        for (final bucket in knownBuckets) {
          if (raw.startsWith('$bucket/')) {
            final path = raw.substring(bucket.length + 1);
            return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
          }
        }
        return Supabase.instance.client.storage.from('vehicle_images').getPublicUrl(raw);
      } catch (_) {
        return raw;
      }
    }

    for (final key in const [
      'primary_image_url',
      'image_url',
      'imageUrl',
      'photo_url',
      'vehicle_photo_url',
      'vehicle_image_url',
      'thumbnail_url',
    ]) {
      final value = vehicle[key];
      final norm = normalize(value);
      if (norm.isNotEmpty) {
        return norm;
      }
    }

    final rawImages = vehicle['vehicle_images'] ?? vehicle['images'] ?? vehicle['photos'];
    if (rawImages is List) {
      for (final image in rawImages) {
        if (image is Map<String, dynamic>) {
          for (final key in const ['image_url', 'url', 'image', 'photo_url']) {
            final norm = normalize(image[key]);
            if (norm.isNotEmpty) return norm;
          }
        } else {
          final norm = normalize(image);
          if (norm.isNotEmpty) return norm;
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
      return formatAmount(value, decimalDigits: 0);
    }
    return formatAmount(value, decimalDigits: 2);
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

  Future<void> _handleBookingAction(String bookingId, String status, {String? reason}) async {
    final currentPartnerId = partnerId ?? AuthService().currentUser?.id;
    final bookingIndex =
        bookings.indexWhere((b) => b['id']?.toString() == bookingId);
    final originalBooking = bookingIndex != -1
        ? Map<String, dynamic>.from(bookings[bookingIndex])
        : null;

    if (status == 'return_confirmed' && currentPartnerId != null) {
      final booking = originalBooking ?? <String, dynamic>{'id': bookingId};
      await _showPartnerInspectionDialog(booking, inspectionType: 'after');
      _loadPartnerData(silent: true);
      return;
    }

    final effectiveReason = reason ?? 'Declined by vehicle owner';

    // ⚡ Optimistic UI update: instantly update local list and counts
    if (bookingIndex != -1) {
      setState(() {
        final target = Map<String, dynamic>.from(bookings[bookingIndex]);
        if (status == 'confirmed') {
          target['status'] = 'confirmed';
          target['partner_booking_confirmed_at'] =
              DateTime.now().toIso8601String();
          target['partner_booking_confirmed_by'] = currentPartnerId;
        } else if (status == 'cancelled' || status == 'rejected') {
          target['status'] = 'rejected';
          target['partner_booking_rejected_at'] =
              DateTime.now().toIso8601String();
          target['rejection_reason'] = effectiveReason;
        } else {
          target['status'] = status;
        }
        bookings[bookingIndex] = target;

        if (status == 'cancelled' || status == 'rejected') {
          bookingCounts['pending'] =
              ((bookingCounts['pending'] ?? 1) - 1).clamp(0, 999999);
          bookingCounts['cancelled'] =
              (bookingCounts['cancelled'] ?? 0) + 1;
        } else if (status == 'confirmed') {
          bookingCounts['pending'] =
              ((bookingCounts['pending'] ?? 1) - 1).clamp(0, 999999);
          bookingCounts['active'] =
              (bookingCounts['active'] ?? 0) + 1;
        }
      });
    }

    _showSuccessSnackBar(
      status == 'confirmed'
          ? 'Booking confirmed!'
          : status == 'return_confirmed'
          ? 'Vehicle return confirmed!'
          : 'Booking declined',
    );

    try {
      final bookingService = BookingService();

      if (status == 'confirmed' && currentPartnerId != null) {
        await bookingService.confirmPartnerBooking(
          bookingId: bookingId,
          partnerId: currentPartnerId,
          cachedBooking: originalBooking,
        );
      } else if ((status == 'cancelled' || status == 'rejected') &&
          currentPartnerId != null) {
        await bookingService.rejectPartnerBooking(
          bookingId: bookingId,
          partnerId: currentPartnerId,
          reason: effectiveReason,
          cachedBooking: originalBooking,
        );
      } else {
        await bookingService.updateBookingStatus(
          bookingId,
          status,
        );
      }

      // Silent sync in the background so local changes aren't interrupted
      _loadPartnerData(silent: true);
    } catch (e) {
      debugPrint('Partner booking action error: $e');
      if (originalBooking != null && bookingIndex != -1 && mounted) {
        setState(() {
          bookings[bookingIndex] = originalBooking;
          if (status == 'cancelled' || status == 'rejected') {
            bookingCounts['pending'] =
                (bookingCounts['pending'] ?? 0) + 1;
            bookingCounts['cancelled'] =
                ((bookingCounts['cancelled'] ?? 1) - 1).clamp(0, 999999);
          } else if (status == 'confirmed') {
            bookingCounts['pending'] =
                (bookingCounts['pending'] ?? 0) + 1;
            bookingCounts['active'] =
                ((bookingCounts['active'] ?? 1) - 1).clamp(0, 999999);
          }
        });
      }
      _showErrorSnackBar('Failed to update booking: $e');
    }
  }

  Widget _buildPaymentStateBadge(Map<String, dynamic> booking) {
    final state = resolveBookingPaymentState(booking);
    final color = bookingPaymentStateColor(state);
    final label = bookingPaymentStateLabel(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVerifyPaymentProofDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renter = booking['users'] as Map<String, dynamic>? ?? booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renterName = renter['full_name']?.toString() ?? 'Renter';
    final vehicleTitle = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
    final proofUrl = (booking['reservation_payment_proof_url'] ??
            booking['final_payment_proof_url'] ??
            booking['payment_proof_url'] ??
            booking['payment_receipt_url'] ??
            booking['proof_url'])
        ?.toString()
        .trim();
    final reference = (booking['reservation_payment_reference'] ??
            booking['final_payment_reference'] ??
            booking['payment_reference'])
        ?.toString()
        .trim();
    final totalAmount = (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_amount'] as num?)?.toDouble() ??
        0.0;
    final notesController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Color(0xFF38BDF8),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verify Renter Payment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$renterName • $vehicleTitle',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Booking Amount', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : Colors.grey.shade600)),
                                      const SizedBox(height: 4),
                                      Text('PHP ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Reference No.', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : Colors.grey.shade600)),
                                      const SizedBox(height: 4),
                                      Text(
                                        reference != null && reference.isNotEmpty ? reference : 'N/A',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Receipt Preview
                          const Text('Uploaded Receipt / Proof', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          if (proofUrl != null && proofUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.network(
                                  proofUrl,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 120,
                                    alignment: Alignment.center,
                                    child: const Text('Failed to load image preview'),
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.4)),
                              ),
                              child: const Center(
                                child: Text('No receipt image attached. Reference provided above.', style: TextStyle(fontSize: 11, color: Colors.amber)),
                              ),
                            ),
                          const SizedBox(height: 14),

                          // Notes
                          const Text('Verification Notes (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'e.g., GCash payment confirmed',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setDialogState(() => isSubmitting = true);
                                    try {
                                      await BookingService().verifyRenterReservationPayment(
                                        bookingId,
                                        notes: notesController.text.trim(),
                                      );
                                      booking['reservation_payment_status'] = 'verified';
                                      booking['payment_verified'] = true;
                                      final idx = bookings.indexWhere((b) => b['id']?.toString() == bookingId);
                                      if (idx != -1) {
                                        bookings[idx]['reservation_payment_status'] = 'verified';
                                        bookings[idx]['payment_verified'] = true;
                                      }
                                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                                      _loadPartnerData(silent: true);
                                      _showSuccessSnackBar('✅ Payment verified! Booking is ready for acceptance.');
                                    } catch (e) {
                                      setDialogState(() => isSubmitting = false);
                                      _showErrorSnackBar('Failed to verify payment: $e');
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: Text(
                              isSubmitting ? 'Verifying...' : 'Verify & Accept Payment',
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
        },
      ),
    );
    notesController.dispose();
  }

  Future<void> _showPartnerDeclineDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payState = resolveBookingPaymentState(booking);
    final hasPaidFunds = payState == BookingPaymentState.paid ||
        payState == BookingPaymentState.pendingConfirmation ||
        payState == BookingPaymentState.paymentReview;

    final reasonController = TextEditingController();
    const reasons = [
      'Vehicle unavailable for the selected dates',
      'Scheduled maintenance / repair',
      'Distance / Location issue',
      'Safety policy violation',
      'Other',
    ];
    String selectedReason = reasons.first;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Decline Booking Request',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasPaidFunds) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Payment Alert: The renter has submitted or completed payment. Declining will initiate a refund requirement for reimbursement.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Text('Reason for decline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          ...reasons.map((reason) {
                            final selected = selectedReason == reason;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => setDialogState(() => selectedReason = reason),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected ? AppColors.primary : (isDark ? Colors.white12 : Colors.grey.shade300),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                        size: 18,
                                        color: selected ? AppColors.primary : Colors.grey,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          reason,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (selectedReason == 'Other') ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: reasonController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Please specify the reason...',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final finalReason = selectedReason == 'Other' && reasonController.text.trim().isNotEmpty
                                  ? reasonController.text.trim()
                                  : selectedReason;
                              Navigator.pop(dialogContext);
                              _handleBookingAction(bookingId, 'cancelled', reason: finalReason);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Decline Booking', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
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
    );
    reasonController.dispose();
  }

  Future<void> _showPartnerBookingRefundDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renter = booking['users'] as Map<String, dynamic>? ?? booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renterName = renter['full_name']?.toString() ?? 'Renter';
    final renterPhone = renter['phone_number']?.toString() ?? renter['phone']?.toString() ?? '';
    final vehicleTitle = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();

    final renterUserId = (booking['renter_id'] ?? renter['id'] ?? renter['user_id'])?.toString();
    List<PayoutMethod> renterPayoutMethods = [];
    String? discoveredQrUrl;

    if (renterUserId != null && renterUserId.isNotEmpty) {
      try {
        renterPayoutMethods = await PayoutMethodService().getPayoutMethods(renterUserId);
      } catch (_) {}
      try {
        discoveredQrUrl = await PayoutMethodService().getRenterQrCodeUrl(renterUserId);
      } catch (_) {}
    }

    final directQrUrl = (discoveredQrUrl != null && discoveredQrUrl.isNotEmpty)
        ? discoveredQrUrl
        : (renter['qr_code_url']?.toString() ?? renter['gcash_qr_url']?.toString() ?? renter['payout_qr_url']?.toString());

    final isAlreadyRefunded = booking['refund_status'] == 'refunded' || booking['refund_completed'] == true;
    final defaultRefundAmount = resolveBookingRefundAmount(booking);

    final refundAmountController = TextEditingController(text: defaultRefundAmount.toStringAsFixed(2));
    final referenceController = TextEditingController(text: booking['refund_ref']?.toString() ?? '');
    final notesController = TextEditingController(text: booking['refund_notes']?.toString() ?? '');
    String selectedMethod = booking['refund_method']?.toString() ?? (renterPayoutMethods.isNotEmpty ? renterPayoutMethods.first.provider : 'GCash');
    PlatformFile? receiptFile;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final refundAmount = double.tryParse(refundAmountController.text) ?? defaultRefundAmount;

          final activeMethod = renterPayoutMethods.firstWhere(
            (m) => m.provider.toLowerCase() == selectedMethod.toLowerCase(),
            orElse: () => renterPayoutMethods.isNotEmpty
                ? renterPayoutMethods.first
                : PayoutMethod(
                    id: '',
                    provider: selectedMethod,
                    accountName: renterName,
                    accountNumber: renterPhone,
                    qrCodeUrl: directQrUrl,
                    createdAt: DateTime.now(),
                  ),
          );

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isAlreadyRefunded
                                ? const Color(0xFFA855F7).withOpacity(0.15)
                                : const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isAlreadyRefunded ? Icons.check_circle_rounded : Icons.currency_exchange_rounded,
                            color: isAlreadyRefunded ? const Color(0xFFA855F7) : const Color(0xFFEF4444),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAlreadyRefunded ? 'Refund Details' : 'Process Booking Refund',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$renterName • $vehicleTitle',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isAlreadyRefunded
                                  ? const Color(0xFFA855F7).withOpacity(0.12)
                                  : const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAlreadyRefunded
                                    ? const Color(0xFFA855F7).withOpacity(0.35)
                                    : const Color(0xFFEF4444).withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isAlreadyRefunded ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                  color: isAlreadyRefunded ? const Color(0xFFA855F7) : const Color(0xFFEF4444),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isAlreadyRefunded
                                        ? 'Refund completed: PHP ${refundAmount.toStringAsFixed(2)} was disbursed to renter.'
                                        : 'Booking was declined after payment. Please disburse the refund to the renter.',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Payout Method Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF101928) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Renter Payout Destination', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (activeMethod.qrCodeUrl != null && activeMethod.qrCodeUrl!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          activeMethod.qrCodeUrl!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.account_balance_wallet_outlined, size: 24),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activeMethod.accountName.isNotEmpty ? activeMethod.accountName : renterName,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${activeMethod.provider}: ${activeMethod.accountNumber.isNotEmpty ? activeMethod.accountNumber : renterPhone}',
                                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Refund Amount
                          const Text('Refund Amount (PHP)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: refundAmountController,
                            readOnly: isAlreadyRefunded,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: 'PHP ',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Method & Ref
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Payout Method', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: selectedMethod,
                                      isDense: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      items: ['GCash', 'Maya', 'Bank Transfer', 'Cash']
                                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 11))))
                                          .toList(),
                                      onChanged: isAlreadyRefunded ? null : (v) => setDialogState(() => selectedMethod = v ?? 'GCash'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Reference No.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: referenceController,
                                      readOnly: isAlreadyRefunded,
                                      decoration: InputDecoration(
                                        hintText: 'e.g. 1002345892',
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Screenshot upload
                          const Text('Transfer Screenshot / Receipt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          if (isAlreadyRefunded)
                            Builder(
                              builder: (_) {
                                final receipt = booking['refund_receipt_url']?.toString();
                                if (receipt != null && receipt.isNotEmpty) {
                                  return Text('Proof URL: $receipt', style: const TextStyle(fontSize: 11, color: AppColors.primary));
                                }
                                return const Text('No receipt attached.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic));
                              },
                            )
                          else if (receiptFile == null)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
                                  withData: true,
                                );
                                if (result != null && result.files.isNotEmpty) {
                                  setDialogState(() => receiptFile = result.files.first);
                                }
                              },
                              icon: const Icon(Icons.upload_file_rounded, size: 16),
                              label: const Text('Upload Transfer Receipt', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(receiptFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    onPressed: () => setDialogState(() => receiptFile = null),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        if (!isAlreadyRefunded) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final ref = referenceController.text.trim();
                                      if (ref.isEmpty) {
                                        _showErrorSnackBar('Please provide a reference number for the refund transfer.');
                                        return;
                                      }
                                      setDialogState(() => isSubmitting = true);
                                      try {
                                        String uploadedReceiptUrl = '';
                                        if (receiptFile?.bytes != null) {
                                          final currentUserId = AuthService().currentUser?.id ?? '';
                                          uploadedReceiptUrl = await BookingInspectionService().uploadEvidenceBytes(
                                            userId: currentUserId,
                                            bookingId: bookingId,
                                            bytes: receiptFile!.bytes!,
                                            extension: receiptFile!.extension ?? 'jpg',
                                          );
                                        }

                                        await BookingService().settleBookingRefund(
                                          bookingId: bookingId,
                                          amount: refundAmount,
                                          method: selectedMethod,
                                          reference: ref,
                                          receiptUrl: uploadedReceiptUrl,
                                          notes: notesController.text.trim(),
                                        );

                                        booking['refund_status'] = 'refunded';
                                        booking['refund_completed'] = true;
                                        booking['refund_amount'] = refundAmount;
                                        booking['refund_ref'] = ref;
                                        booking['refund_method'] = selectedMethod;
                                        booking['refund_receipt_url'] = uploadedReceiptUrl;

                                        final idx = bookings.indexWhere((b) => b['id']?.toString() == bookingId);
                                        if (idx != -1) {
                                          bookings[idx]['refund_status'] = 'refunded';
                                          bookings[idx]['refund_completed'] = true;
                                          bookings[idx]['refund_amount'] = refundAmount;
                                          bookings[idx]['refund_ref'] = ref;
                                          bookings[idx]['refund_method'] = selectedMethod;
                                          bookings[idx]['refund_receipt_url'] = uploadedReceiptUrl;
                                        }

                                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                                        _loadPartnerData(silent: true);
                                        _showSuccessSnackBar('✅ Refund of PHP ${refundAmount.toStringAsFixed(2)} recorded successfully.');
                                      } catch (e) {
                                        setDialogState(() => isSubmitting = false);
                                        _showErrorSnackBar('Failed to complete refund: $e');
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                              label: Text(
                                isSubmitting ? 'Recording...' : 'Confirm & Complete Refund',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    refundAmountController.dispose();
    referenceController.dispose();
    notesController.dispose();
  }

  // ===================== NOTIFICATIONS TAB =====================
  List<Map<String, dynamic>> _uiPartnerNotifications() {
    return notifications.where((n) => !isMessageNotification(n)).map((n) {
      final visual = notificationVisualFor(n);
      final target = resolveNotificationTarget(n);
      var imageUrl =
          target.data['vehicle_image_url']?.toString().trim() ??
          target.data['image_url']?.toString().trim() ??
          '';
      if (imageUrl.isEmpty && target.bookingId != null) {
        final booking = bookings.firstWhere(
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
        'id': n['id']?.toString(),
        'isRead': n['is_read'] == true,
        'title': n['title']?.toString() ?? 'Notification',
        'message': n['message']?.toString() ?? '',
        'timestamp': _formatTime(n['created_at']?.toString()),
        'icon': visual.icon,
        'iconColor': visual.color,
        'imageUrl': imageUrl,
      };
    }).toList();
  }

  Future<void> _handlePartnerNotificationTap(
    Map<String, dynamic> notificationItem,
  ) async {
    final raw = Map<String, dynamic>.from(
      notificationItem['raw'] as Map? ??
          (notificationItem.containsKey('title')
              ? notificationItem
              : const <String, dynamic>{}),
    );
    final notificationId = raw['id']?.toString();
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        raw['is_read'] != true) {
      await NotificationService().markAsRead(notificationId);
      raw['is_read'] = true;
      final index = notifications.indexWhere(
        (item) => item['id']?.toString() == notificationId,
      );
      if (index >= 0) notifications[index]['is_read'] = true;
      if (mounted) setState(() {});
    }
    if (!mounted) return;

    final target = resolveNotificationTarget(raw);
    final targetType = (raw['type'] ?? '').toString().toLowerCase();

    final bookingId = target.bookingId;
    final booking = bookingId == null
        ? <String, dynamic>{}
        : bookings.firstWhere(
            (item) => item['id']?.toString() == bookingId,
            orElse: () => <String, dynamic>{},
          );

    if (targetType == 'policy_restriction' ||
        raw['data']?['event'] == 'active_trip_safety_freeze' ||
        raw['data']?['event'] == 'owner_active_safety_freeze') {
      if (booking.isNotEmpty) {
        _openPartnerBookingSafetyReview(context, booking);
      } else {
        setState(() => selectedNavIndex = 1);
      }
      return;
    }

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
            'recipientName': raw['title']?.toString() ?? 'Chat',
            'recipientAvatar': '',
            'isDarkMode': true,
            'isAutoGenerated': false,
            'userRole': 'partner',
          },
        ).then((_) => _loadPartnerData(silent: true));
      }
      return;
    }

    if (target.destination == NotificationDestination.tracking) {
      _openLiveTracking(
        focusBookingId: booking.isNotEmpty ? booking['id']?.toString() : null,
      );
      return;
    }

    if (target.destination == NotificationDestination.booking &&
        booking.isNotEmpty) {
      final rawStatus = (booking['status'] ?? '').toString().toLowerCase();
      setState(() {
        selectedNavIndex = 1;
        if (rawStatus == 'active' || rawStatus == 'ongoing') {
          _partnerBookingStatus = 'ongoing';
        } else if (rawStatus == 'pending') {
          _partnerBookingStatus = 'pending';
        } else if (rawStatus == 'approved' || rawStatus == 'confirmed') {
          _partnerBookingStatus = 'approved';
        } else if (rawStatus == 'completed' || rawStatus == 'returned') {
          _partnerBookingStatus = 'completed';
        } else if (rawStatus == 'cancelled' || rawStatus == 'rejected') {
          _partnerBookingStatus = 'cancelled';
        }
      });
      return;
    }

    switch (target.destination) {
      case NotificationDestination.payment:
        _openRevenuePayoutScreen();
        return;
      case NotificationDestination.ratings:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RatingsReviewsScreen(
              userId: partnerId ?? AuthService().currentUser?.id ?? '',
            ),
          ),
        );
        return;
      case NotificationDestination.verification:
        setState(() => selectedNavIndex = 4);
        return;
      case NotificationDestination.application:
      case NotificationDestination.vehicles:
        setState(() => selectedNavIndex = 0);
        return;
      case NotificationDestination.booking:
        setState(() => selectedNavIndex = 1);
        return;
      case NotificationDestination.tracking:
        _openLiveTracking(
          focusBookingId: booking.isNotEmpty ? booking['id']?.toString() : null,
        );
        return;
      case NotificationDestination.messages:
        setState(() => selectedNavIndex = 2);
        return;
      case NotificationDestination.announcement:
      case NotificationDestination.general:
        _showPartnerNotificationDetails(notificationItem);
        return;
    }
  }

  void _showPartnerNotificationDetails(Map<String, dynamic> notificationItem) {
    final raw = Map<String, dynamic>.from(
      notificationItem['raw'] as Map? ??
          (notificationItem.containsKey('title')
              ? notificationItem
              : const <String, dynamic>{}),
    );
    final title = raw['title']?.toString() ?? 'Notification';
    final rawMessage = raw['message']?.toString().trim() ?? '';
    final message = rawMessage.isNotEmpty
        ? rawMessage
        : 'No additional details are available.';
    final timestamp = _formatTime(raw['created_at']?.toString());
    final visual = notificationVisualFor(raw);
    final target = resolveNotificationTarget(raw);
    final hasAction = target.destination != NotificationDestination.general &&
        target.destination != NotificationDestination.announcement;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF2A3548) : Colors.white;
        final primaryText = isDark
            ? AppColors.textPrimary
            : AppColors.lightTextPrimary;
        final secondaryText = isDark
            ? AppColors.textSecondary
            : AppColors.lightTextSecondary;

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.lightBorderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
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
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.24)
                          : Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
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
                      decoration: BoxDecoration(
                        color: visual.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(visual.icon, color: visual.color, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            timestamp,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                if (hasAction) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _handlePartnerNotificationTap(notificationItem);
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text(
                        'View Subject',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : Colors.black87,
                      side: BorderSide(
                        color: isDark ? Colors.white24 : AppColors.lightBorderColor,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationItems = _uiPartnerNotifications();
    final unreadCount = notificationItems.where((n) => n['isRead'] != true).length;

    return Column(
      children: [
        _buildCenteredTabHeader(
          'Notifications',
          trailing: unreadCount > 0
              ? TextButton(
                  onPressed: _markAllNotificationsRead,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadPartnerData(silent: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoleTabHeader(
                    title: 'Notifications',
                    subtitle: 'Fleet updates, booking activity, and reminders',
                    icon: Icons.notifications_outlined,
                    badge: '$unreadCount unread',
                    action: unreadCount > 0
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
                  if (notificationItems.isEmpty)
                    const RoleEmptyStateCard(
                      icon: Icons.notifications_none,
                      title: 'No notifications yet',
                      message:
                          'Fleet updates, booking requests, and reminders will appear here.',
                    )
                  else
                    Column(
                      children: List.generate(
                        notificationItems.length,
                        (index) {
                          final item = notificationItems[index];
                          final isRead = item['isRead'] == true;
                          final icon = item['icon'] as IconData;
                          final iconColor = item['iconColor'] as Color;
                          final imageUrl = item['imageUrl']?.toString().trim();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => _handlePartnerNotificationTap(item),
                              onLongPress: () =>
                                  _showPartnerNotificationDetails(item),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? (isRead
                                          ? const Color(0xFF2A3548)
                                          : const Color(0xFF354156))
                                      : (isRead
                                          ? Colors.white
                                          : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? (isRead
                                            ? AppColors.borderColor
                                            : Colors.white70)
                                        : (isRead
                                            ? AppColors.lightBorderColor
                                            : AppColors.primaryDark),
                                    width: isRead ? 1.0 : 1.5,
                                  ),
                                  boxShadow: isDark
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: iconColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: imageUrl != null && imageUrl.isNotEmpty
                                          ? OptimizedNetworkImage(
                                              imageUrl: imageUrl,
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              borderRadius: BorderRadius.circular(10),
                                              errorWidget: Icon(
                                                icon,
                                                color: iconColor,
                                                size: 24,
                                              ),
                                            )
                                          : Icon(
                                              icon,
                                              color: iconColor,
                                              size: 24,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'] ?? 'Notification',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                              color: isDark
                                                  ? AppColors.textPrimary
                                                  : AppColors.lightTextPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item['message'] ?? '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.textSecondary
                                                  : AppColors.lightTextSecondary,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item['timestamp'] ?? '',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? AppColors.textTertiary
                                                  : AppColors.lightTextTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white : AppColors.primaryDark,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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

  // ===================== LIVE FLEET TRACKING TAB =====================

  List<Map<String, dynamic>> _visiblePartnerTrackingLocations() {
    final query = _partnerTrackingSearchController.text.trim().toLowerCase();
    var list = List<Map<String, dynamic>>.from(trackingLocations);

    // Filter by tab: all, active, idle
    if (_partnerTrackingFilter == 'active') {
      list = list.where((loc) => loc['has_active_booking'] == true).toList();
    } else if (_partnerTrackingFilter == 'idle') {
      list = list.where((loc) => loc['has_active_booking'] != true).toList();
    }

    // Filter by search query
    if (query.isNotEmpty) {
      list = list.where((loc) {
        final vName = _resolvePartnerTrackingVehicleName(loc).toLowerCase();
        final booking = loc['bookings'] as Map<String, dynamic>?;
        final renter = booking?['renter'] as Map<String, dynamic>?;
        final renterName = (renter?['full_name'] ?? '').toString().toLowerCase();
        final driver = (booking?['driver'] ?? booking?['drivers'])?['users'] as Map<String, dynamic>?;
        final driverName = (driver?['full_name'] ?? '').toString().toLowerCase();
        final plate = ((loc['vehicle'] ?? booking?['vehicles'])?['plate_number'] ?? '').toString().toLowerCase();
        return vName.contains(query) ||
            renterName.contains(query) ||
            driverName.contains(query) ||
            plate.contains(query);
      }).toList();
    }

    // If focused on a specific vehicle, put it first
    if (_focusedTrackingBookingId != null && _focusedTrackingBookingId!.isNotEmpty) {
      final focusedIndex = list.indexWhere((loc) {
        final booking = loc['bookings'] as Map<String, dynamic>?;
        final rowId = booking?['id']?.toString() ??
            loc['id']?.toString() ??
            'vehicle_${loc['vehicle_id']}';
        return rowId == _focusedTrackingBookingId;
      });
      if (focusedIndex > 0) {
        final focusedItem = list.removeAt(focusedIndex);
        list.insert(0, focusedItem);
      }
    }

    return list;
  }

  Map<String, dynamic> _getPartnerVehicleMotionInfo(Map<String, dynamic> loc) {
    final speedMps = (loc['speed_mps'] as num?)?.toDouble() ?? 0.0;
    final speedKph = (speedMps * 3.6).round();
    final isTripActive = loc['has_active_booking'] == true;
    final recordedAt = DateTime.tryParse(loc['recorded_at']?.toString() ?? '');
    final isStale = recordedAt == null ||
        DateTime.now().toUtc().difference(recordedAt) > const Duration(minutes: 30);

    final isStandby = loc['is_standby'] == true;
    if (isStandby) {
      return {
        'status': 'standby',
        'label': 'STANDBY • AWAITING GPS FIX',
        'short_label': 'STANDBY',
        'color': const Color(0xFF38BDF8),
        'icon': Icons.satellite_alt_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': true,
        'isStopped': false,
      };
    }

    if (speedKph >= 5) {
      return {
        'status': 'moving',
        'label': 'MOVING • $speedKph KM/H',
        'short_label': '$speedKph KM/H',
        'color': const Color(0xFF00E676),
        'icon': Icons.navigation_rounded,
        'speedKph': speedKph,
        'isMoving': true,
        'isParked': false,
        'isStopped': false,
      };
    } else if (isTripActive) {
      return {
        'status': 'on_trip_stopped',
        'label': 'ON TRIP • IDLING',
        'short_label': 'IDLING',
        'color': const Color(0xFFFFB300),
        'icon': Icons.pause_circle_filled_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': false,
        'isStopped': true,
      };
    } else if (isStale) {
      return {
        'status': 'parked',
        'label': 'PARKED • ENGINE OFF',
        'short_label': 'PARKED (OFF)',
        'color': const Color(0xFF9E9E9E),
        'icon': Icons.power_settings_new_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': true,
        'isStopped': false,
      };
    } else {
      return {
        'status': 'stopped',
        'label': 'AVAILABLE • IDLE',
        'short_label': 'IDLE',
        'color': const Color(0xFF38BDF8),
        'icon': Icons.local_parking_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': false,
        'isStopped': true,
      };
    }
  }

  Widget _buildPartnerMovementStatusChip({
    required Map<String, dynamic> location,
    required bool isDark,
    bool isCompact = false,
  }) {
    final motion = _getPartnerVehicleMotionInfo(location);
    final color = motion['color'] as Color;
    final label =
        isCompact ? motion['short_label'] as String : motion['label'] as String;
    final icon = motion['icon'] as IconData;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 7 : 9,
        vertical: isCompact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isCompact ? 11 : 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _resolvePartnerTrackingVehicleName(Map<String, dynamic> loc) {
    final booking = loc['bookings'] as Map<String, dynamic>?;
    final vehicle = (booking?['vehicles'] ?? loc['vehicle']) as Map<String, dynamic>?;
    final tracker = loc['tracker'] as Map<String, dynamic>?;

    var title = _partnerVehicleTitle(vehicle ?? booking);
    if (title.isEmpty || title == 'Partner Vehicle' || title == 'Vehicle') {
      final vName = vehicle?['vehicle_name']?.toString().trim() ?? '';
      if (vName.isNotEmpty &&
          vName.toLowerCase() != 'partner vehicle' &&
          vName.toLowerCase() != 'vehicle') {
        title = vName;
      } else {
        final b = vehicle?['brand']?.toString().trim() ?? '';
        final m = vehicle?['model']?.toString().trim() ?? '';
        final y = vehicle?['year']?.toString().trim() ?? '';
        final combo = [b, m].where((s) => s.isNotEmpty).join(' ');
        if (combo.isNotEmpty) {
          title = y.isEmpty ? combo : '$combo ($y)';
        }
      }
    }

    final deviceId = tracker?['device_identifier']?.toString().trim() ?? '';
    if (title.isEmpty || title == 'Partner Vehicle' || title == 'Vehicle') {
      if (deviceId.isNotEmpty) {
        title = 'GPS Tracker ($deviceId)';
      } else {
        title = loc['has_active_booking'] == true ? 'Tracked Trip' : 'Partner Vehicle';
      }
    }

    final plate = vehicle?['plate_number']?.toString().trim() ?? '';
    if (plate.isNotEmpty && !title.contains(plate)) {
      return '$title ($plate)';
    }
    return title;
  }

  MobilisMapPoint? _resolvePartnerTrackingPoint(
    dynamic latVal,
    dynamic lngVal,
    String locText,
  ) {
    final lat = latVal is num
        ? latVal.toDouble()
        : double.tryParse(latVal?.toString() ?? '');
    final lng = lngVal is num
        ? lngVal.toDouble()
        : double.tryParse(lngVal?.toString() ?? '');
    if (lat != null && lng != null && PhilippineGeocoding.isValidPhilippines(MobilisMapPoint(latitude: lat, longitude: lng))) {
      return MobilisMapPoint(latitude: lat, longitude: lng);
    }
    final parsed = PhilippineGeocoding.parseCoordinate(latVal, lngVal);
    if (parsed != null && PhilippineGeocoding.isValidPhilippines(parsed)) {
      return parsed;
    }
    return PhilippineGeocoding.resolveLocationSync(locText);
  }

  List<MobilisMapPoint> _getPartnerTrackingRoutePoints(
    MobilisMapPoint start,
    MobilisMapPoint end,
  ) {
    return [
      start,
      MobilisMapPoint(
        latitude: (start.latitude + end.latitude) / 2,
        longitude: (start.longitude + end.longitude) / 2,
      ),
      end,
    ];
  }

  void _openLiveTracking({String? focusBookingId}) {
    if (focusBookingId != null && focusBookingId.isNotEmpty) {
      setState(() {
        _focusedTrackingBookingId = focusBookingId;
      });
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: widget.isDarkMode ? AppColors.darkBg : AppColors.lightBg,
          appBar: AppBar(
            backgroundColor: widget.isDarkMode ? AppColors.darkBgSecondary : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Live Fleet Tracking',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.primary,
                tooltip: 'Refresh GPS locations',
                onPressed: () => _refreshPartnerTracking(silent: false),
              ),
            ],
          ),
          body: _buildTrackingTab(isStandalonePage: true),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildTrackingTab({bool isStandalonePage = false}) {
    final isDark = widget.isDarkMode;
    final visibleLocations = _visiblePartnerTrackingLocations();
    final isFocused = _focusedTrackingBookingId != null &&
        _focusedTrackingBookingId!.isNotEmpty;

    final totalCount = trackingLocations.length;
    final activeCount = trackingLocations
        .where((loc) => loc['has_active_booking'] == true)
        .length;
    final idleCount = totalCount - activeCount;

    // Focused trip details
    Map<String, dynamic>? focusedLocation;
    MobilisMapPoint? pickupPoint;
    MobilisMapPoint? destPoint;
    double? remainingDistanceKm;
    bool focusedHasActiveBooking = false;

    if (isFocused && visibleLocations.isNotEmpty) {
      focusedLocation = visibleLocations.first;
      focusedHasActiveBooking = focusedLocation['has_active_booking'] == true &&
          focusedLocation['bookings'] != null;

      if (focusedHasActiveBooking) {
        final fBooking = focusedLocation['bookings'] as Map<String, dynamic>?;
        pickupPoint = _resolvePartnerTrackingPoint(
          fBooking?['pickup_latitude'],
          fBooking?['pickup_longitude'],
          fBooking?['pickup_location']?.toString() ?? '',
        );
        destPoint = _resolvePartnerTrackingPoint(
          fBooking?['dropoff_latitude'],
          fBooking?['dropoff_longitude'],
          fBooking?['dropoff_location']?.toString() ?? '',
        );

        final carLat = (focusedLocation['latitude'] as num?)?.toDouble();
        final carLng = (focusedLocation['longitude'] as num?)?.toDouble();
        if (carLat != null && carLng != null && destPoint != null) {
          remainingDistanceKm = Geolocator.distanceBetween(
                carLat,
                carLng,
                destPoint.latitude,
                destPoint.longitude,
              ) /
              1000;
        }
      }
    }

    // Build map markers
    final mapMarkers = <MobilisMapMarker>[];
    List<MobilisMapPoint> routePoints = const [];

    if (isFocused && focusedLocation != null) {
      final vehicleName = _resolvePartnerTrackingVehicleName(focusedLocation);
      final carLat = (focusedLocation['latitude'] as num?)?.toDouble();
      final carLng = (focusedLocation['longitude'] as num?)?.toDouble();
      final motion = _getPartnerVehicleMotionInfo(focusedLocation);
      final motionColor = motion['color'] as Color;

      if (focusedHasActiveBooking && pickupPoint != null) {
        mapMarkers.add(
          MobilisMapMarker(
            latitude: pickupPoint.latitude,
            longitude: pickupPoint.longitude,
            icon: Icons.trip_origin_rounded,
            color: Colors.greenAccent.shade700,
            size: 32,
            tooltip: 'Pickup Location',
          ),
        );
      }

      if (carLat != null && carLng != null) {
        final carPoint = MobilisMapPoint(latitude: carLat, longitude: carLng);
        mapMarkers.add(
          MobilisMapMarker(
            latitude: carLat,
            longitude: carLng,
            icon: Icons.directions_car_filled_rounded,
            color: motionColor,
            size: 42,
            tooltip: vehicleName.isNotEmpty
                ? '$vehicleName • ${motion['label']}'
                : 'Partner Vehicle • ${motion['label']}',
            label: vehicleName.isNotEmpty
                ? '$vehicleName (${motion['short_label']})'
                : motion['label'],
          ),
        );

        if (focusedHasActiveBooking && destPoint != null) {
          routePoints = _getPartnerTrackingRoutePoints(carPoint, destPoint);
        }
      }

      if (focusedHasActiveBooking && destPoint != null) {
        mapMarkers.add(
          MobilisMapMarker(
            latitude: destPoint.latitude,
            longitude: destPoint.longitude,
            icon: Icons.flag_rounded,
            color: Colors.redAccent,
            size: 38,
            tooltip: 'Declared Destination',
          ),
        );
      }
    } else {
      // Show all partner vehicle markers
      for (final loc in visibleLocations) {
        final lat = (loc['latitude'] as num?)?.toDouble();
        final lng = (loc['longitude'] as num?)?.toDouble();
        final booking = loc['bookings'] as Map<String, dynamic>?;
        final vehicleName = _resolvePartnerTrackingVehicleName(loc);

        final locId = booking?['id']?.toString() ??
            loc['id']?.toString() ??
            'vehicle_${loc['vehicle_id']}';
        final motion = _getPartnerVehicleMotionInfo(loc);
        final motionColor = motion['color'] as Color;

        if (lat != null && lng != null) {
          mapMarkers.add(
            MobilisMapMarker(
              latitude: lat,
              longitude: lng,
              icon: Icons.directions_car_filled_rounded,
              color: motionColor,
              size: 36,
              tooltip: vehicleName.isNotEmpty
                  ? '$vehicleName • ${motion['label']}'
                  : 'Partner Vehicle • ${motion['label']}',
              label: vehicleName.isNotEmpty
                  ? '$vehicleName (${motion['short_label']})'
                  : motion['short_label'],
              onTap: () {
                if (locId.isNotEmpty) {
                  setState(() => _focusedTrackingBookingId = locId);
                }
              },
            ),
          );
        }
      }
    }

    final trackingContent = RefreshIndicator(
            onRefresh: () => _refreshPartnerTracking(silent: false),
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                // Top Header Card
                RoleTabHeader(
                  title: 'Live Tracking',
                  subtitle: 'Real-time GPS monitor for your vehicles ($totalCount total)',
                  icon: Icons.radar_rounded,
                  badge: '${visibleLocations.length} Online',
                ),
                const SizedBox(height: 14),

                // Focus banner or Filter Chips & Search
                if (isFocused) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.gps_fixed_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                focusedLocation != null
                                    ? _resolvePartnerTrackingVehicleName(focusedLocation)
                                    : 'Focused Vehicle',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() => _focusedTrackingBookingId = null);
                              },
                              icon: const Icon(Icons.grid_view_rounded, size: 14),
                              label: const Text('Show All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                                foregroundColor: isDark ? Colors.white : Colors.black87,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                            ),
                          ],
                        ),
                        if (focusedHasActiveBooking) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.borderColor),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.alt_route_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  '🟢 Pickup  ➔  🚕 Live Car  ➔  🚩 Destination',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                                ),
                              ),
                              if (remainingDistanceKm != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: remainingDistanceKm <= 5.0
                                        ? Colors.green.withValues(alpha: 0.25)
                                        : Colors.amber.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: remainingDistanceKm <= 5.0 ? Colors.green : Colors.amber,
                                    ),
                                  ),
                                  child: Text(
                                    '${remainingDistanceKm.toStringAsFixed(1)} km away',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: remainingDistanceKm <= 5.0 ? Colors.green : Colors.amber,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTrackingFilterChip('all', 'All ($totalCount)', isDark),
                        const SizedBox(width: 8),
                        _buildTrackingFilterChip('active', 'Active Trips ($activeCount)', isDark),
                        const SizedBox(width: 8),
                        _buildTrackingFilterChip('idle', 'Available / Idle ($idleCount)', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.borderColor : Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _partnerTrackingSearchController,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search your vehicles, plate, or trip...',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _partnerTrackingSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _partnerTrackingSearchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Live Map Viewport
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 280,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBgSecondary : Colors.grey.shade100,
                      border: Border.all(
                        color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: mapMarkers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_off_rounded, size: 36, color: AppColors.textSecondary),
                                const SizedBox(height: 8),
                                Text(
                                  _focusedTrackingBookingId == null
                                      ? 'No live GPS coordinates received yet'
                                      : 'No coordinates found for this vehicle',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : MobilisLeafletMap(
                            key: ValueKey(
                              'partner_fleet_${_focusedTrackingBookingId ?? "all"}_' +
                                  mapMarkers
                                      .map(
                                        (m) =>
                                            '${m.latitude.toStringAsFixed(4)},${m.longitude.toStringAsFixed(4)}',
                                      )
                                      .join('|') +
                                  '_${routePoints.length}',
                            ),
                            markers: mapMarkers,
                            routePoints: routePoints,
                            routeColor: AppColors.primary,
                            initialZoom: isFocused
                                ? (mapMarkers.length > 1 ? 12 : 15)
                                : (mapMarkers.length > 1 ? 11 : 14),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Vehicle List Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFocused ? 'Focused Vehicle Details' : 'Tracked Vehicles (${visibleLocations.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (isFocused)
                      GestureDetector(
                        onTap: () => setState(() => _focusedTrackingBookingId = null),
                        child: const Text(
                          'Show All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Vehicle Cards
                if (visibleLocations.isEmpty)
                  RoleEmptyStateCard(
                    icon: Icons.directions_car_filled_outlined,
                    title: 'No vehicles found',
                    message: _partnerTrackingFilter == 'active'
                        ? 'None of your vehicles are currently on an active trip.'
                        : 'No partner vehicles matched your search.',
                  )
                else
                  ...visibleLocations.map(
                    (location) => _buildPartnerTrackingCard(location, isDark),
                  ),
              ],
            ),
    );

    if (isStandalonePage) {
      return trackingContent;
    }
    return Column(
      children: [
        _buildCenteredTabHeader('Live Tracking'),
        Expanded(child: trackingContent),
      ],
    );
  }

  Widget _buildTrackingFilterChip(String filterKey, String label, bool isDark) {
    final isSelected = _partnerTrackingFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _partnerTrackingFilter = filterKey;
          _focusedTrackingBookingId = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.borderColor : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerTrackingCard(Map<String, dynamic> location, bool isDark) {
    final booking = location['bookings'] as Map<String, dynamic>?;
    final bStatus = (booking?['status'] ?? '').toString().toLowerCase();
    final hasActiveBooking = location['has_active_booking'] == true &&
        booking != null &&
        {'ongoing', 'active', 'in_progress', 'picked_up'}.contains(bStatus) &&
        booking['returned_at'] == null &&
        booking['completed_at'] == null;
    final vehicle = (booking?['vehicles'] ?? location['vehicle']) as Map<String, dynamic>?;
    final tracker = location['tracker'] as Map<String, dynamic>?;
    final driver = (booking?['driver'] ?? booking?['drivers']) as Map<String, dynamic>?;
    final driverUser = (location['tracked_user'] ?? driver?['users']) as Map<String, dynamic>?;
    final renter = booking?['renter'] as Map<String, dynamic>?;
    final rowId = booking?['id']?.toString() ??
        location['id']?.toString() ??
        'vehicle_${location['vehicle_id']}';
    final pickup = booking?['pickup_location']?.toString().trim() ?? '';
    final dropoff = booking?['dropoff_location']?.toString().trim() ?? '';
    final vehicleName = _resolvePartnerTrackingVehicleName(location);
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    final speedKph = (((location['speed_mps'] as num?) ?? 0) * 3.6).round();

    final isFocused = _focusedTrackingBookingId == rowId;

    // Distance to destination if on active trip
    double? distanceToDestinationKm;
    if (hasActiveBooking) {
      final destPoint = _resolvePartnerTrackingPoint(
        booking?['dropoff_latitude'],
        booking?['dropoff_longitude'],
        dropoff,
      );
      if (lat != null && lng != null && destPoint != null) {
        distanceToDestinationKm = Geolocator.distanceBetween(
              lat,
              lng,
              destPoint.latitude,
              destPoint.longitude,
            ) /
            1000;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isFocused
            ? AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08)
            : (isDark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused
              ? AppColors.primary
              : (isDark ? AppColors.borderColor : Colors.grey.shade300),
          width: isFocused ? 2 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _focusedTrackingBookingId = isFocused ? null : rowId;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header: Icon + Title + Status Chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? AppColors.primary
                            : (hasActiveBooking
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : const Color(0xFF38BDF8).withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        color: isFocused
                            ? Colors.black
                            : (hasActiveBooking ? AppColors.primary : const Color(0xFF38BDF8)),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicleName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasActiveBooking ? 'On Active Rental Trip' : 'Available • Parked / Idle',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPartnerMovementStatusChip(
                      location: location,
                      isDark: isDark,
                      isCompact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Speed & Tracker Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBgSecondary : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        size: 14,
                        color: speedKph > 0 ? const Color(0xFF00E676) : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Speed: $speedKph km/h',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      if (tracker?['battery_level'] != null) ...[
                        const Spacer(),
                        const Icon(Icons.battery_charging_full_rounded, size: 14, color: Colors.green),
                        const SizedBox(width: 3),
                        Text(
                          '${tracker!['battery_level']}%',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                      if (location['recorded_at'] != null) ...[
                        const Spacer(),
                        Text(
                          'Pinged ',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        RelativeTimeText(
                          value: location['recorded_at'],
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trip Information (Active)
                if (hasActiveBooking) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (renter != null)
                          Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Renter: ${renter['full_name'] ?? 'Guest Renter'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (driverUser != null) ...[
                                const SizedBox(width: 8),
                                const Text('•', style: TextStyle(color: Colors.grey)),
                                const SizedBox(width: 8),
                                Text(
                                  'Driver: ${driverUser['full_name']}',
                                  style: const TextStyle(fontSize: 11, color: Colors.cyan, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        if (pickup.isNotEmpty || dropoff.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: Colors.redAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Route: ${pickup.isEmpty ? "Current Location" : pickup} ➔ ${dropoff.isEmpty ? "Unspecified Destination" : dropoff}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (distanceToDestinationKm != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.straighten_rounded, size: 13, color: Colors.amber),
                              const SizedBox(width: 6),
                              Text(
                                '${distanceToDestinationKm.toStringAsFixed(1)} km to declared destination',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Action Buttons Row
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _focusedTrackingBookingId = isFocused ? null : rowId;
                          });
                        },
                        icon: Icon(isFocused ? Icons.check_circle_rounded : Icons.gps_fixed_rounded, size: 14),
                        label: Text(isFocused ? 'Focused ✓' : 'Focus Map', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFocused ? AppColors.primary : (isDark ? Colors.grey[800] : Colors.grey[200]),
                          foregroundColor: isFocused ? Colors.black : (isDark ? Colors.white : Colors.black87),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    if (hasActiveBooking) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openBookingConversation(booking),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                          label: const Text('Message', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          TripLocationMapDialog.show(
                            context: context,
                            booking: booking,
                            vehicleName: vehicleName,
                            plateNumber: (vehicle?['plate_number'] ?? tracker?['device_identifier'])?.toString(),
                          );
                        },
                        icon: const Icon(Icons.map_outlined, size: 18),
                        tooltip: 'Trip Route Map',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.grey.shade100,
                          padding: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
                          final vehicle = (booking?['vehicles'] ??
                                  booking?['partner_vehicles'] ??
                                  booking?['partner_vehicle'] ??
                                  booking?['vehicle']) as Map?;
                          final vehicleName =
                              [vehicle?['brand'], vehicle?['model']]
                                  .where(
                                    (value) =>
                                        value?.toString().trim().isNotEmpty ==
                                        true,
                                  )
                                  .join(' ');
                          final carTitle = vehicleName.isNotEmpty
                              ? vehicleName
                              : (vehicle?['vehicle_name']?.toString().trim().isNotEmpty == true
                                  ? vehicle!['vehicle_name'].toString().trim()
                                  : '');
                          final topicTitle = isCustomerService
                              ? 'Customer Service'
                              : carTitle.isNotEmpty
                              ? '$carTitle Booking'
                              : 'Booking Conversation';
                          var imageUrl =
                              conv['vehicle_image_url']?.toString() ?? '';
                          if (imageUrl.isEmpty) {
                            imageUrl = (booking?['vehicle_image_url'] ??
                                    vehicle?['image_url'] ??
                                    vehicle?['imageUrl'] ??
                                    vehicle?['photo_url'] ??
                                    vehicle?['vehicle_image_url'])
                                ?.toString() ??
                                '';
                          }
                          final messages =
                              conv['messages'] as List<dynamic>? ?? [];
                          final lastMessage = messages.isNotEmpty
                              ? messages.last['content'] ?? ''
                              : 'No messages';

                          final statusRaw = (booking?['status'] ?? '').toString().toLowerCase().trim();
                          final statusGrp = bookingStatusGroup(statusRaw);
                          final String statusBadge = isCustomerService
                              ? 'Support'
                              : (statusGrp == BookingStatusGroup.ongoing
                                  ? 'Ongoing Trip'
                                  : (statusGrp == BookingStatusGroup.approved
                                      ? 'Approved Booking'
                                      : (statusGrp == BookingStatusGroup.completed
                                          ? 'Completed • Read-Only'
                                          : (statusGrp == BookingStatusGroup.cancelled
                                              ? 'Cancelled • Read-Only'
                                              : (statusGrp == BookingStatusGroup.frozen
                                                  ? 'Frozen'
                                                  : (statusRaw.isNotEmpty ? '${bookingStatusLabel(statusGrp)} Booking' : 'Active'))))));

                          return ConversationTile(
                            senderName: topicTitle,
                            lastMessage: lastMessage,
                            timestamp: _formatTime(conv['updated_at']),
                            unreadCount: 0,
                            imageUrl: imageUrl,
                            statusBadge: statusBadge,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const statusList = [
      'pending',
      'approved',
      'ongoing',
      'completed',
      'cancelled',
    ];
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
        // Top Segment Switch: [ 🚗 Rental Bookings ] | [ ⏱️ Extend Trip Requests ]
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgSecondary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      setState(() => _partnerBookingSubSection = 'bookings'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _partnerBookingSubSection == 'bookings'
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book_online_rounded,
                          size: 16,
                          color: _partnerBookingSubSection == 'bookings'
                              ? Colors.black
                              : (isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade700),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Bookings',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _partnerBookingSubSection == 'bookings'
                                ? Colors.black
                                : (isDark
                                    ? Colors.grey[300]
                                    : Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      setState(() => _partnerBookingSubSection = 'extensions'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _partnerBookingSubSection == 'extensions'
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.update_rounded,
                          size: 16,
                          color: _partnerBookingSubSection == 'extensions'
                              ? Colors.black
                              : (isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade700),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Extend Trips',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _partnerBookingSubSection == 'extensions'
                                ? Colors.black
                                : (isDark
                                    ? Colors.grey[300]
                                    : Colors.grey.shade800),
                          ),
                        ),
                        if (_partnerPendingExtensionRequestsCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _partnerBookingSubSection == 'extensions'
                                  ? Colors.black
                                  : AppColors.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_partnerPendingExtensionRequestsCount',
                              style: TextStyle(
                                color:
                                    _partnerBookingSubSection == 'extensions'
                                        ? AppColors.primary
                                        : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPartnerData,
            color: AppColors.primary,
            child: _partnerBookingSubSection == 'extensions'
                ? _buildPartnerExtendTripRequestsSection(isDark)
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
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
                      if (_partnerBookingStatus == 'ongoing' &&
                          filteredBookings.isNotEmpty) ...[
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

  Widget _buildPartnerExtendTripRequestsSection(bool isDark) {
    final allExtensionBookings = bookings.where((b) {
      final ext = b['extension_status']?.toString().toLowerCase().trim();
      return ext != null && ext.isNotEmpty && ext != 'none';
    }).toList();

    final filteredExtensions = allExtensionBookings.where((booking) {
      final status =
          booking['extension_status']?.toString().toLowerCase().trim() ?? '';
      final matchesFilter = switch (_partnerExtensionFilter) {
        'all' => true,
        'pending' =>
          status == 'pending' ||
              status == 'pending_partner' ||
              status == 'pending_operator',
        'payment_pending' =>
          status == 'accepted' || status == 'payment_pending',
        'payment_completed' => status == 'payment_completed',
        'pending_final_confirmation' => status == 'pending_final_confirmation',
        'finalized' => status == 'finalized' || status == 'approved',
        'rejected' => status == 'rejected' || status == 'cancelled',
        _ => true,
      };
      if (!matchesFilter) return false;

      if (_partnerExtensionSearchQuery.isNotEmpty) {
        final query = _partnerExtensionSearchQuery.toLowerCase();
        final vehicle = booking['vehicles'] is Map
            ? booking['vehicles'] as Map<String, dynamic>
            : <String, dynamic>{};
        final renter = booking['users'] is Map
            ? booking['users'] as Map<String, dynamic>
            : <String, dynamic>{};
        final bId = booking['id']?.toString() ?? '';
        final shortBId = bId.length >= 8 ? bId.substring(0, 8) : bId;
        final haystack = [
          bId,
          'EXT-$shortBId',
          renter['full_name'],
          renter['email'],
          renter['phone'],
          vehicle['vehicle_name'],
          vehicle['brand'],
          vehicle['model'],
          vehicle['plate_number'],
          booking['dropoff_location'],
          booking['extension_requested_destination'],
        ].whereType<Object>().join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }

      return true;
    }).toList();

    filteredExtensions.sort((a, b) {
      final aDate = DateTime.tryParse(
            a['extension_requested_at']?.toString() ??
                a['created_at']?.toString() ??
                '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(
            b['extension_requested_at']?.toString() ??
                b['created_at']?.toString() ??
                '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    final pendingCount = allExtensionBookings
        .where(
          (b) =>
              b['extension_status'] == 'pending' ||
              b['extension_status'] == 'pending_partner',
        )
        .length;
    final payPendingCount = allExtensionBookings
        .where(
          (b) =>
              b['extension_status'] == 'accepted' ||
              b['extension_status'] == 'payment_pending',
        )
        .length;
    final payReviewCount = allExtensionBookings
        .where((b) => b['extension_status'] == 'payment_completed')
        .length;
    final pendingConfCount = allExtensionBookings
        .where((b) => b['extension_status'] == 'pending_final_confirmation')
        .length;
    final finalizedCount = allExtensionBookings
        .where((b) => b['extension_status'] == 'finalized')
        .length;
    final rejectedCount = allExtensionBookings
        .where(
          (b) =>
              b['extension_status'] == 'rejected' ||
              b['extension_status'] == 'cancelled',
        )
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        RoleTabHeader(
          title: 'Extend Trip Requests',
          subtitle:
              'Review renter extension requests, verify payments, and finalize trips',
          icon: Icons.update_rounded,
          badge: '${allExtensionBookings.length} total',
        ),
        const SizedBox(height: 12),
        // Filter pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPartnerExtensionFilterTab(
                'all',
                'All (${allExtensionBookings.length})',
                isDark,
              ),
              _buildPartnerExtensionFilterTab(
                'pending',
                'Pending ($pendingCount)',
                isDark,
              ),
              _buildPartnerExtensionFilterTab(
                'payment_pending',
                'Payment Pending ($payPendingCount)',
                isDark,
              ),
              _buildPartnerExtensionFilterTab(
                'payment_completed',
                'Payment Review ($payReviewCount)',
                isDark,
              ),
              _buildPartnerExtensionFilterTab(
                'pending_final_confirmation',
                'To Finalize ($pendingConfCount)',
                isDark,
              ),
              _buildPartnerExtensionFilterTab(
                'finalized',
                'Finalized ($finalizedCount)',
                isDark,
              ),
              _buildPartnerExtensionFilterTab(
                'rejected',
                'Declined ($rejectedCount)',
                isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgSecondary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _partnerExtensionSearchController,
                  onChanged: (value) => setState(() {
                    _partnerExtensionSearchQuery = value.trim();
                  }),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search request ID, renter, vehicle, destination',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_partnerExtensionSearchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    _partnerExtensionSearchController.clear();
                    setState(() => _partnerExtensionSearchQuery = '');
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (filteredExtensions.isEmpty)
          RoleEmptyStateCard(
            icon: Icons.update_disabled_rounded,
            title: 'No trip extension requests',
            message:
                'When renters request to extend their active trips on your vehicles, they will appear here for review.',
          )
        else
          ...filteredExtensions.map(
            (booking) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildPartnerExtendTripRequestCard(booking, isDark),
            ),
          ),
      ],
    );
  }

  Widget _buildPartnerExtensionFilterTab(
    String key,
    String label,
    bool isDark,
  ) {
    final isSelected = _partnerExtensionFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _partnerExtensionFilter = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBg : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.borderColor
                      : AppColors.lightBorderColor),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.black
                  : (isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerExtendTripRequestCard(
    Map<String, dynamic> booking,
    bool isDark,
  ) {
    final bookingId = booking['id']?.toString() ?? '';
    final shortBId = bookingId.length >= 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();
    final requestId = 'EXT-$shortBId';

    final vehicle = booking['vehicles'] is Map
        ? booking['vehicles'] as Map<String, dynamic>
        : <String, dynamic>{};
    final renter = booking['users'] is Map
        ? booking['users'] as Map<String, dynamic>
        : <String, dynamic>{};

    final extStatus =
        booking['extension_status']?.toString().toLowerCase().trim() ??
        'pending';
    final requestedAt = DateTime.tryParse(
      booking['extension_requested_at']?.toString() ?? '',
    );
    final requestedEndAt = DateTime.tryParse(
      booking['extension_requested_end_at']?.toString() ?? '',
    );
    final currentEndAt = DateTime.tryParse(
      (booking['end_at'] ?? booking['end_date'])?.toString() ?? '',
    );

    final extensionDays =
        int.tryParse(booking['extension_days']?.toString() ?? '') ??
        (booking['extension_days'] is num
            ? (booking['extension_days'] as num).toInt()
            : 1);
    final additionalPrice =
        double.tryParse(
          booking['extension_additional_price']?.toString() ?? '',
        ) ??
        (booking['extension_additional_price'] is num
            ? (booking['extension_additional_price'] as num).toDouble()
            : 0.0);
    final currentTotal =
        (booking['total_price'] as num?)?.toDouble() ??
        double.tryParse(booking['total_price']?.toString() ?? '') ??
        0.0;
    final updatedTotalPrice = extStatus == 'finalized'
        ? currentTotal
        : (currentTotal + additionalPrice);

    final requestedDestination =
        booking['extension_requested_destination']?.toString().trim();
    final proofUrl =
        booking['extension_payment_proof_url']?.toString().trim() ?? '';
    final paymentMethod =
        booking['extension_payment_method']?.toString().trim() ?? 'E-Wallet';
    final paymentRef =
        booking['extension_payment_reference']?.toString().trim() ?? 'N/A';

    final vehicleTitle =
        '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
    final vehiclePlate = vehicle['plate_number']?.toString().trim() ?? '';
    final imageUrl = _bookingVehicleImageUrl(vehicle);

    final renterName = renter['full_name']?.toString().trim().isNotEmpty == true
        ? renter['full_name'].toString().trim()
        : 'Renter';
    final renterPhone = renter['phone']?.toString().trim() ?? '';

    final (statusColor, statusLabel) = switch (extStatus) {
      'pending' || 'pending_partner' || 'pending_operator' => (
        const Color(0xFFE5A93C),
        'PENDING REVIEW',
      ),
      'accepted' || 'payment_pending' => (
        Colors.blueAccent,
        'PAYMENT PENDING',
      ),
      'payment_completed' => (
        Colors.purpleAccent,
        'PAYMENT REVIEW',
      ),
      'pending_final_confirmation' => (
        Colors.tealAccent,
        'PENDING CONFIRMATION',
      ),
      'finalized' || 'approved' => (AppColors.success, 'FINALIZED'),
      'rejected' || 'cancelled' => (AppColors.error, 'DECLINED'),
      _ => (AppColors.warning, extStatus.toUpperCase()),
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBgSecondary
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.update_rounded, color: statusColor, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$requestId • Booking #$shortBId',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (requestedAt != null)
                        Text(
                          'Requested ${_formatDateShort(requestedAt.toIso8601String())}',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle & Renter row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: AppColors.darkBgSecondary,
                        child: imageUrl != null
                            ? OptimizedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: _buildBookingImageFallback(),
                              )
                            : _buildBookingImageFallback(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicleTitle.isEmpty ? 'Vehicle' : vehicleTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (vehiclePlate.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Plate: $vehiclePlate',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  renterName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
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
                const SizedBox(height: 14),
                // Extension info grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBgSecondary
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Original End Date',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            currentEndAt != null
                                ? _formatDateShort(currentEndAt.toIso8601String())
                                : 'N/A',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Requested New End Date',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            requestedEndAt != null
                                ? _formatDateShort(requestedEndAt.toIso8601String())
                                : 'N/A',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '+$extensionDays Extra Day${extensionDays == 1 ? '' : 's'} Fee',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'PHP ${_formatMoney(additionalPrice)}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Updated Total Booking Cost',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'PHP ${_formatMoney(updatedTotalPrice)}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      if (requestedDestination != null &&
                          requestedDestination.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Requested Destination: ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                requestedDestination,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (proofUrl.isNotEmpty ||
                    (paymentRef.isNotEmpty && paymentRef != 'N/A')) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.purpleAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$paymentMethod • Ref: $paymentRef',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.purpleAccent,
                            ),
                          ),
                        ),
                        if (proofUrl.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                _showProofImageModal(proofUrl, paymentRef),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'View Receipt',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.purpleAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Action buttons based on status
                if (extStatus == 'pending' ||
                    extStatus == 'pending_partner' ||
                    extStatus == 'pending_operator') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleAcceptTripExtension(booking),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Accept Request',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleRejectTripExtension(booking),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (extStatus == 'payment_completed') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _handleVerifyExtensionPayment(booking),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Verify Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleRejectTripExtension(booking),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                    ],
                  ),
                ] else if (extStatus == 'pending_final_confirmation') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleFinalizeTripExtension(booking),
                      icon: const Icon(Icons.verified, size: 16),
                      label: const Text('Finalize Extension & Update Dates'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else if (extStatus == 'finalized' ||
                    extStatus == 'approved') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Extension Active & Finalized',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (extStatus == 'rejected' ||
                    extStatus == 'cancelled') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Request Declined${booking['extension_rejection_reason'] != null ? ': ${booking['extension_rejection_reason']}' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showBookingDetailModal(context, booking),
                        icon: const Icon(Icons.info_outline, size: 14),
                        label: const Text('Trip Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white70
                              : AppColors.textPrimary,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.borderColor
                                : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
    );
  }

  Future<void> _launchPhone(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri.parse('tel:$cleanPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  void _showProofImageModal(String url, String ref) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'Receipt • $ref',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text(
                      'Failed to load proof image',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAcceptTripExtension(Map<String, dynamic> booking) async {
    try {
      final currentPartnerId = partnerId ?? AuthService().currentUser?.id;
      final bookingId = booking['id']?.toString() ?? '';
      await BookingService().acceptTripExtension(
        bookingId: bookingId,
        reviewerId: currentPartnerId,
        reviewerRole: 'partner',
      );
      _showSuccessSnackBar(
        'Extension request accepted! Renter notified to complete payment.',
      );
      await _loadPartnerData(silent: true);
    } catch (e) {
      _showErrorSnackBar('Failed to accept extension: $e');
    }
  }

  Future<void> _handleRejectTripExtension(Map<String, dynamic> booking) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        title: const Text(
          'Decline Extension Request',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for declining this extension request.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g., Vehicle scheduled for maintenance',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Decline Extension'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final currentPartnerId = partnerId ?? AuthService().currentUser?.id;
      final bookingId = booking['id']?.toString() ?? '';
      final reason = reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : 'Declined by vehicle owner';

      // ⚡ Optimistic UI update
      final bookingIndex =
          bookings.indexWhere((b) => b['id']?.toString() == bookingId);
      final originalBooking = bookingIndex != -1
          ? Map<String, dynamic>.from(bookings[bookingIndex])
          : null;
      if (bookingIndex != -1) {
        setState(() {
          final target = Map<String, dynamic>.from(bookings[bookingIndex]);
          target['extension_status'] = 'rejected';
          target['extension_rejection_reason'] = reason;
          bookings[bookingIndex] = target;
        });
      }

      _showSuccessSnackBar('Trip extension request declined');

      try {
        await BookingService().rejectTripExtension(
          bookingId: bookingId,
          reviewerId: currentPartnerId,
          reviewerRole: 'partner',
          reason: reason,
          cachedBooking: booking,
        );
        await _loadPartnerData(silent: true);
      } catch (e) {
        if (originalBooking != null && bookingIndex != -1 && mounted) {
          setState(() {
            bookings[bookingIndex] = originalBooking;
          });
        }
        _showErrorSnackBar('Failed to decline extension: $e');
      }
    }
  }

  Future<void> _handleVerifyExtensionPayment(
    Map<String, dynamic> booking,
  ) async {
    try {
      final currentPartnerId =
          partnerId ?? AuthService().currentUser?.id ?? '';
      final bookingId = booking['id']?.toString() ?? '';
      await BookingService().verifyExtensionPayment(
        bookingId: bookingId,
        verifierId: currentPartnerId,
        verifierRole: 'partner',
      );
      _showSuccessSnackBar(
        'Extension payment verified! You can now finalize the extension.',
      );
      await _loadPartnerData(silent: true);
    } catch (e) {
      _showErrorSnackBar('Failed to verify payment: $e');
    }
  }

  Future<void> _handleFinalizeTripExtension(
    Map<String, dynamic> booking,
  ) async {
    try {
      final currentPartnerId =
          partnerId ?? AuthService().currentUser?.id ?? '';
      final bookingId = booking['id']?.toString() ?? '';
      await BookingService().finalizeTripExtension(
        bookingId: bookingId,
        finalizerId: currentPartnerId,
        finalizerRole: 'partner',
      );
      _showSuccessSnackBar(
        'Trip extension finalized! Booking end date and total price updated.',
      );
      await _loadPartnerData(silent: true);
    } catch (e) {
      _showErrorSnackBar('Failed to finalize extension: $e');
    }
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
    final brand = vehicle?['brand']?.toString().trim() ?? '';
    final model = vehicle?['model']?.toString().trim() ?? '';
    final year = vehicle?['year']?.toString().trim() ?? '';
    final rawVehicleName = vehicle?['vehicle_name']?.toString().trim() ?? '';
    final combo = [brand, model].where((part) => part.isNotEmpty).join(' ');
    final vehicleTitle = combo.isNotEmpty
        ? (year.isNotEmpty ? '$combo ($year)' : combo)
        : (rawVehicleName.isNotEmpty &&
                rawVehicleName.toLowerCase() != 'partner vehicle' &&
                rawVehicleName.toLowerCase() != 'unknown vehicle' &&
                rawVehicleName.toLowerCase() != 'vehicle'
            ? rawVehicleName
            : 'Partner Vehicle');

    final directImg = (vehicle?['image_url'] ??
            vehicle?['vehicle_photo_url'] ??
            vehicle?['photo_url'] ??
            booking['vehicle_image_url'] ??
            booking['image_url'])
        ?.toString()
        .trim() ??
        '';
    String vehicleImageUrl = directImg;
    if (vehicleImageUrl.isEmpty) {
      final vImgs = vehicle?['vehicle_images'];
      if (vImgs is List && vImgs.isNotEmpty) {
        for (final img in vImgs) {
          if (img is Map) {
            final u = (img['image_url'] ?? img['file_url'] ?? img['url'])
                ?.toString()
                .trim() ??
                '';
            if (u.isNotEmpty) {
              vehicleImageUrl = u;
              break;
            }
          }
        }
      }
    }
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
              if (vehicleImageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: OptimizedNetworkImage(
                      imageUrl: vehicleImageUrl,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: const Color(0xFFE8E0C0),
                        alignment: Alignment.center,
                        child: Text(
                          _initialsForName(renterName),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
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
              ],
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
          // Trip Extension Management Section for Partner
          if (booking['extension_status'] != null &&
              booking['extension_status'].toString().isNotEmpty &&
              booking['extension_status'] != 'none') ...[
            const SizedBox(height: 14),
            _buildPartnerExtensionManagementSection(booking),
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

  Widget _buildPartnerExtensionManagementSection(Map<String, dynamic> booking) {
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
    final proofUrl =
        booking['extension_payment_proof_url']?.toString().trim() ?? '';
    final payMethod =
        booking['extension_payment_method']?.toString().trim() ?? 'E-Wallet';
    final payRef =
        booking['extension_payment_reference']?.toString().trim() ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1F33),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF204B6B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.update_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Trip Extension Request',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              _buildPartnerExtensionStatusPill(extStatus),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Requested Return:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Text(
                requestedEndAt != null
                    ? '${_formatDateShort(requestedEndAt.toIso8601String())} (+$days d)'
                    : 'N/A',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (newDest != null && newDest.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New Destination:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                Flexible(
                  child: Text(
                    newDest,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Extension Fee Due:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Text(
                '+₱${formatAmount(additionalPrice, decimalDigits: 2)}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (proofUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment: $payMethod • Ref: $payRef',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showReceiptProofDialog(proofUrl),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'View Proof',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Action Buttons for Partner
          if (extStatus == 'pending' || extStatus == 'pending_partner') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showPartnerRejectExtensionDialog(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handlePartnerAcceptExtension(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Accept & Request Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else if (extStatus == 'payment_completed') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handlePartnerVerifyPayment(booking),
                icon: const Icon(Icons.verified_user_rounded, size: 16),
                label: const Text('Verify Renter Payment Proof'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else if (extStatus == 'pending_final_confirmation') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handlePartnerFinalizeExtension(booking),
                icon: const Icon(Icons.task_alt_rounded, size: 16),
                label: const Text('Confirm & Finalize Extension'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else if (extStatus == 'accepted' || extStatus == 'payment_pending') ...[
            const Center(
              child: Text(
                'Waiting for Renter to submit extension payment proof...',
                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartnerExtensionStatusPill(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
      case 'pending_partner':
      case 'pending_operator':
        color = Colors.amber;
        label = 'Pending Review';
        break;
      case 'accepted':
      case 'payment_pending':
        color = const Color(0xFF38BDF8);
        label = 'Payment Pending';
        break;
      case 'payment_completed':
        color = Colors.purpleAccent;
        label = 'Payment Review';
        break;
      case 'pending_final_confirmation':
        color = const Color(0xFF6366F1);
        label = 'Pending Final';
        break;
      case 'finalized':
      case 'approved':
        color = Colors.greenAccent;
        label = 'Finalized';
        break;
      case 'rejected':
      case 'cancelled':
        color = AppColors.error;
        label = 'Rejected';
        break;
      default:
        color = AppColors.textSecondary;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _handlePartnerAcceptExtension(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final currentPartnerId = partnerId;
    if (bookingId.isEmpty || currentPartnerId == null) return;

    try {
      await BookingService().acceptTripExtension(
        bookingId: bookingId,
        reviewerId: currentPartnerId,
        reviewerRole: 'partner',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extension request accepted! Renter notified for payment.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadPartnerData();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error accepting extension: $e');
    }
  }

  Future<void> _handlePartnerVerifyPayment(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final currentPartnerId = partnerId;
    if (bookingId.isEmpty || currentPartnerId == null) return;

    try {
      await BookingService().verifyExtensionPayment(
        bookingId: bookingId,
        verifierId: currentPartnerId,
        verifierRole: 'partner',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verified! Extension is ready for final confirmation.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadPartnerData();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error verifying payment: $e');
    }
  }

  Future<void> _handlePartnerFinalizeExtension(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final currentPartnerId = partnerId;
    if (bookingId.isEmpty || currentPartnerId == null) return;

    try {
      await BookingService().finalizeTripExtension(
        bookingId: bookingId,
        finalizerId: currentPartnerId,
        finalizerRole: 'partner',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip extension finalized! New dates & total price committed.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadPartnerData();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error finalizing extension: $e');
    }
  }

  Future<void> _showPartnerRejectExtensionDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final reasonController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Trip Extension', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for declining this extension request:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Schedule conflict or maintenance required.',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final currentPartnerId = partnerId;
              if (currentPartnerId == null) return;
              Navigator.pop(dialogContext);
              try {
                await BookingService().rejectTripExtension(
                  bookingId: bookingId,
                  reviewerId: currentPartnerId,
                  reviewerRole: 'partner',
                  reason: reasonController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Trip extension rejected.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  _loadPartnerData();
                }
              } catch (e) {
                if (mounted) _showErrorSnackBar('Error rejecting extension: $e');
              }
            },
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }

  void _showReceiptProofDialog(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment Receipt Proof',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: OptimizedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: const Center(child: CircularProgressIndicator()),
                    errorWidget: const Center(
                      child: Text('Could not load receipt image.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesBookingTab(Map<String, dynamic> booking, String tabKey) {
    if (tabKey == 'extensions') {
      final ext = booking['extension_status']?.toString().toLowerCase().trim();
      return ext != null && ext.isNotEmpty && ext != 'none';
    }
    return bookingStatusGroup(booking['status']).name == tabKey;
  }

  String _bookingTabLabel(String tabKey) {
    switch (tabKey) {
      case 'pending':
        return 'Pending';
      case 'extensions':
        return 'Extend Trips';
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

  String _formatDateShort(String? raw) {
    if (raw == null || raw.isEmpty) return 'N/A';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
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

      final bookingStatus =
          booking['status']?.toString().trim().toLowerCase() ?? '';
      const activeChatStatuses = {
        'approved',
        'confirmed',
        'active',
        'ongoing',
        'return_pending_inspection',
        'awaiting_completion',
        'completed',
      };

      if (conversation == null) {
        if (!activeChatStatuses.contains(bookingStatus)) {
          _showErrorSnackBar(
            'Chat will be available once the booking is confirmed.',
          );
          return;
        }
        if (!BookingService().isEligibleForBookingChat(booking)) {
          _showErrorSnackBar(
            'Chat will automatically be available 3 days before the trip starts.',
          );
          return;
        }
        if (partnerId != null && renterId.isNotEmpty) {
          conversation = await chatService.createGroupConversation(
            bookingId: bookingId,
            participantIds: [partnerId!, renterId],
          );
        }
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
        if (inspectionType == 'before' && !BookingInspectionService.isPreInspectionUnlocked(booking)) {
          final unlockTime = BookingInspectionService.getPreInspectionUnlockTime(booking);
          final timeStr = unlockTime != null
              ? DateFormat('MMM d, yyyy h:mm a').format(unlockTime)
              : '24 hours before trip start';
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.darkBgSecondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock_clock_rounded, color: Color(0xFFE5A93C)),
                  SizedBox(width: 10),
                  Text('Pre-Checklist Locked', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Text(
                'The Pre-Trip Checklist & Car Inspection is locked until 24 hours before the actual booking start time.\n\nAvailable starting: $timeStr',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: Color(0xFFE5A93C))),
                ),
              ],
            ),
          );
          return;
        }

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

      final bookingStatus =
          booking['status']?.toString().trim().toLowerCase() ?? '';
      const activeChatStatuses = {
        'approved',
        'confirmed',
        'active',
        'ongoing',
        'return_pending_inspection',
        'awaiting_completion',
        'completed',
      };

      if (conversation == null &&
          activeChatStatuses.contains(bookingStatus) &&
          BookingService().isEligibleForBookingChat(booking) &&
          partnerId != null &&
          renterId.isNotEmpty) {
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
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TripRatingFlowScreen(
          bookingId: bookingId,
          reviewerRole: 'partner',
          title: 'Rate Trip',
          subtitle:
              'Rate the renter and driver for this trip.',
        ),
      ),
    );
    if (submitted == true) {
      final actorId = AuthService().currentUser?.id;
      final reconciled = await TripRatingService().reconcileCompletedBooking(
        bookingId,
        operatorFallbackUserId: actorId,
      );
      await _loadPartnerData();
      if (!mounted) return;
      _showSuccessSnackBar(
        reconciled
            ? 'Rating saved. Trip completed and revenue updated.'
            : 'Rating saved. Waiting for remaining required reviews.',
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
    final canAssignDriver = withDriver &&
        (status == 'pending' ||
            status == 'driver_accepted' ||
            status == 'approved' ||
            status == 'confirmed');

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
              onReviewDocs: () =>
                  _openPartnerBookingSafetyReview(pageContext, booking),
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
              onRateTrip: (completionStage == 'partner_rating' ||
                      status == 'completed' ||
                      status == 'returned' ||
                      status == 'return_inspected')
                  ? () => _openPartnerRenterRating(parentContext, booking)
                  : null,
              onReceipt: () => BookingReceiptService.shareReceipt(booking),
            ),
          ),
        ),
      ),
    );
  }

  /// 🚗 Open dedicated screen for Renter Safety Review & Documents
  void _openPartnerBookingSafetyReview(
    BuildContext context,
    Map<String, dynamic> booking,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartnerSafetyReviewScreen(booking: booking),
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

  Future<bool?> _showPartnerReleasePaymentSettlementDialog(
    BuildContext context,
    Map<String, dynamic> currentBooking,
    double remainingBalance,
  ) async {
    final bookingId = currentBooking['id']?.toString() ?? '';
    final partnerId = AuthService().currentUser?.id ?? '';
    String selectedMethod = 'Cash';
    final refController = TextEditingController(text: 'CASH-HANDOVER');
    final notesController = TextEditingController();
    bool isSettling = false;

    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.darkBgSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderColor),
          ),
          title: const Row(
            children: [
              Icon(Icons.point_of_sale_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Settle Remaining Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Balance to Settle:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white70)),
                      Text(
                        'PHP ${formatAmount(remainingBalance, decimalDigits: 2)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  dropdownColor: AppColors.darkBgSecondary,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash Handover at Pickup')),
                    DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                    DropdownMenuItem(value: 'Maya', child: Text('Maya / PayMaya')),
                    DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (BDO/BPI/QR Ph)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedMethod = val;
                        if (val == 'Cash') {
                          refController.text = 'CASH-HANDOVER';
                        } else if (refController.text == 'CASH-HANDOVER') {
                          refController.text = '';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Payment Reference / Transaction ID *',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    hintText: 'e.g. CASH-HANDOVER or GCash Ref #',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks (Optional)',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    hintText: 'e.g. Collected remaining rental payment at key handover',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSettling ? null : () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSettling
                  ? null
                  : () async {
                      final ref = refController.text.trim();
                      if (ref.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please provide a payment reference or receipt ID.')),
                        );
                        return;
                      }
                      setDialogState(() => isSettling = true);
                      try {
                        await BookingService().settleReleasePayment(
                          bookingId: bookingId,
                          actorId: partnerId,
                          actorRole: 'partner',
                          paymentMethod: selectedMethod,
                          paymentReference: ref,
                          notes: notesController.text.trim(),
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                      } catch (e) {
                        setDialogState(() => isSettling = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to settle payment: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              child: isSettling
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Confirm Payment Received', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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

    var currentBookingData = Map<String, dynamic>.from(booking);

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
        builder: (sheetContext, setSheetState) {
          final isFullyPaid = BookingService().isBookingFullyPaid(currentBookingData);
          final remainingBalance = BookingService().getBookingRemainingBalance(currentBookingData);

          return SafeArea(
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
                  if (inspectionType == 'before') ...[
                    if (isFullyPaid) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '100% Fully Paid (PHP 0.00 balance) • Ready for key release',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Unpaid Balance: PHP ${formatAmount(remainingBalance, decimalDigits: 2)}',
                                    style: const TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Full payment is strictly required before handing over vehicle keys. Settle balance below to unlock release.',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final settled = await _showPartnerReleasePaymentSettlementDialog(
                                  sheetContext,
                                  currentBookingData,
                                  remainingBalance,
                                );
                                if (settled == true) {
                                  final updated = await BookingService().getBookingById(bookingId);
                                  if (updated != null) {
                                    setSheetState(() => currentBookingData = updated);
                                  }
                                }
                              },
                              icon: const Icon(Icons.payments_outlined, size: 16),
                              label: const Text('Settle Remaining Balance with Renter'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  DialogStatusIndicator(
                    compact: true,
                    isComplete:
                        fuelController.text.trim().isNotEmpty &&
                        tiresController.text.trim().isNotEmpty &&
                        magsController.text.trim().isNotEmpty &&
                        releasedByController.text.trim().isNotEmpty &&
                        receivedByController.text.trim().isNotEmpty &&
                        selectedEvidence.isNotEmpty,
                    completeLabel: 'Inspection information complete',
                    incompleteLabel: 'Inspection information incomplete',
                    completeDetail:
                        'Required fields and photo evidence are ready. Checklist items are optional.',
                    incompleteDetail:
                        'Fill in required condition fields (fuel, tires, mags, names) and attach at least one photo or video.',
                  ),
                  const SizedBox(height: 12),
                  // Informative checklist banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 15, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            inspectionType == 'before'
                                ? 'Pre-trip checklist items are optional. Check only items that apply and are in working condition. Unchecked items will be recorded as existing defects.'
                                : 'Post-trip checklist items are optional. Check only items that apply — unchecked items will be flagged as issues for review. This determines security deposit refund eligibility.',
                            style: const TextStyle(fontSize: 11, color: Colors.blue, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          .toList();
                      setSheetState(() {
                        final existingNames =
                            selectedEvidence.map((f) => f.name).toSet();
                        for (final file in usableFiles) {
                          if (!existingNames.contains(file.name) &&
                              selectedEvidence.length < 10) {
                            selectedEvidence.add(file);
                            existingNames.add(file.name);
                          }
                        }
                      });
                    },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      selectedEvidence.isEmpty
                          ? 'Add photos or videos (4 to 5 images recommended)'
                          : 'Add more photos/videos (${selectedEvidence.length} selected)',
                    ),
                  ),
                  if (selectedEvidence.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedEvidence
                          .map(
                            (file) => InputChip(
                              avatar: const Icon(Icons.image_outlined, size: 16),
                              label: Text(file.name),
                              onDeleted: () => setSheetState(
                                () => selectedEvidence.remove(file),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (inspectionType == 'before' && !isFullyPaid) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cannot release vehicle keys: Full payment of PHP ${formatAmount(remainingBalance, decimalDigits: 2)} is required before handover. Please settle balance first.',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        final requiredFieldsReady =
                            fuelController.text.trim().isNotEmpty &&
                            tiresController.text.trim().isNotEmpty &&
                            magsController.text.trim().isNotEmpty &&
                            releasedByController.text.trim().isNotEmpty &&
                            receivedByController.text.trim().isNotEmpty;

                        if (!requiredFieldsReady || selectedEvidence.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please fill in condition fields (fuel, tires, mags, names) and attach at least one photo or video.',
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
        );
        },
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
      final filesToUpload = selectedEvidence
          .where((file) => file.bytes != null)
          .map((file) => (bytes: file.bytes!, extension: file.extension ?? 'jpg'))
          .toList();
      final evidenceUrls = await BookingInspectionService()
          .uploadMultipleEvidenceBytes(
            userId: currentUserId,
            bookingId: bookingId,
            files: filesToUpload,
          );
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
        _showSuccessSnackBar(
          'Release checklist submitted. The trip is now ongoing.',
        );
      } else {
        final bookingData =
            await BookingService().getBookingById(bookingId) ?? booking;
        final isFullyPaid = BookingService().isBookingFullyPaid(bookingData);
        final remainingBalance =
            BookingService().getBookingRemainingBalance(bookingData);
        final lateReturn =
            BookingService().getLateReturnDetails(bookingData, DateTime.now());
        final lateReturnFee =
            (lateReturn['late_return_fee'] as num?)?.toDouble() ?? 0.0;
        final lateHours =
            (lateReturn['late_return_hours'] as num?)?.toInt() ?? 0;

        final hasChargesOrViolations =
            lateReturnFee > 0 || remainingBalance > 0 || !isFullyPaid;
        bool confirmPaymentNow = false;

        if (hasChargesOrViolations) {
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
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Late Fee & Balance Settlement',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lateReturnFee > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5C5C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFF5C5C).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Late Return Penalty ($lateHours hr${lateHours == 1 ? '' : 's'}):',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'PHP ${formatAmount(lateReturnFee, decimalDigits: 2)}',
                            style: const TextStyle(
                              color: Color(0xFFFF5C5C),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (remainingBalance > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Unpaid Rental Balance:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'PHP ${formatAmount(remainingBalance, decimalDigits: 2)}',
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Text(
                    'The renter has additional charges or late return fees. Settle and confirm payment to complete this return.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 'cancel'),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, 'proceed_unpaid'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    foregroundColor: Colors.orange,
                  ),
                  child: const Text('Proceed (Stay Awaiting Payment)'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, 'confirm_payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Settle & Complete Return'),
                ),
              ],
            ),
          );

          if (choice == 'cancel' || choice == null) return;
          if (choice == 'confirm_payment') {
            confirmPaymentNow = true;
          }
        } else {
          // No late return fee and fully paid -> completes automatically without showing payment window!
          confirmPaymentNow = true;
        }

        await BookingService().completeBookingAfterInspection(
          bookingId: bookingId,
          inspectorId: currentUserId,
          confirmPaymentIfUnpaid: confirmPaymentNow,
        );

        if (!mounted) return;
        _showSuccessSnackBar(
          (!hasChargesOrViolations || confirmPaymentNow)
              ? 'Return checklist submitted. Trip completed successfully!'
              : 'Return checklist submitted. Trip is awaiting late fee / balance payment confirmation.',
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

  String _partnerVehicleTitle(Map<String, dynamic>? vehicle) {
    if (vehicle == null) return 'Partner Vehicle';
    final name = vehicle['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final parts = [
      vehicle['brand'] ?? vehicle['make'],
      vehicle['model'],
      vehicle['year'],
    ].where((p) => p != null && p.toString().trim().isNotEmpty).map((p) => p.toString().trim()).toList();
    if (parts.isNotEmpty) return parts.join(' ');
    return vehicle['plate_number']?.toString().trim().isNotEmpty == true
        ? 'Vehicle (${vehicle['plate_number']})'
        : 'Partner Vehicle';
  }

  Future<List<Map<String, double>>> _resolvePartnerBookingVehicleAndProximityTargets(
    Map<String, dynamic> booking,
  ) async {
    final targets = <Map<String, double>>[];
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final vehicleId = vehicle['id']?.toString() ?? booking['vehicle_id']?.toString() ?? '';
    final renter = booking['users'] as Map<String, dynamic>? ?? booking['renter'] as Map<String, dynamic>? ?? {};

    void addValidPoint(MobilisMapPoint? point) {
      if (point == null || !PhilippineGeocoding.isValidPhilippines(point)) return;
      final duplicate = targets.any(
        (target) =>
            (target['latitude']! - point.latitude).abs() < 0.0001 &&
            (target['longitude']! - point.longitude).abs() < 0.0001,
      );
      if (!duplicate) {
        targets.add({'latitude': point.latitude, 'longitude': point.longitude});
      }
    }

    // 1. Check vehicle_trackers table for live GPS hardware fix
    if (vehicleId.isNotEmpty) {
      try {
        final trackerRows = await Supabase.instance.client
            .from('vehicle_trackers')
            .select('latitude, longitude, last_location_update')
            .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
            .order('last_location_update', ascending: false)
            .limit(1);
        final list = List<Map<String, dynamic>>.from(trackerRows);
        if (list.isNotEmpty) {
          addValidPoint(PhilippineGeocoding.parseCoordinate(
            list.first['latitude'],
            list.first['longitude'],
          ));
        }
      } catch (err) {
        debugPrint('Partner vehicle tracker lookup note: $err');
      }

      // 2. Check tracking_locations table
      if (targets.isEmpty) {
        try {
          final locRows = await Supabase.instance.client
              .from('tracking_locations')
              .select('latitude, longitude, recorded_at')
              .eq('vehicle_id', vehicleId)
              .order('recorded_at', ascending: false)
              .limit(1);
          final list = List<Map<String, dynamic>>.from(locRows);
          if (list.isNotEmpty) {
            addValidPoint(PhilippineGeocoding.parseCoordinate(
              list.first['latitude'],
              list.first['longitude'],
            ));
          }
        } catch (err) {
          debugPrint('Partner tracking locations lookup note: $err');
        }
      }
    }

    // 3. Resolve vehicle registered location
    final vehLoc = vehicle['location']?.toString() ?? '';
    final vehPoint = await PhilippineGeocoding.resolveLocation(
      vehLoc,
      latitudeValue: vehicle['latitude'],
      longitudeValue: vehicle['longitude'],
    );
    addValidPoint(vehPoint);

    // 4. Resolve pickup location (Plus Code or city)
    final pickup = booking['pickup_location']?.toString() ?? '';
    final pickupPoint = await PhilippineGeocoding.resolveLocation(
      pickup,
      latitudeValue: booking['pickup_latitude'],
      longitudeValue: booking['pickup_longitude'],
    );
    addValidPoint(pickupPoint);

    // 5. Resolve renter location
    final renterLoc = renter['location']?.toString() ?? renter['address']?.toString() ?? '';
    if (renterLoc.isNotEmpty || renter['latitude'] != null) {
      addValidPoint(await PhilippineGeocoding.resolveLocation(
        renterLoc,
        latitudeValue: renter['latitude'],
        longitudeValue: renter['longitude'],
      ));
    }

    if (targets.isEmpty) {
      targets.add({
        'latitude': PhilippineGeocoding.defaultLat,
        'longitude': PhilippineGeocoding.defaultLng,
      });
    }

    return targets;
  }

  Widget _buildPartnerDriverCoverageSummary({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> vehicle,
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, double>> mapTargets,
    String? selectedDriverId,
    bool isRefreshing = false,
    DateTime? lastUpdated,
    VoidCallback? onRefreshTap,
    void Function(String driverId, int driverIndex)? onDriverMarkerTap,
    VoidCallback? onEnlargeTap,
  }) {
    final unitName = _partnerVehicleTitle(vehicle);

    final mapMarkers = <MobilisMapMarker>[
      // ── ONLY ONE Car marker: the booked partner vehicle at its tracker/location ──
      if (mapTargets.isNotEmpty)
        MobilisMapMarker(
          latitude: mapTargets.first['latitude']!,
          longitude: mapTargets.first['longitude']!,
          icon: Icons.directions_car_filled_rounded,
          color: AppColors.primary,
          size: 38,
          label: unitName.isNotEmpty ? unitName : 'Vehicle',
          tooltip: unitName.isNotEmpty ? '$unitName (GPS Tracker)' : 'Partner vehicle',
        ),

      // ── Driver markers ──
      ...drivers.take(12).toList().asMap().entries.expand((entry) {
        final driverIndex = entry.key;
        final driver = entry.value;
        final user = driver['users'] as Map<String, dynamic>? ?? {};

        final rawLocation = user['location'] ?? user['address'] ?? user['city'] ?? driver['address'] ?? '';
        final point = PhilippineGeocoding.resolveLocationSync(
          rawLocation,
          latitudeValue: user['latitude'] ?? driver['latitude'],
          longitudeValue: user['longitude'] ?? driver['longitude'],
        );

        if (!PhilippineGeocoding.isValidPhilippines(point)) return const <MobilisMapMarker>[];

        final driverId = driver['id']?.toString() ?? '';
        final driverName = (user['full_name']?.toString().trim().isNotEmpty == true)
            ? user['full_name'].toString().trim()
            : (user['email']?.toString().split('@').first ?? 'Driver');
        final isSelected = selectedDriverId == driverId;
        final isPsdcDriver =
            driver['is_psdc_driver'] == true ||
            user['is_psdc_driver'] == true ||
            driver['driver_tier']?.toString().toLowerCase() == 'psdc';

        final markerColor = isSelected
            ? AppColors.primary
            : isPsdcDriver
                ? const Color(0xFFD97706)
                : AppColors.success;

        final driverWidget = SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: markerColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : isPsdcDriver
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF0EA5E9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.sports_motorsports_rounded,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
            ],
          ),
        );

        return [
          MobilisMapMarker(
            latitude: point.latitude,
            longitude: point.longitude,
            icon: Icons.person_pin_circle_rounded,
            color: markerColor,
            size: 34,
            label: driverName,
            tooltip: driverName,
            customChild: driverWidget,
            onTap: onDriverMarkerTap == null
                ? null
                : () => onDriverMarkerTap(driverId, driverIndex),
          ),
        ];
      }),
    ];

    return Container(
      height: 190,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderOf(context)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: MobilisLeafletMap(
              key: ValueKey(
                'partner_map_${selectedDriverId ?? ''}_${mapMarkers.map((m) => '${m.latitude.toStringAsFixed(4)},${m.longitude.toStringAsFixed(4)}').join('|')}',
              ),
              markers: mapMarkers,
              initialZoom: mapMarkers.length > 1 ? 11 : 13,
            ),
          ),
          // Live tracker indicator chip
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isRefreshing ? AppColors.primary : const Color(0xFF10B981)).withValues(alpha: 0.5),
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PartnerLivePulseDot(
                    color: isRefreshing ? AppColors.primary : const Color(0xFF10B981),
                    size: 6,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isRefreshing ? 'REFRESHING GPS...' : 'LIVE GPS (8s)',
                    style: TextStyle(
                      color: isRefreshing ? AppColors.primary : const Color(0xFF10B981),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onEnlargeTap != null)
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onEnlargeTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_full_rounded, color: AppColors.primary, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'Enlarge Map',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
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

  void _showEnlargedPartnerDriverMapDialog({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> vehicle,
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, double>> mapTargets,
    String? selectedDriverId,
    required void Function(String? driverId) onSelectDriver,
    required void Function(String driverId) onFinalize,
  }) {
    showDialog(
      context: context,
      builder: (context) => _PartnerEnlargedDriverMapDialog(
        booking: booking,
        vehicle: vehicle,
        initialDrivers: drivers,
        initialMapTargets: mapTargets,
        initialSelectedDriverId: selectedDriverId,
        state: this,
        onSelectDriver: onSelectDriver,
        onFinalize: onFinalize,
      ),
    );
  }

  void _showDriverAssignmentModal(
    BuildContext context,
    Map<String, dynamic> booking,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _PartnerAssignDriverModal(
        booking: booking,
        state: this,
        onAssignDriver: (driverId) {
          _performAssignDriver(booking, driverId);
        },
      ),
    );
  }

  Future<void> _performAssignDriver(
    Map<String, dynamic> booking,
    String driverId,
  ) async {
    final bookingService = BookingService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await bookingService.assignDriver(
        booking['id'],
        driverId,
        0.0,
      );

      booking['driver_id'] = driverId;
      booking['driver_assigned_at'] = DateTime.now().toIso8601String();

      if (!mounted) return;
      Navigator.pop(context); // Close loader

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Driver job offer requested! Waiting for driver confirmation.'),
          backgroundColor: AppColors.success,
        ),
      );

      setState(() {});
      _loadPartnerData();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error assigning driver: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
      final withDriver = booking['with_driver'] == true;
      final driverId = booking['driver_id']?.toString().trim();
      final status = (booking['status']?.toString() ?? '').trim().toLowerCase();

      if (withDriver) {
        if (driverId == null || driverId.isEmpty) {
          throw Exception('Please assign a driver before approving this booking.');
        }
        if (status != 'driver_accepted' && status != 'confirmed' && status != 'approved') {
          throw Exception('Waiting for the assigned driver to accept the job offer first.');
        }
      }

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
    final reasonController = TextEditingController();

    final payState = resolveBookingPaymentState(booking);
    final hasPaidFunds = payState == BookingPaymentState.paid ||
        payState == BookingPaymentState.pendingConfirmation ||
        payState == BookingPaymentState.paymentReview;

    final confirmedReason = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Booking', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPaidFunds) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment Alert: The renter has submitted or completed payment. Declining will initiate a refund requirement.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Text(
              'Please provide a reason for declining this booking request.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g., Vehicle unavailable for scheduled dates',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final r = reasonController.text.trim();
              Navigator.pop(dialogCtx, r.isNotEmpty ? r : 'Declined by vehicle owner');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmedReason == null || !mounted) return;
    final reason = confirmedReason;
    final bookingId = booking['id']?.toString() ?? '';
    final currentPartnerId = partnerId ?? AuthService().currentUser?.id;

    // Pop the booking detail modal immediately so the user returns to the list with 0 latency
    Navigator.of(context).pop();

    // ⚡ Optimistic UI update in the list
    final bookingIndex =
        bookings.indexWhere((b) => b['id']?.toString() == bookingId);
    final originalBooking = bookingIndex != -1
        ? Map<String, dynamic>.from(bookings[bookingIndex])
        : null;

    if (bookingIndex != -1) {
      setState(() {
        final target = Map<String, dynamic>.from(bookings[bookingIndex]);
        target['status'] = 'rejected';
        target['rejection_reason'] = reason;
        target['partner_booking_rejected_at'] = DateTime.now().toIso8601String();
        bookings[bookingIndex] = target;

        bookingCounts['pending'] =
            ((bookingCounts['pending'] ?? 1) - 1).clamp(0, 999999);
        bookingCounts['cancelled'] =
            (bookingCounts['cancelled'] ?? 0) + 1;
      });
    }

    _showSuccessSnackBar('Booking declined');

    try {
      if (currentPartnerId != null) {
        await BookingService().rejectPartnerBooking(
          bookingId: bookingId,
          partnerId: currentPartnerId,
          reason: reason,
          cachedBooking: booking,
        );
      } else {
        await BookingService().rejectBooking(
          bookingId,
          reason,
          cachedBooking: booking,
        );
      }

      _loadPartnerData(silent: true);
    } catch (e) {
      debugPrint('Partner booking rejection error: $e');
      if (originalBooking != null && bookingIndex != -1 && mounted) {
        setState(() {
          bookings[bookingIndex] = originalBooking;
          bookingCounts['pending'] = (bookingCounts['pending'] ?? 0) + 1;
          bookingCounts['cancelled'] =
              ((bookingCounts['cancelled'] ?? 1) - 1).clamp(0, 999999);
        });
      }
      _showErrorSnackBar('Failed to decline booking: $e');
    }
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
      onOpenVerification: () => Navigator.pushNamed(
        context,
        '/owner-verification',
        arguments: const {'viewSubmittedDocuments': true},
      ),
      onProfileUpdated: _loadPartnerData,
      stats: [
        ProfileStatItem(
          label: 'Fleet',
          value: trackingLocations.length.toString(),
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
/// 🎯 Booking Detail Modal Widget (Upgraded with Rich Details & Driver Offer Status)
class BookingDetailModal extends StatefulWidget {
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
  final VoidCallback? onRefresh;
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
    this.onRefresh,
    this.showHeader = true,
  });

  @override
  State<BookingDetailModal> createState() => _BookingDetailModalState();
}

class _BookingDetailModalState extends State<BookingDetailModal> {
  Map<String, dynamic> get booking => widget.booking;
  Map<String, dynamic>? get vehicle => widget.vehicle ?? booking['vehicles'] as Map<String, dynamic>?;
  Map<String, dynamic>? get renter => widget.renter ?? booking['users'] as Map<String, dynamic>?;

  Future<void> _callPhone(String? phone) async {
    final clean = phone?.trim() ?? '';
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial phone: $clean')),
      );
    }
  }

  String _formatDateTime(dynamic dt) {
    if (dt == null) return 'N/A';
    final parsed = DateTime.tryParse(dt.toString());
    if (parsed == null) return dt.toString();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[parsed.month - 1];
    final day = parsed.day.toString().padLeft(2, '0');
    final year = parsed.year;
    final hour24 = parsed.hour;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    return '$month $day, $year • $hour12:$minute $period';
  }

  String _formatDuration(Map<String, dynamic> b) {
    final start = DateTime.tryParse((b['start_at'] ?? b['start_date'])?.toString() ?? '');
    final end = DateTime.tryParse((b['end_at'] ?? b['end_date'])?.toString() ?? '');
    if (start == null || end == null) return '1 Day';
    final diff = end.difference(start);
    final hours = diff.inHours;
    if (hours < 24) {
      return hours <= 0 ? '1 Day' : '$hours Hours (Hourly)';
    }
    final days = (hours / 24).ceil();
    return days == 1 ? '1 Day' : '$days Days';
  }

  Widget _buildPaymentStateBadge(Map<String, dynamic> b) {
    final state = resolveBookingPaymentState(b);
    final color = bookingPaymentStateColor(state);
    final label = bookingPaymentStateLabel(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status, {String? assignmentStatus}) {
    final s = status.trim().toLowerCase();
    final a = assignmentStatus?.trim().toLowerCase();
    if (s == 'driver_accepted' || a == 'accepted') return Colors.cyan;
    if (s == 'pending' || a == 'pending_offer' || a == 'assigned') return Colors.amber.shade700;
    if (s == 'approved' || s == 'confirmed') return AppColors.success;
    if (s == 'active' || s == 'ongoing') return AppColors.primary;
    if (s == 'completed' || s == 'returned') return Colors.blue;
    return Colors.redAccent;
  }

  String _statusLabel(String status, {String? assignmentStatus}) {
    final s = status.trim().toLowerCase();
    final a = assignmentStatus?.trim().toLowerCase();
    if (s == 'driver_accepted' || a == 'accepted') return 'DRIVER ACCEPTED';
    if (a == 'pending_offer') return 'OFFER SENT • WAITING DRIVER';
    if (a == 'rejected' || a == 'declined') return 'DRIVER DECLINED';
    if (s == 'pending') return 'PENDING';
    if (s == 'approved' || s == 'confirmed') return 'APPROVED';
    if (s == 'active' || s == 'ongoing') return 'ONGOING';
    if (s == 'completed' || s == 'returned') return 'COMPLETED';
    if (s == 'cancelled' || s == 'canceled' || s == 'rejected') return 'CANCELLED';
    return status.toUpperCase();
  }

  /// Masks an email address: "renter@psdc.com" → "ren***@*****.com"
  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];

    // Mask local part: show first 3 chars, rest as ***
    final maskedLocal = local.length <= 3
        ? local
        : '${local.substring(0, 3)}${'*' * (local.length - 3)}';

    // Mask domain: show extension (after last dot), mask the rest
    final dotIndex = domain.lastIndexOf('.');
    final maskedDomain = dotIndex > 0
        ? '${'*' * dotIndex}.${domain.substring(dotIndex + 1)}'
        : '*****';

    return '$maskedLocal@$maskedDomain';
  }

  /// Masks a phone number: "09123532512" → "091***32512" (first 3, stars, last 5)
  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return phone;
    final visible = 3;
    final tail = 5;
    final masked = digits.length - visible - tail;
    if (masked <= 0) return phone;
    return '${digits.substring(0, visible)}${'*' * masked}${digits.substring(digits.length - tail)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPrice = (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final withDriver = _bookingNeedsDriver(booking['with_driver']);
    final driverId = booking['driver_id']?.toString().trim();
    final status = (booking['status'] as String? ?? 'pending').toLowerCase();
    final bookingId = booking['id']?.toString() ?? '';
    final shortId = bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase();

    // Resolve driver job assignments
    final rawAssignments = booking['job_assignments'];
    final List<Map<String, dynamic>> assignments = (rawAssignments is List)
        ? rawAssignments
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : [];
    if (assignments.isNotEmpty) {
      assignments.sort((a, b) {
        final aDate = DateTime.tryParse((a['created_at'] ?? a['offered_at'])?.toString() ?? '');
        final bDate = DateTime.tryParse((b['created_at'] ?? b['offered_at'])?.toString() ?? '');
        return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
      });
    }
    final latestAssignment = assignments.isNotEmpty ? assignments.first : null;
    final assignmentStatus = latestAssignment?['status']?.toString().toLowerCase().trim();

    // Driver user info
    final driverMap = booking['driver'] as Map<String, dynamic>?;
    final driverUserMap = driverMap?['users'] as Map<String, dynamic>? ??
        booking['driver_user'] as Map<String, dynamic>?;
    final driverName = driverUserMap?['full_name']?.toString() ??
        latestAssignment?['driver_name']?.toString() ??
        'Assigned Driver';
    final driverPhone = driverUserMap?['phone']?.toString() ?? '';

    final hasDriver = driverId != null && driverId.isNotEmpty;
    final isWaitingDriverResponse = withDriver &&
        (assignmentStatus == 'pending_offer' ||
            assignmentStatus == 'assigned' ||
            (hasDriver && status == 'pending'));
    final isDriverAccepted = withDriver &&
        (status == 'driver_accepted' ||
            assignmentStatus == 'accepted' ||
            assignmentStatus == 'confirmed');
    final isDriverDeclined = withDriver &&
        (assignmentStatus == 'rejected' || assignmentStatus == 'declined');

    final startLabel = _formatDateTime(booking['start_at'] ?? booking['start_date']);
    final endLabel = _formatDateTime(booking['end_at'] ?? booking['end_date']);
    final durationLabel = _formatDuration(booking);

    final pickupLocation = booking['pickup_location']?.toString().trim();
    final dropoffLocation = booking['dropoff_location']?.toString().trim();

    final vehicleMap = booking['vehicles'] is Map
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    final vehicleTitle = vehicleMap['brand'] != null
        ? '${vehicleMap['brand']} ${vehicleMap['model'] ?? ''}'.trim()
        : (booking['vehicle_name']?.toString() ?? booking['vehicleTitle']?.toString() ?? 'Vehicle');
    final plateNumber = vehicleMap['plate_number']?.toString() ??
        booking['plate_number']?.toString() ??
        booking['plateNumber']?.toString();

    final badgeColor = _statusColor(status, assignmentStatus: assignmentStatus);
    final badgeText = _statusLabel(status, assignmentStatus: assignmentStatus);

    Widget detailContent({ScrollController? scrollController}) {
      return SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (when shown in bottom sheet)
            if (widget.showHeader) ...[
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
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 1. Overview & Status Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Reference',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '#$shortId',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildPaymentStateBadge(booking),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Vehicle Information Card
            if (vehicle != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.directions_car_filled_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}'.trim(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (vehicle?['plate_number'] != null &&
                                  vehicle!['plate_number'].toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Plate: ${vehicle!['plate_number']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.handshake_outlined, size: 12, color: Colors.purpleAccent),
                              const SizedBox(width: 4),
                              Text(
                                'PARTNER CAR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.purple[200] : Colors.purple[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (vehicle?['year'] != null)
                          _specBadge('Year: ${vehicle!['year']}', isDark),
                        if (vehicle?['transmission'] != null)
                          _specBadge(vehicle!['transmission'].toString(), isDark),
                        if (vehicle?['fuel_type'] != null)
                          _specBadge(vehicle!['fuel_type'].toString(), isDark),
                        if (vehicle?['seats'] != null)
                          _specBadge('${vehicle!['seats']} Seats', isDark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 3. Renter Information Card with Direct Call Button
            if (renter != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          child: Text(
                            (renter?['full_name']?.toString().isNotEmpty == true)
                                ? renter!['full_name'].toString().substring(0, 1).toUpperCase()
                                : 'R',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
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
                                      renter?['full_name'] ?? 'Rentee',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : Colors.black87,
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
                                      'VERIFIED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (renter?['email'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  renter!['email'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 4. Trip Route & Destinations Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Route',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      TripLocationMapDialog.show(
                        context: context,
                        booking: booking,
                        vehicleName: vehicleTitle,
                        plateNumber: plateNumber,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.trip_origin_rounded, size: 14, color: Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text(
                                      'Pickup Point',
                                      style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.map_rounded, size: 11, color: AppColors.primary),
                                    SizedBox(width: 2),
                                    Text(
                                      '(Tap for Map)',
                                      style: TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (pickupLocation != null && pickupLocation.isNotEmpty)
                                      ? pickupLocation
                                      : 'PSDC Hub / Designated Pickup Point',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
                    child: Container(
                      width: 2,
                      height: 14,
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      TripLocationMapDialog.show(
                        context: context,
                        booking: booking,
                        vehicleName: vehicleTitle,
                        plateNumber: plateNumber,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on_rounded, size: 16, color: Colors.redAccent),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text(
                                      'Destination / Drop-off Point',
                                      style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.map_rounded, size: 11, color: AppColors.primary),
                                    SizedBox(width: 2),
                                    Text(
                                      '(Tap for Map)',
                                      style: TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (dropoffLocation != null && dropoffLocation.isNotEmpty)
                                      ? dropoffLocation
                                      : 'Declared Destination Area',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 5. Rental Schedule & Duration Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Rental Schedule',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Duration: $durationLabel',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _scheduleBlock('Start Date', startLabel, isDark),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _scheduleBlock('End Date', endLabel, isDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 6. Driver Assignment & Job Offer Status Card (Primary Focus)
            if (withDriver) ...[
              if (isWaitingDriverResponse) ...[
                // Offer Sent & Waiting
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.amber.shade700, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hourglass_top_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Driver Job Offer Requested',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.amber,
                                  ),
                                ),
                                Text(
                                  'Selected: $driverName',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A job offer has been sent to the driver (10-minute response window). Once accepted, you can approve and finalize the booking. If unanswered after 10 minutes, it will auto-decline so you can reassign immediately.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.onAssignDriver != null)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget.onAssignDriver,
                            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                            label: const Text('Reassign / Change Driver'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.amber.shade700,
                              side: BorderSide(color: Colors.amber.shade700),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (isDriverAccepted) ...[
                // Driver Accepted!
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.green, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Driver Accepted the Job Offer!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  driverName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The driver accepted this trip assignment! You can now click Approve below to finalize this booking.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                      if (widget.onAssignDriver != null && status == 'pending') ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: widget.onAssignDriver,
                            icon: const Icon(Icons.swap_horiz, size: 14),
                            label: const Text('Change Driver'),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (isDriverDeclined) ...[
                // Driver Declined
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.redAccent, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cancel_rounded, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text(
                            'Driver Declined Job Offer',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'The previously requested driver was unavailable or declined this trip. Please assign another driver.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.onAssignDriver != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onAssignDriver,
                            icon: const Icon(Icons.person_search_rounded, size: 16),
                            label: const Text('Select Another Driver'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (driverId == null &&
                  (status == 'pending' || status == 'approved' || status == 'confirmed')) ...[
                // No Driver Assigned Yet
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.warning),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.drive_eta_rounded, color: AppColors.warning, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Professional Driver Required',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This reservation requires a certified driver. Select a driver from the verified pool to send a job offer.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onAssignDriver,
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                          label: const Text('Assign Driver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // 7. Total Price & Financial Breakdown Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Booking Price',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        withDriver ? 'Includes Vehicle & Driver' : 'Self-Drive Rental',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₱${formatAmount(totalPrice, decimalDigits: 2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 8. Quick Actions Row
            if (widget.onReviewDocs != null ||
                widget.onMessage != null ||
                widget.onBeforeInspection != null ||
                widget.onViewBeforeInspection != null ||
                widget.onAfterInspection != null ||
                widget.onReceipt != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.onReviewDocs != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        if (widget.showHeader) Navigator.pop(context);
                        widget.onReviewDocs?.call();
                      },
                      icon: const Icon(Icons.verified_user_outlined, size: 15),
                      label: const Text('Review Docs'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (widget.onMessage != null)
                    Builder(
                      builder: (context) {
                        final isChatEligible =
                            BookingService().isEligibleForBookingChat(widget.booking);
                        return OutlinedButton.icon(
                          onPressed: () {
                            if (widget.showHeader) Navigator.pop(context);
                            widget.onMessage?.call();
                          },
                          icon: Icon(
                            isChatEligible
                                ? Icons.chat_bubble_outline
                                : Icons.lock_clock,
                            size: 15,
                          ),
                          label: Text(
                            isChatEligible ? 'Message' : 'Chat (72h Prior)',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        );
                      },
                    ),
                  if (widget.onBeforeInspection != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onBeforeInspection?.call();
                      },
                      icon: const Icon(Icons.fact_check_outlined, size: 15),
                      label: const Text('Pre-Trip Inspection'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (widget.onViewBeforeInspection != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onViewBeforeInspection?.call();
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: const Text('View Pre-Trip Check'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (widget.onAfterInspection != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAfterInspection?.call();
                      },
                      icon: const Icon(Icons.assignment_turned_in_outlined, size: 15),
                      label: const Text('After Check'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (widget.onReceipt != null)
                    OutlinedButton.icon(
                      onPressed: widget.onReceipt,
                      icon: const Icon(Icons.download_rounded, size: 15),
                      label: const Text('Download Receipt'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (status == 'active' ||
                      status == 'ongoing' ||
                      status == 'return_pending_inspection' ||
                      status == 'completed' ||
                      status == 'returned' ||
                      status == 'return_inspected')
                    OutlinedButton.icon(
                      onPressed: () {
                        if (widget.showHeader) Navigator.pop(context);
                        TripRouteHistoryDialog.show(
                          context: context,
                          bookingId: bookingId,
                          vehicleName: vehicleTitle,
                          plateNumber: plateNumber,
                          renterName: renter?['full_name']?.toString(),
                        );
                      },
                      icon: const Icon(Icons.route_rounded, size: 15, color: AppColors.primary),
                      label: const Text('Audit Traveled Route & Playback'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // 9. Bottom Decision Actions (Approve / Reject)
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onReject,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onApprove,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        resolveBookingPaymentState(booking) == BookingPaymentState.pendingConfirmation
                            ? 'Confirm & Accept'
                            : 'Approve',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (widget.onConfirmPayment != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onConfirmPayment?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
            ] else if (widget.onRateTrip != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRateTrip?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.star_rate_rounded, size: 18),
                  label: const Text(
                    'Rate Trip',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    if (!widget.showHeader) {
      return detailContent();
    }

    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) =>
          detailContent(scrollController: scrollController),
    );
  }

  Widget _specBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _scheduleBlock(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Pulsing Dot for Partner GPS Tracker Status
// ─────────────────────────────────────────────────────────────────────────────
class _PartnerLivePulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PartnerLivePulseDot({
    this.color = const Color(0xFF10B981),
    this.size = 8,
  });

  @override
  State<_PartnerLivePulseDot> createState() => _PartnerLivePulseDotState();
}

class _PartnerLivePulseDotState extends State<_PartnerLivePulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.6),
                blurRadius: widget.size * 1.2,
                spreadRadius: widget.size * 0.4,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Partner Driver Assignment Modal with Live GPS Tracker Auto-Refresh
// ─────────────────────────────────────────────────────────────────────────────
class _PartnerAssignDriverModal extends StatefulWidget {
  final Map<String, dynamic> booking;
  final _PartnerHomeScreenState state;
  final void Function(String driverId) onAssignDriver;

  const _PartnerAssignDriverModal({
    required this.booking,
    required this.state,
    required this.onAssignDriver,
  });

  @override
  State<_PartnerAssignDriverModal> createState() =>
      _PartnerAssignDriverModalState();
}

class _PartnerAssignDriverModalState extends State<_PartnerAssignDriverModal> {
  String? _selectedDriverId;
  final ScrollController _listScrollController = ScrollController();
  Timer? _trackerTimer;
  List<Map<String, double>> _mapTargets = [
    {
      'latitude': PhilippineGeocoding.defaultLat,
      'longitude': PhilippineGeocoding.defaultLng,
    },
  ];
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoadingDrivers = true;
  bool _isRefreshingTracker = false;
  DateTime? _lastTrackerUpdate;

  @override
  void initState() {
    super.initState();
    _fetchDrivers(initial: true);

    // Continuous 8-second live GPS tracker auto-refresh
    _trackerTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollLiveTracker();
    });
  }

  @override
  void dispose() {
    _trackerTimer?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDrivers({bool initial = false}) async {
    final startDate = DateTime.tryParse(
      (widget.booking['start_at'] ?? widget.booking['start_date'])?.toString() ?? '',
    );
    final endDate = DateTime.tryParse(
      (widget.booking['end_at'] ?? widget.booking['end_date'])?.toString() ?? '',
    );
    final bookingId = widget.booking['id']?.toString();
    try {
      final refinedTargets =
          await widget.state._resolvePartnerBookingVehicleAndProximityTargets(widget.booking);
      if (mounted) {
        if (refinedTargets.isNotEmpty) {
          _mapTargets = refinedTargets;
        }
        final list = await BookingService().getAvailableVerifiedDrivers(
          bookingDate: startDate,
          startDate: startDate,
          endDate: endDate,
          excludeBookingId: bookingId,
          proximityTargets: _mapTargets,
          prioritizeProximity: true,
          prioritizePsdc: false,
        );
        if (mounted) {
          setState(() {
            _drivers = list;
            _isLoadingDrivers = false;
            _lastTrackerUpdate = DateTime.now();
          });
        }
      }
    } catch (e) {
      debugPrint('Partner driver fetch error: $e');
      if (mounted && initial) {
        setState(() => _isLoadingDrivers = false);
      }
    }
  }

  Future<void> _pollLiveTracker() async {
    if (!mounted || _isRefreshingTracker) return;
    setState(() => _isRefreshingTracker = true);
    final startDate = DateTime.tryParse(
      (widget.booking['start_at'] ?? widget.booking['start_date'])?.toString() ?? '',
    );
    final endDate = DateTime.tryParse(
      (widget.booking['end_at'] ?? widget.booking['end_date'])?.toString() ?? '',
    );
    final bookingId = widget.booking['id']?.toString();
    try {
      final refinedTargets =
          await widget.state._resolvePartnerBookingVehicleAndProximityTargets(widget.booking);
      if (mounted) {
        if (refinedTargets.isNotEmpty) {
          _mapTargets = refinedTargets;
        }
        final list = await BookingService().getAvailableVerifiedDrivers(
          bookingDate: startDate,
          startDate: startDate,
          endDate: endDate,
          excludeBookingId: bookingId,
          proximityTargets: _mapTargets,
          prioritizeProximity: true,
          prioritizePsdc: false,
        );
        if (mounted) {
          setState(() {
            _drivers = list;
            _lastTrackerUpdate = DateTime.now();
            _isRefreshingTracker = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Partner auto-refresh live tracker note: $e');
      if (mounted) {
        setState(() => _isRefreshingTracker = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.booking['vehicles'] as Map<String, dynamic>? ?? {};

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.airline_seat_recline_normal_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Assign Certified Driver',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Live tracker indicator chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (_isRefreshingTracker
                                        ? AppColors.primary
                                        : const Color(0xFF10B981))
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PartnerLivePulseDot(
                                  color: _isRefreshingTracker
                                      ? AppColors.primary
                                      : const Color(0xFF10B981),
                                  size: 6,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isRefreshingTracker
                                      ? 'REFRESHING GPS...'
                                      : 'LIVE GPS (8s)',
                                  style: TextStyle(
                                    color: _isRefreshingTracker
                                        ? AppColors.primary
                                        : const Color(0xFF10B981),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Drivers continuously ranked by GPS tracker proximity to ${widget.state._partnerVehicleTitle(vehicle)}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Drivers list & Map
          Expanded(
            child: _isLoadingDrivers
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : (_drivers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off_rounded,
                                color: AppColors.textSecondary,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No Available Certified Drivers',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All certified drivers are currently on active trips or unavailable.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _listScrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _drivers.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return widget.state._buildPartnerDriverCoverageSummary(
                              booking: widget.booking,
                              vehicle: vehicle,
                              drivers: _drivers,
                              mapTargets: _mapTargets,
                              selectedDriverId: _selectedDriverId,
                              isRefreshing: _isRefreshingTracker,
                              lastUpdated: _lastTrackerUpdate,
                              onRefreshTap: _pollLiveTracker,
                              onDriverMarkerTap: (driverId, driverIndex) {
                                final newId = (_selectedDriverId == driverId
                                    ? null
                                    : driverId);
                                setState(() => _selectedDriverId = newId);
                                if (newId != null &&
                                    _listScrollController.hasClients) {
                                  final targetIndex = driverIndex + 1;
                                  _listScrollController.animateTo(
                                    targetIndex * 80.0,
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOut,
                                  );
                                }
                              },
                              onEnlargeTap: () {
                                widget.state._showEnlargedPartnerDriverMapDialog(
                                  booking: widget.booking,
                                  vehicle: vehicle,
                                  drivers: _drivers,
                                  mapTargets: _mapTargets,
                                  selectedDriverId: _selectedDriverId,
                                  onSelectDriver: (driverId) {
                                    setState(() => _selectedDriverId = driverId);
                                  },
                                  onFinalize: (driverId) {
                                    Navigator.pop(context); // Close bottom sheet
                                    widget.onAssignDriver(driverId);
                                  },
                                );
                              },
                            );
                          }

                          final driver = _drivers[index - 1];
                          final driverId = driver['id'].toString();
                          final user =
                              driver['users'] as Map<String, dynamic>? ?? {};
                          final name = (user['full_name']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true)
                              ? user['full_name'].toString().trim()
                              : (user['email']
                                      ?.toString()
                                      .split('@')
                                      .first
                                      .toUpperCase() ??
                                  'Driver');
                          final isPsdcDriver =
                              driver['is_psdc_driver'] == true ||
                                  user['is_psdc_driver'] == true ||
                                  driver['driver_tier']
                                          ?.toString()
                                          .toLowerCase() ==
                                      'psdc';
                          final selected = _selectedDriverId == driverId;
                          final distance =
                              (driver['distance_km'] as num?)?.toDouble();
                          final rating =
                              (driver['rating'] as num?)?.toDouble() ?? 5.0;
                          final trips =
                              (driver['total_trips'] as num?)?.toInt() ?? 0;
                          final locationStr = user['location']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? user['location'].toString().trim()
                              : user['address']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? user['address'].toString().trim()
                                  : user['city']?.toString().trim() ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: InkWell(
                              onTap: () => setState(
                                () => _selectedDriverId =
                                    (_selectedDriverId == driverId
                                        ? null
                                        : driverId),
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.white.withValues(alpha: 0.08),
                                    width: selected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar + Badge
                                    SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? AppColors.primary
                                                  : (isPsdcDriver
                                                      ? const Color(0xFFD97706)
                                                      : const Color(0xFF0284C7)),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.person_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: isPsdcDriver
                                                    ? const Color(0xFFF59E0B)
                                                    : const Color(0xFF0EA5E9),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.sports_motorsports_rounded,
                                                color: Colors.white,
                                                size: 9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (isPsdcDriver)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF59E0B),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'PSDC',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              if (distance != null)
                                                '${distance.toStringAsFixed(1)} km away',
                                              '${rating.toStringAsFixed(1)} ★',
                                              '$trips trips',
                                              if (locationStr.isNotEmpty)
                                                locationStr,
                                            ].join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.circle_outlined,
                                      color: selected
                                          ? AppColors.primary
                                          : Colors.white30,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      )),
          ),

          // Bottom Action
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedDriverId == null
                        ? null
                        : () {
                            Navigator.pop(context);
                            widget.onAssignDriver(_selectedDriverId!);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Assign Driver',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

// ─────────────────────────────────────────────────────────────────────────────
// Partner Enlarged Driver Proximity Map Dialog with Live Tracker Polling
// ─────────────────────────────────────────────────────────────────────────────
class _PartnerEnlargedDriverMapDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> vehicle;
  final List<Map<String, dynamic>> initialDrivers;
  final List<Map<String, double>> initialMapTargets;
  final String? initialSelectedDriverId;
  final _PartnerHomeScreenState state;
  final void Function(String? driverId) onSelectDriver;
  final void Function(String driverId) onFinalize;

  const _PartnerEnlargedDriverMapDialog({
    required this.booking,
    required this.vehicle,
    required this.initialDrivers,
    required this.initialMapTargets,
    this.initialSelectedDriverId,
    required this.state,
    required this.onSelectDriver,
    required this.onFinalize,
  });

  @override
  State<_PartnerEnlargedDriverMapDialog> createState() =>
      _PartnerEnlargedDriverMapDialogState();
}

class _PartnerEnlargedDriverMapDialogState
    extends State<_PartnerEnlargedDriverMapDialog> {
  late String? _activeSelectedId;
  String _searchQuery = '';
  late List<Map<String, double>> _mapTargets;
  late List<Map<String, dynamic>> _drivers;
  Timer? _trackerTimer;
  bool _isRefreshing = false;
  DateTime? _lastTrackerUpdate;

  @override
  void initState() {
    super.initState();
    _activeSelectedId = widget.initialSelectedDriverId;
    _mapTargets = List.from(widget.initialMapTargets);
    _drivers = List.from(widget.initialDrivers);
    _lastTrackerUpdate = DateTime.now();

    // Constant live tracker polling every 8 seconds
    _trackerTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollLiveTracker();
    });
  }

  @override
  void dispose() {
    _trackerTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollLiveTracker() async {
    if (!mounted || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    final startDate = DateTime.tryParse(
      (widget.booking['start_at'] ?? widget.booking['start_date'])?.toString() ?? '',
    );
    final endDate = DateTime.tryParse(
      (widget.booking['end_at'] ?? widget.booking['end_date'])?.toString() ?? '',
    );
    final bookingId = widget.booking['id']?.toString();
    try {
      final refinedTargets =
          await widget.state._resolvePartnerBookingVehicleAndProximityTargets(widget.booking);
      if (mounted) {
        if (refinedTargets.isNotEmpty) {
          _mapTargets = refinedTargets;
        }
        final list = await BookingService().getAvailableVerifiedDrivers(
          bookingDate: startDate,
          startDate: startDate,
          endDate: endDate,
          excludeBookingId: bookingId,
          proximityTargets: _mapTargets,
          prioritizeProximity: true,
          prioritizePsdc: false,
        );
        if (mounted) {
          setState(() {
            _drivers = list;
            _lastTrackerUpdate = DateTime.now();
            _isRefreshing = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Partner enlarged map tracker poll error: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitName = widget.state._partnerVehicleTitle(widget.vehicle);
    final plate = widget.vehicle['plate_number']?.toString() ?? '';
    final pickup = widget.booking['pickup_location']?.toString().trim() ?? '';

    final filteredDrivers = _drivers.where((d) {
      if (_searchQuery.trim().isEmpty) return true;
      final user = d['users'] as Map<String, dynamic>? ?? {};
      final name = user['full_name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      final loc = user['location']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase().trim();
      return name.contains(q) || email.contains(q) || loc.contains(q);
    }).toList();

    final enlargedMapMarkers = <MobilisMapMarker>[
      // ── ONLY ONE Car marker: the booked vehicle at its tracker/location ──
      if (_mapTargets.isNotEmpty)
        MobilisMapMarker(
          latitude: _mapTargets.first['latitude']!,
          longitude: _mapTargets.first['longitude']!,
          icon: Icons.directions_car_filled_rounded,
          color: AppColors.primary,
          size: 44,
          label: unitName.isNotEmpty ? unitName : 'Vehicle',
          tooltip: unitName.isNotEmpty ? '$unitName (GPS Tracker)' : 'Vehicle',
        ),

      // Driver pins
      ..._drivers.map((driver) {
        final user = driver['users'] as Map<String, dynamic>? ?? {};
        final rawLocation = user['location'] ??
            user['address'] ??
            user['city'] ??
            driver['address'] ??
            '';
        final point = PhilippineGeocoding.resolveLocationSync(
          rawLocation,
          latitudeValue: user['latitude'] ?? driver['latitude'],
          longitudeValue: user['longitude'] ?? driver['longitude'],
        );

        if (!PhilippineGeocoding.isValidPhilippines(point)) {
          return const MobilisMapMarker(latitude: 0, longitude: 0);
        }

        final driverId = driver['id']?.toString() ?? '';
        final driverName = (user['full_name']?.toString().trim().isNotEmpty == true)
            ? user['full_name'].toString().trim()
            : (user['email']?.toString().split('@').first ?? 'Driver');
        final isSelected = _activeSelectedId == driverId;
        final isPsdcDriver = driver['is_psdc_driver'] == true ||
            user['is_psdc_driver'] == true ||
            driver['driver_tier']?.toString().toLowerCase() == 'psdc';

        final markerColor = isSelected
            ? AppColors.primary
            : isPsdcDriver
                ? const Color(0xFFD97706)
                : AppColors.success;

        final driverWidget = SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: markerColor.withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: isSelected ? 3 : 1,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 3.0 : 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : isPsdcDriver
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF0EA5E9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.sports_motorsports_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            ],
          ),
        );

        return MobilisMapMarker(
          latitude: point.latitude,
          longitude: point.longitude,
          icon: Icons.person_pin_circle_rounded,
          color: markerColor,
          size: 40,
          label: driverName,
          tooltip: driverName,
          customChild: driverWidget,
          onTap: () {
            final newId = (_activeSelectedId == driverId ? null : driverId);
            setState(() => _activeSelectedId = newId);
            widget.onSelectDriver(newId);
          },
        );
      }).where((m) => m.latitude != 0).toList(),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1100,
          maxHeight: 760,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.modalBgOf(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadowOf(context),
            border: Border.all(color: AppColors.modalBorderOf(context)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.map_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Partner Driver Proximity Map',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unitName,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Live indicator badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (_isRefreshing
                                            ? AppColors.primary
                                            : const Color(0xFF10B981))
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _PartnerLivePulseDot(
                                      color: _isRefreshing
                                          ? AppColors.primary
                                          : const Color(0xFF10B981),
                                      size: 5,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isRefreshing
                                          ? 'GPS REFRESHING...'
                                          : 'LIVE GPS (8s)',
                                      style: TextStyle(
                                        color: _isRefreshing
                                            ? AppColors.primary
                                            : const Color(0xFF10B981),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (plate.isNotEmpty) 'Plate: $plate',
                              if (pickup.isNotEmpty) 'Pickup: $pickup',
                              '${_drivers.length} Certified Drivers',
                              if (_lastTrackerUpdate != null)
                                'Last Fix: ${_lastTrackerUpdate!.hour.toString().padLeft(2, '0')}:${_lastTrackerUpdate!.minute.toString().padLeft(2, '0')}:${_lastTrackerUpdate!.second.toString().padLeft(2, '0')}',
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh Tracker',
                      icon: Icon(
                        Icons.sync_rounded,
                        color: _isRefreshing
                            ? AppColors.primary
                            : Colors.white70,
                      ),
                      onPressed: _isRefreshing ? null : _pollLiveTracker,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    final mapWidget = Stack(
                      children: [
                        Positioned.fill(
                          child: MobilisLeafletMap(
                            key: ValueKey(
                              'partner_enlarged_${_activeSelectedId ?? ''}_${enlargedMapMarkers.map((m) => '${m.latitude.toStringAsFixed(4)},${m.longitude.toStringAsFixed(4)}').join('|')}',
                            ),
                            markers: enlargedMapMarkers,
                            initialZoom:
                                enlargedMapMarkers.length > 1 ? 12 : 14,
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_car_filled_rounded,
                                    color: AppColors.primary, size: 14),
                                const SizedBox(width: 4),
                                const Text('Vehicle Tracker',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                                const SizedBox(width: 10),
                                const Icon(Icons.person_pin_circle_rounded,
                                    color: AppColors.success, size: 14),
                                const SizedBox(width: 4),
                                const Text('Verified Driver',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                                const SizedBox(width: 10),
                                const Icon(Icons.person_pin_circle_rounded,
                                    color: Color(0xFFF59E0B), size: 14),
                                const SizedBox(width: 4),
                                const Text('PSDC Driver',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );

                    final listWidget = Container(
                      width: isWide ? 340 : double.infinity,
                      color: const Color(0xFF0B132B),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Search driver by name or town...',
                                hintStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11),
                                prefixIcon: Icon(Icons.search_rounded,
                                    color: AppColors.textSecondary, size: 16),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.06),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: filteredDrivers.isEmpty
                                ? Center(
                                    child: Text(
                                      'No matching drivers',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    itemCount: filteredDrivers.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 6),
                                    itemBuilder: (context, idx) {
                                      final driver = filteredDrivers[idx];
                                      final driverId = driver['id'].toString();
                                      final user = driver['users']
                                              as Map<String, dynamic>? ??
                                          {};
                                      final name = (user['full_name']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ==
                                              true)
                                          ? user['full_name'].toString().trim()
                                          : (user['email']
                                                  ?.toString()
                                                  .split('@')
                                                  .first
                                                  .toUpperCase() ??
                                              'Driver');
                                      final isPsdcDriver =
                                          driver['is_psdc_driver'] == true ||
                                              user['is_psdc_driver'] == true ||
                                              driver['driver_tier']
                                                      ?.toString()
                                                      .toLowerCase() ==
                                                  'psdc';
                                      final selected =
                                          _activeSelectedId == driverId;
                                      final distance =
                                          (driver['distance_km'] as num?)
                                              ?.toDouble();
                                      final rating =
                                          (driver['rating'] as num?)
                                                  ?.toDouble() ??
                                              5.0;
                                      final trips =
                                          (driver['total_trips'] as num?)
                                                  ?.toInt() ??
                                              0;
                                      final locationStr = user['location']
                                              ?.toString() ??
                                          user['city']?.toString() ??
                                          '';

                                      return InkWell(
                                        onTap: () {
                                          final newId = (_activeSelectedId ==
                                                  driverId
                                              ? null
                                              : driverId);
                                          setState(
                                              () => _activeSelectedId = newId);
                                          widget.onSelectDriver(newId);
                                        },
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 150),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? AppColors.primary
                                                : Colors.white
                                                    .withValues(alpha: 0.05),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: selected
                                                  ? AppColors.primary
                                                  : Colors.white
                                                      .withValues(alpha: 0.08),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? const Color(0xFF0F172A)
                                                      : (isPsdcDriver
                                                          ? const Color(
                                                              0xFFD97706)
                                                          : const Color(
                                                              0xFF0284C7)),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        color: selected
                                                            ? Colors.black
                                                            : Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      [
                                                        if (distance != null)
                                                          '${distance.toStringAsFixed(1)} km away',
                                                        '${rating.toStringAsFixed(1)} ★',
                                                        '$trips trips',
                                                        if (locationStr
                                                            .isNotEmpty)
                                                          locationStr,
                                                      ].join(' • '),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: selected
                                                            ? Colors.black87
                                                            : AppColors
                                                                .textSecondary,
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                selected
                                                    ? Icons.check_circle_rounded
                                                    : Icons.circle_outlined,
                                                color: selected
                                                    ? Colors.black
                                                    : Colors.white30,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              border: Border(
                                  top: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.08))),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: Colors.white24),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                    child: const Text('Close Map',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _activeSelectedId == null
                                        ? null
                                        : () {
                                            Navigator.pop(context);
                                            widget.onFinalize(
                                                _activeSelectedId!);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                    child: const Text('Assign Driver',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: mapWidget),
                          listWidget,
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          Expanded(flex: 3, child: mapWidget),
                          Expanded(flex: 4, child: listWidget),
                        ],
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
