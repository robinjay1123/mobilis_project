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
import '../../../services/booking_settlement_service.dart';
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
import '../../widgets/skeleton_loading.dart';
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
import 'trip_route_history_screen.dart';
import '../../widgets/leaflet_map.dart';
import '../../../utils/philippine_geocoding.dart';
import '../../../utils/currency_formatter.dart';

part 'tabs/partner_dashboard_tab.dart';
part 'tabs/partner_notifications_tab.dart';
part 'tabs/partner_tracking_tab.dart';
part 'tabs/partner_messages_tab.dart';
part 'tabs/partner_bookings_tab.dart';
part 'tabs/partner_profile_tab.dart';
part 'modals/partner_booking_detail_modal.dart';
part 'modals/partner_assign_driver_modal.dart';
part 'modals/partner_enlarged_driver_map_dialog.dart';

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
    // 120s backup sync; live updates are pushed immediately via Supabase Realtime
    _notificationsAutoRefreshTimer = Timer.periodic(
      const Duration(seconds: 120),
      (_) {
        if (mounted) _loadPartnerData(silent: true);
      },
    );
    // 30s live tracking GPS refresh timer
    _partnerTrackingPeriodicTimer = Timer.periodic(
      const Duration(seconds: 30),
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
          BookingSettlementService()
              .getReleasedPayoutsForUser(
                userId: user.id,
                recipientRole: 'partner',
              )
              .catchError((_) => <Map<String, dynamic>>[]),
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
        final releasedPayouts = results.length > 10
            ? (results[10] as List<Map<String, dynamic>>)
            : <Map<String, dynamic>>[];

        double computedEarnings = releasedPayouts.fold<double>(
          0.0,
          (sum, p) => sum + ((p['net_amount'] as num?)?.toDouble() ?? 0.0),
        );
        if (computedEarnings == 0.0) {
          for (final b in bList) {
            final meta = b['metadata'] is Map ? (b['metadata'] as Map) : {};
            final isDisbursed = b['partner_payout_disbursed'] == true ||
                meta['partner_payout_disbursed'] == true ||
                b['partner_payout_status'] == 'disbursed' ||
                meta['partner_payout_status'] == 'disbursed';
            if (isDisbursed) {
              computedEarnings += ((b['partner_payout_amount'] ?? meta['partner_payout_amount']) as num?)?.toDouble() ?? 0.0;
            }
          }
        }

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
            totalEarnings = computedEarnings;
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
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'booking_payouts',
            callback: (_) {
              debugPrint('🔔 Realtime booking_payouts event received');
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
              ? SafeArea(
                  child: MobilisSkeletonDashboard(
                    isDark: Theme.of(context).brightness == Brightness.dark,
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
  // -- Tab implementations extracted to tabs/ --
}

// -- Modals extracted to modals/ --

