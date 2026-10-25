import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import '../../../utils/web_html.dart' as html;
import '../../../mobile_ui/theme/app_colors.dart';
import '../../../mobile_ui/screens/profile/settings_screen.dart';
import '../../../mobile_ui/screens/profile/trip_rating_flow_screen.dart';
import '../../theme/web_portal_theme.dart';
import '../../../utils/booking_status.dart';
import '../../../utils/pricing_policy.dart';
import '../../../utils/csv_export.dart';
import '../../../utils/locations.dart';
import '../../../utils/philippine_geocoding.dart';
import '../../../utils/notification_target.dart';
import '../../../utils/action_guard.dart';
import '../../../utils/notification_visual.dart';
import '../../../widgets/upcoming_release_countdown_badge.dart';
import '../../../services/gps_service.dart';
import '../../../models/gps_tracker_model.dart';
import '../../../services/payout_method_service.dart';
import '../../../services/reservation_payment_service.dart';
import '../../../services/message_filter_service.dart';
import '../../../mobile_ui/widgets/optimized_network_image.dart';
import '../../../mobile_ui/widgets/handover_pin_verifier_modal.dart';
import '../../../mobile_ui/widgets/inspection_damage_comparison_dialog.dart';
import '../../../mobile_ui/widgets/dialog_status_indicator.dart';
import '../../../mobile_ui/widgets/leaflet_map.dart';
import '../../../mobile_ui/widgets/relative_time_text.dart';
import '../../../mobile_ui/widgets/booking_return_countdown.dart';
import '../../../mobile_ui/widgets/vehicle_inspection_checklist_fields.dart';
import '../../../mobile_ui/widgets/vehicle_inspection_record_view.dart';
import '../../../mobile_ui/widgets/trip_route_history_dialog.dart';
import '../../../mobile_ui/widgets/restriction_ui.dart';
import '../../../widgets/gps_tracker_telemetry_card.dart';
import '../../../services/operator_activity_logger.dart';
import '../../../services/booking_inspection_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/booking_receipt_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/tracking_service.dart';
import '../../../services/image_optimization_service.dart';
import '../../../services/trip_rating_service.dart';
import '../../../services/booking_viewed_service.dart';
import '../../../services/payout_method_service.dart';
import '../../../services/mpin_service.dart';
import '../../../services/vehicle_turnaround_service.dart';

part 'tabs/operator_price_requests_tab.dart';
part 'tabs/operator_inspections_tab.dart';
part 'tabs/operator_settings_tab.dart';
part 'tabs/operator_vehicles_tab.dart';
part 'tabs/operator_messages_tab.dart';
part 'tabs/operator_notifications_tab.dart';
part 'tabs/operator_tracking_tab.dart';
part 'tabs/operator_applications_tab.dart';
part 'tabs/operator_bookings_tab.dart';
part 'tabs/operator_revenue_tab.dart';
part 'tabs/operator_dashboard_tab.dart';

const int _dashboardQueuePageSize = 10;
const int _bookingPageSize = 10;
const String _vehicleImagesBucket = 'vehicle_images';

bool _bookingNeedsDriver(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == 'yes' || normalized == '1';
  }
  return false;
}

class OperatorWebScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const OperatorWebScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  State<OperatorWebScreen> createState() => _OperatorWebScreenState();
}

class _OperatorWebScreenState extends State<OperatorWebScreen> {
  String _selectedThemeKey = 'gold_navy';

  static final Map<String, Map<String, dynamic>> _themePalettes = {
    'gold_navy': {
      'name': 'Golden Navy',
      'accent': const Color(0xFFFFD740),
      'navy': const Color(0xFF032A46),
      'navyDeep': const Color(0xFF021F35),
      'ink': const Color(0xFF08233D),
      'icon': Icons.stars_rounded,
    },
    'emerald': {
      'name': 'Emerald Cyber',
      'accent': const Color(0xFF10B981),
      'navy': const Color(0xFF0F766E),
      'navyDeep': const Color(0xFF042F2E),
      'ink': const Color(0xFF134E4A),
      'icon': Icons.eco_rounded,
    },
    'violet': {
      'name': 'Royal Violet',
      'accent': const Color(0xFFF59E0B),
      'navy': const Color(0xFF312E81),
      'navyDeep': const Color(0xFF1E1B4B),
      'ink': const Color(0xFF3730A3),
      'icon': Icons.auto_awesome_rounded,
    },
    'sapphire': {
      'name': 'Electric Cyan',
      'accent': const Color(0xFF00E5FF),
      'navy': const Color(0xFF0284C7),
      'navyDeep': const Color(0xFF0F172A),
      'ink': const Color(0xFF1E293B),
      'icon': Icons.bolt_rounded,
    },
    'crimson': {
      'name': 'Sunset Crimson',
      'accent': const Color(0xFFFF5252),
      'navy': const Color(0xFF881337),
      'navyDeep': const Color(0xFF4C0519),
      'ink': const Color(0xFFBE123C),
      'icon': Icons.local_fire_department_rounded,
    },
    'onyx': {
      'name': 'Monochrome Onyx',
      'accent': const Color(0xFFE0E0E0),
      'navy': const Color(0xFF212121),
      'navyDeep': const Color(0xFF121212),
      'ink': const Color(0xFF424242),
      'icon': Icons.contrast_rounded,
    },
  };

  Color get _operatorGold =>
      (_themePalettes[_selectedThemeKey]?['accent'] as Color?) ??
      const Color(0xFFFFD740);
  Color get _operatorNavy =>
      (_themePalettes[_selectedThemeKey]?['navy'] as Color?) ??
      const Color(0xFF032A46);
  Color get _operatorNavyDeep =>
      (_themePalettes[_selectedThemeKey]?['navyDeep'] as Color?) ??
      const Color(0xFF021F35);
  Color get _operatorInk =>
      (_themePalettes[_selectedThemeKey]?['ink'] as Color?) ??
      const Color(0xFF08233D);
  Color get _operatorPage => const Color(0xFFF5F7F9);

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _sidebarExpanded = true;
  String? _focusedTrackingBookingId;
  final Map<String, Map<String, dynamic>> _activeGeofences = {};
  String _bookingFilter = 'all';
  String _bookingSearchQuery = '';
  String _bookingDateFilter = 'all';
  String _bookingVehicleTypeFilter = 'all';
  String _vehicleView = 'company';
  String _vehicleViewMode = 'table'; // 'table' or 'grid'

  String _operatorPickupLabel(String? value) =>
      PhilippineLocations.normalizePsdcGarageLabel(value);
  String _vehicleSearchQuery = '';
  String _revenuePeriod = 'month';
  int _dashboardQueuePage = 0;
  int _bookingPage = 0;

  // Extend Trip Requests tab state
  String _bookingMainSubSection = 'bookings'; // 'bookings' or 'extensions'
  String _extensionFilter = 'all';
  String _extensionSearchQuery = '';
  final TextEditingController _extensionSearchController =
      TextEditingController();

  // Database-backed badge counts
  int _pendingBookingsCount = 0;
  int _unviewedBookingsCount = 0;
  Set<String> _viewedBookingIds = {};
  int _unreadMessagesCount = 0;
  Map<String, int> _conversationUnreadCounts = {};
  Map<String, Set<String>> _operatorSubmittedRatingRolesByBooking = {};

  bool _isPendingBookingForCurrentOperator(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    if (status != 'pending') {
      return false;
    }

    final operatorId = _supabase.auth.currentUser?.id;
    if (operatorId == null || operatorId.isEmpty) return false;

    final vehicleValue = booking['vehicles'];
    final vehicle = vehicleValue is Map
        ? Map<String, dynamic>.from(vehicleValue)
        : <String, dynamic>{};
    final bookingOperatorId = booking['operator_id']?.toString().trim();
    final vehicleOperatorId = vehicle['operator_id']?.toString().trim();
    final isAssignedToThisOperator = bookingOperatorId == operatorId ||
        vehicleOperatorId == operatorId;
    final isUnassigned = (bookingOperatorId == null ||
            bookingOperatorId.isEmpty) &&
        (vehicleOperatorId == null || vehicleOperatorId.isEmpty);

    return isAssignedToThisOperator || isUnassigned;
  }

  Future<void> _openOperatorHandoverVerifier({
    String? bookingId,
    String? vehicleName,
    String? renterName,
    String mode = 'release',
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final result = await HandoverPinVerifierModal.show(
      context,
      bookingId: bookingId ?? '',
      verifierId: currentUserId,
      verifierRole: 'operator',
      vehicleName: vehicleName,
      renterName: renterName,
      mode: mode,
    );

    if (result == true) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadPendingBookingsCount() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      if (mounted && _pendingBookingsCount != 0) {
        setState(() => _pendingBookingsCount = 0);
      }
      return;
    }

    try {
      final response = await _supabase
          .from('bookings')
          .select('id, status, operator_id, vehicles(owner_id, operator_id)')
          .eq('status', 'pending');

      final pendingBookings = List<Map<String, dynamic>>.from(response);
      final count = pendingBookings
          .where(_isPendingBookingForCurrentOperator)
          .length;

      if (mounted && _pendingBookingsCount != count) {
        setState(() => _pendingBookingsCount = count);
      }
    } catch (e) {
      debugPrint('Error loading pending bookings count: $e');
    }
  }

  Future<void> _loadUnviewedBookingsCount() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      if (mounted && _unviewedBookingsCount != 0) {
        setState(() => _unviewedBookingsCount = 0);
      }
      return;
    }

    try {
      final response = await _supabase
          .from('bookings')
          .select('id, status, operator_id, vehicles(owner_id, operator_id)')
          .order('created_at', ascending: false)
          .limit(100);

      final allBookings = List<Map<String, dynamic>>.from(response);
      final relevantBookings = allBookings
          .where(_isPendingBookingForCurrentOperator)
          .toList();

      final unviewedCount = relevantBookings
          .where((b) => !_viewedBookingIds.contains(b['id']?.toString()))
          .length;

      if (mounted && _unviewedBookingsCount != unviewedCount) {
        setState(() => _unviewedBookingsCount = unviewedCount);
      }
    } catch (e) {
      debugPrint('Error loading unviewed bookings count: $e');
    }
  }

  Future<void> _loadUnreadMessagesCount() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      if (mounted) {
        setState(() {
          _unreadMessagesCount = 0;
          _conversationUnreadCounts = {};
        });
      }
      return;
    }

    try {
      List<String> conversationIds = _conversations
          .map((c) => c['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (conversationIds.isEmpty) {
        await _loadConversations();
        conversationIds = _conversations
            .map((c) => c['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList();
      }

      if (conversationIds.isEmpty) {
        if (mounted) {
          setState(() {
            _unreadMessagesCount = 0;
            _conversationUnreadCounts = {};
          });
        }
        return;
      }

      final unreadMessages = await _supabase
          .from('messages')
          .select('id, conversation_id')
          .inFilter('conversation_id', conversationIds)
          .eq('is_read', false)
          .neq('sender_id', currentUserId);

      final unreadMap = <String, int>{};
      for (final msg in List<Map<String, dynamic>>.from(unreadMessages)) {
        final convId = msg['conversation_id']?.toString() ?? '';
        if (convId.isNotEmpty) {
          unreadMap[convId] = (unreadMap[convId] ?? 0) + 1;
        }
      }

      final unreadConversationCount = unreadMap.keys.length;
      if (mounted) {
        setState(() {
          _conversationUnreadCounts = unreadMap;
          _unreadMessagesCount = unreadConversationCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading unread messages count: $e');
    }
  }

  Future<void> _recalculatePendingBookings() async {
    final operatorId = _supabase.auth.currentUser?.id;
    final viewedIds = await BookingViewedService().getViewedBookingIds(
      role: 'operator',
      userId: operatorId,
    );
    _viewedBookingIds = viewedIds;

    final pendingList =
        _recentBookings.where(_isPendingBookingForCurrentOperator).toList();
    final count = pendingList.length;

    // If currently viewing Bookings tab (index 1), immediately mark them as viewed
    if (_selectedIndex == 1) {
      final idsToMark = pendingList
          .map((b) => b['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (idsToMark.isNotEmpty) {
        await BookingViewedService().markAllBookingsAsViewed(
          idsToMark,
          role: 'operator',
          userId: operatorId,
        );
        _viewedBookingIds.addAll(idsToMark);
      }
      if (mounted) {
        setState(() {
          _pendingBookingsCount = count;
          _unviewedBookingsCount = 0;
        });
      }
      return;
    }

    final unviewedCount = pendingList
        .where((b) => !_viewedBookingIds.contains(b['id']?.toString()))
        .length;

    if (mounted) {
      setState(() {
        _pendingBookingsCount = count;
        _unviewedBookingsCount = unviewedCount;
      });
    }
  }

  Future<void> _markAllVisibleBookingsAsViewed() async {
    final operatorId = _supabase.auth.currentUser?.id;
    final allIds = _recentBookings
        .map((b) => b['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (allIds.isNotEmpty) {
      await BookingViewedService().markAllBookingsAsViewed(
        allIds,
        role: 'operator',
        userId: operatorId,
      );
      _viewedBookingIds.addAll(allIds);
    }
    if (mounted && _unviewedBookingsCount != 0) {
      setState(() => _unviewedBookingsCount = 0);
    }
  }


  // Stats
  int _totalUsers = 0;
  int _totalPartners = 0;
  int _totalVehicles = 0;
  int _pendingVerifications = 0;
  int _activeBookings = 0;
  int _totalBookings = 0;

  // Lists
  List<Map<String, dynamic>> _pendingApplications = [];
  List<Map<String, dynamic>> _recentBookings = [];
  List<Map<String, dynamic>> _operatorRevenueBookings = [];
  List<Map<String, dynamic>> _operatorSettlements = [];
  Map<String, dynamic> _operatorProfile = {};
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _partnerVehicles = [];
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationLoadError;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _priceChangeRequests = [];
  int _pendingPriceRequestsCount = 0;
  String _priceRequestFilter = 'all';
  String _priceRequestSearchQuery = '';
  List<Map<String, dynamic>> _trackingLocations = [];
  bool _isTrackingLoading = true;
  Timer? _trackingRefreshTimer;
  Timer? _notificationsRefreshTimer;
  Timer? _bookingsSilentRefreshTimer;
  Timer? _countdownTickerTimer;
  Timer? _bookingFlowRefreshDebounce;
  Timer? _conversationFlowRefreshDebounce;
  bool _hasRepairedSettlements = false;
  RealtimeChannel? _bookingFlowChannel;
  RealtimeChannel? _conversationMessagesChannel;
  Map<String, List<Map<String, dynamic>>> _messages = {};
  final Map<String, List<Map<String, dynamic>>> _conversationFlags = {};
  bool _isSendingMessage = false;
  final Map<String, List<Map<String, dynamic>>> _conversationParticipants = {};
  final Map<String, MobilisMapPoint?> _addressCoordinateCache = {};

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _pricePerHourController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _vehicleTypeController = TextEditingController();
  final TextEditingController _vehicleNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _transmissionController = TextEditingController();
  final TextEditingController _seatsController = TextEditingController();
  final TextEditingController _gpsDeviceIdController = TextEditingController();
  final TextEditingController _gpsPasswordController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  final ScrollController _dashboardQueueScrollController = ScrollController();
  final TextEditingController _bookingSearchController =
      TextEditingController();
  final TextEditingController _vehicleSearchController =
      TextEditingController();
  String _selectedConversationId = '';
  bool _showOperatorBookingActivity = true;
  String _selectedStatus = 'active';
  List<XFile> _selectedImages = [];
  final Map<String, Future<Uint8List>> _selectedImageBytes = {};
  bool _isSubmittingVehicle = false;
  bool _isOpeningEditVehicleDialog = false;
  bool _isTestingGps = false;
  bool? _isGpsVerified;
  String? _gpsTestMessage;
  bool _isPerformingOperation = false;
  String _operationLoadingMessage = 'Processing booking action...';

  // Inspection System State & Controllers
  final TextEditingController _inspectionOdometerController =
      TextEditingController();
  final TextEditingController _inspectionNotesController =
      TextEditingController();

  void _showOperationLoading(String message) {
    if (!mounted) return;
    setState(() {
      _isPerformingOperation = true;
      _operationLoadingMessage = message;
    });
  }

  void _hideOperationLoading() {
    if (!mounted) return;
    setState(() {
      _isPerformingOperation = false;
    });
  }

  Future<void> _loadColorTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('operator_color_theme');
      if (savedTheme != null && _themePalettes.containsKey(savedTheme)) {
        if (mounted) {
          setState(() => _selectedThemeKey = savedTheme);
        }
      }
    } catch (e) {
      debugPrint('Error loading color theme: $e');
    }
  }

  Future<void> _saveColorTheme(String key) async {
    setState(() => _selectedThemeKey = key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('operator_color_theme', key);
    } catch (e) {
      debugPrint('Error saving color theme: $e');
    }
  }

  Future<void> _showColorThemeDialog(bool isDark) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? const Color(0xFF172235) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(28),
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
                      color: _operatorGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      color: _operatorGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operator Color Theme',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : _operatorInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select your preferred workspace color theme',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _themePalettes.length,
                itemBuilder: (context, index) {
                  final key = _themePalettes.keys.elementAt(index);
                  final palette = _themePalettes[key]!;
                  final name = palette['name'] as String;
                  final accent = palette['accent'] as Color;
                  final navyDeep = palette['navyDeep'] as Color;
                  final icon = palette['icon'] as IconData;
                  final isSelected = _selectedThemeKey == key;

                  return InkWell(
                    onTap: () {
                      _saveColorTheme(key);
                      Navigator.pop(dialogContext);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: navyDeep,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? accent : Colors.white24,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: accent, width: 1.5),
                            ),
                            child: Icon(icon, color: accent, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: navyDeep,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: accent,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOperatorMpinSetupDialog(bool isDark) async {
    final mpinService = MpinService();
    final isConfigured = mpinService.currentState().isConfigured;
    final currentPinController = TextEditingController();
    final passwordController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool obscurePins = true;
    bool obscurePassword = true;
    bool isResetWithPasswordMode = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final surface = isDark ? const Color(0xFF172235) : Colors.white;
          final foreground = isDark ? Colors.white : _operatorInk;
          final muted = isDark ? Colors.grey[400] : Colors.grey.shade600;

          return Dialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(28),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _operatorGold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.pin_outlined,
                            color: _operatorGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isResetWithPasswordMode
                                    ? 'Reset Desk MPIN'
                                    : (isConfigured
                                        ? 'Change Desk Authorization MPIN'
                                        : 'Setup Desk Authorization MPIN'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: foreground,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isResetWithPasswordMode
                                    ? 'Verify your account password to set a new MPIN'
                                    : (isConfigured
                                        ? 'Update your 6-digit MPIN for cashier & desk payments'
                                        : 'Create a 6-digit MPIN to authorize in-person payments'),
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed:
                              isSaving ? null : () => Navigator.pop(dialogCtx),
                          icon: Icon(Icons.close_rounded, color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (isConfigured && !isResetWithPasswordMode) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current 6-Digit MPIN',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => setDialogState(() {
                                      isResetWithPasswordMode = true;
                                      dialogError = null;
                                    }),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot MPIN?',
                              style: TextStyle(
                                color: _operatorGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: currentPinController,
                        obscureText: obscurePins,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (v) {
                          if (isResetWithPasswordMode) return null;
                          if (v == null || v.trim().length != 6) {
                            return 'Enter your current 6-digit MPIN.';
                          }
                          return null;
                        },
                        style: TextStyle(color: foreground),
                        decoration: InputDecoration(
                          hintText: '••••••',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : const Color(0xFFF4F6F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (isConfigured && isResetWithPasswordMode) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _operatorGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _operatorGold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_reset_rounded,
                              size: 20,
                              color: _operatorGold,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Forgot your current MPIN? Verify your account password to set a new 6-digit MPIN.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: foreground,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Account Password',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => setDialogState(() {
                                      isResetWithPasswordMode = false;
                                      dialogError = null;
                                    }),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Remember current MPIN?',
                              style: TextStyle(
                                color: _operatorGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        validator: (v) {
                          if (!isResetWithPasswordMode) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your account password.';
                          }
                          return null;
                        },
                        style: TextStyle(color: foreground),
                        decoration: InputDecoration(
                          hintText: 'Enter your account password',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : const Color(0xFFF4F6F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.password_rounded,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      isConfigured ? 'New 6-Digit MPIN' : '6-Digit MPIN',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: newPinController,
                      obscureText: obscurePins,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().length != 6) {
                          return 'Enter exactly 6 digits.';
                        }
                        return null;
                      },
                      style: TextStyle(color: foreground),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : const Color(0xFFF4F6F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.pin_rounded, size: 20),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(
                            () => obscurePins = !obscurePins,
                          ),
                          icon: Icon(
                            obscurePins
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Confirm New MPIN',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: confirmPinController,
                      obscureText: obscurePins,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (v) {
                        if (v == null ||
                            v.trim() != newPinController.text.trim()) {
                          return 'MPINs do not match.';
                        }
                        return null;
                      },
                      style: TextStyle(color: foreground),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : const Color(0xFFF4F6F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                              isSaving ? null : () => Navigator.pop(dialogCtx),
                          child: Text('Cancel', style: TextStyle(color: muted)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() {
                                    isSaving = true;
                                    dialogError = null;
                                  });

                                  try {
                                    final newPin = newPinController.text.trim();

                                    if (isConfigured && isResetWithPasswordMode) {
                                      final password = passwordController.text.trim();
                                      final success = await mpinService.resetMpinWithPassword(
                                        password: password,
                                        newMpin: newPin,
                                      );
                                      if (!success) {
                                        setDialogState(() {
                                          dialogError =
                                              'Incorrect account password. Please try again.';
                                          isSaving = false;
                                        });
                                        return;
                                      }
                                    } else if (isConfigured) {
                                      final currentPin = currentPinController.text
                                          .trim();
                                      if (!mpinService.verify(currentPin)) {
                                        setDialogState(() {
                                          dialogError =
                                              'Current MPIN is incorrect.';
                                          isSaving = false;
                                        });
                                        return;
                                      }
                                      await mpinService.configure(newPin);
                                    } else {
                                      await mpinService.configure(newPin);
                                    }

                                    if (!mounted) return;
                                    Navigator.pop(dialogCtx);
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isResetWithPasswordMode
                                              ? 'Desk Authorization MPIN reset successfully!'
                                              : (isConfigured
                                                  ? 'Desk Authorization MPIN updated successfully.'
                                                  : 'Desk Authorization MPIN set up successfully!'),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    setDialogState(() {
                                      dialogError = 'Failed to save MPIN: $e';
                                      isSaving = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorGold,
                            foregroundColor: _operatorNavyDeep,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(
                                  isResetWithPasswordMode
                                      ? Icons.lock_reset_rounded
                                      : Icons.check_circle_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            isSaving
                                ? 'Saving...'
                                : (isResetWithPasswordMode
                                    ? 'Reset MPIN'
                                    : (isConfigured ? 'Update MPIN' : 'Save MPIN')),
                            style: const TextStyle(fontWeight: FontWeight.w800),
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
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadColorTheme();
    _restoreSavedTab();
    _loadUnreadMessagesCount();
    _loadDashboardData();
    MpinService().syncCurrentUserMpinToRegistry();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadConversations();
    });
    _setupBookingFlowListener();
    _bookingsSilentRefreshTimer = Timer.periodic(
      const Duration(seconds: 120),
      (_) {
        if (mounted && (_selectedIndex == 1 || _selectedIndex == 0)) {
          _loadRecentBookings();
        }
      },
    );
    _trackingRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (mounted && _selectedIndex == 6) {
          _refreshTrackingLocations();
        }
      },
    );
    _notificationsRefreshTimer = Timer.periodic(const Duration(seconds: 120), (
      _,
    ) {
      if (mounted) {
        _loadNotifications();
        _loadPriceChangeRequests();
        _loadUnreadMessagesCount();
      }
    });
    // Relaxed countdown ticker (30s) prevents rebuilding the entire 40,000-line screen every 1s
    _countdownTickerTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted && (_selectedIndex == 1 || _selectedIndex == 0)) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _bookingsSilentRefreshTimer?.cancel();
    _trackingRefreshTimer?.cancel();
    _notificationsRefreshTimer?.cancel();
    _countdownTickerTimer?.cancel();
    _bookingFlowRefreshDebounce?.cancel();
    _conversationFlowRefreshDebounce?.cancel();
    _bookingFlowChannel?.unsubscribe();
    _conversationMessagesChannel?.unsubscribe();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _priceController.dispose();
    _pricePerHourController.dispose();
    _categoryController.dispose();
    _vehicleTypeController.dispose();
    _vehicleNameController.dispose();
    _descriptionController.dispose();
    _colorController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _transmissionController.dispose();
    _seatsController.dispose();
    _gpsDeviceIdController.dispose();
    _gpsPasswordController.dispose();
    _messageController.dispose();
    _messageScrollController.dispose();
    _dashboardQueueScrollController.dispose();
    _bookingSearchController.dispose();
    _vehicleSearchController.dispose();
    _inspectionOdometerController.dispose();
    _inspectionNotesController.dispose();
    super.dispose();
  }

  void _setupBookingFlowListener() {
    final channelName =
        'operator-booking-flow-${_supabase.auth.currentUser?.id ?? 'guest'}';
    _bookingFlowChannel = _supabase.realtime.channel(channelName);

    void refreshDashboard(PostgresChangePayload payload) {
      if (!mounted) return;
      _bookingFlowRefreshDebounce?.cancel();
      _bookingFlowRefreshDebounce = Timer(
        const Duration(milliseconds: 2500),
        () {
          if (!mounted) return;
          _loadRecentBookings();
          _loadStats();
          _loadOperatorRevenueBookings();
          final table = payload.table;
          if (table == 'vehicles' ||
              table == 'partner_vehicles' ||
              table == 'vehicle_applications' ||
              table == 'partner_vehicle_applications') {
            _loadVehicles();
          }
        },
      );
    }

    void refreshConversations(PostgresChangePayload payload) {
      if (!mounted) return;
      _conversationFlowRefreshDebounce?.cancel();
      _conversationFlowRefreshDebounce = Timer(
        const Duration(milliseconds: 300),
        () => _loadConversations(),
      );
    }

    _bookingFlowChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_job_assignments',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicles',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicle_images',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicle_applications',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'partner_vehicles',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'partner_vehicle_applications',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'booking_settlements',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _supabase.auth.currentUser?.id ?? '',
          ),
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: refreshConversations,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_participants',
          callback: refreshConversations,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: refreshConversations,
        )
        .subscribe();
  }

  Future<void> _getCurrentVehicleLocation({
    required void Function(String location, String latitude, String longitude)
    onLocationFound,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services in your settings'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is permanently denied. Please enable it in app settings.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final location = placemarks.isNotEmpty
          ? [
              placemarks.first.street,
              placemarks.first.subLocality,
              placemarks.first.locality,
              placemarks.first.administrativeArea,
              placemarks.first.country,
            ].where((s) => s != null && s.isNotEmpty).toList().join(', ')
          : 'Current Location';

      onLocationFound(
        location,
        position.latitude.toString(),
        position.longitude.toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadDashboardData({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);
    try {
      final tasks = <Future<void>>[
        _loadOperatorProfile(),
        _loadStats(),
        _loadNotifications(),
        _loadPriceChangeRequests(),
        _loadUnreadMessagesCount(),
        _loadVehicles(),
        _loadRecentBookings(),
        _loadOperatorRevenueBookings(),
        _loadOperatorSettlements(), // moved into parallel block — no need to sequence after
      ];
      if (_selectedIndex == 6) {
        tasks.add(_loadTrackingLocationsFast());
      }
      await Future.wait(tasks);
      if (!_hasRepairedSettlements) {
        _hasRepairedSettlements = true;
        // Fire-and-forget: repair runs in background, never blocks the dashboard render
        unawaited(_repairOperatorRevenueSettlements());
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (showLoading) _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadOperatorProfile() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      _operatorProfile = {};
      return;
    }

    try {
      final response = await _supabase
          .from('users')
          .select(
            'id, full_name, email, phone, location, avatar_url',
          )
          .eq('id', currentUser.id)
          .maybeSingle();
      final metadata = currentUser.userMetadata ?? const <String, dynamic>{};
      final profile = response == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(response);

      String? firstValue(List<dynamic> values) {
        for (final value in values) {
          final text = value?.toString().trim();
          if (text != null && text.isNotEmpty) return text;
        }
        return null;
      }

      profile['full_name'] = firstValue([
        profile['full_name'],
        metadata['full_name'],
        metadata['name'],
      ]);
      profile['email'] = firstValue([profile['email'], currentUser.email]);
      final avatar = firstValue([
        profile['avatar_url'],
        profile['profile_picture_url'],
        metadata['avatar_url'],
        metadata['profile_picture_url'],
        metadata['picture'],
      ]);
      profile['avatar_url'] = avatar;
      profile['profile_picture_url'] = avatar;
      _operatorProfile = profile;
    } catch (error) {
      debugPrint('Error loading operator profile: $error');
      _operatorProfile = <String, dynamic>{
        'full_name': currentUser.userMetadata?['full_name'],
        'email': currentUser.email,
        'avatar_url':
            currentUser.userMetadata?['avatar_url'] ??
            currentUser.userMetadata?['profile_picture_url'] ??
            currentUser.userMetadata?['picture'],
      };
    }
  }

  Future<void> _loadNotifications() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      _notifications = [];
      return;
    }

    try {
      _notifications = await NotificationService().getNotifications(
        currentUserId,
      );
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      _notifications = [];
    }
  }

  Future<void> _loadPriceChangeRequests() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      _priceChangeRequests = [];
      _pendingPriceRequestsCount = 0;
      return;
    }

    try {
      final response = await _supabase
          .from('notifications')
          .select('id, user_id, title, message, type, data, is_read, created_at')
          .eq('user_id', currentUserId)
          .inFilter('type', ['price_change_request', 'price_change_request_forwarded'])
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(response);

      // Pre-enrich requests with car images from vehicles & partner applications
      final missingAppIds = <String>{};
      final missingPartnerVehIds = <String>{};
      final missingVehIds = <String>{};

      for (final r in list) {
        final data = r['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(r['data'])
            : (r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : <String, dynamic>{});
        var img = (data['image_url'] ?? data['vehicle_image_url'] ?? data['photo_url'])?.toString().trim() ?? '';
        final vid = (data['vehicle_id'] ?? data['partner_vehicle_id'] ?? data['application_id'])?.toString().trim() ?? '';

        if (img.isEmpty && vid.isNotEmpty) {
          for (final v in [..._vehicles, ..._partnerVehicles]) {
            final vId = v['id']?.toString() ?? '';
            final pId = (v['partner_vehicle_id'] ?? v['_partner_vehicle_id'] ?? v['application_id'])?.toString() ?? '';
            if (vId == vid || pId == vid) {
              img = _primaryVehicleImageUrl(v);
              if (img.isNotEmpty) {
                data['vehicle_image_url'] = img;
                r['data'] = data;
                break;
              }
            }
          }
        }

        if (img.isEmpty) {
          final appId = data['application_id']?.toString() ?? '';
          final pvId = data['partner_vehicle_id']?.toString() ?? '';
          final vId = data['vehicle_id']?.toString() ?? '';
          if (appId.isNotEmpty) missingAppIds.add(appId);
          if (pvId.isNotEmpty) missingPartnerVehIds.add(pvId);
          if (vId.isNotEmpty) missingVehIds.add(vId);
        }
      }

      if (missingAppIds.isNotEmpty) {
        try {
          final appRows = await _supabase
              .from('partner_vehicle_applications')
              .select('id, vehicle_photo_url')
              .inFilter('id', missingAppIds.toList());
          for (final row in List<Map<String, dynamic>>.from(appRows)) {
            final id = row['id']?.toString();
            final img = _normalizeVehicleImageUrl(row['vehicle_photo_url']);
            if (id != null && img.isNotEmpty) {
              for (final r in list) {
                final d = r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : <String, dynamic>{};
                if (d['application_id']?.toString() == id) {
                  d['vehicle_image_url'] = img;
                  r['data'] = d;
                }
              }
            }
          }
        } catch (_) {}
      }

      if (missingPartnerVehIds.isNotEmpty) {
        try {
          final pvRows = await _supabase
              .from('partner_vehicles')
              .select('id, vehicle_photo_url, photo_url')
              .inFilter('id', missingPartnerVehIds.toList());
          for (final row in List<Map<String, dynamic>>.from(pvRows)) {
            final id = row['id']?.toString();
            final img = _normalizeVehicleImageUrl(row['vehicle_photo_url'] ?? row['photo_url']);
            if (id != null && img.isNotEmpty) {
              for (final r in list) {
                final d = r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : <String, dynamic>{};
                if (d['partner_vehicle_id']?.toString() == id) {
                  d['vehicle_image_url'] = img;
                  r['data'] = d;
                }
              }
            }
          }
        } catch (_) {}
      }

      _priceChangeRequests = list;
      _pendingPriceRequestsCount = list.where((r) {
        final data = r['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(r['data'])
            : <String, dynamic>{};
        final status = (data['status'] ?? '').toString().toLowerCase();
        final isApproved = data['approved'] == true || status == 'approved';
        final isDeclined = data['declined'] == true || status == 'declined' || status == 'rejected';
        return !isApproved && !isDeclined && r['is_read'] != true;
      }).length;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading price change requests: $e');
    }
  }

  Future<void> _loadTrackingLocationsFast() async {
    if (_trackingLocations.isEmpty && mounted) {
      setState(() => _isTrackingLoading = true);
    }
    try {
      final locations = await TrackingService().getActiveTrackingLocations();
      if (mounted) {
        setState(() {
          _trackingLocations = locations;
          if (locations.isNotEmpty) {
            _isTrackingLoading = false;
          }
        });
      }
      TrackingService().pollGpsTrackersForActiveBookings().then((_) async {
        if (!mounted) return;
        final updated = await TrackingService().getActiveTrackingLocations();
        if (mounted) {
          setState(() {
            _trackingLocations = updated;
            _isTrackingLoading = false;
          });
        }
      }).catchError((e) {
        debugPrint('Background GPS poll error: $e');
        if (mounted) setState(() => _isTrackingLoading = false);
      });
    } catch (e) {
      debugPrint('Error loading tracking locations: $e');
    } finally {
      if (mounted && _trackingLocations.isNotEmpty) {
        setState(() => _isTrackingLoading = false);
      }
    }
  }

  Future<void> _loadTrackingLocations() async {
    if (_trackingLocations.isEmpty && mounted) {
      setState(() => _isTrackingLoading = true);
    }
    try {
      final locations = await TrackingService().getActiveTrackingLocations();
      if (mounted) {
        setState(() {
          _trackingLocations = locations;
          if (locations.isNotEmpty) {
            _isTrackingLoading = false;
          }
        });
      }
      TrackingService().pollGpsTrackersForActiveBookings().then((_) async {
        if (!mounted) return;
        final updated = await TrackingService().getActiveTrackingLocations();
        if (mounted) {
          setState(() {
            _trackingLocations = updated;
            _isTrackingLoading = false;
          });
        }
      }).catchError((e) {
        debugPrint('Operator background GPS poll error: $e');
        if (mounted) setState(() => _isTrackingLoading = false);
      });
    } catch (e) {
      debugPrint('Error loading tracking locations: $e');
    } finally {
      if (mounted) {
        setState(() => _isTrackingLoading = false);
      }
    }
  }

  Future<void> _refreshTrackingLocations({bool forceLoading = false}) async {
    if ((_trackingLocations.isEmpty || forceLoading) && mounted) {
      setState(() => _isTrackingLoading = true);
    }
    try {
      final locations = await TrackingService().getActiveTrackingLocations();
      if (mounted) {
        setState(() {
          _trackingLocations = locations;
          if (locations.isNotEmpty) {
            _isTrackingLoading = false;
          }
        });
      }
      TrackingService().pollGpsTrackersForActiveBookings().then((_) async {
        if (!mounted) return;
        final updated = await TrackingService().getActiveTrackingLocations();
        if (mounted) {
          setState(() {
            _trackingLocations = updated;
            _isTrackingLoading = false;
          });
        }
      }).catchError((e) {
        debugPrint('Operator background GPS poll error: $e');
        if (mounted) setState(() => _isTrackingLoading = false);
      });
    } catch (e) {
      debugPrint('Error refreshing tracking locations: $e');
    } finally {
      if (mounted) {
        setState(() => _isTrackingLoading = false);
      }
    }
  }

  bool _isOperatorRatingFullyCompleted(Map<String, dynamic> booking) {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return false;

    if (booking['operator_trip_confirmed_at'] != null) {
      return true;
    }

    final isPartner = _isPartnerOwnedBooking(booking);
    final withDriver = _bookingNeedsDriver(booking['with_driver']);

    final ratedRoles =
        _operatorSubmittedRatingRolesByBooking[bookingId] ?? const {};

    // 1. Renter is ALWAYS required for operator
    if (!ratedRoles.contains('renter')) return false;

    // 2. Partner is required if partner vehicle
    if (isPartner && !ratedRoles.contains('partner')) return false;

    // 3. Driver is required if with driver
    if (withDriver && !ratedRoles.contains('driver')) return false;

    return true;
  }

  Future<void> _openOperatorRenterRating(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty || _isPartnerOwnedBooking(booking)) return;

    try {
      final latestBooking =
          await BookingService().getBookingById(bookingId) ?? booking;
      final completionState = BookingService().getTripCompletionState(
        latestBooking,
      );
      final completionStage =
          completionState['completionStage']?.toString() ?? '';
      final actorId = _supabase.auth.currentUser?.id;
      if (actorId == null || actorId.isEmpty) {
        throw Exception('Sign in again before rating this trip.');
      }

      // Check if payment is still pending and not paid
      if (completionStage == 'awaiting_payment' &&
          latestBooking['final_payment_status'] != 'paid') {
        await _confirmOperatorFinalPayment(latestBooking);
        return;
      }

      final isComplete = await TripRatingService().isReviewerRatingComplete(
        bookingId: bookingId,
        reviewerUserId: actorId,
        reviewerRole: 'operator',
        operatorFallbackUserId: actorId,
      );

      if (latestBooking['operator_id']?.toString().trim().isEmpty ?? true) {
        try {
          await _supabase
              .from('bookings')
              .update({
                'operator_id': actorId,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', bookingId);
        } catch (_) {}
      }

      if (!mounted) return;
      final submitted = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 48,
            vertical: 32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: TripRatingFlowScreen(
                bookingId: bookingId,
                reviewerRole: 'operator',
                title: isComplete ? 'View Rating' : 'Rate Trip',
                subtitle: isComplete
                    ? 'View submitted ratings for this booking.'
                    : 'Submit all required ratings for this completed booking.',
              ),
            ),
          ),
        ),
      );

      if (submitted == true) {
        final reconciled = await TripRatingService().reconcileCompletedBooking(
          bookingId,
          operatorFallbackUserId: actorId,
        );
        await Future.wait([
          _loadRecentBookings(),
          _loadOperatorRevenueBookings(),
          _loadOperatorSettlements(),
        ]);
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reconciled
                  ? 'All ratings submitted. Trip completed and revenue updated.'
                  : 'Rating submitted successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmOperatorFinalPayment(
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    final actorId = _supabase.auth.currentUser?.id;
    if (bookingId.isEmpty || actorId == null || _isPartnerOwnedBooking(booking)) {
      return;
    }

    final finalReceiptUrl =
        (booking['final_payment_proof_url'] ??
                booking['payment_proof_url'] ??
                booking['proof_url'] ??
                booking['reservation_payment_proof_url'])
            ?.toString()
            .trim();
    final hasReceipt = finalReceiptUrl != null && finalReceiptUrl.isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Full Payment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm that the full rental balance and any late-return fee have been paid. This action unlocks the mandatory renter rating.',
              ),
              if (hasReceipt) ...[
                const SizedBox(height: 14),
                const Text(
                  'Attached Renter Payment Receipt:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: OnDemandNetworkImage(
                      imageUrl: finalReceiptUrl,
                      width: 240,
                      height: 160,
                      fit: BoxFit.cover,
                      label: 'Receipt Proof',
                    ),
                  ),
                ),
              ],
            ],
          ),
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

    _showOperationLoading('Confirming full payment & updating revenue...');
    try {
      await BookingService().confirmFinalPayment(
        bookingId: bookingId,
        actorId: actorId,
        actorRole: 'operator',
      );
      await _loadRecentBookings();
      if (!mounted) return;
      setState(() {});
      _hideOperationLoading();
      await _showActionFeedbackModal(
        title: 'Payment Confirmed',
        message: 'Full payment confirmed successfully. Proceeding to renter rating...',
        isError: false,
      );
      // Keep the completion flow moving forward instead of returning the
      // operator to the booking list after every required action.
      final latestBooking =
          await BookingService().getBookingById(bookingId) ?? booking;
      await _openOperatorRenterRating(latestBooking);
    } catch (e) {
      _hideOperationLoading();
      if (!mounted) return;
      await _showActionFeedbackModal(
        title: 'Cannot Confirm Payment',
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      _hideOperationLoading();
    }
  }

  Future<void> _showActionFeedbackModal({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132235),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError
                ? Colors.redAccent.withValues(alpha: 0.6)
                : const Color(0xFF10B981).withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isError
                    ? Colors.redAccent.withValues(alpha: 0.15)
                    : const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                color: isError ? Colors.redAccent : const Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isError ? Colors.redAccent.shade700 : const Color(0xFFE5A93C),
              foregroundColor: isError ? Colors.white : const Color(0xFF0F1A26),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  bool _isCompanyOwnedBooking(Map<String, dynamic> booking) {
    if (_isPartnerOwnedBooking(booking)) return false;
    final vehicle = booking['vehicles'];
    return vehicle != null;
  }

  bool _isPartnerOwnedBooking(Map<String, dynamic> booking) {
    final vehicleRaw = booking['vehicles'] ?? booking['partner_vehicles'];
    final vehicle = vehicleRaw is Map<String, dynamic>
        ? vehicleRaw
        : (vehicleRaw is Map ? Map<String, dynamic>.from(vehicleRaw) : <String, dynamic>{});
    final ownerRaw = vehicle['owner'] ?? vehicle['partners'] ?? booking['partner'];
    final owner = ownerRaw is Map<String, dynamic>
        ? ownerRaw
        : (ownerRaw is Map ? Map<String, dynamic>.from(ownerRaw) : <String, dynamic>{});
    final partnerId = booking['partner_id'] ?? vehicle['partner_id'] ?? booking['partner_vehicle_id'];
    return (partnerId != null && partnerId.toString().trim().isNotEmpty) ||
        owner['role']?.toString().trim().toLowerCase() == 'partner' ||
        vehicle['owner_role']?.toString().trim().toLowerCase() == 'partner' ||
        vehicle['is_partner_vehicle'] == true ||
        booking['is_partner_booking'] == true;
  }

  bool _canTrackBooking(Map<String, dynamic> booking) {
    final status = (booking['status'] as String? ?? '').toLowerCase();
    final group = bookingStatusGroup(booking['status']);
    return status == 'active' ||
        status == 'approved' ||
        status == 'confirmed' ||
        status == 'ongoing' ||
        status == 'in_progress' ||
        status == 'picked_up' ||
        group == BookingStatusGroup.ongoing;
  }

  bool _isOngoingBooking(Map<String, dynamic> booking) {
    final status = (booking['status'] as String? ?? '').toLowerCase();
    final group = bookingStatusGroup(booking['status']);
    return group == BookingStatusGroup.ongoing ||
        status == 'active' ||
        status == 'ongoing' ||
        status == 'in_progress' ||
        status == 'picked_up' ||
        status == 'return_pending_inspection' ||
        status == 'awaiting_completion';
  }

  Future<void> _openBookingConversation(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    try {
      Map<String, dynamic>? conversation;
      for (final item in _conversations) {
        if (item['booking_id']?.toString() == bookingId) {
          conversation = item;
          break;
        }
      }

      if (conversation == null) {
        final operatorId = _supabase.auth.currentUser?.id;
        await BookingService().ensureBookingConversationForActiveBooking(
          bookingId: bookingId,
          operatorId: operatorId,
        );
        await _loadConversations();

        for (final item in _conversations) {
          if (item['booking_id']?.toString() == bookingId) {
            conversation = item;
            break;
          }
        }
      }

      // Realtime/list refreshes can arrive a little later than the insert.
      // Fetch the newly-created row directly so the Message action works now.
      if (conversation == null) {
        final rows = await _supabase
            .from('conversations')
            .select(
              'id, booking_id, user_id, other_user_id, status, created_at, updated_at',
            )
            .eq('booking_id', bookingId)
            .eq('status', 'active')
            .order('created_at', ascending: true)
            .limit(1);
        final directRows = List<Map<String, dynamic>>.from(rows);
        if (directRows.isNotEmpty) {
          conversation = {...directRows.first, 'bookings': booking};
          _conversations.removeWhere(
            (item) => item['booking_id']?.toString() == bookingId,
          );
          _conversations.insert(0, conversation);
        }
      }

      if (!mounted) return;
      final conversationId = conversation?['id']?.toString() ?? '';
      if (conversationId.isEmpty) {
        final status = booking['status']?.toString() ?? 'pending';
        final notEligibleYet = !BookingService().isEligibleForBookingChat(booking);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bookingStatusGroup(status) == BookingStatusGroup.pending
                  ? 'Finalize this booking first to open its group conversation.'
                  : notEligibleYet
                      ? 'Group chat will automatically be created 3 days before the scheduled trip start.'
                      : 'The booking conversation could not be created. Please try again.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }

      setState(() {
        _selectedIndex = 2;
        _selectedConversationId = conversationId;
        _showOperatorBookingActivity = true;
      });
      await _loadConversationMessages(conversationId);
    } catch (error) {
      debugPrint(
        '[Messages] Could not open conversation for $bookingId: $error',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to open the booking conversation right now.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _openOperatorInspectionRecordOrForm(
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
      final status = booking['status']?.toString().trim().toLowerCase() ?? '';
      if (inspectionType == 'before' &&
          allowCreate &&
          (status == 'approved' || status == 'confirmed')) {
        try {
          final inspectorId = Supabase.instance.client.auth.currentUser?.id;
          if (inspectorId == null) {
            throw Exception('Please sign in again');
          }
          await BookingService().startBookingAfterInspection(
            bookingId: bookingId,
            inspectorId: inspectorId,
          );
          if (!mounted) return;
          await _loadDashboardData(showLoading: false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip started successfully')),
          );
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to start trip: $error')),
          );
        }
        return;
      }
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
              backgroundColor: const Color(0xFF132235),
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

        await _showInspectionDialog(booking, inspectionType: inspectionType);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No submitted checklist is available yet'),
        ),
      );
    }
  }

  Future<void> _openTrackingForBooking(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty || !_canTrackBooking(booking)) return;

    setState(() {
      _selectedIndex = 6;
      _focusedTrackingBookingId = bookingId;
      _isLoading = true;
    });

    try {
      await _loadTrackingLocations();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _visibleTrackingLocations() {
    final isFocused = _focusedTrackingBookingId != null &&
        _focusedTrackingBookingId!.isNotEmpty;

    final source = !isFocused
        ? _trackingLocations
        : _trackingLocations.where((location) {
            final booking = location['bookings'] as Map<String, dynamic>?;
            final bookingId = booking?['id']?.toString();
            final rowId = location['id']?.toString();
            final vehicleId = location['vehicle_id']?.toString() ??
                booking?['vehicle_id']?.toString() ??
                (booking?['vehicles'] as Map?)?['id']?.toString();
            return bookingId == _focusedTrackingBookingId ||
                rowId == _focusedTrackingBookingId ||
                vehicleId == _focusedTrackingBookingId;
          }).toList();

    if (isFocused && source.isEmpty) {
      return const [];
    }

    final seenKeys = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final loc in source) {
      final veh = (loc['vehicle'] ?? loc['bookings']?['vehicles']) as Map?;
      final rawPlate = veh?['plate_number']?.toString() ??
          loc['tracker']?['device_identifier']?.toString() ??
          '';
      final plate =
          rawPlate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final vid =
          loc['vehicle_id']?.toString() ?? veh?['id']?.toString() ?? '';
      final trackerId = loc['tracker']?['id']?.toString() ??
          loc['id']?.toString() ??
          '';
      final key = plate.isNotEmpty
          ? 'plate_$plate'
          : (vid.isNotEmpty ? 'vid_$vid' : 'track_$trackerId');
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        deduped.add(loc);
      }
    }
    return deduped;
  }

  bool _isCompanyOwnedTrackingLocation(Map<String, dynamic> location) {
    if (location['has_active_booking'] == false) return true;
    final booking = location['bookings'] as Map<String, dynamic>?;
    if (booking == null) return true;
    return _isCompanyOwnedBooking(booking);
  }

  Future<void> _loadStats() async {
    try {
      // Use server-side COUNT to avoid downloading thousands of IDs just to .length them.
      final results = await Future.wait([
        _supabase.from('users').count().eq('role', 'renter'),
        _supabase.from('users').count().eq('role', 'partner'),
        _supabase.from('vehicles').count().eq('status', 'active'),
        _supabase.from('vehicle_applications').count().eq('status', 'pending'),
        _supabase.from('bookings').count().inFilter('status', ['active', 'approved', 'confirmed']),
        _supabase.from('bookings').count(),
      ]);

      _totalUsers = results[0] as int;
      _totalPartners = results[1] as int;
      _totalVehicles = results[2] as int;
      _pendingVerifications = results[3] as int;
      _activeBookings = results[4] as int;
      _totalBookings = results[5] as int;
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadPendingApplications() async {
    try {
      final response = await _supabase
          .from('vehicle_applications')
          .select('''
              *,
              partners:partner_id (
                user_id,
                users:user_id (full_name, email)
              )
            ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);
      _pendingApplications = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading pending applications: $e');
      _pendingApplications = [];
    }
  }

  Future<void> _loadRecentBookings() async {
    try {
      debugPrint(
        '[Bookings] Loading recent bookings (driver embed via drivers -> users)',
      );
      final response = await _supabase
          .from('bookings')
          .select('''
              *,
              vehicles:vehicle_id (
                id,
                brand,
                model,
                year,
                plate_number,
                owner_id,
                owner_role,
                operator_id,
                location,
                latitude,
                longitude,
                vehicle_name,
                price_per_day,
                transmission,
                vehicle_type,
                category,
                seats,
                owner:users!vehicles_owner_id_fkey (
                  id,
                  role,
                  full_name,
                  email,
                  phone,
                  location,
                  latitude,
                  longitude,
                  avatar_url
                ),
                vehicle_images(id, image_url, display_order)
              ),
              partner_vehicles:partner_vehicle_id (
                id,
                brand,
                model,
                year,
                plate_number,
                vehicle_name,
                price_per_day,
                transmission,
                vehicle_type,
                seats,
                location,
                partners:partner_id (
                  id,
                  user_id,
                  business_name,
                  business_phone,
                  users:user_id (
                    id,
                    full_name,
                    email,
                    phone,
                    avatar_url
                  )
                ),
                vehicle_images(id, image_url, display_order)
              ),
              renter:users!bookings_renter_id_fkey (
                id,
                full_name,
                email,
                phone,
                location,
                avatar_url,
                verification_status
              ),
              driver:drivers!bookings_driver_id_fkey (
                user_id,
                user:users!drivers_user_id_fkey (
                  id,
                  full_name,
                  email,
                  phone,
                  avatar_url
                )
              ),
              job_assignments:driver_job_assignments!driver_job_assignments_booking_id_fkey (
                id,
                driver_id,
                status,
                trip_fee,
                offered_at,
                replied_at,
                created_at,
                updated_at
              )
            ''')
          .order('created_at', ascending: false)
          .limit(100);

      final combinedRawList = List<Map<String, dynamic>>.from(response);
      try {
        final List<dynamic> extQuery = await _supabase
            .from('bookings')
            .select('''
              *,
              vehicles:vehicle_id (
                id,
                brand,
                model,
                year,
                plate_number,
                owner_id,
                owner_role,
                operator_id,
                location,
                vehicle_name,
                price_per_day,
                transmission,
                vehicle_type,
                seats,
                owner:users!vehicles_owner_id_fkey (
                  id,
                  role,
                  full_name,
                  email,
                  phone
                ),
                vehicle_images(id, image_url, display_order)
              ),
              partner_vehicles:partner_vehicle_id (
                id,
                brand,
                model,
                year,
                plate_number,
                vehicle_name,
                price_per_day,
                transmission,
                vehicle_type,
                seats,
                location,
                partners:partner_id (
                  id,
                  user_id,
                  business_name,
                  business_phone,
                  users:user_id (
                    id,
                    full_name,
                    email,
                    phone
                  )
                ),
                vehicle_images(id, image_url, display_order)
              ),
              renter:users!bookings_renter_id_fkey (
                id,
                full_name,
                email,
                phone,
                avatar_url
              )
            ''')
            .neq('extension_status', 'none')
            .not('extension_status', 'is', null)
            .order('updated_at', ascending: false)
            .limit(50);

        final existingIds = Set<String>.from(
          combinedRawList.map((e) => e['id']?.toString() ?? ''),
        );
        for (final item in List<Map<String, dynamic>>.from(extQuery)) {
          final id = item['id']?.toString() ?? '';
          if (id.isNotEmpty && !existingIds.contains(id)) {
            combinedRawList.add(item);
            existingIds.add(id);
          }
        }
      } catch (extErr) {
        debugPrint('[Bookings] Non-critical: error fetching extension bookings: $extErr');
      }

      final hydratedList = await BookingService().hydrateBookingVehicles(
        combinedRawList,
      );

      _recentBookings = hydratedList.map((
        booking,
      ) {
        final normalizedBooking = Map<String, dynamic>.from(booking);
        var vehicle = booking['vehicles'];
        final pv = booking['partner_vehicles'];

        final brand = vehicle is Map ? vehicle['brand']?.toString().trim() ?? '' : '';
        final model = vehicle is Map ? vehicle['model']?.toString().trim() ?? '' : '';
        final vName = vehicle is Map ? vehicle['vehicle_name']?.toString().trim() ?? '' : '';
        final isGenericPlaceholder = (brand.isEmpty && model.isEmpty) ||
            vName.toLowerCase() == 'partner vehicle' ||
            vName.toLowerCase() == 'unknown vehicle' ||
            vName.toLowerCase() == 'vehicle';

        if ((vehicle is! Map || (vehicle as Map).isEmpty || isGenericPlaceholder) &&
            pv is Map &&
            pv.isNotEmpty) {
          vehicle = pv;
        }

        if (vehicle is Map) {
          final normalizedVehicle = Map<String, dynamic>.from(vehicle);
          normalizedVehicle['image_url'] = _primaryVehicleImageUrl(
            normalizedVehicle,
          );
          normalizedBooking['vehicles'] = normalizedVehicle;
        }
        return normalizedBooking;
      }).toList();

      final actorId = _supabase.auth.currentUser?.id;
      if (actorId != null && actorId.isNotEmpty) {
        try {
          final ratingsResp = await _supabase
              .from('trip_ratings')
              .select('booking_id, target_role')
              .eq('reviewer_user_id', actorId);
          final ratingsList = List<Map<String, dynamic>>.from(ratingsResp);
          final ratedMap = <String, Set<String>>{};
          for (final r in ratingsList) {
            final bId = r['booking_id']?.toString() ?? '';
            final role =
                r['target_role']?.toString().toLowerCase().trim() ?? '';
            if (bId.isNotEmpty && role.isNotEmpty) {
              ratedMap.putIfAbsent(bId, () => {}).add(role);
            }
          }
          _operatorSubmittedRatingRolesByBooking = ratedMap;
        } catch (e) {
          debugPrint('Error loading operator ratings: $e');
        }
      }

      _recalculatePendingBookings();
    } catch (e, st) {
      debugPrint(
        '[Bookings] Error loading recent bookings: $e, falling back to BookingService.getAllBookings()',
      );
      try {
        final fallbackList = await BookingService().getAllBookings();
        _recentBookings = fallbackList;
        _recalculatePendingBookings();
      } catch (fbErr) {
        debugPrint('[Bookings] Operator fallback loading failed: $fbErr');
        _recentBookings = [];
      }
    }
  }

  Future<void> _loadOperatorRevenueBookings() async {
    final operatorId = _supabase.auth.currentUser?.id;
    if (operatorId == null || operatorId.isEmpty) {
      _operatorRevenueBookings = [];
      return;
    }

    try {
      final response = await _supabase
          .from('bookings')
          .select('''
            id,
            operator_id,
            vehicle_id,
            partner_vehicle_id,
            renter_id,
            status,
            payment_status,
            total_price,
            total_paid_amount,
            metadata,
            created_at,
            completed_at,
            booking_financials (
              total_cost,
              final_payment_status,
              reservation_payment_status
            ),
            renter:users!bookings_renter_id_fkey (
              id,
              full_name,
              email,
              avatar_url
            ),
            vehicles:vehicle_id (
              id,
              brand,
              model,
              year,
              plate_number,
              vehicle_name,
              owner_role,
              operator_id,
              vehicle_images (
                id,
                image_url,
                display_order
              )
            )
          ''')
          .order('created_at', ascending: false);
      _operatorRevenueBookings = List<Map<String, dynamic>>.from(response);
      for (final b in _operatorRevenueBookings) {
        final meta = b['metadata'] is Map ? (b['metadata'] as Map) : null;
        if (meta != null) {
          b['completion_stage'] ??= meta['completion_stage'];
          b['final_payment_confirmed_at'] ??= meta['final_payment_confirmed_at'];
        }
      }
    } catch (e) {
      debugPrint('Error loading operator revenue analytics: $e');
      _operatorRevenueBookings = [];
    }
  }

  Future<void> _loadOperatorSettlements() async {
    final operatorId = _supabase.auth.currentUser?.id;
    if (operatorId == null || operatorId.isEmpty) {
      _operatorSettlements = [];
      return;
    }
    try {
      final response = await _supabase
          .from('booking_settlements')
          .select('''
            id,
            booking_id,
            gross_amount,
            operator_managed_amount,
            platform_commission,
            partner_amount,
            driver_amount,
            status,
            released_at
          ''')
          .eq('operator_user_id', operatorId)
          .order('released_at', ascending: false);
      _operatorSettlements = List<Map<String, dynamic>>.from(response);
    } catch (error) {
      // The dashboard remains usable before the new migration is deployed.
      debugPrint('Error loading operator settlement summary: $error');
      _operatorSettlements = [];
    }
  }

  Future<void> _repairOperatorRevenueSettlements() async {
    final operatorId = _supabase.auth.currentUser?.id;
    if (operatorId == null ||
        operatorId.isEmpty ||
        _operatorRevenueBookings.isEmpty) {
      return;
    }

    final candidates = _operatorRevenueBookings
        .where((booking) {
          final status = bookingStatusGroup(booking['status']);
          final financials = booking['booking_financials'];
          final finStatus = financials is Map
              ? financials['final_payment_status']?.toString().trim().toLowerCase()
              : null;
          final paymentStatus = (booking['payment_status'] ??
                  booking['final_payment_status'] ??
                  finStatus)
              ?.toString()
              .trim()
              .toLowerCase();
          final isPaid = paymentStatus == 'paid' ||
              paymentStatus == 'completed' ||
              (booking['total_paid_amount'] as num? ?? 0) > 0;
          final commissionStatus = booking['commission_status']
              ?.toString()
              .trim()
              .toLowerCase();
          return status == BookingStatusGroup.completed &&
              isPaid &&
              commissionStatus != 'released';
        })
        .take(8);

    for (final booking in candidates) {
      final bookingId = booking['id']?.toString();
      if (bookingId == null || bookingId.isEmpty) continue;
      try {
        await TripRatingService().reconcileCompletedBooking(
          bookingId,
          operatorFallbackUserId: operatorId,
        );
        booking['commission_status'] = 'released';
        booking['operator_id'] ??= operatorId;
      } catch (error) {
        debugPrint(
          'Could not repair operator settlement for $bookingId: $error',
        );
      }
    }
  }

  Future<void> _loadVehicles() async {
    try {
      await VehicleTurnaroundService().processExpiredTurnarounds();
      final ownVehicles = await _supabase
          .from('vehicles')
          .select('*, vehicle_images(id, image_url, display_order)')
          .order('created_at', ascending: false);
      debugPrint('vehicles loaded: ${(ownVehicles as List).length}');

      final normalizedOwnVehicles = (ownVehicles as List)
          .whereType<Map<String, dynamic>>()
          .where((vehicle) {
            final isPartner = vehicle['is_partner_vehicle'] == true ||
                vehicle['partner_id'] != null ||
                vehicle['owner_role']?.toString().toLowerCase() == 'partner';
            return !isPartner;
          })
          .map((vehicle) {
            final merged = Map<String, dynamic>.from(vehicle);
            merged['_source'] = 'company';
            merged['source'] = 'company';
            final rawPosted = vehicle['is_posted'];
            final rawAvailable = vehicle['is_available'];
            final rawStatus = vehicle['status']?.toString().toLowerCase();

            final isListed = rawPosted is bool
                ? rawPosted
                : (rawAvailable == true ||
                   rawStatus == 'available' ||
                   rawStatus == 'active');
            merged['is_posted'] = isListed;
            merged['is_available'] = rawAvailable is bool ? rawAvailable : isListed;

            final pricePerDay = (vehicle['price_per_day'] as num?)?.toDouble() ?? 0.0;
            final existingPerHour = (vehicle['price_per_hour'] as num?)?.toDouble();
            merged['price_per_hour'] = (existingPerHour != null && existingPerHour > 0)
                ? existingPerHour
                : (pricePerDay > 0 ? (pricePerDay / 10).roundToDouble() : 0.0);
            return merged;
          })
          .toList();

      List partnerVehiclesResp = [];
      try {
        partnerVehiclesResp =
            await _supabase
                    .from('partner_vehicles')
                    .select(
                      '*, partners:partner_id(id,user_id,business_name,business_address,business_phone,users:user_id(full_name,email,phone))',
                    )
                    .order('created_at', ascending: false)
                as List;
      } catch (e) {
        debugPrint('Partner relation select failed, using fallback: $e');
        try {
          partnerVehiclesResp =
              await _supabase
                      .from('partner_vehicles')
                      .select('*')
                      .order('created_at', ascending: false)
                  as List;
        } catch (fallbackError) {
          debugPrint('Error loading partner_vehicles: $fallbackError');
          partnerVehiclesResp = [];
        }
      }

      // Filter only approved/verified partner vehicles from partner_vehicles table
      const blockedStatuses = {'rejected', 'deleted'};
      final approvedPartnerVehiclesResp = partnerVehiclesResp
          .whereType<Map<String, dynamic>>()
          .where((pv) {
            final appStatus =
                (pv['application_status'] ?? '').toString().trim().toLowerCase();
            final status =
                (pv['status'] ?? '').toString().trim().toLowerCase();
            if (blockedStatuses.contains(appStatus) ||
                blockedStatuses.contains(status)) {
              return false;
            }
            return true;
          })
          .toList();

      final candidateIdsSet = <String>{};
      for (final pv in approvedPartnerVehiclesResp) {
        final id = pv['id']?.toString();
        final vid = pv['vehicle_id']?.toString();
        final pvid = pv['partner_vehicle_id']?.toString();
        final appId = pv['application_id']?.toString();
        if (id != null && id.isNotEmpty) candidateIdsSet.add(id);
        if (vid != null && vid.isNotEmpty) candidateIdsSet.add(vid);
        if (pvid != null && pvid.isNotEmpty) candidateIdsSet.add(pvid);
        if (appId != null && appId.isNotEmpty) candidateIdsSet.add(appId);
      }
      final candidateIds = candidateIdsSet.toList();

      final partnerImagesByVehicleId = <String, List<Map<String, dynamic>>>{};
      final partnerAppPhotosByVehicleId = <String, String>{};

      if (candidateIds.isNotEmpty) {
        try {
          final partnerImages = await _supabase
              .from('vehicle_images')
              .select('id,partner_vehicle_id,vehicle_id,image_url,display_order')
              .inFilter('partner_vehicle_id', candidateIds);
          for (final image in List<Map<String, dynamic>>.from(partnerImages)) {
            final partnerVehicleId = image['partner_vehicle_id']?.toString();
            if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
              partnerImagesByVehicleId
                  .putIfAbsent(partnerVehicleId, () => [])
                  .add(image);
            }
          }
        } catch (e) {
          debugPrint('Error loading partner vehicle images by partner_vehicle_id: $e');
        }

        try {
          final canonicalImages = await _supabase
              .from('vehicle_images')
              .select('id,partner_vehicle_id,vehicle_id,image_url,display_order')
              .inFilter('vehicle_id', candidateIds);
          for (final image in List<Map<String, dynamic>>.from(canonicalImages)) {
            final vehicleId = image['vehicle_id']?.toString();
            if (vehicleId != null && vehicleId.isNotEmpty) {
              partnerImagesByVehicleId
                  .putIfAbsent(vehicleId, () => [])
                  .add(image);
            }
          }
        } catch (e) {
          debugPrint('Error loading partner vehicle images by vehicle_id: $e');
        }

        try {
          final appPhotos = await _supabase
              .from('partner_vehicle_applications')
              .select('id,partner_vehicle_id,vehicle_photo_url')
              .inFilter('partner_vehicle_id', candidateIds);
          for (final app in List<Map<String, dynamic>>.from(appPhotos)) {
            final pvid = app['partner_vehicle_id']?.toString();
            final appId = app['id']?.toString();
            final photoUrl = app['vehicle_photo_url']?.toString().trim();
            if (photoUrl != null && photoUrl.isNotEmpty) {
              if (pvid != null && pvid.isNotEmpty) partnerAppPhotosByVehicleId[pvid] = photoUrl;
              if (appId != null && appId.isNotEmpty) partnerAppPhotosByVehicleId[appId] = photoUrl;
            }
          }
        } catch (e) {
          debugPrint('Error loading fallback partner application photos: $e');
        }

        try {
          final docPhotos = await _supabase
              .from('partner_vehicle_documents')
              .select('partner_vehicle_application_id,file_url')
              .eq('document_type', 'vehicle_photo')
              .inFilter('partner_vehicle_application_id', candidateIds);
          for (final doc in List<Map<String, dynamic>>.from(docPhotos)) {
            final appId = doc['partner_vehicle_application_id']?.toString();
            final fileUrl = doc['file_url']?.toString().trim();
            if (appId != null && fileUrl != null && fileUrl.isNotEmpty) {
              partnerImagesByVehicleId
                  .putIfAbsent(appId, () => [])
                  .add({'image_url': fileUrl, 'display_order': 0});
            }
          }
        } catch (e) {
          debugPrint('Error loading partner vehicle document photos: $e');
        }
      }

      final normalizedPartnerVehicles = approvedPartnerVehiclesResp
          .map((pv) {
            final partner = pv['partners'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(pv['partners'])
                : <String, dynamic>{};
            final partnerUser = partner['users'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(partner['users'])
                : <String, dynamic>{};
            final partnerName =
                partner['business_name']?.toString().trim().isNotEmpty == true
                ? partner['business_name'].toString()
                : partnerUser['full_name']?.toString().trim().isNotEmpty == true
                ? partnerUser['full_name'].toString()
                : 'Mobilis Partner';
            final partnerVehicleId = pv['id']?.toString() ?? '';
            final canonicalVehicleId = pv['vehicle_id']?.toString() ?? '';
            final appId = pv['application_id']?.toString() ?? '';

            final imagesList = <Map<String, dynamic>>[];
            final seenUrls = <String>{};

            void collectImages(List<Map<String, dynamic>>? imgs) {
              if (imgs == null) return;
              for (final img in imgs) {
                final url = (img['image_url'] ?? img['file_url'] ?? img['url'])?.toString().trim() ?? '';
                if (url.isNotEmpty && !seenUrls.contains(url)) {
                  seenUrls.add(url);
                  imagesList.add(img);
                }
              }
            }

            collectImages(partnerImagesByVehicleId[partnerVehicleId]);
            if (canonicalVehicleId.isNotEmpty) {
              collectImages(partnerImagesByVehicleId[canonicalVehicleId]);
            }
            if (appId.isNotEmpty) {
              collectImages(partnerImagesByVehicleId[appId]);
            }

            final fallbackPhoto = partnerAppPhotosByVehicleId[partnerVehicleId] ??
                (canonicalVehicleId.isNotEmpty ? partnerAppPhotosByVehicleId[canonicalVehicleId] : null) ??
                (appId.isNotEmpty ? partnerAppPhotosByVehicleId[appId] : null) ??
                pv['vehicle_photo_url']?.toString().trim() ??
                pv['photo_url']?.toString().trim() ??
                pv['image_url']?.toString().trim() ??
                '';

            if (fallbackPhoto.isNotEmpty && !seenUrls.contains(fallbackPhoto)) {
              imagesList.add({'image_url': fallbackPhoto, 'display_order': imagesList.length});
              seenUrls.add(fallbackPhoto);
            }

            imagesList.sort((a, b) {
              final aOrder = (a['display_order'] as num?)?.toInt() ?? 9999;
              final bOrder = (b['display_order'] as num?)?.toInt() ?? 9999;
              return aOrder.compareTo(bOrder);
            });

            final resolvedImageUrl = imagesList.isNotEmpty
                ? imagesList.first['image_url']?.toString()
                : fallbackPhoto;

            final merged = Map<String, dynamic>.from(pv)
              ..['_source'] = 'partner'
              ..['source'] = 'partner'
              ..['_partner_vehicle_id'] = partnerVehicleId
              ..['partner_vehicle_id'] = partnerVehicleId
              ..['is_partner_vehicle'] = true
              ..['partner_name'] = partnerName
              ..['partner_email'] = partnerUser['email']
              ..['partner_phone'] =
                  partner['business_phone'] ?? partnerUser['phone']
              ..['partner_address'] = partner['business_address']
              ..['owner_name'] = partnerName
              ..['vehicle_images'] = imagesList
              ..['image_url'] = resolvedImageUrl
              ..['vehicle_photo_url'] = fallbackPhoto
              ..['vehicle_name'] =
                  pv['vehicle_name'] ??
                  '${pv['brand'] ?? ''} ${pv['model'] ?? ''}'.trim()
              ..['category'] =
                  pv['category'] ?? pv['vehicle_type'] ?? 'Partner Vehicle'
              ..['vehicle_type'] =
                  pv['vehicle_type'] ?? pv['category'] ?? 'Partner Vehicle'
              ..['is_posted'] = pv['is_posted'] is bool
                  ? pv['is_posted']
                  : (pv['is_available'] == true ||
                     pv['status']?.toString().toLowerCase() == 'available' ||
                     pv['status']?.toString().toLowerCase() == 'active' ||
                     pv['status']?.toString().toLowerCase() == 'approved')
              ..['is_available'] = pv['is_available'] is bool
                  ? pv['is_available']
                  : (pv['is_posted'] == true ||
                     pv['status']?.toString().toLowerCase() == 'available' ||
                     pv['status']?.toString().toLowerCase() == 'active' ||
                     pv['status']?.toString().toLowerCase() == 'approved');

            final pvPricePerDay = (merged['price_per_day'] as num?)?.toDouble() ?? 0.0;
            final pvExistingPerHour = (merged['price_per_hour'] as num?)?.toDouble();
            merged['price_per_hour'] = (pvExistingPerHour != null && pvExistingPerHour > 0)
                ? pvExistingPerHour
                : (pvPricePerDay > 0 ? (pvPricePerDay / 10).roundToDouble() : 0.0);
            return merged;
          })
          .toList();

      setState(() {
        _vehicles = List<Map<String, dynamic>>.from(normalizedOwnVehicles);
        _partnerVehicles = List<Map<String, dynamic>>.from(
          normalizedPartnerVehicles,
        );
      });
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      _vehicles = [];
      _partnerVehicles = [];
    }
  }

  String _primaryVehicleImageUrl(Map<String, dynamic>? vehicle) {
    if (vehicle == null || vehicle.isEmpty) return '';

    final directImageUrl = (vehicle['image_url'] ??
            vehicle['vehicle_photo_url'] ??
            vehicle['photo_url'])
        ?.toString()
        .trim() ??
        '';
    if (directImageUrl.isNotEmpty) {
      return _normalizeVehicleImageUrl(directImageUrl);
    }

    final images = vehicle['vehicle_images'];
    if (images is List && images.isNotEmpty) {
      for (final image in images) {
        if (image is! Map) continue;
        final imageMap = Map<String, dynamic>.from(image);
        final imageUrl = (imageMap['image_url'] ??
                imageMap['file_url'] ??
                imageMap['url'])
            ?.toString()
            .trim() ??
            '';
        if (imageUrl.isNotEmpty) return _normalizeVehicleImageUrl(imageUrl);
      }
    }

    final id = vehicle['id']?.toString() ??
        vehicle['partner_vehicle_id']?.toString() ??
        vehicle['_partner_vehicle_id']?.toString() ??
        '';
    if (id.isNotEmpty) {
      final pool = [..._vehicles, ..._partnerVehicles];
      for (final v in pool) {
        if (v['id']?.toString() == id ||
            v['partner_vehicle_id']?.toString() == id ||
            v['_partner_vehicle_id']?.toString() == id) {
          final cachedImg = (v['image_url'] ??
                  v['vehicle_photo_url'] ??
                  v['photo_url'])
              ?.toString()
              .trim() ??
              '';
          if (cachedImg.isNotEmpty) return _normalizeVehicleImageUrl(cachedImg);
          final vImgs = v['vehicle_images'] as List?;
          if (vImgs != null && vImgs.isNotEmpty) {
            for (final img in vImgs) {
              if (img is Map) {
                final url = (img['image_url'] ?? img['file_url'] ?? img['url'])
                    ?.toString()
                    .trim() ??
                    '';
                if (url.isNotEmpty) return _normalizeVehicleImageUrl(url);
              }
            }
          }
        }
      }
    }

    return '';
  }

  String _normalizeVehicleImageUrl(dynamic value, [dynamic vehicleImages]) {
    if (value == null && vehicleImages == null) return '';
    var imageUrl = value?.toString().trim() ?? '';
    if (imageUrl.isEmpty && vehicleImages is List && vehicleImages.isNotEmpty) {
      final first = vehicleImages.first;
      if (first is Map) {
        imageUrl = first['image_url']?.toString().trim() ?? '';
      } else {
        imageUrl = first.toString().trim();
      }
    }
    if (imageUrl.isEmpty ||
        imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://') ||
        imageUrl.startsWith('data:')) {
      return imageUrl;
    }

    imageUrl = imageUrl.replaceFirst(RegExp(r'^/+'), '');
    const knownBuckets = [
      'vehicle_images',
      'vehicle-images',
      'partner_documents',
      'partner-documents',
      'partner_vehicle_application_documents',
      'documents',
      'avatars',
    ];

    for (final bucket in knownBuckets) {
      if (imageUrl.startsWith('$bucket/')) {
        final relativePath = imageUrl.substring(bucket.length + 1);
        return _supabase.storage.from(bucket).getPublicUrl(relativePath);
      }
    }

    return _supabase.storage.from(_vehicleImagesBucket).getPublicUrl(imageUrl);
  }

  String _notificationVehicleImageUrl(Map<String, dynamic> notification) {
    final target = resolveNotificationTarget(notification);
    final directImage =
        target.data['vehicle_image_url']?.toString().trim() ??
        target.data['image_url']?.toString().trim() ??
        '';
    if (directImage.isNotEmpty) return _normalizeVehicleImageUrl(directImage);

    final bookingId = target.bookingId;
    if (bookingId == null || bookingId.isEmpty) return '';
    for (final booking in _recentBookings) {
      if (booking['id']?.toString() != bookingId) continue;
      final vehicle = booking['vehicles'];
      if (vehicle is Map) {
        return _primaryVehicleImageUrl(Map<String, dynamic>.from(vehicle));
      }
    }
    return '';
  }

  Future<void> _handleApplicationAction(
    String applicationId,
    String action,
  ) async {
    try {
      await _supabase
          .from('vehicle_applications')
          .update({'status': action})
          .eq('id', applicationId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Application ${action == 'approved' ? 'approved' : 'rejected'}',
          ),
          backgroundColor: action == 'approved' ? Colors.green : Colors.red,
        ),
      );
      await Future.wait([
        _loadDashboardData(showLoading: false),
        _loadConversations(),
      ]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
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

  /// ✅ Approve booking with optional driver assignment and destination surcharge
  Future<void> _approveBooking(
    Map<String, dynamic> booking, {
    String? driverId,
    double? dailyDestinationSurcharge,
    double? destinationFee,
    String? destinationFeeNotes,
    double? updatedTotalPrice,
    double? updatedRentalSubtotal,
    double? updatedPrincipalTotalPrice,
  }) async {
    _showOperationLoading(
      driverId != null
          ? 'Assigning driver & processing booking approval...'
          : 'Finalizing booking & creating group chat...',
    );
    try {
      final bookingId = booking['id']?.toString() ?? '';
      if (bookingId.isEmpty) {
        throw Exception('Invalid booking id');
      }
      if (_isPartnerOwnedBooking(booking)) {
        throw Exception('Partner bookings are managed and approved solely by the Partner.');
      }

      final operatorId = _supabase.auth.currentUser?.id;
      if (operatorId == null || operatorId.isEmpty) {
        throw Exception('Operator is not authenticated');
      }

      final bookingService = BookingService();

      final updatePayload = <String, dynamic>{
        'operator_id': operatorId,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (dailyDestinationSurcharge != null) {
        updatePayload['daily_destination_surcharge'] = dailyDestinationSurcharge;
      }
      if (destinationFee != null) {
        updatePayload['destination_fee'] = destinationFee;
      }
      if (destinationFeeNotes != null && destinationFeeNotes.trim().isNotEmpty) {
        updatePayload['destination_fee_notes'] = destinationFeeNotes.trim();
      }
      if (updatedTotalPrice != null) {
        updatePayload['total_price'] = updatedTotalPrice;
      }
      if (updatedRentalSubtotal != null) {
        updatePayload['rental_subtotal'] = updatedRentalSubtotal;
      }
      if (updatedPrincipalTotalPrice != null) {
        updatePayload['principal_total_price'] = updatedPrincipalTotalPrice;
      }

      await BookingService.safeUpdateBooking(bookingId, updatePayload);

      if (driverId != null) {
        await bookingService.assignDriver(bookingId, driverId, 0.0);
      } else {
        await bookingService.finalizeBooking(
          bookingId: bookingId,
          operatorId: operatorId,
        );
      }

      _hideOperationLoading();
      _loadDashboardData(showLoading: false);
      _loadConversations();

      if (mounted) {
        await _showActionFeedbackModal(
          title: 'Booking Approved',
          message: driverId != null
              ? 'Driver job offer sent. Waiting for driver response.'
              : 'Booking confirmed and finalized successfully! Conversation created.',
          isError: false,
        );
      }
    } catch (e) {
      _hideOperationLoading();
      if (mounted) {
        await _showActionFeedbackModal(
          title: 'Approval Failed',
          message: 'Error approving booking: $e',
          isError: true,
        );
      }
    } finally {
      _hideOperationLoading();
    }
  }

  Future<String?> _resolveDriverUserId(dynamic driverId) async {
    final value = driverId?.toString().trim();
    if (value == null || value.isEmpty) return null;

    final byUserId = await _supabase
        .from('drivers')
        .select('user_id')
        .eq('user_id', value)
        .maybeSingle();
    final existingUserId = byUserId?['user_id']?.toString();
    if (existingUserId != null && existingUserId.isNotEmpty) {
      return existingUserId;
    }

    final byProfileId = await _supabase
        .from('drivers')
        .select('user_id')
        .eq('id', value)
        .maybeSingle();
    final profileUserId = byProfileId?['user_id']?.toString();
    return profileUserId == null || profileUserId.isEmpty
        ? null
        : profileUserId;
  }

  Map<String, dynamic>? _latestDriverAssignment(Map<String, dynamic> booking) {
    final rawAssignments = booking['job_assignments'];
    if (rawAssignments is! List || rawAssignments.isEmpty) return null;
    final assignments = rawAssignments
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (assignments.isEmpty) return null;
    assignments.sort((a, b) {
      final aDate = DateTime.tryParse(
        (a['created_at'] ?? a['offered_at'])?.toString() ?? '',
      );
      final bDate = DateTime.tryParse(
        (b['created_at'] ?? b['offered_at'])?.toString() ?? '',
      );
      return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
    });
    return assignments.first;
  }

  Future<void> _createBookingGroupChat(
    Map<String, dynamic> booking,
    String? driverId,
  ) async {
    try {
      final bookingId = booking['id'] as String;
      final operatorId = _supabase.auth.currentUser?.id;
      final vehicle = (booking['vehicles'] as Map<String, dynamic>?) ?? {};
      final ownerId = vehicle['owner_id'] as String?;
      final renterId = booking['renter_id'] as String?;

      if (operatorId == null || renterId == null) {
        return;
      }

      final participantIds = <String>{renterId, operatorId};

      final driverIdForChat =
          driverId?.toString() ?? booking['driver_id']?.toString();
      if (driverIdForChat != null && driverIdForChat.isNotEmpty) {
        final driverUserId = await _resolveDriverUserId(driverIdForChat);
        if (driverUserId != null && driverUserId.isNotEmpty) {
          participantIds.add(driverUserId);
        }
      }

      if (ownerId != null) {
        participantIds.add(ownerId);
      }

      await ChatService().createGroupConversation(
        bookingId: bookingId,
        participantIds: participantIds.toList(),
      );

      await BookingService.safeUpdateBooking(bookingId, {
        'conversation_created': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Group chat created for booking: $bookingId');
    } catch (e) {
      debugPrint('Error creating group chat: $e');
    }
  }

  /// ❌ Reject booking with reason
  Future<void> _rejectBooking(String bookingId, String reason) async {
    try {
      Map<String, dynamic>? targetBooking;
      for (final b in _recentBookings) {
        if (b['id']?.toString() == bookingId) {
          targetBooking = b;
          break;
        }
      }
      if (targetBooking != null && _isPartnerOwnedBooking(targetBooking)) {
        throw Exception('Partner bookings are managed solely by the Partner and cannot be rejected by the operator.');
      }

      final bookingService = BookingService();
      await bookingService.rejectBooking(bookingId, reason, cachedBooking: targetBooking);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Booking rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _loadDashboardData();

      // Instantly open the refund window if booking has payment / refund is required
      if (mounted) {
        final freshBooking = await BookingService().getBookingById(bookingId) ?? targetBooking;
        if (freshBooking != null) {
          final refundAmount = resolveBookingRefundAmount(freshBooking);
          final hasPayment = (freshBooking['reservation_payment_reference']?.toString().trim().isNotEmpty == true) ||
              (freshBooking['reservation_payment_proof_url']?.toString().trim().isNotEmpty == true) ||
              (freshBooking['final_payment_reference']?.toString().trim().isNotEmpty == true) ||
              (freshBooking['paid_amount'] != null && ((freshBooking['paid_amount'] as num).toDouble() > 0)) ||
              (freshBooking['reservation_fee_amount'] != null && ((freshBooking['reservation_fee_amount'] as num).toDouble() > 0)) ||
              refundAmount > 0;
          if (hasPayment) {
            await _showBookingRefundDialog(freshBooking);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 🚗 Assign driver to booking
  Future<void> _assignDriver(String bookingId, String driverId) async {
    try {
      final bookingService = BookingService();
      await bookingService.assignDriver(bookingId, driverId, 0.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Driver assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getMonthName(int month) {
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
    return month >= 1 && month <= 12 ? months[month - 1] : '';
  }

  String _formatBookingDateTime(DateTime? value) {
    if (value == null) return 'N/A';
    final localValue = value.toLocal();
    final hour12 = localValue.hour % 12 == 0 ? 12 : localValue.hour % 12;
    final minute = localValue.minute.toString().padLeft(2, '0');
    final suffix = localValue.hour >= 12 ? 'PM' : 'AM';
    return '${localValue.day.toString().padLeft(2, '0')} ${_getMonthName(localValue.month)} ${localValue.year}, $hour12:$minute $suffix';
  }

  int _inclusiveRentalDays(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) return 0;

    final localStartDate = startDate.toLocal();
    final localEndDate = endDate.toLocal();
    final startDay = DateTime(
      localStartDate.year,
      localStartDate.month,
      localStartDate.day,
    );
    final endDay = DateTime(
      localEndDate.year,
      localEndDate.month,
      localEndDate.day,
    );
    final calendarDays = endDay.difference(startDay).inDays + 1;

    return calendarDays < 1 ? 1 : calendarDays;
  }

  String _vehicleTitle(dynamic input) {
    if (input == null) return 'Partner Vehicle';
    final map = input is Map<String, dynamic>
        ? input
        : (input is Map ? Map<String, dynamic>.from(input) : <String, dynamic>{});
    if (map.isEmpty) return 'Partner Vehicle';

    // 1. Check direct brand / model in map
    final brand = map['brand']?.toString().trim() ?? '';
    final model = map['model']?.toString().trim() ?? '';
    final year = map['year']?.toString().trim() ?? '';
    final combo = [brand, model].where((part) => part.isNotEmpty).join(' ');
    if (combo.isNotEmpty) {
      return year.isEmpty ? combo : '$combo ($year)';
    }

    // 2. If map contains nested 'partner_vehicles'
    if (map['partner_vehicles'] is Map) {
      final pv = Map<String, dynamic>.from(map['partner_vehicles'] as Map);
      final b = pv['brand']?.toString().trim() ?? '';
      final m = pv['model']?.toString().trim() ?? '';
      final y = pv['year']?.toString().trim() ?? '';
      final c = [b, m].where((part) => part.isNotEmpty).join(' ');
      if (c.isNotEmpty) return y.isEmpty ? c : '$c ($y)';
      final vName = pv['vehicle_name']?.toString().trim() ?? '';
      if (vName.isNotEmpty &&
          vName.toLowerCase() != 'partner vehicle' &&
          vName.toLowerCase() != 'unknown vehicle' &&
          vName.toLowerCase() != 'vehicle') {
        return vName;
      }
    }

    // 3. If map contains nested 'vehicles'
    if (map['vehicles'] is Map) {
      final v = Map<String, dynamic>.from(map['vehicles'] as Map);
      final b = v['brand']?.toString().trim() ?? '';
      final m = v['model']?.toString().trim() ?? '';
      final y = v['year']?.toString().trim() ?? '';
      final c = [b, m].where((part) => part.isNotEmpty).join(' ');
      if (c.isNotEmpty) return y.isEmpty ? c : '$c ($y)';
      final vName = v['vehicle_name']?.toString().trim() ?? '';
      if (vName.isNotEmpty &&
          vName.toLowerCase() != 'partner vehicle' &&
          vName.toLowerCase() != 'unknown vehicle' &&
          vName.toLowerCase() != 'vehicle') {
        return vName;
      }
    }

    // 4. Check vehicle_name if not generic placeholder
    final vehicleName = map['vehicle_name']?.toString().trim() ?? '';
    if (vehicleName.isNotEmpty &&
        vehicleName.toLowerCase() != 'partner vehicle' &&
        vehicleName.toLowerCase() != 'unknown vehicle' &&
        vehicleName.toLowerCase() != 'vehicle') {
      return vehicleName;
    }

    // 5. Candidate IDs to check in _partnerVehicles & _vehicles pool
    final candidateIds = <String>{
      if (map['id'] != null) map['id'].toString(),
      if (map['partner_vehicle_id'] != null) map['partner_vehicle_id'].toString(),
      if (map['vehicle_id'] != null) map['vehicle_id'].toString(),
      if (map['_partner_vehicle_id'] != null) map['_partner_vehicle_id'].toString(),
      if (map['partner_vehicles'] is Map && (map['partner_vehicles'] as Map)['id'] != null)
        (map['partner_vehicles'] as Map)['id'].toString(),
      if (map['vehicles'] is Map && (map['vehicles'] as Map)['id'] != null)
        (map['vehicles'] as Map)['id'].toString(),
    }.where((id) => id.isNotEmpty).toSet();

    final pool = [..._partnerVehicles, ..._vehicles];
    for (final id in candidateIds) {
      for (final v in pool) {
        final vId = v['id']?.toString() ?? '';
        final vPvid = v['partner_vehicle_id']?.toString() ?? '';
        final vVid = v['vehicle_id']?.toString() ?? '';
        final vAppId = v['application_id']?.toString() ?? '';

        if (vId == id || vPvid == id || vVid == id || vAppId == id) {
          final b = v['brand']?.toString().trim() ?? '';
          final m = v['model']?.toString().trim() ?? '';
          final y = v['year']?.toString().trim() ?? '';
          final vCombo = [b, m].where((part) => part.isNotEmpty).join(' ');
          if (vCombo.isNotEmpty) return y.isEmpty ? vCombo : '$vCombo ($y)';

          final vName = v['vehicle_name']?.toString().trim() ?? '';
          if (vName.isNotEmpty &&
              vName.toLowerCase() != 'partner vehicle' &&
              vName.toLowerCase() != 'unknown vehicle' &&
              vName.toLowerCase() != 'vehicle') {
            return vName;
          }
        }
      }
    }

    // 6. Match by plate number in pool if ID didn't match
    final plate = (map['plate_number'] ??
            (map['vehicles'] is Map ? (map['vehicles'] as Map)['plate_number'] : null) ??
            (map['partner_vehicles'] is Map ? (map['partner_vehicles'] as Map)['plate_number'] : null))
        ?.toString()
        .trim() ??
        '';
    if (plate.isNotEmpty) {
      for (final v in pool) {
        if (v['plate_number']?.toString().trim() == plate) {
          final b = v['brand']?.toString().trim() ?? '';
          final m = v['model']?.toString().trim() ?? '';
          final y = v['year']?.toString().trim() ?? '';
          final vCombo = [b, m].where((part) => part.isNotEmpty).join(' ');
          if (vCombo.isNotEmpty) return y.isEmpty ? vCombo : '$vCombo ($y)';
        }
      }
      return 'Vehicle ($plate)';
    }

    return 'Partner Vehicle';
  }

  double? _coordinateValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '');
  }

  MobilisMapPoint? _coordinatePoint(dynamic latitude, dynamic longitude) {
    final parsedLatitude = _coordinateValue(latitude);
    final parsedLongitude = _coordinateValue(longitude);
    if (parsedLatitude == null ||
        parsedLongitude == null ||
        parsedLatitude < -90 ||
        parsedLatitude > 90 ||
        parsedLongitude < -180 ||
        parsedLongitude > 180) {
      return null;
    }
    return MobilisMapPoint(
      latitude: parsedLatitude,
      longitude: parsedLongitude,
    );
  }

  bool _isLikelyPhilippinesPoint(MobilisMapPoint? point) {
    if (point == null) return false;
    if (point.latitude.abs() < 0.000001 && point.longitude.abs() < 0.000001) {
      return false;
    }
    return point.latitude >= 4.0 &&
        point.latitude <= 22.5 &&
        point.longitude >= 116.0 &&
        point.longitude <= 127.5;
  }

  MobilisMapPoint? _philippinesCoordinatePoint(
    dynamic latitude,
    dynamic longitude,
  ) {
    final point = _coordinatePoint(latitude, longitude);
    if (_isLikelyPhilippinesPoint(point)) return point;

    // Some saved rows from older map pickers used longitude/latitude order.
    // Try the swapped values before giving up so valid PH pins do not render
    // as intercontinental routes in the operator route modal.
    final swappedPoint = _coordinatePoint(longitude, latitude);
    return _isLikelyPhilippinesPoint(swappedPoint) ? swappedPoint : null;
  }

  MobilisMapPoint _psdcGaragePoint() {
    return const MobilisMapPoint(
      latitude: PhilippineLocations.psdcGarageLatitude,
      longitude: PhilippineLocations.psdcGarageLongitude,
    );
  }

  bool _isDefaultPsdcPickup(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized.isEmpty ||
        PhilippineLocations.isPsdcGarageLabel(normalized) ||
        normalized.contains('self-pickup') ||
        normalized.contains('self pickup') ||
        normalized.contains('psdc garage') ||
        normalized.contains('xgfw+jq') ||
        normalized.contains('urdaneta');
  }

  String _stripPlusCodePrefix(String address) {
    final trimmedAddress = address.trim();
    if (trimmedAddress.isEmpty) return '';
    final withoutLeadingPlusCode = trimmedAddress
        .replaceFirst(
          RegExp(
            r'^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,4},?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final source = withoutLeadingPlusCode.isNotEmpty
        ? withoutLeadingPlusCode
        : trimmedAddress;
    final parts = source
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isNotEmpty &&
        RegExp(
          r'^[23456789CFGHJMPQRVWX]{4,}\+[23456789CFGHJMPQRVWX]{2,}$',
          caseSensitive: false,
        ).hasMatch(parts.first)) {
      return parts.skip(1).join(', ');
    }
    return source;
  }

  MobilisMapPoint? _knownBookingAddressPoint(String address) {
    final normalized = address.toLowerCase();
    if (_isDefaultPsdcPickup(address) ||
        PhilippineLocations.isPsdcGarageLabel(address)) {
      return _psdcGaragePoint();
    }
    if (normalized.contains('bolinao')) {
      return const MobilisMapPoint(latitude: 16.3883, longitude: 119.8949);
    }
    if (normalized.contains('santa barbara') &&
        normalized.contains('san carlos')) {
      return const MobilisMapPoint(latitude: 15.89210, longitude: 120.37159);
    }
    if (normalized.contains('san carlos city') &&
        normalized.contains('pangasinan')) {
      return const MobilisMapPoint(latitude: 15.9281, longitude: 120.3488);
    }
    if (normalized.contains('bayambang')) {
      return const MobilisMapPoint(latitude: 15.8127, longitude: 120.4557);
    }
    if (normalized.contains('malasiqui')) {
      return const MobilisMapPoint(latitude: 15.9197, longitude: 120.4144);
    }
    return null;
  }

  double _routeDistanceInKm(MobilisMapPoint from, MobilisMapPoint to) {
    return Geolocator.distanceBetween(
          from.latitude,
          from.longitude,
          to.latitude,
          to.longitude,
        ) /
        1000;
  }

  bool _isReasonableBookingRoute(MobilisMapPoint from, MobilisMapPoint to) {
    // Local rentals should never draw intercontinental lines. Keep a generous
    // PH-wide ceiling so old bad pins cannot override readable PH addresses.
    return _routeDistanceInKm(from, to) <= 1500;
  }

  Future<MobilisMapPoint?> _geocodeBookingAddress(String address) async {
    final cleanAddress = address.trim();
    if (cleanAddress.isEmpty) return null;

    final embeddedCoordinates = RegExp(
      r'(-?\d{1,2}(?:\.\d+)?)\s*[,/]\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(cleanAddress);
    if (embeddedCoordinates != null) {
      final point = _coordinatePoint(
        embeddedCoordinates.group(1),
        embeddedCoordinates.group(2),
      );
      if (_isLikelyPhilippinesPoint(point)) return point;
    }

    final cacheKey = cleanAddress.toLowerCase();
    if (_addressCoordinateCache.containsKey(cacheKey)) {
      return _addressCoordinateCache[cacheKey];
    }
    final knownPoint = _knownBookingAddressPoint(cleanAddress);
    if (knownPoint != null) {
      _addressCoordinateCache[cacheKey] = knownPoint;
      return knownPoint;
    }

    final candidates = <String>[cleanAddress];
    final withoutPlusCode = _stripPlusCodePrefix(cleanAddress);
    if (withoutPlusCode != cleanAddress && withoutPlusCode.isNotEmpty) {
      candidates.add(withoutPlusCode);
    }
    final addressParts = cleanAddress
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (addressParts.length > 4) {
      candidates.add(addressParts.sublist(addressParts.length - 4).join(', '));
    }

    for (final candidate in candidates.toSet()) {
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': candidate,
          'format': 'jsonv2',
          'limit': '1',
          'countrycodes': 'ph',
        });
        final response = await http
            .get(
              uri,
              headers: const {
                'Accept': 'application/json',
                'Accept-Language': 'en',
              },
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;

        final payload = jsonDecode(response.body);
        if (payload is! List || payload.isEmpty || payload.first is! Map) {
          continue;
        }
        final result = Map<String, dynamic>.from(payload.first as Map);
        final point = _coordinatePoint(result['lat'], result['lon']);
        if (_isLikelyPhilippinesPoint(point)) {
          _addressCoordinateCache[cacheKey] = point;
          return point;
        }
      } catch (error) {
        debugPrint('Unable to resolve booking address "$candidate": $error');
      }
    }

    return null;
  }

  Future<List<MobilisMapPoint>> _resolveBookingRoutePoints(
    Map<String, dynamic> booking,
  ) async {
    var routeBooking = Map<String, dynamic>.from(booking);
    final bookingId = booking['id']?.toString().trim() ?? '';
    if (bookingId.isNotEmpty) {
      try {
        final latest = await _supabase
            .from('bookings')
            .select('pickup_location, dropoff_location, metadata')
            .eq('id', bookingId)
            .maybeSingle();
        if (latest != null) {
          final meta = latest['metadata'] is Map
              ? Map<String, dynamic>.from(latest['metadata'] as Map)
              : <String, dynamic>{};
          routeBooking.addAll({
            if (latest['pickup_location'] != null)
              'pickup_location': latest['pickup_location'],
            if (latest['dropoff_location'] != null)
              'dropoff_location': latest['dropoff_location'],
            if (meta['pickup_latitude'] != null)
              'pickup_latitude': meta['pickup_latitude'],
            if (meta['pickup_longitude'] != null)
              'pickup_longitude': meta['pickup_longitude'],
            if (meta['dropoff_latitude'] != null)
              'dropoff_latitude': meta['dropoff_latitude'],
            if (meta['dropoff_longitude'] != null)
              'dropoff_longitude': meta['dropoff_longitude'],
          });
        }
      } catch (error) {
        debugPrint('Unable to refresh booking route coordinates: $error');
      }
    }

    final vehicle = routeBooking['vehicles'] as Map<String, dynamic>? ?? {};
    final rawPickupAddress = routeBooking['pickup_location']?.toString();
    final pickupAddress = _operatorPickupLabel(rawPickupAddress);
    final isPsdcGaragePickup =
        _isDefaultPsdcPickup(rawPickupAddress) ||
        _isDefaultPsdcPickup(pickupAddress);
    var pickupPoint = isPsdcGaragePickup
        ? _psdcGaragePoint()
        : _knownBookingAddressPoint(pickupAddress);
    if (!isPsdcGaragePickup) {
      pickupPoint ??= _philippinesCoordinatePoint(
        routeBooking['pickup_latitude'],
        routeBooking['pickup_longitude'],
      );
      pickupPoint ??= await _geocodeBookingAddress(pickupAddress);
      pickupPoint ??= _philippinesCoordinatePoint(
        vehicle['latitude'],
        vehicle['longitude'],
      );
    }

    final destinationAddress =
        routeBooking['dropoff_location']?.toString().trim() ?? '';
    final destinationLookupAddress = _stripPlusCodePrefix(destinationAddress);
    final isPsdcGarageDestination = PhilippineLocations.isPsdcGarageLabel(
      destinationAddress,
    );
    var destinationPoint = isPsdcGarageDestination
        ? _psdcGaragePoint()
        : _knownBookingAddressPoint(destinationAddress) ??
              _knownBookingAddressPoint(destinationLookupAddress);
    if (!isPsdcGarageDestination) {
      destinationPoint ??= _philippinesCoordinatePoint(
        routeBooking['dropoff_latitude'],
        routeBooking['dropoff_longitude'],
      );
      destinationPoint ??= await _geocodeBookingAddress(
        destinationLookupAddress,
      );
    }

    pickupPoint = isPsdcGaragePickup
        ? _psdcGaragePoint()
        : (_isLikelyPhilippinesPoint(pickupPoint)
              ? pickupPoint
              : _psdcGaragePoint());
    destinationPoint = _isLikelyPhilippinesPoint(destinationPoint)
        ? destinationPoint
        : null;

    if (destinationPoint == null) {
      return pickupPoint == null ? const [] : [pickupPoint];
    }
    if (pickupPoint == null) return [destinationPoint];

    if (!_isReasonableBookingRoute(pickupPoint, destinationPoint)) {
      final knownDestination =
          _knownBookingAddressPoint(destinationAddress) ??
          _knownBookingAddressPoint(destinationLookupAddress);
      if (knownDestination != null &&
          _isReasonableBookingRoute(pickupPoint, knownDestination)) {
        destinationPoint = knownDestination;
      } else {
        return [pickupPoint];
      }
    }

    final samePoint =
        (pickupPoint.latitude - destinationPoint.latitude).abs() < 0.0001 &&
        (pickupPoint.longitude - destinationPoint.longitude).abs() < 0.0001;
    if (samePoint) return [pickupPoint];

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${pickupPoint.longitude},${pickupPoint.latitude};'
        '${destinationPoint.longitude},${destinationPoint.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = payload['routes'] as List<dynamic>? ?? const [];
        if (routes.isNotEmpty) {
          final first = Map<String, dynamic>.from(routes.first as Map);
          final geometry = first['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?;
          if (coordinates != null && coordinates.length >= 2) {
            final roadPoints = coordinates.map((coordinate) {
              final pair = coordinate as List<dynamic>;
              return MobilisMapPoint(
                latitude: (pair[1] as num).toDouble(),
                longitude: (pair[0] as num).toDouble(),
              );
            }).toList();
            return roadPoints;
          }
        }
      }
    } catch (e) {
      debugPrint('Unable to fetch OSRM road route points: $e');
    }

    return [pickupPoint, destinationPoint];
  }

  bool _isPartnerBookingVehicle(Map<String, dynamic> vehicle) {
    final ownerRole =
        vehicle['owner_role']?.toString().trim().toLowerCase() ?? '';
    final source = vehicle['source']?.toString().trim().toLowerCase() ?? '';
    final isPartner =
        vehicle['is_partner_vehicle'] == true ||
        vehicle['partner_vehicle_id'] != null ||
        vehicle['partner_name'] != null;
    final owner = vehicle['owner'] as Map<String, dynamic>?;
    final ownerRoleNested =
        owner?['role']?.toString().trim().toLowerCase() ?? '';
    return ownerRole == 'partner' ||
        source == 'partner' ||
        isPartner ||
        ownerRoleNested == 'partner';
  }

  /// Resolves the most accurate vehicle location from its real-time GPS tracker,
  /// registered vehicle coordinates, pickup location (Plus Code / city / address),
  /// and renter location.
  Future<List<Map<String, double>>> _resolveBookingVehicleAndProximityTargets(
    Map<String, dynamic> booking,
  ) async {
    final targets = <Map<String, double>>[];
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final vehicleId = vehicle['id']?.toString() ?? booking['vehicle_id']?.toString() ?? '';
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};

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

    // 1. Check vehicle_trackers table for active GPS hardware fix
    if (vehicleId.isNotEmpty) {
      try {
        final trackerRows = await _supabase
            .from('vehicle_trackers')
            .select('last_latitude, last_longitude, last_location_at, last_sync_at')
            .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
            .order('updated_at', ascending: false)
            .limit(1);
        final list = List<Map<String, dynamic>>.from(trackerRows);
        if (list.isNotEmpty) {
          addValidPoint(PhilippineGeocoding.parseCoordinate(
            list.first['last_latitude'],
            list.first['last_longitude'],
          ));
        }
      } catch (err) {
        debugPrint('Vehicle tracker lookup note: $err');
      }

      // 2. Check tracking_locations table for latest vehicle position
      if (targets.isEmpty) {
        try {
          final locRows = await _supabase
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
          debugPrint('Tracking locations lookup note: $err');
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

    // 4. Resolve pickup location (e.g. Plus Code: "2C26+P6G, Santa Barbara...")
    final pickup = booking['pickup_location']?.toString() ?? '';
    final pickupPoint = await PhilippineGeocoding.resolveLocation(
      pickup,
      latitudeValue: booking['pickup_latitude'],
      longitudeValue: booking['pickup_longitude'],
    );
    addValidPoint(pickupPoint);

    // 5. Resolve renter / owner location
    final owner = vehicle['owner'] as Map<String, dynamic>? ?? {};
    final ownerLoc = owner['location']?.toString() ?? '';
    if (ownerLoc.isNotEmpty || owner['latitude'] != null) {
      addValidPoint(await PhilippineGeocoding.resolveLocation(
        ownerLoc,
        latitudeValue: owner['latitude'],
        longitudeValue: owner['longitude'],
      ));
    }

    final renterLoc = renter['location']?.toString() ?? renter['address']?.toString() ?? '';
    if (renterLoc.isNotEmpty || renter['latitude'] != null) {
      addValidPoint(await PhilippineGeocoding.resolveLocation(
        renterLoc,
        latitudeValue: renter['latitude'],
        longitudeValue: renter['longitude'],
      ));
    }

    // Fallback: If nothing was found, use PSDC Garage in Urdaneta, Pangasinan
    if (targets.isEmpty) {
      targets.add({
        'latitude': PhilippineGeocoding.defaultLat,
        'longitude': PhilippineGeocoding.defaultLng,
      });
    }

    return targets;
  }

  /// Synchronous fast target resolution for instant map rendering.
  List<Map<String, double>> _driverProximityTargetsSync(
    Map<String, dynamic> vehicle,
    Map<String, dynamic> renter, {
    String? pickupLocation,
  }) {
    final targets = <Map<String, double>>[];

    void addPoint(MobilisMapPoint point) {
      if (!PhilippineGeocoding.isValidPhilippines(point)) return;
      final duplicate = targets.any(
        (target) =>
            (target['latitude']! - point.latitude).abs() < 0.0001 &&
            (target['longitude']! - point.longitude).abs() < 0.0001,
      );
      if (!duplicate) {
        targets.add({'latitude': point.latitude, 'longitude': point.longitude});
      }
    }

    // 1. Vehicle coordinates / location
    final vehLoc = vehicle['location']?.toString() ?? '';
    final vehPoint = PhilippineGeocoding.resolveLocationSync(
      vehLoc,
      latitudeValue: vehicle['latitude'],
      longitudeValue: vehicle['longitude'],
    );
    addPoint(vehPoint);

    // 2. Pickup location (Plus Code or city)
    if (pickupLocation != null && pickupLocation.trim().isNotEmpty) {
      addPoint(PhilippineGeocoding.resolveLocationSync(pickupLocation));
    }

    // 3. Renter location
    final renterLoc = renter['location']?.toString() ?? renter['address']?.toString() ?? '';
    if (renterLoc.isNotEmpty || renter['latitude'] != null) {
      addPoint(PhilippineGeocoding.resolveLocationSync(
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

  void _showApproveDialog(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => _OperatorAssignDriverDialog(
        booking: booking,
        state: this,
      ),
    );
  }

  /// Builds the interactive map summary showing the car location and driver locations.
  /// Includes an Enlarge button in the upper-right corner and real-time tracker auto-refresh badge.
  Widget _buildDriverCoverageSummary({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> vehicle,
    required bool partnerVehicle,
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, double>> mapTargets,
    String? selectedDriverId,
    bool isRefreshing = false,
    DateTime? lastUpdated,
    VoidCallback? onRefreshTap,
    void Function(String driverId, int driverIndex)? onDriverMarkerTap,
    VoidCallback? onEnlargeTap,
  }) {
    final pickup = booking['pickup_location']?.toString().trim();
    final vehicleLocation = vehicle['location']?.toString().trim();
    final referenceLocation = pickup?.isNotEmpty == true
        ? pickup!
        : vehicleLocation?.isNotEmpty == true
        ? vehicleLocation!
        : 'Location coordinates are not yet available';

    final unitName = _vehicleTitle(vehicle);

    final mapMarkers = <MobilisMapMarker>[
      // ── ONLY ONE Car marker: the booked vehicle at its tracker/location ──
      if (mapTargets.isNotEmpty)
        MobilisMapMarker(
          latitude: mapTargets.first['latitude']!,
          longitude: mapTargets.first['longitude']!,
          icon: Icons.directions_car_filled_rounded,
          color: _operatorGold,
          size: 40,
          label: unitName.isNotEmpty ? unitName : 'Vehicle',
          tooltip: unitName.isNotEmpty ? '$unitName (GPS Tracker)' : 'Booked vehicle',
        ),

      // ── Driver markers (person icon + steering-wheel badge) ──
      ...drivers.take(12).toList().asMap().entries.expand((entry) {
        final driverIndex = entry.key;
        final driver = entry.value;
        final user = driver['users'] as Map<String, dynamic>? ?? {};

        // Use resolved coordinates or fallback to geocoder
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
            ? _operatorGold
            : isPsdcDriver
                ? const Color(0xFFD97706)
                : AppColors.success;

        final driverWidget = SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
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
                        ? _operatorNavyDeep
                        : isPsdcDriver
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF0EA5E9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
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

        return [
          MobilisMapMarker(
            latitude: point.latitude,
            longitude: point.longitude,
            icon: Icons.person_pin_circle_rounded,
            color: markerColor,
            size: 36,
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
      height: 230,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF082944),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Positioned.fill(
                  child: mapMarkers.isEmpty
                      ? Container(
                          color: const Color(0xFF06233A),
                          child: const Center(
                            child: Icon(
                              Icons.map_outlined,
                              color: Color(0xFF46677F),
                              size: 50,
                            ),
                          ),
                        )
                      : MobilisLeafletMap(
                          key: ValueKey(
                            'summary_${selectedDriverId ?? ''}_${mapMarkers.map((m) => '${m.latitude.toStringAsFixed(4)},${m.longitude.toStringAsFixed(4)}').join('|')}',
                          ),
                          markers: mapMarkers,
                          initialZoom: mapMarkers.length > 1 ? 11 : 14,
                        ),
                ),
                // ── Live Tracker Status Chip Overlay ──
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF031A2C).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isRefreshing ? _operatorGold : const Color(0xFF10B981)).withValues(alpha: 0.5),
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _OperatorLivePulseDot(
                          color: isRefreshing ? _operatorGold : const Color(0xFF10B981),
                          size: 7,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isRefreshing ? 'REFRESHING GPS...' : 'LIVE GPS TRACKER (8s)',
                          style: TextStyle(
                            color: isRefreshing ? _operatorGold : const Color(0xFF10B981),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Enlarge Map button ──
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
                            color: _operatorNavyDeep.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _operatorGold.withValues(alpha: 0.5)),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_full_rounded, color: _operatorGold, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                'Enlarge Map',
                                style: TextStyle(
                                  color: _operatorGold,
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
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _operatorGold.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.location_searching_rounded,
                          color: _operatorGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          partnerVehicle
                              ? 'Partner Vehicle & Proximity'
                              : 'PSDC Fleet & Verified Drivers',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (onRefreshTap != null)
                        IconButton(
                          icon: Icon(
                            Icons.sync_rounded,
                            color: isRefreshing ? _operatorGold : const Color(0xFF8CA5BB),
                            size: 18,
                          ),
                          tooltip: 'Refresh GPS Tracker & Driver Distances',
                          onPressed: isRefreshing ? null : onRefreshTap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    referenceLocation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF91A9BE),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.directions_car_filled_rounded, color: _operatorGold, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          unitName.isNotEmpty ? unitName : 'Vehicle',
                          style: TextStyle(color: _operatorGold, fontSize: 11, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${drivers.length} eligible drivers  |  Proximity verified',
                    style: TextStyle(
                      color: _operatorGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const _OperatorLivePulseDot(color: Color(0xFF10B981), size: 5),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          lastUpdated != null
                              ? 'Auto-refreshes every 8s (Updated ${lastUpdated.hour.toString().padLeft(2, '0')}:${lastUpdated.minute.toString().padLeft(2, '0')}:${lastUpdated.second.toString().padLeft(2, '0')})'
                              : 'Continuous real-time GPS tracking',
                          style: const TextStyle(
                            color: Color(0xFF82A0B7),
                            fontSize: 9.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Displays the full enlarged interactive driver proximity map dialog.
  void _showEnlargedDriverMapDialog({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> vehicle,
    required bool partnerVehicle,
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, double>> mapTargets,
    String? selectedDriverId,
    required void Function(String? driverId) onSelectDriver,
    required void Function(String driverId) onFinalize,
  }) {
    showDialog(
      context: context,
      builder: (context) => _OperatorEnlargedDriverMapDialog(
        booking: booking,
        vehicle: vehicle,
        partnerVehicle: partnerVehicle,
        initialDrivers: drivers,
        initialMapTargets: mapTargets,
        initialSelectedDriverId: selectedDriverId,
        state: this,
        onSelectDriver: onSelectDriver,
        onFinalize: onFinalize,
      ),
    );
  }

  Future<void> _showRejectDialog(String bookingId) async {
    final reasonController = TextEditingController();
    const reasons = [
      'Vehicle unavailable',
      'Incomplete renter documents',
      'Safety policy violation',
      'Maintenance schedule conflict',
      'Other',
    ];

    Map<String, dynamic>? targetBooking;
    for (final b in _recentBookings) {
      if (b['id']?.toString() == bookingId) {
        targetBooking = b;
        break;
      }
    }
    final targetPayState = targetBooking != null ? resolveBookingPaymentState(targetBooking) : BookingPaymentState.paymentPending;
    final hasPaidFunds = targetPayState == BookingPaymentState.paid ||
        targetPayState == BookingPaymentState.pendingConfirmation ||
        targetPayState == BookingPaymentState.paymentReview;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String selectedReason = reasons.first;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final surface = isDark
                ? const Color(0xFF263247)
                : const Color(0xFFF5F6F8);
            final border = isDark
                ? const Color(0xFF46536A)
                : const Color(0xFFD6DAE1);
            final secondary = isDark
                ? Colors.blueGrey.shade200
                : Colors.blueGrey.shade700;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 540,
                  maxHeight: 760,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 12, 18),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Decline Reservation',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Select a clear reason for the renter.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: border.withOpacity(0.65)),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasPaidFunds) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Payment Alert: The renter has submitted or completed payment for this booking. Declining will initiate a refund requirement for reimbursement.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Text(
                              'Reason for decline',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...reasons.map((reason) {
                              final selected = selectedReason == reason;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: selected
                                      ? _operatorGold.withOpacity(0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: () => setDialogState(
                                      () => selectedReason = reason,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: selected
                                              ? _operatorGold
                                              : border,
                                          width: selected ? 1.5 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 160,
                                            ),
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: selected
                                                    ? _operatorGold
                                                    : secondary,
                                                width: 2,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: selected
                                                ? Container(
                                                    width: 9,
                                                    height: 9,
                                                    decoration: BoxDecoration(
                                                      color: _operatorGold,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              reason,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            const Text(
                              'Additional comments for renter',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: reasonController,
                              minLines: 3,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText:
                                    'Provide details to help the renter understand the decision...',
                                hintStyle: TextStyle(color: secondary),
                                filled: true,
                                fillColor: surface,
                                contentPadding: const EdgeInsets.all(16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: _operatorGold,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'The selected reason and comments will be included in the renter notification.',
                              style: TextStyle(
                                color: secondary,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: border.withOpacity(0.65)),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                ),
                                child: const Text('Go Back'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final comments = reasonController.text.trim();
                                  final reason = comments.isEmpty
                                      ? selectedReason
                                      : '$selectedReason: $comments';
                                  Navigator.pop(dialogContext);
                                  _rejectBooking(bookingId, reason);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.block_outlined,
                                  size: 17,
                                ),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Confirm Decline',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
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
          },
        );
      },
    ).whenComplete(reasonController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 980;
    final isPhone = screenWidth < 768;

    if (isPhone) {
      final navIndex = _selectedIndex > 4 && _selectedIndex != 8
          ? 0
          : (_selectedIndex == 8
                ? 2
                : (_selectedIndex == 4
                      ? 3
                      : (_selectedIndex == 2 ? 4 : _selectedIndex)));
      return Theme(
        data: WebPortalTheme.resolve(context, isDark: isDark),
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF101827) : _operatorPage,
          appBar: AppBar(
            backgroundColor: _operatorNavyDeep,
            elevation: 0,
            title: Row(
              children: [
                Image.asset(
                  'assets/icon/logo-black.png',
                  width: 26,
                  height: 26,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.directions_car_filled_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'PSDC Operator',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Release Inspection',
                onPressed: () => setState(() => _selectedIndex = 8),
              ),
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  widget.onThemeToggle?.call(!isDark);
                },
              ),
            ],
          ),
          drawer: Drawer(
            backgroundColor: _operatorNavyDeep,
            child: _buildSidebar(isDark, false),
          ),
          body: _buildContent(isDark),
          bottomNavigationBar: NavigationBar(
            selectedIndex: navIndex,
            onDestinationSelected: (idx) {
              if (idx == 0) _selectNavigationIndex(0); // Home
              if (idx == 1) _selectNavigationIndex(1); // Bookings
              if (idx == 2)
                _selectNavigationIndex(8); // Inspections (Camera Release)
              if (idx == 3) _selectNavigationIndex(4); // Vehicles
              if (idx == 4) _selectNavigationIndex(2); // Messages
            },
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            indicatorColor: AppColors.primary.withValues(alpha: 0.25),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _unviewedBookingsCount > 0,
                  label: Text(_unviewedBookingsCount.toString()),
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.calendar_month_rounded),
                ),
                label: 'Bookings',
              ),
              const NavigationDestination(
                icon: Icon(Icons.camera_alt_rounded),
                label: 'Inspection',
              ),
              const NavigationDestination(
                icon: Icon(Icons.directions_car_rounded),
                label: 'Vehicles',
              ),
              const NavigationDestination(
                icon: Icon(Icons.chat_bubble_rounded),
                label: 'Messages',
              ),
            ],
          ),
        ),
      );
    }

    return Theme(
      data: WebPortalTheme.resolve(context, isDark: isDark),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: isDark ? const Color(0xFF101827) : _operatorPage,
            body: Row(
              children: [
                _buildSidebar(isDark, isCompact),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(isDark),
                      Expanded(child: _buildContent(isDark)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isPerformingOperation)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF172235),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 30,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                            strokeWidth: 4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _operationLoadingMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Please wait while the action completes...',
                          style: TextStyle(
                            color: Color(0xFF91A9BE),
                            fontSize: 12,
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

  Widget _buildSidebar(bool isDark, bool isCompact) {
    final expanded = _sidebarExpanded && !isCompact;
    final sidebarWidth = expanded ? 252.0 : 76.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: _operatorNavyDeep,
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 92,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 20 : 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _operatorGold,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Image.asset(
                    'assets/icon/logo-black.png',
                    fit: BoxFit.contain,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PSDC Operator',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'VEHICLE MANAGEMENT',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w600,
                            color: _operatorGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                _buildNavItem(0, Icons.grid_view_rounded, 'Home', isDark),
                _buildNavItem(
                  1,
                  Icons.calendar_month_outlined,
                  'Bookings',
                  isDark,
                  badge:
                      _unviewedBookingsCount > 0 ? _unviewedBookingsCount : null,
                ),
                _buildNavItem(
                  2,
                  Icons.chat_bubble_outline_rounded,
                  'Messages',
                  isDark,
                  badge: _unreadMessagesCount > 0 ? _unreadMessagesCount : null,
                ),
                _buildNavItem(
                  3,
                  Icons.notifications_none_rounded,
                  'Notifications',
                  isDark,
                  badge:
                      _notifications.where((n) => n['is_read'] == false).isEmpty
                      ? null
                      : _notifications
                            .where((n) => n['is_read'] == false)
                            .length,
                ),
                _buildNavItem(
                  4,
                  Icons.directions_car_outlined,
                  'Vehicles',
                  isDark,
                ),
                _buildNavItem(
                  9,
                  Icons.price_change_outlined,
                  'Price Requests',
                  isDark,
                  badge: _pendingPriceRequestsCount > 0
                      ? _pendingPriceRequestsCount
                      : null,
                ),
                _buildNavItem(
                  6,
                  Icons.location_on_outlined,
                  'Live Tracking',
                  isDark,
                  badge: _trackingLocations.isEmpty
                      ? null
                      : _trackingLocations.length,
                ),
                _buildNavItem(
                  7,
                  Icons.account_balance_wallet_outlined,
                  'Revenue',
                  isDark,
                ),
                const SizedBox(height: 20),
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Text(
                      'SETTINGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7991A5),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                _buildNavItem(5, Icons.settings_outlined, 'Settings', isDark),
              ],
            ),
          ),
          Tooltip(
            message: expanded ? 'Collapse sidebar' : 'Expand sidebar',
            child: InkWell(
              onTap: isCompact
                  ? null
                  : () => setState(() => _sidebarExpanded = !_sidebarExpanded),
              child: Container(
                height: isCompact ? 12 : 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: expanded
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.center,
                  children: [
                    if (!isCompact)
                      Icon(
                        expanded ? Icons.chevron_left : Icons.chevron_right,
                        color: const Color(0xFF8CA0B2),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    bool isDark, {
    int? badge,
  }) {
    final isSelected = _selectedIndex == index;
    final expanded =
        _sidebarExpanded && MediaQuery.of(context).size.width >= 980;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _selectNavigationIndex(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0),
          decoration: BoxDecoration(
            color: isSelected ? _operatorGold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? _operatorNavyDeep
                        : const Color(0xFF9CB0C2),
                    size: 21,
                  ),
                  if (badge != null && !expanded)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? _operatorNavyDeep
                          : const Color(0xFFC4D0DB),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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

  static const Map<int, String> _operatorTabSlugs = {
    0: 'overview',
    1: 'bookings',
    2: 'messages',
    3: 'notifications',
    4: 'vehicles',
    5: 'settings',
    6: 'tracking',
    7: 'revenue',
    8: 'handover-inspections',
    9: 'price-requests',
  };

  static const Map<String, int> _operatorSlugToTab = {
    'home': 0,
    'overview': 0,
    'dashboard': 0,
    'bookings': 1,
    'booking': 1,
    'messages': 2,
    'chats': 2,
    'chat': 2,
    'notifications': 3,
    'vehicles': 4,
    'fleet': 4,
    'settings': 5,
    'tracking': 6,
    'live-tracking': 6,
    'gps': 6,
    'revenue': 7,
    'earnings': 7,
    'handover-inspections': 8,
    'inspections': 8,
    'inspection': 8,
    'activity': 8,
    'price-requests': 9,
    'pricing': 9,
  };

  void _syncWebUrl(int index) {
    if (!kIsWeb) return;
    try {
      final slug = _operatorTabSlugs[index] ?? 'overview';
      final currentUri = Uri.base;
      final newUrl = '${currentUri.origin}/#/operator-home?tab=$slug';
      html.window.history.replaceState(null, '', newUrl);
    } catch (_) {}
  }

  void _selectNavigationIndex(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      _persistSelectedTab(index);
      _syncWebUrl(index);
    }
    if (index == 1) {
      _unviewedBookingsCount = 0;
      _markAllVisibleBookingsAsViewed();
    }
    if (index == 2) {
      _loadConversations();
      _loadUnreadMessagesCount();
    }
    if (index == 6) {
      _refreshTrackingLocations(forceLoading: _trackingLocations.isEmpty);
    }
    if (index == 9) {
      _loadPriceChangeRequests();
    }
  }

  Future<void> _persistSelectedTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('mobilis_operator_web_tab', index);
    } catch (_) {}
  }

  Future<void> _restoreSavedTab() async {
    int? initialTab;

    if (kIsWeb) {
      try {
        final currentUri = Uri.base;
        String? tabParam = currentUri.queryParameters['tab'];

        if (tabParam == null || tabParam.isEmpty) {
          final fragment = currentUri.fragment;
          if (fragment.contains('?')) {
            final queryPart = fragment.substring(fragment.indexOf('?') + 1);
            final params = Uri.splitQueryString(queryPart);
            tabParam = params['tab'];
          }
        }

        if (tabParam != null && _operatorSlugToTab.containsKey(tabParam.toLowerCase().trim())) {
          initialTab = _operatorSlugToTab[tabParam.toLowerCase().trim()];
        }
      } catch (_) {}
    }

    if (initialTab == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedIndex = prefs.getInt('mobilis_operator_web_tab');
        if (savedIndex != null &&
            savedIndex >= 0 &&
            savedIndex <= 9) {
          initialTab = savedIndex;
        }
      } catch (_) {}
    }

    if (initialTab != null && mounted) {
      setState(() => _selectedIndex = initialTab!);
      _syncWebUrl(initialTab);
    }
  }

  Future<void> _refreshCurrentSection() async {
    if (_selectedIndex == 6) {
      setState(() => _isTrackingLoading = true);
      await _refreshTrackingLocations(forceLoading: true);
      if (mounted) setState(() {});
      return;
    }
    if (_selectedIndex == 2) {
      await _loadConversations();
      return;
    }
    if (_selectedIndex == 9) {
      await _loadPriceChangeRequests();
      return;
    }
    await _loadDashboardData(showLoading: false);
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172235) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _getPageTitle(),
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : _operatorInk,
            ),
          ),
          const SizedBox(width: 34),
          if (MediaQuery.of(context).size.width >= 1250)
            SizedBox(
              width: 350,
              height: 42,
              child: TextField(
                onChanged: (value) {
                  if (_selectedIndex == 1) {
                    setState(() => _bookingSearchQuery = value.trim());
                  } else if (_selectedIndex == 4) {
                    setState(() => _vehicleSearchQuery = value.trim());
                  }
                },
                decoration: InputDecoration(
                  hintText: switch (_selectedIndex) {
                    1 => 'Search booking ID, renter, or vehicle...',
                    4 => 'Search vehicle, plate, or owner...',
                    _ => 'Search operations...',
                  },
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFF0F2F4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: MpinService().currentState().isConfigured
                ? 'Desk Authorization MPIN (Configured)'
                : 'Setup Desk Authorization MPIN (Required for Desk Payments)',
            onPressed: () => _showOperatorMpinSetupDialog(isDark),
            icon: Icon(
              MpinService().currentState().isConfigured
                  ? Icons.pin_outlined
                  : Icons.pin_rounded,
              color: MpinService().currentState().isConfigured
                  ? _operatorGold
                  : Colors.orangeAccent,
            ),
          ),
          IconButton(
            tooltip: 'Scan QR / Verify Handover & Return Pass',
            onPressed: () => _openOperatorHandoverVerifier(),
            icon: Icon(Icons.qr_code_scanner_rounded, color: _operatorGold),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Customize Workspace Color Theme',
            onPressed: () => _showColorThemeDialog(isDark),
            icon: Icon(Icons.palette_rounded, color: _operatorGold),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: isDark ? 'Use light theme' : 'Use dark theme',
            onPressed: () => widget.onThemeToggle?.call(!isDark),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Refresh current view and data',
            onPressed: _refreshCurrentSection,
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 1,
            height: 30,
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          const SizedBox(width: 18),
          PopupMenuButton<String>(
            tooltip: 'Account options (Operator)',
            onSelected: (value) {
              if (value == 'mpin') {
                _showOperatorMpinSetupDialog(isDark);
              } else if (value == 'settings') {
                setState(() => _selectedIndex = 5);
              } else if (value == 'logout') {
                _handleLogout();
              }
            },
            child: Row(
              children: [
                _buildOperatorTopBarAvatar(),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _operatorDisplayName(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : _operatorInk,
                      ),
                    ),
                    Text(
                      'Operations Desk',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_drop_down,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ],
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'mpin',
                child: Row(
                  children: [
                    Icon(
                      Icons.pin_outlined,
                      color: _operatorGold,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text('Desk Authorization MPIN'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Console Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _operatorDisplayName() {
    final name = _operatorProfile['full_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Operator';
  }

  Widget _buildOperatorTopBarAvatar() {
    final avatarUrl = _operatorUserAvatarUrl(_operatorProfile);
    final fallback = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _operatorGold,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        _operatorDisplayName().substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    if (avatarUrl == null || avatarUrl.isEmpty) return fallback;
    return OptimizedNetworkImage(
      imageUrl: avatarUrl,
      width: 38,
      height: 38,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(11),
      placeholder: fallback,
      errorWidget: fallback,
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Bookings';
      case 2:
        return 'Messages';
      case 3:
        return 'Notifications';
      case 4:
        return 'Vehicles';
      case 5:
        return 'Settings';
      case 6:
        return 'Live Tracking';
      case 7:
        return 'Revenue & Analytics';
      case 8:
        return 'Inspections & Handover';
      case 9:
        return 'Price Change Requests';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent(isDark);
      case 1:
        return _buildBookingsContent(isDark);
      case 2:
        return _buildMessagesContent(isDark);
      case 3:
        return _buildNotificationsContent(isDark);
      case 4:
        return _buildVehiclesContent(isDark);
      case 5:
        return _buildSettingsContent(isDark);
      case 6:
        return _buildTrackingContent(isDark);
      case 7:
        return _buildRevenueContent(isDark);
      case 8:
        return _buildInspectionsContent(isDark);
      case 9:
        return _buildPriceRequestsContent(isDark);
      default:
        return _buildDashboardContent(isDark);
    }
  }

  // ── Dashboard extracted to tabs/operator_dashboard_tab.dart ──

  List<Map<String, dynamic>> _operatorManagedBookings() {
    final operatorId = _supabase.auth.currentUser?.id;
    if (operatorId == null || operatorId.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    final source = _operatorRevenueBookings.isNotEmpty
        ? _operatorRevenueBookings
        : _recentBookings;

    final filtered = source.where((booking) {
      final bOpId = booking['operator_id']?.toString().trim();
      if (bOpId != null && bOpId.isNotEmpty) {
        return bOpId == operatorId;
      }
      final v = booking['vehicles'];
      if (v is Map) {
        final vOpId = v['operator_id']?.toString().trim();
        if (vOpId != null && vOpId.isNotEmpty) {
          return vOpId == operatorId;
        }
      }
      return true;
    }).toList();

    return filtered.isNotEmpty ? filtered : source;
  }

  Map<String, dynamic>? _extractBookingFinancials(Map<String, dynamic> booking) {
    final raw = booking['booking_financials'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  double _bookingAmount(Map<String, dynamic> booking) {
    final financials = _extractBookingFinancials(booking);
    final finCost = (financials?['total_cost'] as num?)?.toDouble();
    return (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_paid_amount'] as num?)?.toDouble() ??
        finCost ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0;
  }

  bool _isPartnerVehicleBooking(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final ownerRole = vehicle['owner_role']?.toString().toLowerCase();
    final owner = vehicle['owner'] as Map<String, dynamic>? ?? {};
    final oRole = owner['role']?.toString().toLowerCase();
    return ownerRole == 'partner' ||
        oRole == 'partner' ||
        booking['is_partner_vehicle'] == true ||
        vehicle['is_partner_vehicle'] == true ||
        vehicle['partner_vehicle_id'] != null;
  }

  double _operatorManagedFallbackRevenue(List<Map<String, dynamic>> bookings) {
    return bookings
        .where((booking) => !_isPartnerVehicleBooking(booking))
        .fold<double>(0, (total, booking) => total + _bookingAmount(booking));
  }

  bool _isPaidCompletedBooking(Map<String, dynamic> booking) {
    final financials = _extractBookingFinancials(booking);
    final finStatus =
        financials?['final_payment_status']?.toString().trim().toLowerCase();
    final paymentStatus = (booking['payment_status'] ??
            booking['final_payment_status'] ??
            finStatus)
        ?.toString()
        .trim()
        .toLowerCase();
    final isPaid = paymentStatus == 'paid' ||
        paymentStatus == 'completed' ||
        (booking['total_paid_amount'] as num? ?? 0) > 0;
    return bookingStatusGroup(booking['status']) ==
            BookingStatusGroup.completed &&
        isPaid;
  }

  Set<String> _settlementBookingIds(List<Map<String, dynamic>> settlements) {
    return settlements
        .map((settlement) => settlement['booking_id']?.toString())
        .whereType<String>()
        .toSet();
  }

  List<Map<String, dynamic>> _paidCompletedWithoutSettlement({
    required List<Map<String, dynamic>> bookings,
    required List<Map<String, dynamic>> settlements,
  }) {
    final settledBookingIds = _settlementBookingIds(settlements);
    return bookings.where((booking) {
      final bookingId = booking['id']?.toString();
      return bookingId != null &&
          !settledBookingIds.contains(bookingId) &&
          _isPaidCompletedBooking(booking);
    }).toList();
  }

  DateTime? _operatorRevenueDate(Map<String, dynamic> row) {
    for (final key in const [
      'released_at',
      'final_payment_confirmed_at',
      'completed_at',
      'created_at',
    ]) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isEmpty) continue;
      final parsed = DateTime.tryParse(value)?.toLocal();
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool _matchesOperatorRevenuePeriod(Map<String, dynamic> row) {
    final date = _operatorRevenueDate(row);
    if (date == null) return false;
    final now = DateTime.now();
    switch (_revenuePeriod) {
      case 'day':
        return DateUtils.isSameDay(date, now);
      case 'week':
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        return !date.isBefore(start) && !date.isAfter(now);
      case 'year':
        return date.year == now.year;
      case 'month':
      default:
        return date.year == now.year && date.month == now.month;
    }
  }

  String _operatorRevenuePeriodLabel() {
    return switch (_revenuePeriod) {
      'day' => 'Today',
      'week' => 'Last 7 days',
      'year' => 'This year',
      _ => 'This month',
    };
  }

  // ── Revenue extracted to tabs/operator_revenue_tab.dart ──

  String _resolveTrackingVehicleName(Map<String, dynamic> loc) {
    final booking = loc['bookings'] as Map<String, dynamic>?;
    var vehicle = (booking?['vehicles'] ??
            booking?['partner_vehicles'] ??
            loc['vehicle'])
        as Map<String, dynamic>?;
    final tracker = loc['tracker'] as Map<String, dynamic>?;

    final targetId = loc['vehicle_id']?.toString() ??
        tracker?['vehicle_id']?.toString() ??
        tracker?['partner_vehicle_id']?.toString() ??
        vehicle?['id']?.toString();
    if (targetId != null && targetId.isNotEmpty && !targetId.startsWith('tracker_')) {
      final real = _vehicles.firstWhere(
        (v) => v['id']?.toString() == targetId || v['partner_vehicle_id']?.toString() == targetId,
        orElse: () => const {},
      );
      if (real.isNotEmpty) {
        vehicle = real;
      }
    }

    final isUnassigned = (loc['is_unassigned_tracker'] == true ||
            vehicle?['is_unassigned_tracker'] == true ||
            (vehicle?['brand']?.toString().toLowerCase() == 'gps tracker' &&
                (vehicle?['model']?.toString().isEmpty != false ||
                    vehicle?['model']?.toString() == tracker?['device_identifier']?.toString() ||
                    vehicle?['model']?.toString() == loc['device_identifier']?.toString() ||
                    vehicle?['model']?.toString() == 'Device'))) &&
        (vehicle?['brand']?.toString().toLowerCase() == 'gps tracker' || vehicle?['brand'] == null);

    final deviceId = tracker?['device_identifier']?.toString().trim() ??
        loc['device_identifier']?.toString().trim() ??
        vehicle?['plate_number']?.toString().trim() ??
        '';

    if (isUnassigned) {
      return deviceId.isNotEmpty
          ? 'GPS Tracker $deviceId (Standby)'
          : 'GPS Tracker (Standby)';
    }

    // 1. Try resolving vehicle title via full _vehicleTitle lookup
    var title = _vehicleTitle(vehicle ?? booking);
    if (title.isEmpty || title == 'Partner Vehicle' || title == 'Vehicle') {
      final vName = vehicle?['vehicle_name']?.toString().trim() ?? '';
      if (vName.isNotEmpty &&
          vName.toLowerCase() != 'partner vehicle' &&
          vName.toLowerCase() != 'unknown vehicle' &&
          vName.toLowerCase() != 'vehicle' &&
          !vName.toLowerCase().startsWith('gps tracker')) {
        title = vName;
      } else {
        final b = vehicle?['brand']?.toString().trim() ?? '';
        final m = vehicle?['model']?.toString().trim() ?? '';
        final y = vehicle?['year']?.toString().trim() ?? '';
        final combo = [b, m].where((s) => s.isNotEmpty && s.toLowerCase() != 'gps tracker').join(' ');
        if (combo.isNotEmpty) {
          title = y.isEmpty ? combo : '$combo ($y)';
        }
      }
    }

    // 2. Fallback to tracker device ID if still generic
    if (title.isEmpty || title == 'Partner Vehicle' || title == 'Vehicle') {
      if (deviceId.isNotEmpty) {
        title = 'GPS Tracker $deviceId (Standby)';
      } else {
        title = loc['has_active_booking'] == true ? 'Tracked Trip' : 'Tracked Vehicle';
      }
    }

    // 3. Append plate number if not already part of title
    final plate = vehicle?['plate_number']?.toString().trim() ?? '';
    if (plate.isNotEmpty && !title.contains(plate) && !title.startsWith('GPS Tracker')) {
      return '$title ($plate)';
    }
    return title;
  }

  // ── Tracking extracted to tabs/operator_tracking_tab.dart ──

  // ── Applications extracted to tabs/operator_applications_tab.dart ──

  // ── Bookings extracted to tabs/operator_bookings_tab.dart ──

  // ── Notifications extracted to tabs/operator_notifications_tab.dart ──

  // ── Messages extracted to tabs/operator_messages_tab.dart ──

  // ── Vehicles extracted to tabs/operator_vehicles_tab.dart ──

  // ── Settings extracted to tabs/operator_settings_tab.dart ──

  // ── Inspections extracted to tabs/operator_inspections_tab.dart ──

  // ── Price Requests extracted to tabs/operator_price_requests_tab.dart ──

  void _showOperatorCheckModal({
    required String title,
    required String message,
    Color accentColor = const Color(0xFF10B981),
    IconData icon = Icons.check_circle_rounded,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _OperatorCheckModal(
        title: title,
        message: message,
        accentColor: accentColor,
        icon: icon,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stateful vehicle card extracted to avoid Switch overflow in GridView/Wrap
// ---------------------------------------------------------------------------
class _OperatorVideoAttachmentViewer extends StatefulWidget {
  const _OperatorVideoAttachmentViewer({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  State<_OperatorVideoAttachmentViewer> createState() =>
      _OperatorVideoAttachmentViewerState();
}

class _OperatorVideoAttachmentViewerState
    extends State<_OperatorVideoAttachmentViewer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeVideo;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initializeVideo = _controller.initialize().then((_) {
      _controller.setLooping(false);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: viewport.width * 0.78,
        height: viewport.height * 0.78,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
              color: const Color(0xFF0A2034),
              child: Row(
                children: [
                  const Icon(Icons.videocam_outlined, color: Color(0xFFFFD438)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close video',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<void>(
                future: _initializeVideo,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !_controller.value.isInitialized) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'This video could not be loaded.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  );
                },
              ),
            ),
            FutureBuilder<void>(
              future: _initializeVideo,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    snapshot.hasError ||
                    !_controller.value.isInitialized) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 18, 12),
                  color: const Color(0xFF0A2034),
                  child: Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD438),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                          });
                        },
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFFFFD438),
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatefulWidget {
  final String brand;
  final String model;
  final String vehicleName;
  final String category;
  final String vehicleType;
  final String description;
  final String color;
  final String location;
  final dynamic latitude;
  final dynamic longitude;
  final String year;
  final dynamic pricePerDay;
  final dynamic pricePerHour;
  final bool isPosted;
  final List images;
  final bool isDark;
  final bool isPartnerVehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onTogglePost;
  final String transmission;

  const _VehicleCard({
    required this.brand,
    required this.model,
    required this.vehicleName,
    required this.category,
    required this.vehicleType,
    required this.description,
    required this.color,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.year,
    required this.pricePerDay,
    required this.pricePerHour,
    required this.isPosted,
    required this.images,
    required this.isDark,
    this.isPartnerVehicle = false,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePost,
    required this.transmission,
  });

  @override
  State<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<_VehicleCard> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final isDark = widget.isDark;
    final title = widget.vehicleName.isNotEmpty
        ? widget.vehicleName
        : '${widget.brand} ${widget.model}'.trim();
    final metadata = <String>[
      if (widget.category.isNotEmpty) widget.category,
      if (widget.vehicleType.isNotEmpty) widget.vehicleType,
      if (widget.transmission.isNotEmpty) widget.transmission,
      if (widget.color.isNotEmpty) widget.color,
      if (widget.location.isNotEmpty) widget.location,
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image gallery ──────────────────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 130,
                  child: images.isNotEmpty
                      ? OptimizedNetworkImage(
                          imageUrl:
                              images[_currentImageIndex]['image_url'] ?? '',
                          fit: BoxFit.cover,
                          errorWidget: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: isDark
                                  ? Colors.grey[600]
                                  : Colors.grey.shade400,
                            ),
                          ),
                        )
                      : Container(
                          color: isDark ? Colors.black26 : Colors.grey.shade100,
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 32,
                              color: isDark
                                  ? Colors.grey[600]
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                ),
              ),
              // Counter badge
              if (images.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // Prev arrow
              if (images.length > 1)
                Positioned(
                  left: 4,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _currentImageIndex =
                          (_currentImageIndex - 1 + images.length) %
                          images.length;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              // Next arrow
              if (images.length > 1)
                Positioned(
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _currentImageIndex =
                          (_currentImageIndex + 1) % images.length;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Title ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: Text(
              widget.year,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
          ),
          if (metadata.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Text(
                metadata.join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey : Colors.grey.shade500,
                ),
              ),
            ),

          Divider(
            height: 1,
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),

          // ── Price section ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'PHP ',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        TextSpan(
                          text: widget.pricePerDay.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(
                          text: '/day',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'PHP ${widget.pricePerHour} /hr',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // ── Posted status + toggle ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: widget.isPartnerVehicle
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFD4AF37,
                          ).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'Partner Vehicle',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                      Text(
                        widget.isPosted ? '● Available' : '● Unavailable',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.isPosted
                              ? AppColors.primary
                              : (isDark ? Colors.grey : Colors.grey.shade500),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isPosted ? 'Posted' : 'Not posted',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isPosted
                              ? AppColors.primary
                              : (isDark ? Colors.grey : Colors.grey.shade500),
                        ),
                      ),
                      // Compact toggle
                      GestureDetector(
                        onTap: () => widget.onTogglePost(!widget.isPosted),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: widget.isPosted
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.grey[700]
                                      : Colors.grey.shade300),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: widget.isPosted
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          Divider(
            height: 1,
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),

          // ── Actions: View Details (Partner) OR Edit/Delete (Company) ───
          Padding(
            padding: const EdgeInsets.all(6),
            child: widget.isPartnerVehicle
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD4AF37),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : Colors.blueGrey.shade200,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit, size: 13),
                          label: const Text(
                            'Edit',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete, size: 13),
                          label: const Text(
                            'Delete',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

String _formatCurrency(num value, {int decimals = 2}) {
  final parts = value.toStringAsFixed(decimals).split('.');
  final integerPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
  if (parts.length > 1 && decimals > 0) {
    return '$integerPart.${parts[1]}';
  }
  return integerPart;
}

String _formatNumber(num value) {
  return value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Pulsing Dot for GPS Tracker Status
// ─────────────────────────────────────────────────────────────────────────────
class _OperatorLivePulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const _OperatorLivePulseDot({
    this.color = const Color(0xFF10B981),
    this.size = 8,
  });

  @override
  State<_OperatorLivePulseDot> createState() => _OperatorLivePulseDotState();
}

class _OperatorLivePulseDotState extends State<_OperatorLivePulseDot>
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
// Operator Booking Approval Dialog with Destination Surcharge Adjustment
// ─────────────────────────────────────────────────────────────────────────────
class _OperatorBookingApprovalDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final _OperatorWebScreenState state;

  const _OperatorBookingApprovalDialog({
    required this.booking,
    required this.state,
  });

  @override
  State<_OperatorBookingApprovalDialog> createState() =>
      _OperatorBookingApprovalDialogState();
}

class _OperatorBookingApprovalDialogState
    extends State<_OperatorBookingApprovalDialog> {
  double _dailySurcharge = 0.0;
  bool _isCustom = false;
  final TextEditingController _customController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicle = widget.booking['vehicles'] as Map<String, dynamic>? ??
        (widget.booking['vehicle'] as Map<String, dynamic>? ?? {});

    final destination = (widget.booking['dropoff_location']?.toString().trim().isNotEmpty == true)
        ? widget.booking['dropoff_location'].toString().trim()
        : 'Destination not specified';

    DateTime? startDate = DateTime.tryParse(widget.booking['start_date']?.toString() ?? widget.booking['start_at']?.toString() ?? '');
    DateTime? endDate = DateTime.tryParse(widget.booking['end_date']?.toString() ?? widget.booking['end_at']?.toString() ?? '');
    final days = widget.state._inclusiveRentalDays(startDate, endDate).clamp(1, 365);

    final originalTotalPrice = (widget.booking['total_price'] as num?)?.toDouble() ?? 0.0;
    final originalRentalSubtotal = (widget.booking['rental_subtotal'] as num?)?.toDouble() ?? originalTotalPrice;
    final originalPrincipalTotalPrice = (widget.booking['principal_total_price'] as num?)?.toDouble() ?? originalRentalSubtotal;

    final vehiclePricePerDay = (vehicle['price_per_day'] as num?)?.toDouble() ??
        (vehicle['daily_rate'] as num?)?.toDouble() ??
        (days > 0 ? (originalRentalSubtotal / days) : originalRentalSubtotal);

    final isFullPayment = widget.booking['reservation_payment_type']?.toString().toLowerCase() == 'full_payment' ||
        widget.booking['is_full_payment'] == true ||
        widget.booking['is_full_payment']?.toString().toLowerCase() == 'true';

    final reservationFeeAmount = (widget.booking['reservation_fee_amount'] as num?)?.toDouble() ?? 1000.0;
    final paidAmount = isFullPayment ? originalTotalPrice : reservationFeeAmount;

    final effectiveDailyRate = vehiclePricePerDay + _dailySurcharge;
    final destinationFee = _dailySurcharge * days;
    final newRentalSubtotal = originalRentalSubtotal + destinationFee;
    final newTotalPrice = originalTotalPrice + destinationFee;
    final newPrincipalTotalPrice = originalPrincipalTotalPrice + destinationFee;
    final remainingBalance = (newTotalPrice - paidAmount).clamp(0.0, double.infinity);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review & Approve Booking',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Booking #${widget.booking['id']?.toString().substring(0, (widget.booking['id']?.toString().length ?? 0).clamp(0, 8)) ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trip details card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.place_rounded, size: 18, color: Colors.redAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Trip Destination:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        destination,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.directions_car_rounded, size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.state._vehicleTitle(vehicle),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$days Day${days > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Base Rate: ₱${vehiclePricePerDay.toStringAsFixed(2)}/day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Paid Upfront: ₱${paidAmount.toStringAsFixed(2)} (${isFullPayment ? 'Full' : 'Reservation'})',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isFullPayment ? Colors.green : Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Destination addition section
                      const Text(
                        'Set Daily Destination Surcharge',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Destination pricing formula: (Base Rate + Destination Addition) × $days Days',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('₱0/day (Local / Included)'),
                            selected: !_isCustom && _dailySurcharge == 0.0,
                            selectedColor: Colors.green.withValues(alpha: 0.2),
                            onSelected: (val) {
                              setState(() {
                                _isCustom = false;
                                _dailySurcharge = 0.0;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('+₱500/day (Mountain / Mid)'),
                            selected: !_isCustom && _dailySurcharge == 500.0,
                            selectedColor: Colors.amber.withValues(alpha: 0.2),
                            onSelected: (val) {
                              setState(() {
                                _isCustom = false;
                                _dailySurcharge = 500.0;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('+₱1,000/day (Long Distance)'),
                            selected: !_isCustom && _dailySurcharge == 1000.0,
                            selectedColor: Colors.deepOrange.withValues(alpha: 0.2),
                            onSelected: (val) {
                              setState(() {
                                _isCustom = false;
                                _dailySurcharge = 1000.0;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text(_isCustom ? 'Custom: ₱${_dailySurcharge.toStringAsFixed(0)}/day' : 'Custom Amount'),
                            selected: _isCustom,
                            selectedColor: Colors.blue.withValues(alpha: 0.2),
                            onSelected: (val) {
                              setState(() {
                                _isCustom = true;
                                _dailySurcharge = double.tryParse(_customController.text) ?? 0.0;
                              });
                            },
                          ),
                        ],
                      ),

                      if (_isCustom) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Custom daily surcharge per day (PHP)',
                            prefixText: '₱ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _dailySurcharge = double.tryParse(val) ?? 0.0;
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: 'Destination surcharge notes / reason (optional)',
                          hintText: 'e.g. Baguio steep mountain terrain wear',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Live Calculation Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _dailySurcharge > 0
                              ? Colors.amber.withValues(alpha: 0.08)
                              : Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _dailySurcharge > 0
                                ? Colors.amber.withValues(alpha: 0.4)
                                : Colors.green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calculate_outlined,
                                  size: 16,
                                  color: _dailySurcharge > 0 ? Colors.amber.shade800 : Colors.green,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Live Computation Breakdown ($days Day${days > 1 ? 's' : ''})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _dailySurcharge > 0 ? Colors.amber.shade900 : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Base Daily Rate:', style: TextStyle(fontSize: 12)),
                                Text('₱${vehiclePricePerDay.toStringAsFixed(2)}/day', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Destination Daily Addition:', style: TextStyle(fontSize: 12)),
                                Text(
                                  '+ ₱${_dailySurcharge.toStringAsFixed(2)}/day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _dailySurcharge > 0 ? Colors.amber.shade800 : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Effective Daily Rate:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text(
                                  '₱${effectiveDailyRate.toStringAsFixed(2)}/day',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Destination Fee ($days days):', style: const TextStyle(fontSize: 12)),
                                Text(
                                  '₱${destinationFee.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _dailySurcharge > 0 ? Colors.amber.shade900 : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('New Rental Subtotal:', style: TextStyle(fontSize: 12)),
                                Text('₱${newRentalSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('New Total Booking Price:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text('₱${newTotalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Less Upfront Payment (${isFullPayment ? 'Paid in Full' : 'Reservation Fee'}):', style: const TextStyle(fontSize: 12)),
                                Text('- ₱${paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Handover Balance to Collect:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '₱${remainingBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            if (isFullPayment && destinationFee > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '* Renter paid base rent upfront. The ₱${destinationFee.toStringAsFixed(2)} destination surcharge will be collected upon vehicle turnover.',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, {
                        'daily_destination_surcharge': _dailySurcharge,
                        'destination_fee': destinationFee,
                        'destination_fee_notes': _notesController.text.trim(),
                        'updated_total_price': newTotalPrice,
                        'updated_rental_subtotal': newRentalSubtotal,
                        'updated_principal_total_price': newPrincipalTotalPrice,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text(
                      'Confirm & Approve Booking',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Operator Assign Driver Dialog with Continuous Live GPS Tracker Refresh
// ─────────────────────────────────────────────────────────────────────────────
class _OperatorAssignDriverDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final _OperatorWebScreenState state;

  const _OperatorAssignDriverDialog({
    required this.booking,
    required this.state,
  });

  @override
  State<_OperatorAssignDriverDialog> createState() =>
      _OperatorAssignDriverDialogState();
}

class _OperatorAssignDriverDialogState
    extends State<_OperatorAssignDriverDialog> {
  String? _selectedDriverId;
  final ScrollController _listScrollController = ScrollController();
  Timer? _trackerTimer;
  List<Map<String, double>> _mapTargets = [];
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoadingDrivers = true;
  bool _isRefreshingTracker = false;
  DateTime? _lastTrackerUpdate;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = widget.booking['renter'] as Map<String, dynamic>? ?? {};
    final pickupLocation = widget.booking['pickup_location']?.toString();
    _mapTargets = widget.state._driverProximityTargetsSync(
      vehicle,
      renter,
      pickupLocation: pickupLocation,
    );

    // Initial load
    _fetchDrivers(initial: true);

    // Periodic live tracker refresh every 15 seconds
    _trackerTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshTrackerAndDrivers();
    });
  }

  @override
  void dispose() {
    _trackerTimer?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDrivers({bool initial = false}) async {
    final vehicle = widget.booking['vehicles'] as Map<String, dynamic>? ?? {};
    final partnerVehicle = widget.state._isPartnerBookingVehicle(vehicle);
    final startDate = DateTime.tryParse(
      (widget.booking['start_at'] ?? widget.booking['start_date'])?.toString() ?? '',
    );
    final endDate = DateTime.tryParse(
      (widget.booking['end_at'] ?? widget.booking['end_date'])?.toString() ?? '',
    );
    final bookingId = widget.booking['id']?.toString();
    try {
      final refinedTargets =
          await widget.state._resolveBookingVehicleAndProximityTargets(widget.booking);
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
          prioritizePsdc: !partnerVehicle,
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
      debugPrint('Error fetching drivers / live tracker: $e');
      if (mounted && initial) {
        setState(() => _isLoadingDrivers = false);
      }
    }
  }

  Future<void> _refreshTrackerAndDrivers({bool isManual = false}) async {
    if (!mounted || _isRefreshingTracker) return;
    setState(() => _isRefreshingTracker = true);
    final vehicle = widget.booking['vehicles'] as Map<String, dynamic>? ?? {};
    final partnerVehicle = widget.state._isPartnerBookingVehicle(vehicle);
    final startDate = DateTime.tryParse(
      (widget.booking['start_at'] ?? widget.booking['start_date'])?.toString() ?? '',
    );
    final endDate = DateTime.tryParse(
      (widget.booking['end_at'] ?? widget.booking['end_date'])?.toString() ?? '',
    );
    final bookingId = widget.booking['id']?.toString();

    try {
      final refinedTargets =
          await widget.state._resolveBookingVehicleAndProximityTargets(widget.booking);
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
          prioritizePsdc: !partnerVehicle,
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
      debugPrint('Auto-refresh live tracker note: $e');
      if (mounted) {
        setState(() => _isRefreshingTracker = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final withDriver =
        _bookingNeedsDriver(widget.booking['with_driver']);
    final vehicle = widget.booking['vehicles'] as Map<String, dynamic>? ?? {};
    final partnerVehicle = widget.state._isPartnerBookingVehicle(vehicle);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 940,
          maxHeight: 720,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: widget.state._operatorNavyDeep,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 40,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 18, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.state._operatorGold,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  partnerVehicle
                                      ? 'PSDC PARTNER VEHICLE'
                                      : 'PSDC VEHICLE',
                                  style: TextStyle(
                                    color: widget.state._operatorNavyDeep,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Live Pulse Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF031A2C).withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _OperatorLivePulseDot(
                                      color: Color(0xFF10B981),
                                      size: 6,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _isRefreshingTracker
                                          ? 'REFRESHING GPS...'
                                          : 'LIVE GPS (8s)',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            withDriver
                                ? 'Assign Professional Driver'
                                : 'Finalize Booking',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            withDriver
                                ? 'Available certified drivers continuously ranked by real-time GPS tracker proximity to ${widget.state._vehicleTitle(vehicle)}.'
                                : 'Confirm the reservation and create its booking conversation.',
                            style: const TextStyle(
                              color: Color(0xFF87A0B7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.08)),
              Expanded(
                child: withDriver
                    ? (_isLoadingDrivers
                        ? Center(
                            child: CircularProgressIndicator(
                              color: widget.state._operatorGold,
                            ),
                          )
                        : (_drivers.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.06),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_search_rounded,
                                          color: Color(0xFFF59E0B),
                                          size: 40,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No Available Certified Drivers Found',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'All certified drivers may currently be assigned to ongoing trips or off duty.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xFF87A0B7),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _refreshTrackerAndDrivers(isManual: true),
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('Refresh Drivers & Tracker'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: widget.state._operatorGold,
                                          side: BorderSide(
                                            color: widget.state._operatorGold
                                                .withOpacity(0.5),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: _listScrollController,
                                padding: const EdgeInsets.all(24),
                                itemCount: _drivers.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return widget.state._buildDriverCoverageSummary(
                                      booking: widget.booking,
                                      vehicle: vehicle,
                                      partnerVehicle: partnerVehicle,
                                      drivers: _drivers,
                                      mapTargets: _mapTargets,
                                      selectedDriverId: _selectedDriverId,
                                      isRefreshing: _isRefreshingTracker,
                                      lastUpdated: _lastTrackerUpdate,
                                      onRefreshTap: () =>
                                          _refreshTrackerAndDrivers(isManual: true),
                                      onDriverMarkerTap: (driverId, driverIndex) {
                                        final newId = (_selectedDriverId == driverId
                                            ? null
                                            : driverId);
                                        setState(() {
                                          _selectedDriverId = newId;
                                        });
                                        if (newId != null &&
                                            _listScrollController.hasClients) {
                                          final targetIndex = driverIndex + 1;
                                          _listScrollController.animateTo(
                                            targetIndex * 90.0,
                                            duration: const Duration(
                                              milliseconds: 350,
                                            ),
                                            curve: Curves.easeOut,
                                          );
                                        }
                                      },
                                      onEnlargeTap: () {
                                        widget.state._showEnlargedDriverMapDialog(
                                          booking: widget.booking,
                                          vehicle: vehicle,
                                          partnerVehicle: partnerVehicle,
                                          drivers: _drivers,
                                          mapTargets: _mapTargets,
                                          selectedDriverId: _selectedDriverId,
                                          onSelectDriver: (driverId) {
                                            setState(() {
                                              _selectedDriverId = driverId;
                                            });
                                          },
                                          onFinalize: (driverId) {
                                            Navigator.pop(context);
                                            widget.state._approveBooking(
                                              widget.booking,
                                              driverId: driverId,
                                            );
                                          },
                                        );
                                      },
                                    );
                                  }
                                  final driver = _drivers[index - 1];
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
                                          'Professional Driver');
                                  final isPsdcDriver =
                                      driver['is_psdc_driver'] == true ||
                                          user['is_psdc_driver'] == true ||
                                          driver['driver_tier']
                                                  ?.toString()
                                                  .toLowerCase() ==
                                              'psdc';
                                  final selected =
                                      _selectedDriverId == driverId;
                                  final rating =
                                      (driver['rating'] as num?)?.toDouble() ??
                                          0.0;
                                  final trips =
                                      (driver['total_trips'] as num?)?.toInt() ??
                                          0;
                                  final distance =
                                      (driver['distance_km'] as num?)?.toDouble();
                                  final driverLocationLabel = user['location']
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

                                  return InkWell(
                                    onTap: () => setState(
                                      () => _selectedDriverId =
                                          (_selectedDriverId == driverId
                                              ? null
                                              : driverId),
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? widget.state._operatorGold
                                            : Colors.white.withOpacity(0.06),
                                        borderRadius:
                                            BorderRadius.circular(15),
                                        border: Border.all(
                                          color: selected
                                              ? widget.state._operatorGold
                                              : Colors.white.withOpacity(0.09),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Driver avatar: person icon + steering wheel badge
                                          SizedBox(
                                            width: 52,
                                            height: 52,
                                            child: Stack(
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: selected
                                                        ? widget.state._operatorNavy
                                                        : (isPsdcDriver
                                                            ? const Color(0xFFD97706)
                                                            : const Color(0xFF0284C7)),
                                                    borderRadius:
                                                        BorderRadius.circular(14),
                                                  ),
                                                  child: const Icon(
                                                    Icons.person_rounded,
                                                    color: Colors.white,
                                                    size: 26,
                                                  ),
                                                ),
                                                Positioned(
                                                  right: 0,
                                                  bottom: 0,
                                                  child: Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: BoxDecoration(
                                                      color: selected
                                                          ? widget.state._operatorNavyDeep
                                                          : (isPsdcDriver
                                                              ? const Color(0xFFF59E0B)
                                                              : const Color(0xFF0EA5E9)),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: selected
                                                            ? widget.state._operatorGold
                                                            : widget.state._operatorNavyDeep,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.sports_motorsports_rounded,
                                                      color: Colors.white,
                                                      size: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        color: selected
                                                            ? widget.state._operatorNavyDeep
                                                            : Colors.white,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: selected
                                                            ? (isPsdcDriver
                                                                ? widget.state._operatorNavy
                                                                : widget.state._operatorNavy.withOpacity(0.3))
                                                            : (isPsdcDriver
                                                                ? const Color(0xFFF59E0B)
                                                                : const Color(0xFF0284C7).withOpacity(0.2)),
                                                        borderRadius:
                                                            BorderRadius.circular(12),
                                                        border: isPsdcDriver
                                                            ? null
                                                            : Border.all(
                                                                color: const Color(0xFF0284C7).withOpacity(0.5),
                                                              ),
                                                      ),
                                                      child: Text(
                                                        isPsdcDriver
                                                            ? 'PSDC DRIVER'
                                                            : 'VERIFIED DRIVER',
                                                        style: TextStyle(
                                                          color: selected
                                                              ? (isPsdcDriver
                                                                  ? Colors.white
                                                                  : widget.state._operatorNavyDeep)
                                                              : (isPsdcDriver
                                                                  ? Colors.black
                                                                  : const Color(0xFF38BDF8)),
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  [
                                                    '$trips completed trips',
                                                    '${rating.toStringAsFixed(1)} rating',
                                                    if (distance != null)
                                                      '${distance.toStringAsFixed(1)} km from vehicle${index == 1 ? ' (Nearest)' : ''}',
                                                    if (driverLocationLabel.isNotEmpty)
                                                      driverLocationLabel,
                                                  ].join('  |  '),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: selected
                                                        ? widget.state._operatorNavy
                                                        : const Color(0xFF8CA5BB),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            selected
                                                ? Icons.check_circle
                                                : Icons.circle_outlined,
                                            color: selected
                                                ? widget.state._operatorNavy
                                                : Colors.white38,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )))
                    : Center(
                        child: Icon(
                          Icons.verified_outlined,
                          color: widget.state._operatorGold,
                          size: 72,
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (withDriver && _selectedDriverId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select an available driver',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        widget.state._approveBooking(
                          widget.booking,
                          driverId: _selectedDriverId,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.state._operatorGold,
                        foregroundColor: widget.state._operatorNavyDeep,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        withDriver
                            ? 'Finalize Assignment'
                            : 'Finalize Booking',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Operator Enlarged Driver Proximity Map Dialog with Live Tracker Polling
// ─────────────────────────────────────────────────────────────────────────────
class _OperatorEnlargedDriverMapDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> vehicle;
  final bool partnerVehicle;
  final List<Map<String, dynamic>> initialDrivers;
  final List<Map<String, double>> initialMapTargets;
  final String? initialSelectedDriverId;
  final _OperatorWebScreenState state;
  final void Function(String? driverId) onSelectDriver;
  final void Function(String driverId) onFinalize;

  const _OperatorEnlargedDriverMapDialog({
    required this.booking,
    required this.vehicle,
    required this.partnerVehicle,
    required this.initialDrivers,
    required this.initialMapTargets,
    this.initialSelectedDriverId,
    required this.state,
    required this.onSelectDriver,
    required this.onFinalize,
  });

  @override
  State<_OperatorEnlargedDriverMapDialog> createState() =>
      _OperatorEnlargedDriverMapDialogState();
}

class _OperatorEnlargedDriverMapDialogState
    extends State<_OperatorEnlargedDriverMapDialog> {
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

    // Constant live tracker refresh every 15 seconds while enlarged map is open
    _trackerTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
    final startDate = DateTime.tryParse(
      (widget.booking['start_at'] ?? widget.booking['start_date'])?.toString() ?? '',
    );
    final endDate = DateTime.tryParse(
      (widget.booking['end_at'] ?? widget.booking['end_date'])?.toString() ?? '',
    );
    final bookingId = widget.booking['id']?.toString();
    try {
      final refinedTargets =
          await widget.state._resolveBookingVehicleAndProximityTargets(widget.booking);
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
          prioritizePsdc: !widget.partnerVehicle,
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
      debugPrint('Enlarged map tracker poll note: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitName = widget.state._vehicleTitle(widget.vehicle);
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
          color: widget.state._operatorGold,
          size: 46,
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
            ? widget.state._operatorGold
            : isPsdcDriver
                ? const Color(0xFFD97706)
                : AppColors.success;

        final driverWidget = SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
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
                  size: 22,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.state._operatorNavyDeep
                        : isPsdcDriver
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF0EA5E9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_motorsports_rounded,
                    color: Colors.white,
                    size: 12,
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
          size: 42,
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
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1240,
          maxHeight: 820,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: widget.state._operatorNavyDeep,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 50,
                offset: Offset(0, 20),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              // ── Top Header Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.state._operatorGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.map_rounded,
                          color: widget.state._operatorGold, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Interactive Fleet & Driver Map',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: widget.state._operatorGold,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unitName.isNotEmpty ? unitName : 'Vehicle',
                                  style: TextStyle(
                                    color: widget.state._operatorNavyDeep,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Live Auto-Refresh indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF031A2C).withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _OperatorLivePulseDot(
                                      color: Color(0xFF10B981),
                                      size: 6,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _isRefreshing
                                          ? 'GPS REFRESHING...'
                                          : 'LIVE TRACKER (8s)',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (plate.isNotEmpty) 'Plate: $plate',
                              if (pickup.isNotEmpty) 'Pickup: $pickup',
                              '${_drivers.length} Certified Drivers Available',
                              if (_lastTrackerUpdate != null)
                                'Last Fix: ${_lastTrackerUpdate!.hour.toString().padLeft(2, '0')}:${_lastTrackerUpdate!.minute.toString().padLeft(2, '0')}:${_lastTrackerUpdate!.second.toString().padLeft(2, '0')}',
                            ].join('  •  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF8BA5BA), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh Tracker Now',
                      icon: Icon(
                        Icons.sync_rounded,
                        color: _isRefreshing
                            ? widget.state._operatorGold
                            : Colors.white70,
                      ),
                      onPressed: _isRefreshing ? null : _pollLiveTracker,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.08)),

              // ── Main Body: Map (Flex 7) + Driver Selection Panel (Flex 5) ──
              Expanded(
                child: Row(
                  children: [
                    // ── Map View ──
                    Expanded(
                      flex: 7,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: MobilisLeafletMap(
                              key: ValueKey(
                                'enlarged_${_activeSelectedId ?? ''}_${enlargedMapMarkers.map((m) => '${m.latitude.toStringAsFixed(4)},${m.longitude.toStringAsFixed(4)}').join('|')}',
                              ),
                              markers: enlargedMapMarkers,
                              initialZoom: enlargedMapMarkers.length > 1 ? 12 : 14,
                            ),
                          ),
                          // Legend Overlay
                          Positioned(
                            left: 14,
                            bottom: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF071D31)
                                    .withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.15)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.directions_car_filled_rounded,
                                      color: widget.state._operatorGold, size: 15),
                                  const SizedBox(width: 4),
                                  const Text('Car Tracker',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.person_pin_circle_rounded,
                                      color: AppColors.success, size: 15),
                                  const SizedBox(width: 4),
                                  const Text('Verified Driver',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.person_pin_circle_rounded,
                                      color: Color(0xFFF59E0B), size: 15),
                                  const SizedBox(width: 4),
                                  const Text('PSDC Driver',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Right Side Panel: Driver Selector ──
                    Container(
                      width: 380,
                      decoration: BoxDecoration(
                        color: const Color(0xFF071E33),
                        border: Border(
                          left: BorderSide(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Search box
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: TextField(
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Search driver by name or town...',
                                hintStyle: const TextStyle(
                                    color: Color(0xFF6B8EA8), fontSize: 12),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: Color(0xFF6B8EA8), size: 18),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),

                          // Driver List
                          Expanded(
                            child: filteredDrivers.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No matching drivers',
                                      style:
                                          TextStyle(color: Color(0xFF6B8EA8)),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    itemCount: filteredDrivers.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
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
                                              0.0;
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
                                            BorderRadius.circular(12),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 150),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? widget.state._operatorGold
                                                : Colors.white
                                                    .withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: selected
                                                  ? widget.state._operatorGold
                                                  : Colors.white
                                                      .withOpacity(0.08),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Driver Icon
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? widget.state._operatorNavy
                                                      : (isPsdcDriver
                                                          ? const Color(0xFFD97706)
                                                          : const Color(0xFF0284C7)),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        color: selected
                                                            ? widget.state._operatorNavyDeep
                                                            : Colors.white,
                                                        fontSize: 13,
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
                                                        if (locationStr.isNotEmpty)
                                                          locationStr,
                                                      ].join(' • '),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: selected
                                                            ? widget.state._operatorNavy
                                                            : const Color(0xFF8CA5BB),
                                                        fontSize: 10,
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
                                                    ? widget.state._operatorNavy
                                                    : Colors.white30,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          // Bottom Confirmation Actions in Modal
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              border: Border(
                                top: BorderSide(
                                    color: Colors.white.withOpacity(0.08)),
                              ),
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
                                          vertical: 12),
                                    ),
                                    child: const Text('Close Map'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _activeSelectedId == null
                                        ? null
                                        : () {
                                            Navigator.pop(context); // Close map modal
                                            widget.onFinalize(_activeSelectedId!);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.state._operatorGold,
                                      foregroundColor: widget.state._operatorNavyDeep,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    child: const Text('Assign Driver'),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _OperatorCheckModal extends StatefulWidget {
  final String title;
  final String message;
  final Color accentColor;
  final IconData icon;

  const _OperatorCheckModal({
    required this.title,
    required this.message,
    required this.accentColor,
    required this.icon,
  });

  @override
  State<_OperatorCheckModal> createState() => _OperatorCheckModalState();
}

class _OperatorCheckModalState extends State<_OperatorCheckModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: _fade,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2535) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 42,
                      color: widget.accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor:
                          widget.accentColor.withValues(alpha: 0.12),
                      foregroundColor: widget.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
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
}



class _TrackingRadarLoadingView extends StatefulWidget {
  final bool isDark;
  final Color accentColor;

  const _TrackingRadarLoadingView({
    required this.isDark,
    required this.accentColor,
  });

  @override
  State<_TrackingRadarLoadingView> createState() => _TrackingRadarLoadingViewState();
}

class _TrackingRadarLoadingViewState extends State<_TrackingRadarLoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );
    _opacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = widget.accentColor;
    final bgColor = isDark ? const Color(0xFF031A2C) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF08273E) : Colors.white;

    return Container(
      width: double.infinity,
      height: 420,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(double.infinity, 420),
            painter: _RadarGridPainter(
              lineColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: _pulseAnimation.value * 1.35,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: _opacityAnimation.value * 0.4),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: _opacityAnimation.value * 0.12),
                        border: Border.all(
                          color: accent.withValues(alpha: _opacityAnimation.value * 0.7),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  child!,
                ],
              );
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardBg,
                border: Border.all(color: accent, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  Icon(
                    Icons.radar_rounded,
                    size: 32,
                    color: accent,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fetching live GPS tracker signals...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Querying satellite telemetry & vehicle GPS units. Please wait a moment...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
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

class _RadarGridPainter extends CustomPainter {
  final Color lineColor;

  _RadarGridPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2 - 20);

    for (double r = 40; r <= 180; r += 45) {
      canvas.drawCircle(center, r, paint);
    }

    canvas.drawLine(Offset(center.dx - 200, center.dy), Offset(center.dx + 200, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - 160), Offset(center.dx, center.dy + 160), paint);
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

class _OperatorActionMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDestructive;

  const _OperatorActionMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isDestructive = false,
  });
}

class _OperatorAnimatedActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final Color foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final String tooltip;
  final bool compact;
  final bool isIconOnly;
  final bool isMenuTrigger;

  const _OperatorAnimatedActionButton({
    required this.onPressed,
    required this.icon,
    this.label,
    required this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
    required this.tooltip,
    this.compact = true,
    this.isIconOnly = false,
    this.isMenuTrigger = false,
  });

  @override
  State<_OperatorAnimatedActionButton> createState() =>
      _OperatorAnimatedActionButtonState();
}

class _OperatorAnimatedActionButtonState
    extends State<_OperatorAnimatedActionButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.isMenuTrigger || widget.onPressed != null;
    final baseBg = enabled
        ? (widget.backgroundColor ?? Colors.transparent)
        : Colors.grey.shade800.withValues(alpha: 0.35);
    final baseFg = enabled ? widget.foregroundColor : Colors.grey.shade400;

    final effectiveBg = _isHovered && enabled
        ? (widget.backgroundColor != null
            ? Color.alphaBlend(Colors.white.withValues(alpha: 0.15), baseBg)
            : baseFg.withValues(alpha: 0.12))
        : baseBg;

    final scale = _isPressed ? 0.94 : (_isHovered && enabled ? 1.05 : 1.0);

    final buttonWidget = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        height: widget.compact ? 30 : 34,
        constraints: widget.isIconOnly
            ? BoxConstraints(
                minWidth: widget.compact ? 30 : 34,
                maxWidth: widget.compact ? 30 : 34,
              )
            : null,
        padding: widget.isIconOnly
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(
                horizontal: widget.compact ? 10 : 12,
              ),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? (widget.borderColor ??
                    widget.backgroundColor ??
                    (widget.isIconOnly
                        ? baseFg.withValues(alpha: 0.25)
                        : Colors.transparent))
                : Colors.grey.shade700.withValues(alpha: 0.5),
            width: 1.0,
          ),
          boxShadow: _isHovered && enabled
              ? [
                  BoxShadow(
                    color: (widget.backgroundColor ?? widget.foregroundColor)
                        .withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: widget.isIconOnly || widget.label == null
              ? Icon(
                  widget.icon,
                  size: widget.compact ? 15 : 17,
                  color: baseFg,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: widget.compact ? 13 : 15,
                      color: baseFg,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.label!,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: baseFg,
                        fontSize: widget.compact ? 11 : 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    if (widget.isMenuTrigger) {
      return Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 350),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: buttonWidget,
        ),
      );
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: MouseRegion(
        onEnter: enabled ? (_) => setState(() => _isHovered = true) : null,
        onExit: enabled ? (_) => setState(() => _isHovered = false) : null,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
          onTap: widget.onPressed,
          child: buttonWidget,
        ),
      ),
    );
  }
}

