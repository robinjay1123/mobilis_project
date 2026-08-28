import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/input_validation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../mobile_ui/theme/app_colors.dart';
import '../../../mobile_ui/widgets/optimized_network_image.dart';
import '../../../mobile_ui/widgets/dialog_status_indicator.dart';
import '../../../mobile_ui/widgets/leaflet_map.dart';
import 'package:geolocator/geolocator.dart';
import '../../../mobile_ui/widgets/relative_time_text.dart';
import '../../../services/reservation_payment_service.dart';
import '../../../utils/action_guard.dart';
import '../../../services/terms_service.dart';
import '../../../services/tracking_service.dart';
import '../../../services/verification_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/gps_service.dart';
import '../../../services/admin_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/support_faq_service.dart';
import '../../../mobile_ui/screens/admin/message_review_screen.dart';
import '../../../mobile_ui/screens/profile/settings_screen.dart';
import '../../../mobile_ui/screens/profile/ratings_reviews_screen.dart';
import '../../../mobile_ui/widgets/trip_route_history_dialog.dart';
import '../../../utils/web_html.dart' as html;
import '../../theme/web_portal_theme.dart';
import '../../../utils/booking_status.dart';
import '../../../services/report_service.dart';
import '../../../services/user_restriction_service.dart';
import '../../../services/booking_viewed_service.dart';
import '../../../services/trip_rating_service.dart';

class AdminWebScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const AdminWebScreen({super.key, this.onThemeToggle, this.isDarkMode = true});

  @override
  State<AdminWebScreen> createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  static String get _placeholderLicenseExpiry => DateTime.now()
      .add(const Duration(days: 365))
      .toIso8601String()
      .split('T')[0];
  static String _placeholderLicenseNumber(String userId) =>
      'PENDING-${userId.replaceAll('-', '').substring(0, 12)}';

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

  Color get _adminGold =>
      (_themePalettes[_selectedThemeKey]?['accent'] as Color?) ??
      const Color(0xFFFFD740);
  Color get _adminNavy =>
      (_themePalettes[_selectedThemeKey]?['navy'] as Color?) ??
      const Color(0xFF032A46);
  Color get _adminNavyDeep =>
      (_themePalettes[_selectedThemeKey]?['navyDeep'] as Color?) ??
      const Color(0xFF021F35);
  Color get _adminInk =>
      (_themePalettes[_selectedThemeKey]?['ink'] as Color?) ??
      const Color(0xFF08233D);

  Future<void> _loadColorTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('admin_color_theme');
      if (savedTheme != null && _themePalettes.containsKey(savedTheme)) {
        if (mounted) {
          setState(() => _selectedThemeKey = savedTheme);
        }
      }
    } catch (e) {
      debugPrint('Error loading admin color theme: $e');
    }
  }

  Future<void> _saveColorTheme(String key) async {
    setState(() => _selectedThemeKey = key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_color_theme', key);
    } catch (e) {
      debugPrint('Error saving admin color theme: $e');
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
                      color: _adminGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      color: _adminGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Portal Color Theme',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : _adminInk,
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

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _sidebarExpanded = true;

  // Stats
  int _totalUsers = 0;
  int _totalPartners = 0;
  int _totalOperators = 0;
  int _totalVehicles = 0;

  int _pendingVerifications = 0;
  int _pendingBookingsCount = 0;
  int _unviewedBookingsCount = 0;
  Set<String> _viewedBookingIds = {};
  int _pendingApplicationsCount = 0;
  int _unreadNotificationsCount = 0;
  int _activeBookings = 0;
  int _totalBookings = 0;
  double _totalRevenue = 0;

  // Lists
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allBookings = [];
  List<Map<String, dynamic>> _allVehicles = [];
  List<Map<String, dynamic>> _verificationRecords = [];
  List<Map<String, dynamic>> _pendingPartnerVehicleApplications = [];
  List<Map<String, dynamic>> _trackingLocations = [];
  String? _focusedTrackingBookingId;
  Timer? _trackingRefreshTimer;
  Timer? _notificationsRefreshTimer;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _announcements = [];
  Timer? _announcementRefreshTimer;
  List<Map<String, dynamic>> _supportConversations = [];
  final Map<String, List<Map<String, dynamic>>> _supportMessages = {};
  String? _selectedSupportConversationId;
  bool _isLoadingSupportInbox = false;
  bool _isSendingSupportReply = false;
  RealtimeChannel? _supportMessagesSubscription;
  RealtimeChannel? _supportTypingChannel;
  final Map<String, String> _supportTypingUsers = {};
  final Map<String, Timer> _supportTypingExpiryTimers = {};
  Timer? _supportTypingStopTimer;

  // Action Logs & Support unread badge state
  int _unreadActionLogsCount = 0;
  int _lastSeenActionLogCount = 0;
  int _unreadSupportCount = 0;
  int _lastSeenSupportCount = 0;

  // Bookings state & filters
  String _bookingSearchQuery = '';
  String _bookingStatusFilter = 'all';
  String _bookingViewMode = 'cards'; // 'cards' vs 'table'
  int _recentBookingsPage = 1;
  static const int _recentBookingsPerPage = 5;
  RealtimeChannel? _bookingsSubscription;
  Timer? _bookingsSilentRefreshTimer;

  // Vehicles tab & search state
  String _vehicleTabFilter = 'all'; // 'all', 'psdc', 'partner'
  String _vehicleSearchQuery = '';
  String _vehicleViewMode = 'cards'; // 'cards' vs 'table'

  Future<void> _loadLastSeenCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _lastSeenActionLogCount =
              prefs.getInt('admin_last_seen_action_log_count') ?? 0;
          _lastSeenSupportCount =
              prefs.getInt('admin_last_seen_support_count') ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading last seen counts: $e');
    }
  }

  Future<void> _saveLastSeenActionLogCount(int count) async {
    _lastSeenActionLogCount = count;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('admin_last_seen_action_log_count', count);
    } catch (e) {
      debugPrint('Error saving last seen action log count: $e');
    }
  }

  Future<void> _saveLastSeenSupportCount(int count) async {
    _lastSeenSupportCount = count;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('admin_last_seen_support_count', count);
    } catch (e) {
      debugPrint('Error saving last seen support count: $e');
    }
  }

  // Action Logs state & timers
  List<Map<String, dynamic>> _actionLogs = [];
  bool _isLoadingActionLogs = false;
  String _actionLogSearchQuery = '';
  String _actionLogCategoryFilter = 'all';
  String _actionLogRoleFilter = 'all';
  Timer? _actionLogsRefreshTimer;
  RealtimeChannel? _actionLogsSubscription;

  // User Reports & Safety State
  List<Map<String, dynamic>> _userReports = [];
  bool _isLoadingReports = false;
  String _reportStatusFilter = 'all';
  String _reportSearchQuery = '';
  int _pendingReportsCount = 0;
  Timer? _userReportsRefreshTimer;

  // Verifications & Applications tab filters
  String _verificationRoleFilter =
      'all'; // 'all', 'renter', 'driver', 'partner'
  String _verificationSearchQuery = '';
  String _applicationTypeFilter = 'all'; // 'all', 'vehicle', 'driver'
  String _applicationSearchQuery = '';

  // Pagination & Search
  int _currentUserPage = 1;
  final int _usersPerPage = 10;
  String _userSearchQuery = '';
  String _userRoleFilter = 'all';
  String _userVerificationFilter = 'all'; // 'all', 'verified', 'unverified'
  bool _isLoadingTerms = false;
  bool _isSavingTerms = false;
  bool _isLoadingReservationPayment = false;
  bool _isSavingReservationPayment = false;
  bool _isUploadingReservationQr = false;
  bool _isDeletingReservationQr = false;
  bool _isLoadingSupportFaqs = false;
  bool _isSavingSupportFaqs = false;
  String _supportFaqRole = 'renter';
  Map<String, List<SupportFaq>> _supportFaqsByRole = {};
  bool _settingsLoaded = false;
  final TextEditingController _rentalTermsController = TextEditingController();
  final TextEditingController _privacyPolicyController =
      TextEditingController();
  bool _isLoadingPrivacy = false;
  bool _isSavingPrivacy = false;
  // Rental Terms PDF
  String? _termsPdfUrl;
  bool _isLoadingTermsPdf = false;
  bool _isUploadingTermsPdf = false;
  bool _isDeletingTermsPdf = false;
  final TextEditingController _reservationAmountController =
      TextEditingController();
  final TextEditingController _securityDeposit4to5Controller =
      TextEditingController();
  final TextEditingController _securityDeposit6PlusController =
      TextEditingController();
  final TextEditingController _reservationQrUrlController =
      TextEditingController();
  final TextEditingController _reservationAccountNameController =
      TextEditingController();
  final TextEditingController _reservationInstructionsController =
      TextEditingController();
  final TextEditingController _lateFee4to5Controller = TextEditingController();
  final TextEditingController _lateFee6PlusController = TextEditingController();
  final TextEditingController _lateFeeDayCapHoursController =
      TextEditingController();
  final TextEditingController _announcementTitleController =
      TextEditingController();
  final TextEditingController _announcementMessageController =
      TextEditingController();
  final TextEditingController _supportReplyController = TextEditingController();
  String _announcementTargetRole = 'all';
  String _announcementType = 'maintenance';
  DateTime _announcementScheduledAt = DateTime.now().add(
    const Duration(hours: 1),
  );
  DateTime _announcementFocusedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime _announcementSelectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  bool _isAnnouncementEditorOpen = false;
  Map<String, dynamic>? _editingAnnouncement;
  bool _isSendingAnnouncement = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadColorTheme();
    _restoreSavedTab();
    _loadLastSeenCounts().then((_) {
      _loadDashboardData();
    });
    _setupSupportMessagesListener();
    _setupActionLogsRealtimeListener();
    _setupBookingsRealtimeListener();
    _bookingsSilentRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) {
        if (mounted) {
          _loadAllBookings();
        }
      },
    );
    _trackingRefreshTimer = Timer.periodic(
      const Duration(seconds: 11),
      (_) {
        if (_selectedIndex == 10 || _selectedIndex == 0) {
          _refreshTrackingLocations();
        }
      },
    );
    _actionLogsRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (_selectedIndex == 12) {
          _loadActionLogs(showLoading: false);
        }
      },
    );
    _announcementRefreshTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshAnnouncementsIfVisible(),
    );
    _notificationsRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadNotifications(showLoading: false),
    );
    _userReportsRefreshTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) {
        if (_selectedIndex == 13 || _selectedIndex == 0) {
          _loadUserReports(showLoading: false);
        }
      },
    );
    _loadUserReports(showLoading: false);
  }

  Future<void> _loadSettingsLazily() async {
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    await Future.wait([
      _loadRentalTerms(),
      _loadPrivacyPolicy(),
      _loadReservationPaymentSettings(),
      _loadSupportFaqSettings(),
      _loadTermsPdfUrl(),
    ]);
  }

  @override
  void dispose() {
    _userReportsRefreshTimer?.cancel();
    _bookingsSilentRefreshTimer?.cancel();
    _bookingsSubscription?.unsubscribe();
    _trackingRefreshTimer?.cancel();
    _notificationsRefreshTimer?.cancel();
    _actionLogsRefreshTimer?.cancel();
    _announcementRefreshTimer?.cancel();
    _actionLogsSubscription?.unsubscribe();
    _supportMessagesSubscription?.unsubscribe();
    _supportTypingChannel?.unsubscribe();
    _supportTypingStopTimer?.cancel();
    for (final timer in _supportTypingExpiryTimers.values) {
      timer.cancel();
    }
    _rentalTermsController.dispose();
    _privacyPolicyController.dispose();
    _reservationAmountController.dispose();
    _securityDeposit4to5Controller.dispose();
    _securityDeposit6PlusController.dispose();
    _reservationQrUrlController.dispose();
    _reservationAccountNameController.dispose();
    _reservationInstructionsController.dispose();
    _lateFee4to5Controller.dispose();
    _lateFee6PlusController.dispose();
    _lateFeeDayCapHoursController.dispose();
    _announcementTitleController.dispose();
    _announcementMessageController.dispose();
    _supportReplyController.dispose();
    super.dispose();
  }

  void _setupBookingsRealtimeListener() {
    _bookingsSubscription = _supabase
        .channel('admin-bookings-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (payload) {
            if (mounted) {
              _loadAllBookings();
            }
          },
        )
        .subscribe();
  }

  void _setupSupportMessagesListener() {
    _supportMessagesSubscription = _supabase
        .channel('admin-support-messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final message = Map<String, dynamic>.from(payload.newRecord);
            final conversationId = message['conversation_id']?.toString();
            if (conversationId == null || conversationId.isEmpty) return;
            final index = _supportConversations.indexWhere(
              (conversation) =>
                  conversation['id']?.toString() == conversationId,
            );
            if (index < 0) {
              unawaited(_refreshSupportInboxIfCustomerService(conversationId));
              return;
            }
            if (!mounted) return;
            setState(() {
              _mergeSupportMessage(conversationId, message);
              final conversation = Map<String, dynamic>.from(
                _supportConversations.removeAt(index),
              );
              conversation['latest_message'] = message;
              conversation['updated_at'] = message['created_at'];
              _supportConversations.insert(0, conversation);

              if (_selectedIndex == 7) {
                _unreadSupportCount = 0;
                _lastSeenSupportCount = _supportConversations.length;
              } else {
                _unreadSupportCount++;
              }
            });
          },
        )
        .subscribe();
  }

  Future<void> _refreshSupportInboxIfCustomerService(
    String conversationId,
  ) async {
    try {
      final conversation = await _supabase
          .from('conversations')
          .select('booking_id')
          .eq('id', conversationId)
          .maybeSingle();
      if (conversation != null && conversation['booking_id'] == null) {
        await _loadSupportInbox();
      }
    } catch (error) {
      debugPrint('Unable to classify incoming support message: $error');
    }
  }

  void _mergeSupportMessage(
    String conversationId,
    Map<String, dynamic> message,
  ) {
    final messages = _supportMessages.putIfAbsent(conversationId, () => []);
    final messageId = message['id']?.toString();
    if (messageId != null) {
      final existingIndex = messages.indexWhere(
        (item) => item['id']?.toString() == messageId,
      );
      if (existingIndex >= 0) {
        messages[existingIndex] = message;
      } else {
        messages.add(message);
      }
    } else {
      messages.add(message);
    }
    messages.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      return (aDate ?? DateTime(1970)).compareTo(bDate ?? DateTime(1970));
    });
  }

  void _watchSupportTyping(String conversationId) {
    _supportTypingChannel?.unsubscribe();
    _supportTypingUsers.clear();
    _supportTypingChannel = _supabase
        .channel(ChatService().typingChannelName(conversationId))
        .onBroadcast(
          event: 'typing',
          callback: (rawPayload) {
            final nested = rawPayload['payload'];
            final payload = nested is Map
                ? Map<String, dynamic>.from(nested)
                : rawPayload;
            final userId = payload['user_id']?.toString();
            if (userId == null ||
                userId.isEmpty ||
                userId == _supabase.auth.currentUser?.id) {
              return;
            }
            final isTyping = payload['is_typing'] == true;
            _supportTypingExpiryTimers.remove(userId)?.cancel();
            if (!mounted) return;
            setState(() {
              if (isTyping) {
                _supportTypingUsers[userId] =
                    payload['name']?.toString().trim().isNotEmpty == true
                    ? payload['name'].toString().trim()
                    : 'User';
              } else {
                _supportTypingUsers.remove(userId);
              }
            });
            if (isTyping) {
              _supportTypingExpiryTimers[userId] = Timer(
                const Duration(seconds: 3),
                () {
                  if (!mounted) return;
                  setState(() => _supportTypingUsers.remove(userId));
                },
              );
            }
          },
        )
        .subscribe();
  }

  void _handleSupportTyping(String value) {
    final isTyping = value.trim().isNotEmpty;
    unawaited(_sendSupportTyping(isTyping));
    _supportTypingStopTimer?.cancel();
    if (isTyping) {
      _supportTypingStopTimer = Timer(
        const Duration(milliseconds: 1200),
        () => unawaited(_sendSupportTyping(false)),
      );
    }
  }

  Future<void> _sendSupportTyping(bool isTyping) async {
    final channel = _supportTypingChannel;
    final admin = _supabase.auth.currentUser;
    if (channel == null || admin == null) return;
    try {
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': admin.id,
          'name': 'Admin support',
          'is_typing': isTyping,
        },
      );
    } catch (e) {
      debugPrint('Admin typing status skipped: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fast First Paint: fetch core statistics, users, and bookings
      await Future.wait([
        _loadAllUsers(),
        _loadAllBookings(),
      ]);

      _computeStatsFromMemory();

      // Immediately render the dashboard UI
      if (mounted) {
        setState(() => _isLoading = false);
      }

      // 2. Non-blocking progressive background hydration for secondary datasets
      unawaited(
        Future.wait([
          _loadAllVehicles(),
          _loadPendingVerifications(),
          _loadPendingPartnerVehicleApplications(),
          _loadNotifications(showLoading: false),
          _loadTrackingLocationsFast(),
          _loadAnnouncements(),
        ]).then((_) {
          if (mounted) {
            setState(() {
              _pendingApplicationsCount =
                  _pendingPartnerVehicleApplications.length;
              _computeStatsFromMemory();
            });
          }
        }),
      );
    } catch (e) {
      debugPrint('Error loading admin dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActionLogs({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoadingActionLogs = true);
    }
    try {
      final logs = await AdminService().getSystemActionLogs(limit: 200);
      if (mounted) {
        setState(() {
          if (_selectedIndex == 12) {
            _unreadActionLogsCount = 0;
            _saveLastSeenActionLogCount(logs.length);
          } else if (_lastSeenActionLogCount > 0 &&
              logs.length > _lastSeenActionLogCount) {
            _unreadActionLogsCount = logs.length - _lastSeenActionLogCount;
          } else {
            _unreadActionLogsCount = 0;
          }
          _actionLogs = logs;
          _isLoadingActionLogs = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading action logs: $e');
      if (mounted) setState(() => _isLoadingActionLogs = false);
    }
  }

  void _setupActionLogsRealtimeListener() {
    _actionLogsSubscription = _supabase
        .channel('admin-action-logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'admin_audit_logs',
          callback: (_) => _loadActionLogs(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (_) => _loadActionLogs(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'booking_vehicle_inspections',
          callback: (_) => _loadActionLogs(showLoading: false),
        )
        .subscribe();
  }

  Future<void> _loadAnnouncements() async {
    _announcements = await AdminService().getRecentAnnouncements();
  }

  Future<void> _refreshAnnouncementsIfVisible() async {
    if (!mounted || _selectedIndex != 9) return;
    await _loadAnnouncements();
    if (mounted) setState(() {});
  }

  Future<void> _loadSupportInbox() async {
    _isLoadingSupportInbox = true;

    try {
      final adminRows = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'admin');
      final adminIds = List<Map<String, dynamic>>.from(adminRows)
          .map((row) => row['id']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (adminIds.isEmpty) {
        _supportConversations = [];
        _selectedSupportConversationId = null;
        return;
      }

      final conversationIds = <String>{};
      try {
        final participations = await _supabase
            .from('conversation_participants')
            .select('conversation_id')
            .inFilter('user_id', adminIds);
        conversationIds.addAll(
          List<Map<String, dynamic>>.from(participations)
              .map((row) => row['conversation_id']?.toString().trim() ?? '')
              .where((id) => id.isNotEmpty),
        );
      } on PostgrestException catch (error) {
        debugPrint('Normalized admin support lookup skipped: ${error.message}');
      }

      // Legacy customer-service threads may predate the normalized
      // conversation_participants rows but still reference the admin through
      // conversations.user_id/other_user_id.
      for (final adminId in adminIds) {
        try {
          final directRows = await _supabase
              .from('conversations')
              .select('id')
              .or('user_id.eq.$adminId,other_user_id.eq.$adminId')
              .isFilter('booking_id', null);
          for (final row in List<Map<String, dynamic>>.from(directRows)) {
            final id = row['id']?.toString().trim() ?? '';
            if (id.isNotEmpty) conversationIds.add(id);
          }
        } on PostgrestException catch (error) {
          debugPrint(
            'Legacy admin support conversation lookup skipped: ${error.message}',
          );
        }
      }

      if (conversationIds.isEmpty) {
        _supportConversations = [];
        _selectedSupportConversationId = null;
        return;
      }

      final rows = await _supabase
          .from('conversations')
          .select('id, status, created_at, updated_at, booking_id')
          .inFilter('id', conversationIds.toList())
          .isFilter('booking_id', null)
          .order('updated_at', ascending: false);

      final conversations = <Map<String, dynamic>>[];
      for (final raw in List<Map<String, dynamic>>.from(rows)) {
        final conversationId = raw['id']?.toString() ?? '';
        if (conversationId.isEmpty) continue;

        final participants = await ChatService().getConversationParticipants(
          conversationId,
        );
        final customer = participants.firstWhere(
          (participant) =>
              (participant['role']?.toString().toLowerCase() ?? '') != 'admin',
          orElse: () => <String, dynamic>{},
        );

        final latestMessages = await _supabase
            .from('messages')
            .select('content, created_at, sender_id, is_read')
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .limit(1);

        final latestMessage = latestMessages.isNotEmpty
            ? Map<String, dynamic>.from(latestMessages.first)
            : <String, dynamic>{};

        conversations.add({
          ...raw,
          'participants': participants,
          'customer': customer,
          'latest_message': latestMessage,
        });
      }

      if (_selectedIndex == 7) {
        _unreadSupportCount = 0;
        _saveLastSeenSupportCount(conversations.length);
      } else if (_lastSeenSupportCount > 0 &&
          conversations.length > _lastSeenSupportCount) {
        _unreadSupportCount = conversations.length - _lastSeenSupportCount;
      } else {
        _unreadSupportCount = 0;
      }

      _supportConversations = conversations;
      if (_supportConversations.isEmpty) {
        _selectedSupportConversationId = null;
      } else {
        _selectedSupportConversationId ??= _supportConversations.first['id']
            ?.toString();
        if (!_supportConversations.any(
          (conversation) =>
              conversation['id']?.toString() == _selectedSupportConversationId,
        )) {
          _selectedSupportConversationId = _supportConversations.first['id']
              ?.toString();
        }
        if (_selectedSupportConversationId != null) {
          _watchSupportTyping(_selectedSupportConversationId!);
          await _loadSupportConversationMessages(
            _selectedSupportConversationId!,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading support inbox: $e');
    } finally {
      _isLoadingSupportInbox = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadSupportConversationMessages(String conversationId) async {
    try {
      final messages = await ChatService().getMessages(conversationId);
      _supportMessages[conversationId] = messages;
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId != null && adminId.isNotEmpty) {
        await ChatService().markMessagesAsRead(conversationId, adminId);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading support conversation messages: $e');
    }
  }

  Future<void> _sendSupportReply() async {
    final conversationId = _selectedSupportConversationId;
    final content = _supportReplyController.text.trim();
    final adminId = _supabase.auth.currentUser?.id;
    if (conversationId == null ||
        conversationId.isEmpty ||
        content.isEmpty ||
        adminId == null ||
        adminId.isEmpty ||
        _isSendingSupportReply) {
      return;
    }

    final optimisticId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _isSendingSupportReply = true;
      _mergeSupportMessage(conversationId, {
        'id': optimisticId,
        'conversation_id': conversationId,
        'sender_id': adminId,
        'content': content,
        'message': content,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        '_is_sending': true,
      });
    });
    _supportReplyController.clear();
    unawaited(_sendSupportTyping(false));
    try {
      final sentMessage = await ChatService().sendMessage(
        conversationId: conversationId,
        senderId: adminId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _supportMessages[conversationId]?.removeWhere(
          (message) => message['id'] == optimisticId,
        );
        _mergeSupportMessage(conversationId, sentMessage);
        final index = _supportConversations.indexWhere(
          (conversation) => conversation['id']?.toString() == conversationId,
        );
        if (index >= 0) {
          final conversation = Map<String, dynamic>.from(
            _supportConversations.removeAt(index),
          );
          conversation['latest_message'] = sentMessage;
          conversation['updated_at'] = sentMessage['created_at'];
          _supportConversations.insert(0, conversation);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final messages = _supportMessages[conversationId];
        final index = messages?.indexWhere(
          (message) => message['id'] == optimisticId,
        );
        if (messages != null && index != null && index >= 0) {
          messages[index] = {
            ...messages[index],
            '_is_sending': false,
            '_send_failed': true,
          };
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to send support reply: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingSupportReply = false);
    }
  }

  Future<void> _deleteSupportMessage(Map<String, dynamic> message) async {
    final messageId = message['id']?.toString();
    final adminId = _supabase.auth.currentUser?.id;
    if (messageId == null || messageId.isEmpty || adminId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'The message will be marked as deleted for everyone in this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final deleted = await ChatService().softDeleteMessage(
        messageId: messageId,
        userId: adminId,
      );
      if (!mounted) return;
      setState(() {
        final conversationId = deleted['conversation_id']?.toString();
        if (conversationId != null) {
          _mergeSupportMessage(conversationId, deleted);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete message: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openAnnouncementEditor([Map<String, dynamic>? announcement]) {
    final scheduled = announcement == null
        ? DateTime.now().add(const Duration(hours: 1))
        : _announcementDate(announcement).toLocal();
    _announcementTitleController.text =
        announcement?['title']?.toString() ?? '';
    _announcementMessageController.text =
        announcement?['message']?.toString() ?? '';
    setState(() {
      _editingAnnouncement = announcement;
      _announcementType =
          announcement?['announcement_type']?.toString() ?? 'maintenance';
      _announcementTargetRole =
          announcement?['target_role']?.toString() ?? 'all';
      _announcementScheduledAt = scheduled;
      _isAnnouncementEditorOpen = true;
    });
  }

  void _closeAnnouncementEditor() {
    _announcementTitleController.clear();
    _announcementMessageController.clear();
    setState(() {
      _editingAnnouncement = null;
      _isAnnouncementEditorOpen = false;
      _announcementType = 'maintenance';
      _announcementTargetRole = 'all';
      _announcementScheduledAt = DateTime.now().add(const Duration(hours: 1));
    });
  }

  Future<void> _pickAnnouncementDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _announcementScheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _announcementScheduledAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _announcementScheduledAt.hour,
        _announcementScheduledAt.minute,
      );
    });
  }

  Future<void> _pickAnnouncementTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_announcementScheduledAt),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _announcementScheduledAt = DateTime(
        _announcementScheduledAt.year,
        _announcementScheduledAt.month,
        _announcementScheduledAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _saveAnnouncement() async {
    final title = _announcementTitleController.text.trim();
    final message = _announcementMessageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both announcement title and message'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!_announcementScheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled date and time must be in the future'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSendingAnnouncement = true);
    try {
      final editingId = _editingAnnouncement?['id']?.toString();
      if (editingId == null) {
        await AdminService().createAnnouncement(
          title: title,
          message: message,
          announcementType: _announcementType,
          scheduledAt: _announcementScheduledAt,
          targetRole: _announcementTargetRole,
        );
      } else {
        await AdminService().updateScheduledAnnouncement(
          announcementId: editingId,
          title: title,
          message: message,
          announcementType: _announcementType,
          scheduledAt: _announcementScheduledAt,
          targetRole: _announcementTargetRole,
        );
      }
      await _loadAnnouncements();
      if (!mounted) return;
      final selectedDate = DateTime(
        _announcementScheduledAt.year,
        _announcementScheduledAt.month,
        _announcementScheduledAt.day,
      );
      _announcementTitleController.clear();
      _announcementMessageController.clear();
      setState(() {
        _announcementSelectedDay = selectedDate;
        _announcementFocusedDay = selectedDate;
        _editingAnnouncement = null;
        _isAnnouncementEditorOpen = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editingId == null
                ? 'Announcement scheduled for ${_formatAnnouncementDateTime(_announcementScheduledAt)}'
                : 'Announcement schedule updated',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to send announcement: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingAnnouncement = false);
      }
    }
  }

  Future<void> _cancelAnnouncement(Map<String, dynamic> announcement) async {
    final confirmed = await _confirmAnnouncementAction(
      title: 'Cancel scheduled announcement?',
      message: 'This prevents "${announcement['title']}" from being published.',
      confirmLabel: 'Cancel announcement',
      destructive: true,
    );
    if (!confirmed) return;
    await _runAnnouncementAction(
      () => AdminService().cancelScheduledAnnouncement(
        announcement['id'].toString(),
      ),
      'Announcement cancelled',
    );
  }

  Future<void> _completeAnnouncement(Map<String, dynamic> announcement) async {
    final confirmed = await _confirmAnnouncementAction(
      title: 'Mark announcement completed?',
      message:
          '"${announcement['title']}" will move out of the active announcements list.',
      confirmLabel: 'Mark completed',
    );
    if (!confirmed) return;
    await _runAnnouncementAction(
      () => AdminService().completeAnnouncement(announcement['id'].toString()),
      'Announcement marked completed',
    );
  }

  Future<void> _deleteAnnouncement(Map<String, dynamic> announcement) async {
    final confirmed = await _confirmAnnouncementAction(
      title: 'Delete announcement?',
      message:
          'This permanently deletes "${announcement['title']}". This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    await _runAnnouncementAction(
      () => AdminService().deleteAnnouncement(announcement['id'].toString()),
      'Announcement deleted',
    );
  }

  Future<void> _runAnnouncementAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      await _loadAnnouncements();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update announcement: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<bool> _confirmAnnouncementAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: destructive
                  ? AppColors.error
                  : AppColors.primary,
              foregroundColor: destructive ? Colors.white : Colors.black,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _loadRentalTerms() async {
    setState(() => _isLoadingTerms = true);

    try {
      final terms = await TermsService().getRentalTerms();
      if (!mounted) return;
      _rentalTermsController.text = terms;
    } catch (e) {
      debugPrint('Error loading rental terms: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingTerms = false);
      }
    }
  }

  Future<void> _saveRentalTerms() async {
    setState(() => _isSavingTerms = true);

    try {
      await TermsService().updateRentalTerms(_rentalTermsController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rental terms updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update rental terms: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingTerms = false);
      }
    }
  }

  // ── Rental Terms PDF helpers ────────────────────────────────────────────

  Future<void> _loadTermsPdfUrl() async {
    if (mounted) setState(() => _isLoadingTermsPdf = true);
    try {
      final url = await TermsService().getRentalTermsPdfUrl();
      if (mounted) setState(() => _termsPdfUrl = url);
    } catch (e) {
      debugPrint('Error loading terms PDF URL: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTermsPdf = false);
    }
  }

  Future<void> _uploadTermsPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;

    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      _showAdminCheckModal(
        title: 'File Too Large',
        message: 'Please choose a PDF smaller than 20 MB.',
        accentColor: AppColors.error,
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    setState(() => _isUploadingTermsPdf = true);
    try {
      final url = await TermsService().uploadRentalTermsPdf(bytes);
      if (mounted) {
        setState(() => _termsPdfUrl = url);
        _showAdminCheckModal(
          title: 'PDF Uploaded',
          message: 'The rental terms PDF has been uploaded and is now available for renters to download.',
          accentColor: AppColors.success,
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        _showAdminCheckModal(
          title: 'Upload Failed',
          message: 'Could not upload the PDF: $e',
          accentColor: AppColors.error,
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingTermsPdf = false);
    }
  }

  Future<void> _deleteTermsPdf() async {
    final confirmed = await _confirmAnnouncementAction(
      title: 'Remove Terms PDF',
      message: 'This will permanently remove the rental terms PDF. Renters will no longer be able to download it.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isDeletingTermsPdf = true);
    try {
      await TermsService().deleteRentalTermsPdf();
      if (mounted) {
        setState(() => _termsPdfUrl = null);
        _showAdminCheckModal(
          title: 'PDF Removed',
          message: 'The rental terms PDF has been removed.',
          accentColor: Colors.orange,
          icon: Icons.delete_outline_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        _showAdminCheckModal(
          title: 'Remove Failed',
          message: 'Could not remove the PDF: $e',
          accentColor: AppColors.error,
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingTermsPdf = false);
    }
  }

  void _showAdminCheckModal({
    required String title,
    required String message,
    required Color accentColor,
    required IconData icon,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AdminCheckModal(
        title: title,
        message: message,
        accentColor: accentColor,
        icon: icon,
      ),
    );
  }

  Future<void> _loadPrivacyPolicy() async {
    setState(() => _isLoadingPrivacy = true);

    try {
      final privacy = await TermsService().getPrivacyPolicy();
      if (!mounted) return;
      _privacyPolicyController.text = privacy;
    } catch (e) {
      debugPrint('Error loading privacy policy: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPrivacy = false);
      }
    }
  }

  Future<void> _savePrivacyPolicy() async {
    setState(() => _isSavingPrivacy = true);

    try {
      await TermsService().updatePrivacyPolicy(_privacyPolicyController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy policy updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update privacy policy: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingPrivacy = false);
      }
    }
  }

  Future<void> _loadReservationPaymentSettings() async {
    setState(() => _isLoadingReservationPayment = true);

    try {
      final settings = await ReservationPaymentService().getSettings();
      if (!mounted) return;
      _reservationAmountController.text = settings.amount.toStringAsFixed(0);
      _securityDeposit4to5Controller.text =
          settings.deposit4to5Seater.toStringAsFixed(0);
      _securityDeposit6PlusController.text =
          settings.deposit6PlusSeater.toStringAsFixed(0);
      _reservationQrUrlController.text = settings.qrUrl;
      _reservationAccountNameController.text = settings.accountName;
      _reservationInstructionsController.text = settings.instructions;
      _lateFee4to5Controller.text =
          settings.lateFee4to5Seater.toStringAsFixed(0);
      _lateFee6PlusController.text =
          settings.lateFee6PlusSeater.toStringAsFixed(0);
      _lateFeeDayCapHoursController.text =
          settings.lateFeeDayCapHours.toString();
    } catch (e) {
      debugPrint('Error loading reservation payment settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingReservationPayment = false);
      }
    }
  }

  Future<void> _loadSupportFaqSettings() async {
    if (mounted) setState(() => _isLoadingSupportFaqs = true);
    try {
      final faqs = await SupportFaqService().getAllFaqs();
      if (!mounted) return;
      setState(() => _supportFaqsByRole = faqs);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load support FAQs: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingSupportFaqs = false);
    }
  }

  Future<void> _saveSupportFaqSettings() async {
    final faqs = _supportFaqsByRole[_supportFaqRole] ?? const <SupportFaq>[];
    if (faqs.isEmpty || _isSavingSupportFaqs) return;
    setState(() => _isSavingSupportFaqs = true);
    try {
      await SupportFaqService().updateFaqs(_supportFaqRole, faqs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer support auto-replies updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save support FAQs: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingSupportFaqs = false);
    }
  }

  Future<void> _saveReservationPaymentSettings() async {
    final amount =
        double.tryParse(_reservationAmountController.text.trim()) ?? 0;
    final deposit4to5 =
        double.tryParse(_securityDeposit4to5Controller.text.trim()) ?? 2000.0;
    final deposit6Plus =
        double.tryParse(_securityDeposit6PlusController.text.trim()) ?? 3000.0;
    final lateFee4to5 =
        double.tryParse(_lateFee4to5Controller.text.trim()) ?? 200.0;
    final lateFee6Plus =
        double.tryParse(_lateFee6PlusController.text.trim()) ?? 350.0;
    final lateCapHours =
        int.tryParse(_lateFeeDayCapHoursController.text.trim()) ?? 6;
    setState(() => _isSavingReservationPayment = true);

    try {
      await ReservationPaymentService().updateSettings(
        amount: amount,
        deposit4to5Seater: deposit4to5,
        deposit6PlusSeater: deposit6Plus,
        lateFee4to5Seater: lateFee4to5,
        lateFee6PlusSeater: lateFee6Plus,
        lateFeeDayCapHours: lateCapHours,
        qrUrl: _reservationQrUrlController.text,
        accountName: _reservationAccountNameController.text,
        instructions: _reservationInstructionsController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reservation payment settings updated'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update reservation payment settings: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingReservationPayment = false);
      }
    }
  }

  Future<void> _uploadReservationPaymentQr() async {
    setState(() => _isUploadingReservationQr = true);

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null) return;

      final qrUrl = await ReservationPaymentService().uploadQrCode(
        file: picked,
      );
      if (!mounted) return;
      setState(() => _reservationQrUrlController.text = qrUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reservation QR uploaded. Save settings to publish it.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to upload reservation QR: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingReservationQr = false);
      }
    }
  }

  Future<void> _deleteReservationPaymentQr() async {
    final currentQrUrl = _reservationQrUrlController.text.trim();
    if (currentQrUrl.isEmpty || _isDeletingReservationQr) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        title: const Text(
          'Delete Payment QR?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will remove the current QR from payment settings. Renters cannot submit reservation payment until a new QR is uploaded.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isDeletingReservationQr = true);
    try {
      final service = ReservationPaymentService();
      await service.deleteQrCode(currentQrUrl);
      await service.updateSettings(
        amount: double.tryParse(_reservationAmountController.text.trim()) ?? 0,
        deposit4to5Seater:
            double.tryParse(_securityDeposit4to5Controller.text.trim()) ?? 2000.0,
        deposit6PlusSeater:
            double.tryParse(_securityDeposit6PlusController.text.trim()) ?? 3000.0,
        qrUrl: '',
        accountName: _reservationAccountNameController.text,
        instructions: _reservationInstructionsController.text,
      );
      if (!mounted) return;
      setState(() => _reservationQrUrlController.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reservation QR deleted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete reservation QR: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingReservationQr = false);
      }
    }
  }

  Future<void> _loadStats() async {
    _computeStatsFromMemory();
    if (_allUsers.isEmpty || _allBookings.isEmpty || _allVehicles.isEmpty) {
      try {
        if (_allUsers.isEmpty) {
          final usersResponse =
              await _supabase.from('users').select('id, role');
          final users = List<Map<String, dynamic>>.from(usersResponse);
          _totalUsers = users.length;
          _totalPartners = users
              .where(
                (u) => (u['role'] as String? ?? '').toLowerCase() == 'partner',
              )
              .length;
          _totalOperators = users
              .where(
                (u) => (u['role'] as String? ?? '').toLowerCase() == 'operator',
              )
              .length;
        }

        if (_allVehicles.isEmpty) {
          final vehiclesResponse =
              await _supabase.from('vehicles').select('id');
          final partnerVehiclesResponse =
              await _supabase.from('partner_vehicles').select('id');
          _totalVehicles = (vehiclesResponse as List).length +
              (partnerVehiclesResponse as List).length;
        }

        if (_allBookings.isEmpty) {
          final totalBookingsResponse = await _supabase
              .from('bookings')
              .select('id, total_cost, status');
          final bList = List<Map<String, dynamic>>.from(totalBookingsResponse);
          _totalBookings = bList.length;
          _pendingBookingsCount =
              bList.where((b) => b['status'] == 'pending').length;
          _activeBookings =
              bList.where((b) => b['status'] == 'active').length;
          _totalRevenue = bList.fold(
            0.0,
            (sum, b) => sum + ((b['total_cost'] as num?)?.toDouble() ?? 0),
          );
        }

        final pendingResponse = await _supabase
            .from('user_verifications')
            .select('id')
            .eq('verification_status', 'pending');
        _pendingVerifications = (pendingResponse as List).length;
      } catch (e) {
        debugPrint('Error loading stats fallback: $e');
      }
    }
  }

  void _computeStatsFromMemory() {
    if (_allUsers.isNotEmpty) {
      _totalUsers = _allUsers.length;
      _totalPartners = _allUsers
          .where(
            (u) => (u['role'] as String? ?? '').toLowerCase() == 'partner',
          )
          .length;
      _totalOperators = _allUsers
          .where(
            (u) => (u['role'] as String? ?? '').toLowerCase() == 'operator',
          )
          .length;
    }

    if (_allVehicles.isNotEmpty) {
      _totalVehicles = _allVehicles.length;
    }

    if (_allBookings.isNotEmpty) {
      _totalBookings = _allBookings.length;
      _pendingBookingsCount = _allBookings
          .where(
            (b) =>
                (b['status'] as String? ?? '').toLowerCase() == 'pending',
          )
          .length;
      _activeBookings = _allBookings
          .where(
            (b) =>
                (b['status'] as String? ?? '').toLowerCase() == 'active',
          )
          .length;
      _totalRevenue = _allBookings.fold(
        0.0,
        (sum, b) => sum + ((b['total_cost'] as num?)?.toDouble() ?? 0.0),
      );
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      final futures = await Future.wait([
        // 0: user_verifications
        _supabase
            .from('user_verifications')
            .select('user_id, verification_status')
            .then((res) => List<Map<String, dynamic>>.from(res))
            .catchError((e) => <Map<String, dynamic>>[]),
        // 1: renters
        _supabase
            .from('renters')
            .select('user_id, is_verified')
            .then((res) => List<Map<String, dynamic>>.from(res))
            .catchError((e) => <Map<String, dynamic>>[]),
        // 2: users
        _supabase
            .from('users')
            .select(
              'id, email, full_name, phone, role, created_at, id_verified, '
              'verification_status, updated_at, avatar_url, profile_picture_url, profile_image, image_url',
            )
            .order('created_at', ascending: false)
            .then((res) => List<Map<String, dynamic>>.from(res))
            .catchError((e) async {
              try {
                final fallback = await _supabase
                    .from('users')
                    .select('id, email, full_name, phone, role, created_at')
                    .order('created_at', ascending: false);
                return List<Map<String, dynamic>>.from(fallback);
              } catch (_) {
                return <Map<String, dynamic>>[];
              }
            }),
        // 3: drivers
        _supabase
            .from('drivers')
            .select(
              'id, user_id, driver_tier, verification_status, license_verified, nbi_verified',
            )
            .then((res) => List<Map<String, dynamic>>.from(res))
            .catchError((e) => <Map<String, dynamic>>[]),
        // 4: verification users fallback
        _supabase
            .from('user_verifications')
            .select(
              'user_id, users:user_id(id, email, full_name, phone, role, created_at, avatar_url)',
            )
            .then((res) => List<Map<String, dynamic>>.from(res))
            .catchError((e) => <Map<String, dynamic>>[]),
      ]);

      final verifications = futures[0];
      final renters = futures[1];
      final usersResponse = futures[2];
      final driversResponse = futures[3];
      final verificationUsers = futures[4];

      final approvedUserIds = <String>{};
      for (final v in verifications) {
        final uid = v['user_id']?.toString() ?? '';
        final statusStr =
            v['verification_status']?.toString().trim().toLowerCase() ?? '';
        if (uid.isNotEmpty &&
            (statusStr == 'approved' ||
                statusStr == 'verified' ||
                statusStr == 'certified')) {
          approvedUserIds.add(uid);
        }
      }

      for (final r in renters) {
        final uid = r['user_id']?.toString() ?? '';
        final isVer = r['is_verified'] == true;
        if (uid.isNotEmpty && isVer) {
          approvedUserIds.add(uid);
        }
      }

      for (final d in driversResponse) {
        final uid = d['user_id']?.toString() ?? '';
        final statusStr =
            d['verification_status']?.toString().trim().toLowerCase() ?? '';
        final isVer = d['is_verified'] == true;
        if (uid.isNotEmpty &&
            (isVer || statusStr == 'approved' || statusStr == 'verified')) {
          approvedUserIds.add(uid);
        }
      }

      final driversMap = <String, Map<String, dynamic>>{
        for (final d in driversResponse) d['user_id']?.toString() ?? '': d,
      };

      final userList = <Map<String, dynamic>>[];
      final seenUserIds = <String>{};

      for (final user in usersResponse) {
        final userId = user['id']?.toString() ?? '';
        if (userId.isEmpty) continue;
        seenUserIds.add(userId);

        final driverData = driversMap[userId];
        final isPsdcDriver =
            user['is_psdc_driver'] == true ||
            driverData?['is_psdc_driver'] == true ||
            driverData?['driver_tier'] == 'psdc';

        final userRole =
            user['role']?.toString().trim().toLowerCase() ?? 'renter';
        final isAdminOrOperator =
            userRole == 'admin' ||
            userRole == 'operator' ||
            userRole == 'superadmin' ||
            userRole == 'staff';

        final verStatus =
            user['verification_status']?.toString().trim().toLowerCase() ?? '';
        final idVerified =
            user['id_verified'] == true || user['is_verified'] == true;
        final isVerified =
            isAdminOrOperator ||
            idVerified ||
            verStatus == 'approved' ||
            verStatus == 'verified' ||
            verStatus == 'certified' ||
            approvedUserIds.contains(userId);

        userList.add({
          ...user,
          'id_verified': isVerified,
          'is_psdc_driver': isPsdcDriver,
          'driver_id': driverData?['id'],
        });
      }

      for (final v in verificationUsers) {
        final uMap = v['users'] as Map<String, dynamic>?;
        final uid =
            uMap?['id']?.toString() ?? v['user_id']?.toString() ?? '';
        if (uid.isNotEmpty && !seenUserIds.contains(uid)) {
          seenUserIds.add(uid);
          userList.add({
            'id': uid,
            'email': uMap?['email'] ?? 'User Email',
            'full_name': uMap?['full_name'] ?? 'User ($uid)',
            'phone': uMap?['phone'] ?? '',
            'role': uMap?['role'] ?? 'renter',
            'created_at':
                uMap?['created_at'] ?? DateTime.now().toIso8601String(),
            'id_verified': true,
            'avatar_url': uMap?['avatar_url'],
          });
        }
      }

      _allUsers = userList;
      _totalUsers = _allUsers.length;
      _totalPartners = _allUsers
          .where(
            (user) =>
                (user['role'] as String? ?? '').toLowerCase() == 'partner',
          )
          .length;
      _totalOperators = _allUsers
          .where(
            (user) =>
                (user['role'] as String? ?? '').toLowerCase() == 'operator',
          )
          .length;

      debugPrint(
        'Admin: successfully loaded ${_allUsers.length} users (parallel fast load)',
      );
    } catch (e) {
      debugPrint('Admin _loadAllUsers error: $e');
      _allUsers = [];
    }
  }

  Future<void> _loadAllBookings() async {
    try {
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
              is_partner_vehicle,
              partner_id
            ),
            renter:renter_id (id, full_name, email, phone),
            drivers:drivers!bookings_driver_id_fkey (
              id,
              user_id,
              users:users!drivers_user_id_fkey (id, full_name, email, phone)
            )
          ''')
          .order('created_at', ascending: false);

      final rawBookings = List<Map<String, dynamic>>.from(response);

      // Load partner profiles mapping
      final partnerMap = <String, Map<String, dynamic>>{};
      try {
        final partnersResp = await _supabase
            .from('partners')
            .select(
              'id, business_name, business_phone, business_address, user_id, users:user_id(id, full_name, email, phone)',
            );
        for (final p in List<Map<String, dynamic>>.from(partnersResp)) {
          final pid = p['id']?.toString() ?? '';
          final uid = p['user_id']?.toString() ?? '';
          if (pid.isNotEmpty) partnerMap[pid] = p;
          if (uid.isNotEmpty) partnerMap[uid] = p;
        }
      } catch (pe) {
        debugPrint('Could not load partners mapping: $pe');
      }

      // Also check booking_settlements map for exact disbursement records
      final settlementsMap = <String, Map<String, dynamic>>{};
      try {
        final settlementsResp = await _supabase
            .from('booking_settlements')
            .select(
              'booking_id, status, released_at, partner_amount, partner_commission, driver_amount, gross_amount',
            );
        for (final s in List<Map<String, dynamic>>.from(settlementsResp)) {
          final bId = s['booking_id']?.toString() ?? '';
          if (bId.isNotEmpty) settlementsMap[bId] = s;
        }
      } catch (_) {}

      // Merge partner and settlement details into each booking
      for (final booking in rawBookings) {
        final bId = booking['id']?.toString() ?? '';
        final vehicle = booking['vehicles'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(booking['vehicles'])
            : <String, dynamic>{};
        final ownerId = vehicle['owner_id']?.toString() ?? '';
        final partnerId =
            booking['partner_id']?.toString() ??
            vehicle['partner_id']?.toString() ??
            ownerId;
        final isPartner =
            vehicle['is_partner_vehicle'] == true ||
            vehicle['owner_role']?.toString().toLowerCase() == 'partner' ||
            partnerMap.containsKey(partnerId) ||
            partnerMap.containsKey(ownerId);

        booking['is_partner_vehicle'] = isPartner;

        if (isPartner) {
          final partnerData = partnerMap[partnerId] ?? partnerMap[ownerId];
          if (partnerData != null) {
            final partnerUser = partnerData['users'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(partnerData['users'])
                : <String, dynamic>{};
            booking['partner_business_name'] =
                partnerData['business_name'] ??
                partnerUser['full_name'] ??
                'Partner';
            booking['partner_email'] = partnerUser['email'];
            booking['partner_phone'] =
                partnerData['business_phone'] ?? partnerUser['phone'];
            booking['partner_name'] =
                partnerData['business_name'] ??
                partnerUser['full_name'] ??
                'Mobilis Partner';
          } else {
            booking['partner_name'] = 'Mobilis Partner';
          }
        }

        if (settlementsMap.containsKey(bId)) {
          booking['settlement'] = settlementsMap[bId];
        }
      }

      _allBookings = rawBookings;
      await _recalculateUnviewedBookings();
    } catch (e) {
      debugPrint('Error loading bookings in admin web: $e, falling back to BookingService.getAllBookings()');
      try {
        final fallback = await BookingService().getAllBookings();
        _allBookings = fallback;
        await _recalculateUnviewedBookings();
      } catch (fallbackErr) {
        debugPrint('Admin fallback load bookings failed: $fallbackErr');
        _allBookings = [];
      }
    }
  }

  Future<void> _recalculateUnviewedBookings() async {
    final adminId = _supabase.auth.currentUser?.id;
    final viewedIds = await BookingViewedService().getViewedBookingIds(
      role: 'admin',
      userId: adminId,
    );
    _viewedBookingIds = viewedIds;

    if (_selectedIndex == 3) {
      final allIds = _allBookings
          .map((b) => b['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (allIds.isNotEmpty) {
        await BookingViewedService().markAllBookingsAsViewed(
          allIds,
          role: 'admin',
          userId: adminId,
        );
        _viewedBookingIds.addAll(allIds);
      }
      if (mounted && _unviewedBookingsCount != 0) {
        setState(() => _unviewedBookingsCount = 0);
      }
      return;
    }

    final unviewed = _allBookings
        .where((b) => !_viewedBookingIds.contains(b['id']?.toString()))
        .length;
    if (mounted && _unviewedBookingsCount != unviewed) {
      setState(() => _unviewedBookingsCount = unviewed);
    }
  }

  Future<void> _markAllBookingsAsViewed() async {
    final adminId = _supabase.auth.currentUser?.id;
    final allIds = _allBookings
        .map((b) => b['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (allIds.isNotEmpty) {
      await BookingViewedService().markAllBookingsAsViewed(
        allIds,
        role: 'admin',
        userId: adminId,
      );
      _viewedBookingIds.addAll(allIds);
    }
    if (mounted && _unviewedBookingsCount != 0) {
      setState(() => _unviewedBookingsCount = 0);
    }
  }

  Future<void> _loadAllVehicles() async {
    try {

      // 1. Load Partner vehicles from partner_vehicles table
      List<Map<String, dynamic>> partnerVehicles = [];
      try {
        final partnerResponse = await _supabase
            .from('partner_vehicles')
            .select('''
              *,
              partners:partner_id (
                id,
                business_name,
                user_id,
                users:user_id (full_name, email, role)
              )
            ''')
            .order('created_at', ascending: false);
        partnerVehicles = List<Map<String, dynamic>>.from(
          partnerResponse,
        ).map(_normalizeAdminPartnerVehicle).toList();
      } catch (e) {
        debugPrint('Partner vehicle relation load failed: $e');
        final fallback = await _supabase
            .from('partner_vehicles')
            .select('*')
            .order('created_at', ascending: false);
        partnerVehicles = List<Map<String, dynamic>>.from(
          fallback,
        ).map(_normalizeAdminPartnerVehicle).toList();
      }

      final partnerPlates = partnerVehicles
          .map(
            (pv) => pv['plate_number']?.toString().trim().toLowerCase() ?? '',
          )
          .where((p) => p.isNotEmpty)
          .toSet();
      final partnerIds = partnerVehicles
          .map((pv) => pv['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // 2. Load PSDC vehicles from vehicles table
      final companyResponse = await _supabase
          .from('vehicles')
          .select('''
            *,
            owner:owner_id (full_name, email, role)
          ''')
          .order('created_at', ascending: false);

      final companyVehicles = <Map<String, dynamic>>[];
      for (final vehicle in List<Map<String, dynamic>>.from(companyResponse)) {
        final merged = Map<String, dynamic>.from(vehicle);
        final plate =
            merged['plate_number']?.toString().trim().toLowerCase() ?? '';
        final id = merged['id']?.toString() ?? '';
        final ownerRole =
            (merged['owner'] as Map<String, dynamic>?)?['role']
                ?.toString()
                .toLowerCase() ??
            '';
        final isPartnerFlag =
            merged['is_partner_vehicle'] == true ||
            merged['partner_id'] != null ||
            ownerRole == 'partner' ||
            partnerPlates.contains(plate) ||
            partnerIds.contains(id);

        if (!isPartnerFlag) {
          merged['source'] = 'company';
          merged['source_label'] = 'PSDC';
          merged['is_partner_vehicle'] = false;
          companyVehicles.add(merged);
        }
      }

      await _attachAdminVehicleImages(companyVehicles, partnerVehicles);
      _allVehicles = [...companyVehicles, ...partnerVehicles];
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      _allVehicles = [];
    }
  }

  Map<String, dynamic> _normalizeAdminPartnerVehicle(
    Map<String, dynamic> vehicle,
  ) {
    final partner = vehicle['partners'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(vehicle['partners'])
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

    final merged = Map<String, dynamic>.from(vehicle);
    merged['source'] = 'partner';
    merged['source_label'] = 'Partner';
    merged['partner_name'] = partnerName;
    merged['owner'] = {
      'full_name': partnerName,
      'email': partnerUser['email'],
      'role': 'partner',
    };
    merged['is_partner_vehicle'] = true;
    merged['partner_vehicle_id'] = vehicle['id'];
    merged['is_posted'] = vehicle['is_available'] ?? false;
    return merged;
  }

  Future<void> _attachAdminVehicleImages(
    List<Map<String, dynamic>> companyVehicles,
    List<Map<String, dynamic>> partnerVehicles,
  ) async {
    final vehicleIds = companyVehicles
        .map((vehicle) => vehicle['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final partnerVehicleIds = partnerVehicles
        .map((vehicle) => vehicle['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (vehicleIds.isNotEmpty) {
      final images = await _supabase
          .from('vehicle_images')
          .select('vehicle_id,image_url,display_order')
          .inFilter('vehicle_id', vehicleIds);
      final grouped = _groupImagesByKey(
        List<Map<String, dynamic>>.from(images),
        'vehicle_id',
      );
      for (final vehicle in companyVehicles) {
        vehicle['vehicle_images'] = grouped[vehicle['id']?.toString()] ?? [];
      }
    }

    if (partnerVehicleIds.isNotEmpty) {
      final candidatePartnerIds = <String>{...partnerVehicleIds};
      for (final pv in partnerVehicles) {
        final vid = pv['vehicle_id']?.toString();
        if (vid != null && vid.isNotEmpty) candidatePartnerIds.add(vid);
      }
      final idsList = candidatePartnerIds.toList();

      final groupedPv = <String, List<Map<String, dynamic>>>{};
      try {
        final imagesByPvId = await _supabase
            .from('vehicle_images')
            .select('partner_vehicle_id,vehicle_id,image_url,display_order')
            .inFilter('partner_vehicle_id', idsList);
        for (final img in List<Map<String, dynamic>>.from(imagesByPvId)) {
          final pvid = img['partner_vehicle_id']?.toString();
          if (pvid != null && pvid.isNotEmpty) {
            groupedPv.putIfAbsent(pvid, () => []).add(img);
          }
        }
      } catch (_) {}

      try {
        final imagesByVid = await _supabase
            .from('vehicle_images')
            .select('partner_vehicle_id,vehicle_id,image_url,display_order')
            .inFilter('vehicle_id', idsList);
        for (final img in List<Map<String, dynamic>>.from(imagesByVid)) {
          final vid = img['vehicle_id']?.toString();
          if (vid != null && vid.isNotEmpty) {
            groupedPv.putIfAbsent(vid, () => []).add(img);
          }
        }
      } catch (_) {}

      for (final vehicle in partnerVehicles) {
        final pvid = vehicle['id']?.toString() ?? '';
        final vid = vehicle['vehicle_id']?.toString() ?? '';
        final imgs = <Map<String, dynamic>>[];
        final seen = <String>{};

        for (final img in groupedPv[pvid] ?? []) {
          final url = (img['image_url'] ?? img['url'])?.toString().trim() ?? '';
          if (url.isNotEmpty && !seen.contains(url)) {
            seen.add(url);
            imgs.add(img);
          }
        }
        if (vid.isNotEmpty) {
          for (final img in groupedPv[vid] ?? []) {
            final url = (img['image_url'] ?? img['url'])?.toString().trim() ?? '';
            if (url.isNotEmpty && !seen.contains(url)) {
              seen.add(url);
              imgs.add(img);
            }
          }
        }

        final directPhoto = (vehicle['vehicle_photo_url'] ??
                vehicle['photo_url'] ??
                vehicle['image_url'])
            ?.toString()
            .trim() ??
            '';
        if (directPhoto.isNotEmpty && !seen.contains(directPhoto)) {
          imgs.add({'image_url': directPhoto, 'display_order': imgs.length});
        }

        imgs.sort((a, b) {
          final aOrder = (a['display_order'] as num?)?.toInt() ?? 9999;
          final bOrder = (b['display_order'] as num?)?.toInt() ?? 9999;
          return aOrder.compareTo(bOrder);
        });

        vehicle['vehicle_images'] = imgs;
        if (vehicle['image_url'] == null || vehicle['image_url'].toString().isEmpty) {
          vehicle['image_url'] = imgs.isNotEmpty ? imgs.first['image_url'] : directPhoto;
        }
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupImagesByKey(
    List<Map<String, dynamic>> images,
    String key,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final image in images) {
      final id = image[key]?.toString();
      if (id == null || id.isEmpty) continue;
      grouped.putIfAbsent(id, () => []).add(image);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final aOrder = (a['display_order'] as num?)?.toInt() ?? 9999;
        final bOrder = (b['display_order'] as num?)?.toInt() ?? 9999;
        return aOrder.compareTo(bOrder);
      });
    }
    return grouped;
  }

  Future<void> _loadTrackingLocationsFast() async {
    try {
      final locations = await TrackingService().getActiveTrackingLocations();
      if (mounted) setState(() => _trackingLocations = locations);
      TrackingService().pollGpsTrackersForActiveBookings().then((_) async {
        if (!mounted) return;
        final updated = await TrackingService().getActiveTrackingLocations();
        if (mounted) setState(() => _trackingLocations = updated);
      }).catchError((e) {
        debugPrint('Admin background GPS poll error: $e');
      });
    } catch (e) {
      debugPrint('Error loading tracking locations: $e');
    }
  }

  Future<void> _loadTrackingLocations() async {
    // First poll IMEI GPS trackers to upsert their latest positions
    await TrackingService().pollGpsTrackersForActiveBookings();
    final locations = await TrackingService().getActiveTrackingLocations();
    if (!mounted) return;
    setState(() => _trackingLocations = locations);
  }

  Future<void> _refreshTrackingLocations() async {
    // Poll GPS trackers first, then refresh the locations list
    await TrackingService().pollGpsTrackersForActiveBookings();
    final locations = await TrackingService().getActiveTrackingLocations();
    if (!mounted) return;
    setState(() => _trackingLocations = locations);
  }

  bool _canTrackBooking(Map<String, dynamic> booking) {
    final status = (booking['status'] as String? ?? '').toLowerCase();
    return status == 'active' || status == 'approved' || status == 'confirmed';
  }

  Future<void> _openTrackingForBooking(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty || !_canTrackBooking(booking)) return;

    setState(() {
      _selectedIndex = 10;
      _focusedTrackingBookingId = bookingId;
      _isLoading = true;
    });

    try {
      await _loadTrackingLocations();
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _visibleTrackingLocations() {
    final source = (_focusedTrackingBookingId == null ||
            _focusedTrackingBookingId!.isEmpty)
        ? _trackingLocations
        : _trackingLocations.where((location) {
            final booking = location['bookings'] as Map<String, dynamic>?;
            final bookingId = booking?['id']?.toString();
            final rowId = location['id']?.toString();
            return bookingId == _focusedTrackingBookingId ||
                rowId == _focusedTrackingBookingId ||
                location['vehicle_id']?.toString() ==
                    _focusedTrackingBookingId;
          }).toList();

    final seenKeys = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final loc in (source.isNotEmpty ? source : _trackingLocations)) {
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

  Future<void> _loadPendingVerifications() async {
    try {
      final response = await _supabase
          .from('user_verifications')
          .select('''
            *,
            users:user_id (id, full_name, email, role, verification_status)
          ''')
          .order('created_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(response);
      for (final record in records) {
        final user = record['users'] as Map<String, dynamic>?;
        final userId = record['user_id']?.toString() ?? user?['id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          record['driver_signature_url'] = await _loadDriverSignatureUrl(
            userId,
          );
          record['driver_nbi_url'] = await _loadDriverNbiUrl(userId);
        }
      }

      _verificationRecords = records;
    } catch (e) {
      debugPrint('Error loading applications: $e');
      _verificationRecords = [];
    }
  }

  Future<String?> _loadDriverSignatureUrl(String userId) async {
    return _loadDriverDocumentUrl(userId, const [
      'digital_signature',
      'signature',
    ]);
  }

  Future<String?> _loadDriverNbiUrl(String userId) async {
    return _loadDriverDocumentUrl(userId, const ['nbi_clearance', 'nbi']);
  }

  Future<String?> _loadDriverDocumentUrl(
    String userId,
    List<String> documentTypeKeywords,
  ) async {
    try {
      final driver = await _supabase
          .from('drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      final driverId = driver?['id']?.toString();
      final driverIds = <String>[
        if (driverId != null && driverId.isNotEmpty) driverId,
        userId,
      ];

      for (final id in driverIds) {
        final documents = await _supabase
            .from('driver_documents')
            .select('document_type, file_url, created_at')
            .eq('driver_id', id)
            .order('created_at', ascending: false);

        for (final document in List<Map<String, dynamic>>.from(documents)) {
          final type = document['document_type']
              ?.toString()
              .trim()
              .toLowerCase();
          final url = document['file_url']?.toString().trim();
          if (url == null || url.isEmpty) continue;
          if (type != null &&
              documentTypeKeywords.any((keyword) => type.contains(keyword))) {
            return url;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Unable to load driver document: $e');
      return null;
    }
  }

  Future<void> _loadPendingPartnerVehicleApplications() async {
    try {
      final response = await _supabase
          .from('partner_vehicle_applications')
          .select('''
            *,
            partner:partner_id (id, full_name, email)
          ''')
          .eq('application_status', 'pending')
          .order('created_at', ascending: false);

      final applications = List<Map<String, dynamic>>.from(response);
      for (final application in applications) {
        application['photo_urls'] = await _loadVehicleApplicationPhotoUrls(
          application,
        );
      }
      _pendingPartnerVehicleApplications = applications;
    } catch (e) {
      debugPrint('Error loading partner vehicle applications: $e');
      _pendingPartnerVehicleApplications = [];
    }
  }

  Future<List<String>> _loadVehicleApplicationPhotoUrls(
    Map<String, dynamic> application,
  ) async {
    final urls = <String>{};
    final primaryUrl = application['vehicle_photo_url']?.toString().trim();
    if (primaryUrl != null && primaryUrl.isNotEmpty) {
      urls.add(primaryUrl);
    }

    final applicationId = application['id']?.toString().trim() ?? '';
    final partnerVehicleId =
        application['partner_vehicle_id']?.toString().trim() ?? '';
    final createdVehicleId =
        application['created_vehicle_id']?.toString().trim() ?? '';

    try {
      if (applicationId.isNotEmpty) {
        final docs = await _supabase
            .from('partner_vehicle_documents')
            .select('file_url')
            .eq('partner_vehicle_application_id', applicationId)
            .eq('document_type', 'vehicle_photo');
        for (final row in List<Map<String, dynamic>>.from(docs)) {
          final url = row['file_url']?.toString().trim();
          if (url != null && url.isNotEmpty) {
            urls.add(url);
          }
        }
      }

      if (partnerVehicleId.isNotEmpty) {
        final images = await _supabase
            .from('vehicle_images')
            .select('image_url')
            .eq('partner_vehicle_id', partnerVehicleId);
        for (final row in List<Map<String, dynamic>>.from(images)) {
          final url = row['image_url']?.toString().trim();
          if (url != null && url.isNotEmpty) {
            urls.add(url);
          }
        }
      }

      if (createdVehicleId.isNotEmpty) {
        final images = await _supabase
            .from('vehicle_images')
            .select('image_url')
            .eq('vehicle_id', createdVehicleId);
        for (final row in List<Map<String, dynamic>>.from(images)) {
          final url = row['image_url']?.toString().trim();
          if (url != null && url.isNotEmpty) {
            urls.add(url);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading application photo urls: $e');
    }

    return urls.toList();
  }

  Future<void> _loadNotifications({bool showLoading = false}) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      _notifications = [];
      _unreadNotificationsCount = 0;
      return;
    }

    try {
      final list = await NotificationService().getNotifications(currentUserId);
      final unreadCount = list.where((n) => n['is_read'] == false).length;
      if (mounted) {
        setState(() {
          _notifications = list;
          _unreadNotificationsCount = unreadCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin notifications: $e');
    }
  }

  Future<void> _showNotificationsDialog(bool isDark) async {
    return ActionGuard.runGuarded('admin_notifications_dialog', () async {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final unreadCount =
                _notifications.where((n) => n['is_read'] == false).length;
            final bg = isDark ? _adminNavyDeep : Colors.white;
            final border = isDark ? Colors.white12 : Colors.black12;

            return Dialog(
              backgroundColor: bg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: border),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 650,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: border)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_rounded,
                            color: _adminGold,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : _adminInk,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount unread',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (unreadCount > 0)
                            TextButton.icon(
                              onPressed: () async {
                                await NotificationService().markAllAsRead(
                                  currentUserId,
                                );
                                if (mounted) {
                                  setState(() {
                                    for (var n in _notifications) {
                                      n['is_read'] = true;
                                    }
                                    _unreadNotificationsCount = 0;
                                  });
                                  setModalState(() {});
                                }
                              },
                              icon: const Icon(
                                Icons.done_all_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Mark all read',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _adminGold,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 48,
                                    color: Colors.grey.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No notifications yet',
                                    style: TextStyle(
                                      color: Colors.grey.withOpacity(0.8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                              itemCount: _notifications.length,
                              separatorBuilder: (_, __) =>
                                  Divider(color: border, height: 1),
                              itemBuilder: (context, index) {
                                final n = _notifications[index];
                                final isRead = n['is_read'] == true;
                                final title = n['title']?.toString() ?? 'Notification';
                                final message = n['message']?.toString() ?? '';
                                final notifId = n['id']?.toString() ?? '';

                                return InkWell(
                                  onTap: () async {
                                    if (!isRead && notifId.isNotEmpty) {
                                      await NotificationService().markAsRead(notifId);
                                      if (mounted) {
                                        setState(() {
                                          n['is_read'] = true;
                                          _unreadNotificationsCount =
                                              _notifications.where((x) => x['is_read'] == false).length;
                                        });
                                        setModalState(() {});
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isRead
                                          ? Colors.transparent
                                          : _adminGold.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 3),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isRead
                                                ? Colors.transparent
                                                : _adminGold,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.w800,
                                                  color: isDark
                                                      ? Colors.white
                                                      : _adminInk,
                                                ),
                                              ),
                                              if (message.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  message,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black87,
                                                    height: 1.3,
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    });
  }

  Future<bool> _showVehicleApprovalConfirmation(
    Map<String, dynamic> application,
  ) async {
    final vehicleTitle =
        '${application['brand'] ?? 'Vehicle'} ${application['model'] ?? ''}'
            .trim();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _adminNavyDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Confirm Approval',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to approve this vehicle application?\n\n${vehicleTitle.isEmpty ? 'This application' : vehicleTitle} will be added to the partner fleet.',
          style: const TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<String?> _showVehicleRejectionDialog() async {
    const rejectionReasons = [
      'Incomplete/Missing Papers',
      'Uploaded Document is Unclear',
      'Government ID is Expired',
      'Invalid or Unreadable Document',
      'Vehicle Information is Incomplete',
      'Submitted Information Does Not Match',
      'Vehicle Photos are Unclear',
      'Vehicle Does Not Meet Listing Requirements',
      'Daily Rental Price is Too High',
      'Hourly Rental Price is Too High',
      'Pricing Information is Inconsistent',
      'Other',
    ];
    final otherController = TextEditingController();
    String? selectedReason;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isOther = selectedReason == 'Other';
          final enteredReason = otherController.text.trim();
          final reasonToConfirm = isOther
              ? enteredReason
              : selectedReason?.trim() ?? '';
          final canConfirm = reasonToConfirm.isNotEmpty;

          return AlertDialog(
            backgroundColor: _adminNavyDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Reject Vehicle Application',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a rejection reason before confirming this action.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    isExpanded: true,
                    dropdownColor: _adminNavy,
                    decoration: InputDecoration(
                      labelText: 'Rejection Reason',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    hint: const Text(
                      'Choose a reason',
                      style: TextStyle(color: Colors.white54),
                    ),
                    items: rejectionReasons
                        .map(
                          (reason) => DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedReason = value;
                        if (value != 'Other') otherController.clear();
                      });
                    },
                  ),
                  if (isOther) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: otherController,
                      onChanged: (_) => setDialogState(() {}),
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Specify the reason',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Enter the specific admin feedback',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                  ],
                  if (canConfirm) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Are you sure you want to reject this vehicle application?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Selected reason: $reasonToConfirm',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: canConfirm
                    ? () => Navigator.of(dialogContext).pop(reasonToConfirm)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Rejection'),
              ),
            ],
          );
        },
      ),
    );
    otherController.dispose();
    return result;
  }

  Future<void> _approvePartnerVehicleApplication(
    Map<String, dynamic> application,
  ) async {
    final shouldApprove = await _showVehicleApprovalConfirmation(application);
    if (!shouldApprove) return;

    try {
      final appId = application['id']?.toString();
      final partnerId = application['partner_id']?.toString();
      if (appId == null ||
          appId.isEmpty ||
          partnerId == null ||
          partnerId.isEmpty) {
        throw Exception('Invalid application payload');
      }

      var partnerProfile = await _supabase
          .from('partners')
          .select('id, business_name, users:user_id(full_name)')
          .eq('user_id', partnerId)
          .maybeSingle();

      partnerProfile ??= await _supabase
          .from('partners')
          .insert({
            'user_id': partnerId,
            'verification_status': 'approved',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id, business_name')
          .single();

      final partnerProfileId = partnerProfile['id']?.toString();
      if (partnerProfileId == null || partnerProfileId.isEmpty) {
        throw Exception('Partner profile could not be resolved');
      }

      final partnerName = (partnerProfile['business_name']?.toString().trim().isNotEmpty == true)
          ? partnerProfile['business_name'].toString().trim()
          : ((partnerProfile['users'] is Map && partnerProfile['users']['full_name']?.toString().trim().isNotEmpty == true)
              ? partnerProfile['users']['full_name'].toString().trim()
              : 'Mobilis Partner');

      final vehicleName =
          '${application['brand'] ?? ''} ${application['model'] ?? ''}'.trim();

      final existingPvId = application['partner_vehicle_id']?.toString();
      String partnerVehicleId;

      if (existingPvId != null && existingPvId.isNotEmpty) {
        await _supabase.from('partner_vehicles').update({
          'partner_id': partnerProfileId,
          'vehicle_name': vehicleName.isNotEmpty ? vehicleName : 'Partner Vehicle',
          'brand': application['brand'],
          'model': application['model'],
          'year': application['year'],
          'plate_number': application['plate_number'],
          'seats': application['seats'] ?? 5,
          'price_per_day': application['price_per_day'] ?? 0,
          'price_per_hour': application['price_per_hour'] ?? 0,
          'fuel_type': application['fuel_type'] ?? 'Gasoline',
          'transmission': application['transmission'] ?? 'Manual',
          'category': application['category'] ?? application['vehicle_type'] ?? 'Partner Vehicle',
          'vehicle_type': application['vehicle_type'] ?? application['category'] ?? 'Partner Vehicle',
          'owner_is_driver': application['owner_is_driver'] ?? false,
          'owner_name': partnerName,
          'owner_role': 'partner',
          'is_available': true,
          'is_posted': true,
          'status': 'available',
          'application_status': 'approved',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existingPvId);
        partnerVehicleId = existingPvId;
      } else {
        final createdPartnerVehicle = await _supabase
            .from('partner_vehicles')
            .insert({
              'partner_id': partnerProfileId,
              'vehicle_name': vehicleName.isNotEmpty ? vehicleName : 'Partner Vehicle',
              'brand': application['brand'],
              'model': application['model'],
              'year': application['year'],
              'plate_number': application['plate_number'],
              'seats': application['seats'] ?? 5,
              'price_per_day': application['price_per_day'] ?? 0,
              'price_per_hour': application['price_per_hour'] ?? 0,
              'fuel_type': application['fuel_type'] ?? 'Gasoline',
              'transmission': application['transmission'] ?? 'Manual',
              'category': application['category'] ?? application['vehicle_type'] ?? 'Partner Vehicle',
              'vehicle_type': application['vehicle_type'] ?? application['category'] ?? 'Partner Vehicle',
              'owner_is_driver': application['owner_is_driver'] ?? false,
              'owner_name': partnerName,
              'owner_role': 'partner',
              'is_available': true,
              'is_posted': true,
              'status': 'available',
              'application_status': 'approved',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();
        partnerVehicleId = createdPartnerVehicle['id'].toString();
      }

      final vehiclePhotoUrl = (application['vehicle_photo_url'] ??
              application['photo_url'] ??
              application['image_url'])
          ?.toString();
      final photoUrls = <String>[
        if (vehiclePhotoUrl != null && vehiclePhotoUrl.isNotEmpty)
          vehiclePhotoUrl,
      ];

      try {
        final photoDocs = await _supabase
            .from('partner_vehicle_documents')
            .select('file_url')
            .eq('partner_vehicle_application_id', appId)
            .eq('document_type', 'vehicle_photo');
        for (final doc in List<Map<String, dynamic>>.from(photoDocs)) {
          final url = doc['file_url']?.toString().trim();
          if (url != null && url.isNotEmpty && !photoUrls.contains(url)) {
            photoUrls.add(url);
          }
        }
      } catch (e) {
        debugPrint('Note: partner_vehicle_documents lookup: $e');
      }

      if (photoUrls.isNotEmpty) {
        try {
          await _supabase
              .from('vehicle_images')
              .delete()
              .eq('partner_vehicle_id', partnerVehicleId);
        } catch (_) {}

        await _supabase
            .from('vehicle_images')
            .insert(
              List.generate(photoUrls.length, (index) {
                return {
                  'partner_vehicle_id': partnerVehicleId,
                  'image_url': photoUrls[index],
                  'display_order': index,
                };
              }),
            );

        try {
          await _supabase
              .from('partner_vehicles')
              .update({'image_url': photoUrls.first})
              .eq('id', partnerVehicleId);
        } catch (_) {}
      }

      final orUrl = application['or_document_url']?.toString();
      final crUrl = application['cr_document_url']?.toString();

      if (orUrl != null && orUrl.isNotEmpty) {
        await _supabase.from('partner_vehicle_documents').insert({
          'partner_vehicle_application_id': appId,
          'document_type': 'or',
          'file_url': orUrl,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      if (crUrl != null && crUrl.isNotEmpty) {
        await _supabase.from('partner_vehicle_documents').insert({
          'partner_vehicle_application_id': appId,
          'document_type': 'cr',
          'file_url': crUrl,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await _supabase
          .from('partner_vehicle_applications')
          .update({
            'application_status': 'approved',
            'status': 'approved',
            'verified_at': DateTime.now().toIso8601String(),
            'reviewed_at': DateTime.now().toIso8601String(),
            'verified_by': _supabase.auth.currentUser?.id,
            'partner_vehicle_id': partnerVehicleId,
            'created_vehicle_id': null,
            'rejection_reason': null,
          })
          .eq('id', appId);

      try {
        await GpsService().transferTrackerToVehicle(
          applicationId: appId,
          targetVehicleId: partnerVehicleId.toString(),
          isPartnerVehicle: true,
        );
      } catch (trackerErr) {
        debugPrint('GPS tracker transfer note: $trackerErr');
      }

      final vehicleTitle =
          '${application['brand'] ?? ''} ${application['model'] ?? ''}'.trim();
      await NotificationService().notifyPartnerApplicationApproved(
        partnerId: partnerId,
        applicationId: appId,
        vehicleTitle: vehicleTitle.isEmpty ? null : vehicleTitle,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle application approved')),
      );
      _loadDashboardData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approval failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectPartnerVehicleApplication(
    Map<String, dynamic> application,
  ) async {
    final rejectionReason = await _showVehicleRejectionDialog();
    if (rejectionReason == null || rejectionReason.trim().isEmpty) return;

    try {
      final appId = application['id']?.toString();
      if (appId == null || appId.isEmpty) {
        throw Exception('Invalid application payload');
      }

      final currentApplication = await _supabase
          .from('partner_vehicle_applications')
          .select('partner_vehicle_id,created_vehicle_id,plate_number')
          .eq('id', appId)
          .single();

      await _supabase
          .from('partner_vehicle_applications')
          .update({
            'application_status': 'rejected',
            'status': 'rejected',
            'reviewed_at': DateTime.now().toIso8601String(),
            'verified_at': DateTime.now().toIso8601String(),
            'verified_by': _supabase.auth.currentUser?.id,
            'rejection_reason': rejectionReason.trim(),
            'is_available': false,
          })
          .eq('id', appId);

      final partnerVehicleId = currentApplication['partner_vehicle_id']
          ?.toString();
      if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
        await _supabase
            .from('partner_vehicles')
            .update({'status': 'disabled', 'is_available': false})
            .eq('id', partnerVehicleId);
      }

      final createdVehicleId = currentApplication['created_vehicle_id']
          ?.toString();
      if (createdVehicleId != null && createdVehicleId.isNotEmpty) {
        await _supabase
            .from('vehicles')
            .update({
              'status': 'inactive',
              'is_available': false,
              'is_posted': false,
            })
            .eq('id', createdVehicleId);
      }

      final plateNumber = currentApplication['plate_number']?.toString().trim();
      if (plateNumber != null && plateNumber.isNotEmpty) {
        await _supabase
            .from('vehicles')
            .update({
              'status': 'inactive',
              'is_available': false,
              'is_posted': false,
            })
            .eq('owner_role', 'partner')
            .eq('plate_number', plateNumber);
        await _supabase
            .from('partner_vehicles')
            .update({'status': 'disabled', 'is_available': false})
            .eq('plate_number', plateNumber);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle application rejected')),
      );
      _loadDashboardData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rejection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await _supabase.from('users').update({'role': newRole}).eq('id', userId);

      if (newRole == 'partner' || newRole == 'driver') {
        await _supabase
            .from('users')
            .update({'application_status': 'pending'})
            .eq('id', userId);
      }

      if (newRole == 'partner') {
        final partnerRow = await _supabase
            .from('partners')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (partnerRow == null) {
          await _supabase.from('partners').insert({
            'user_id': userId,
            'verification_status': 'pending',
          });
        }
      }

      if (newRole == 'renter') {
        final renterRow = await _supabase
            .from('renters')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (renterRow == null) {
          // Pull user details so we can satisfy any NOT NULL columns
          final userDetails = await _supabase
              .from('users')
              .select('full_name, phone, location')
              .eq('id', userId)
              .maybeSingle();
          try {
            await _supabase.from('renters').insert({
              'id': userId,
              'user_id': userId,
              if (userDetails?['full_name'] != null)
                'full_name': userDetails!['full_name'],
              if (userDetails?['phone'] != null)
                'phone': userDetails!['phone'],
              if (userDetails?['location'] != null)
                'address': userDetails!['location'],
              'rating': 5.0,
              'rating_count': 0,
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (renterInsertErr) {
            debugPrint('Renter insert note: $renterInsertErr');
          }
        }
      }

      if (newRole == 'driver') {
        // public.drivers row is ONLY created after admin verification approval.
        // Changing role to 'driver' here just marks the user as a driver applicant
        // in public.users — no row is inserted into public.drivers yet.
        debugPrint('Role set to driver — awaiting verification before creating drivers row.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User role updated to $newRole'),
          backgroundColor: Colors.green,
        ),
      );

      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _togglePsdcDriverStatus(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) return;

    final currentStatus = user['is_psdc_driver'] == true;
    final newStatus = !currentStatus;

    try {
      // 1. Update user role on users table (role = 'driver')
      try {
        await _supabase
            .from('users')
            .update({
              'role': 'driver',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
      } catch (userErr) {
        debugPrint('Updating user role note: $userErr');
      }

      // 2. Upsert / update drivers table for PSDC driver flag & tier
      final driverRow = await _supabase
          .from('drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (driverRow == null) {
        try {
          await _supabase.from('drivers').insert({
            'user_id': userId,
            'license_number': _placeholderLicenseNumber(userId),
            'license_expiry': _placeholderLicenseExpiry,
            'license_verified': true,
            'nbi_verified': true,
            'verification_status': 'verified',
            'is_psdc_driver': newStatus,
            'driver_tier': newStatus ? 'psdc' : 'standard',
            'rating': 5.0,
            'total_trips': 0,
          });
        } catch (insertErr) {
          debugPrint(
            'Driver insert with is_psdc_driver failed, trying driver_tier: $insertErr',
          );
          await _supabase.from('drivers').insert({
            'user_id': userId,
            'license_number': _placeholderLicenseNumber(userId),
            'license_expiry': _placeholderLicenseExpiry,
            'license_verified': true,
            'nbi_verified': true,
            'verification_status': 'verified',
            'driver_tier': newStatus ? 'psdc' : 'standard',
            'rating': 5.0,
            'total_trips': 0,
          });
        }
      } else {
        try {
          await _supabase
              .from('drivers')
              .update({
                'is_psdc_driver': newStatus,
                'driver_tier': newStatus ? 'psdc' : 'standard',
                'verification_status': 'verified',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);
        } catch (updateErr) {
          debugPrint(
            'Driver update with is_psdc_driver failed, trying driver_tier: $updateErr',
          );
          await _supabase
              .from('drivers')
              .update({
                'driver_tier': newStatus ? 'psdc' : 'standard',
                'verification_status': 'verified',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);
        }
      }

      await _loadAllUsers();
      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? '✅ User flagged as Official PSDC Driver'
                : '⚪ Driver status set to Standard Driver',
          ),
          backgroundColor: newStatus ? Colors.amber.shade800 : Colors.blueGrey,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update PSDC driver flag: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('users').delete().eq('id', userId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDashboardData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: WebPortalTheme.resolve(context, isDark: isDark),
      child: Scaffold(
        body: Row(
          children: [
            _buildSidebar(isDark),
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
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Users';
      case 2:
        return 'Vehicles';
      case 3:
        return 'Bookings';
      case 4:
        return 'Verifications';
      case 5:
        return 'Application Management';
      case 6:
        return 'Message Review';
      case 7:
        return 'Customer Service';
      case 8:
        return 'Analytics';
      case 9:
        return 'Announcements';
      case 10:
        return 'Live Tracking';
      case 11:
        return 'Settings';
      case 12:
        return 'Action Logs';
      case 13:
        return 'Safety & User Reports';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent(isDark);
      case 1:
        return _buildUsersContent(isDark);
      case 2:
        return _buildVehiclesContent(isDark);
      case 3:
        return _buildBookingsContent(isDark);
      case 4:
        return _buildVerificationsContent(isDark);
      case 5:
        return _buildApplicationsContentEnhanced(isDark);
      case 6:
        return _buildMessageReviewContent(isDark);
      case 7:
        return _buildCustomerServiceContent(isDark);
      case 8:
        return _buildAnalyticsContent(isDark);
      case 9:
        return _buildAnnouncementsContent(isDark);
      case 10:
        return _buildTrackingContent(isDark);
      case 11:
        return _buildSettingsContent(isDark);
      case 12:
        return _buildActionLogsContent(isDark);
      case 13:
        return _buildReportsContent(isDark);
      default:
        return _buildDashboardContent(isDark);
    }
  }

  Widget _buildSidebar(bool isDark) {
    final adminNavy = _adminNavy;
    final adminNavyDeep = _adminNavyDeep;
    final adminGold = _adminGold;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarExpanded ? 260 : 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [adminNavy, adminNavyDeep],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 24),
        ],
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 92,
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarExpanded ? 20 : 14,
            ),
            child: Row(
              children: [
                // Logo matching operator rounded square design
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: adminGold,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: adminGold.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icon/logo-black.png',
                    fit: BoxFit.contain,
                  ),
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mobilis Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'ADMIN PORTAL',
                          style: TextStyle(
                            color: adminGold,
                            fontSize: 9,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          const SizedBox(height: 10),
          if (_sidebarExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'MAIN MENU',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.35),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          const SizedBox(height: 10),
          _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard', isDark),
          _buildNavItem(
            1,
            Icons.people_rounded,
            'Users',
            isDark,
          ),
          _buildNavItem(2, Icons.directions_car_rounded, 'Vehicles', isDark),
          _buildNavItem(
            3,
            Icons.book_rounded,
            'Bookings',
            isDark,
            badge: _unviewedBookingsCount > 0 ? _unviewedBookingsCount : null,
          ),
          _buildNavItem(
            4,
            Icons.fact_check_rounded,
            'Verifications',
            isDark,
            badge: _pendingVerifications > 0 ? _pendingVerifications : null,
          ),
          _buildNavItem(
            5,
            Icons.assignment_rounded,
            'Applications',
            isDark,
            badge:
                _pendingApplicationsCount > 0
                    ? _pendingApplicationsCount
                    : null,
          ),
          _buildNavItem(6, Icons.mail_rounded, 'Message Review', isDark),
          _buildNavItem(
            7,
            Icons.support_agent_rounded,
            'Customer Service',
            isDark,
            badge: _selectedIndex == 7
                ? null
                : (_unreadSupportCount > 0 ? _unreadSupportCount : null),
          ),
          _buildNavItem(
            13,
            Icons.shield_outlined,
            'Safety & Reports',
            isDark,
            badge: _pendingReportsCount > 0 ? _pendingReportsCount : null,
          ),
          const SizedBox(height: 18),
          if (_sidebarExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'SYSTEM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.35),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          const SizedBox(height: 10),
          _buildNavItem(8, Icons.analytics_rounded, 'Analytics', isDark),
          _buildNavItem(
            12,
            Icons.fact_check_rounded,
            'Action Logs',
            isDark,
            badge: _selectedIndex == 12
                ? null
                : (_unreadActionLogsCount > 0 ? _unreadActionLogsCount : null),
          ),
          _buildNavItem(
            10,
            Icons.location_on_rounded,
            'Live Tracking',
            isDark,
            badge: _trackingLocations.isNotEmpty
                ? _trackingLocations.length
                : null,
          ),
          _buildNavItem(9, Icons.campaign_rounded, 'Announcements', isDark),
          _buildNavItem(11, Icons.settings_rounded, 'Settings', isDark),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          Tooltip(
            message: _sidebarExpanded ? 'Collapse sidebar' : 'Expand sidebar',
            child: InkWell(
              onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
              child: SizedBox(
                height: 46,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: _sidebarExpanded
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.center,
                    children: [
                      Icon(
                        _sidebarExpanded
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        color: Colors.white38,
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

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    bool isDark, {
    int? badge,
  }) {
    final isSelected = _selectedIndex == index;
    final adminGold = _adminGold;
    final adminNavyDeep = _adminNavyDeep;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            if (index == 3) {
              _markAllBookingsAsViewed();
            } else if (index == 12) {
              _unreadActionLogsCount = 0;
              _saveLastSeenActionLogCount(_actionLogs.length);
              if (_actionLogs.isEmpty) {
                _loadActionLogs();
              }
            } else if (index == 7) {
              _unreadSupportCount = 0;
              _saveLastSeenSupportCount(_supportConversations.length);
              if (_supportConversations.isEmpty) {
                _loadSupportInbox();
              }
            } else if (index == 11) {
              _loadSettingsLazily();
            } else if (index == 9) {
              if (_announcements.isEmpty) {
                _loadAnnouncements();
              }
            } else if (index == 10) {
              _refreshTrackingLocations();
            } else if (index == 2) {
              if (_allVehicles.isEmpty) {
                _loadAllVehicles();
              }
            } else if (index == 4) {
              if (_verificationRecords.isEmpty) {
                _loadPendingVerifications();
              }
            } else if (index == 5) {
              if (_pendingPartnerVehicleApplications.isEmpty) {
                _loadPendingPartnerVehicleApplications();
              }
            }
          });
          _persistSelectedTab(index);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: _sidebarExpanded ? 16 : 0),
          decoration: BoxDecoration(
            color: isSelected ? adminGold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: adminGold.withOpacity(0.25),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: _sidebarExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? adminNavyDeep : Colors.white54,
                    size: 22,
                  ),
                  if (!_sidebarExpanded && badge != null && badge > 0)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(color: _adminNavy, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              if (_sidebarExpanded) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? adminNavyDeep : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (badge != null && badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? adminNavyDeep.withOpacity(0.18)
                          : Colors.red.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge.toString(),
                      style: TextStyle(
                        color: isSelected ? adminNavyDeep : Colors.white,
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

  Future<void> _persistSelectedTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('mobilis_admin_web_tab', index);
    } catch (_) {}
  }

  Future<void> _restoreSavedTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt('mobilis_admin_web_tab');
      if (savedIndex != null &&
          savedIndex >= 0 &&
          savedIndex <= 12 &&
          mounted) {
        setState(() => _selectedIndex = savedIndex);
      }
    } catch (_) {}
  }

  Future<void> _refreshCurrentSection() async {
    if (_selectedIndex == 10) {
      await _refreshTrackingLocations();
      if (mounted) setState(() {});
      return;
    }
    if (_selectedIndex == 7) {
      await _loadSupportInbox();
      return;
    }
    await _loadDashboardData();
  }

  Widget _buildTopBar(bool isDark) {
    final adminNavyDeep = _adminNavyDeep;
    final adminGold = _adminGold;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: isDark ? adminNavyDeep : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.grey.shade200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            _getPageTitle(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : _adminInk,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          _buildQuickAction('Export', Icons.download_rounded, Colors.green, () {
            _generateAndExportReport(isDark);
          }),
          const SizedBox(width: 16),
          Tooltip(
            message: 'Customize Workspace Color Theme',
            child: IconButton(
              onPressed: () => _showColorThemeDialog(isDark),
              icon: Icon(Icons.palette_rounded, color: adminGold),
            ),
          ),
          Tooltip(
            message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            child: IconButton(
              onPressed: () => widget.onThemeToggle?.call(!isDark),
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: isDark ? Colors.white70 : _adminInk,
              ),
            ),
          ),
          Tooltip(
            message: 'Notifications',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => _showNotificationsDialog(isDark),
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: isDark ? Colors.white70 : _adminInk,
                  ),
                ),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _unreadNotificationsCount > 99
                            ? '99+'
                            : '$_unreadNotificationsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Tooltip(
            message: 'Refresh dashboard metrics and system data',
            child: IconButton(
              onPressed: _refreshCurrentSection,
              icon: Icon(
                Icons.refresh_rounded,
                color: isDark ? Colors.white70 : _adminInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Administrator Account & Settings',
            onSelected: (value) {
              if (value == 'logout') _handleLogout();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: adminGold,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: adminGold.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Image.asset(
                      'assets/icon/logo-black.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Admin',
                    style: TextStyle(
                      color: Color(0xFF021F35),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF021F35),
                    size: 20,
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_rounded),
                    SizedBox(width: 10),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.red),
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

  Widget _buildQuickAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: 'Export current system report to CSV',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Banner
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFD97706,
                  ).withValues(alpha: isDark ? 0.35 : 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.monetization_on_rounded,
                            color: Colors.black.withValues(alpha: 0.65),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TOTAL REVENUE',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.65),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'PHP ${_formatCurrency(_totalRevenue)}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Aggregated from ${_formatNumber(_totalBookings)} total bookings',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Colors.black,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // Stats Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 1.55,
            children: [
              _buildStatCard(
                title: 'Total Renters',
                value: _totalUsers.toString(),
                icon: Icons.person_rounded,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
                subtitle: 'Registered customer accounts',
                onTap: () {
                  setState(() {
                    _userRoleFilter = 'renter';
                    _selectedIndex = 1;
                  });
                },
              ),
              _buildStatCard(
                title: 'Partners',
                value: _totalPartners.toString(),
                icon: Icons.business_rounded,
                color: const Color(0xFF10B981),
                isDark: isDark,
                subtitle: 'Registered vehicle partners',
                onTap: () {
                  setState(() {
                    _userRoleFilter = 'partner';
                    _selectedIndex = 1;
                  });
                },
              ),
              _buildStatCard(
                title: 'Operators',
                value: _totalOperators.toString(),
                icon: Icons.shield_rounded,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
                subtitle: 'PSDC fleet administrators',
                onTap: () {
                  setState(() {
                    _userRoleFilter = 'operator';
                    _selectedIndex = 1;
                  });
                },
              ),
              _buildStatCard(
                title: 'Ongoing Bookings',
                value: _activeBookings.toString(),
                icon: Icons.event_available_rounded,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                subtitle: 'Active trips currently on road',
                onTap: () {
                  setState(() {
                    _bookingStatusFilter = 'active';
                    _selectedIndex = 3;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildCard(
                  'Recent Bookings',
                  _buildRecentBookingsTable(isDark),
                  isDark,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildCard(
                  'Booking Status Distribution',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Real-time breakdown of bookings by status',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildBookingStatusChartWithLegend(
                        isDark,
                        chartHeight: 180,
                      ),
                    ],
                  ),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusItem(
    String name,
    String status,
    Color color,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey.shade800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '• $status',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: 'Click to view $title details ($subtitle)',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: color.withValues(alpha: 0.08),
          splashColor: color.withValues(alpha: 0.12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? color.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.1 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: color,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildCard(String title, Widget content, bool isDark) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildRecentBookingsTable(bool isDark) {
    if (_allBookings.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(40), child: Text('No bookings')),
      );
    }

    final totalPages = (_allBookings.length / _recentBookingsPerPage).ceil();
    final currentPage = _recentBookingsPage.clamp(1, totalPages).toInt();
    final startIndex = (currentPage - 1) * _recentBookingsPerPage;
    final endIndex = (startIndex + _recentBookingsPerPage).clamp(
      0,
      _allBookings.length,
    );
    final pageBookings = _allBookings.sublist(startIndex, endIndex);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    horizontalMargin: 16,
                    columnSpacing: 32,
                    columns: [
                      DataColumn(
                        label: Text(
                          'Vehicle',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Renter',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Status',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Amount',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                    rows: pageBookings.map((booking) {
                      final vehicle =
                          (booking['vehicles'] as Map<String, dynamic>?) ??
                          (booking['vehicle'] as Map<String, dynamic>?);
                      final renterMap =
                          (booking['renter'] as Map<String, dynamic>?) ??
                          (booking['users'] as Map<String, dynamic>?) ??
                          (booking['user'] as Map<String, dynamic>?);
                      final renterName =
                          (renterMap?['full_name'] as String?)?.isNotEmpty ==
                              true
                          ? renterMap!['full_name'] as String
                          : ((renterMap?['name'] as String?)?.isNotEmpty == true
                                ? renterMap!['name'] as String
                                : ((booking['renter_name'] as String?)
                                              ?.isNotEmpty ==
                                          true
                                      ? booking['renter_name'] as String
                                      : ((booking['user_name'] as String?)
                                                    ?.isNotEmpty ==
                                                true
                                            ? booking['user_name'] as String
                                            : 'Unknown Renter')));
                      final brand = vehicle?['brand']?.toString().trim() ?? '';
                      final model = vehicle?['model']?.toString().trim() ?? '';
                      final combo = [brand, model].where((part) => part.isNotEmpty).join(' ');
                      final vName = vehicle?['vehicle_name']?.toString().trim() ?? '';
                      final vehicleTitle = combo.isNotEmpty
                          ? combo
                          : (vName.isNotEmpty &&
                                  vName.toLowerCase() != 'partner vehicle' &&
                                  vName.toLowerCase() != 'unknown vehicle'
                              ? vName
                              : (vehicle?['plate_number']?.toString().isNotEmpty == true
                                  ? 'Vehicle (${vehicle!['plate_number']})'
                                  : (booking['vehicle_name']?.toString() ?? 'Partner Vehicle')));
                      final status = booking['status'] as String? ?? 'pending';
                      final total =
                          (booking['total_cost'] as num?)?.toDouble() ??
                          (booking['amount'] as num?)?.toDouble() ??
                          0;

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  vehicleTitle.isNotEmpty
                                      ? vehicleTitle
                                      : 'Unknown Vehicle',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                if (!_viewedBookingIds.contains(booking['id']?.toString())) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              renterName,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          DataCell(_buildStatusBadge(status)),
                          DataCell(
                            Text(
                              'PHP ${total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Divider(
          height: 1,
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing ${startIndex + 1}-$endIndex of ${_allBookings.length}',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Previous page',
              onPressed: currentPage > 1
                  ? () => setState(() => _recentBookingsPage = currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$currentPage / $totalPages',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: currentPage < totalPages
                  ? () => setState(() => _recentBookingsPage = currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final group = bookingStatusGroup(status);
    final color = bookingStatusColor(group);
    final label = bookingStatusLabel(group);

    final statusDescription = switch (group) {
      BookingStatusGroup.pending => 'Pending: Reservation is waiting for operator/admin review',
      BookingStatusGroup.approved => 'Approved: Confirmed and awaiting vehicle handover',
      BookingStatusGroup.ongoing => 'Ongoing: Vehicle currently on trip with customer',
      BookingStatusGroup.completed => 'Completed: Rental concluded and successfully settled',
      BookingStatusGroup.cancelled => 'Cancelled: Booking was declined or cancelled',
      _ => 'Status: $label',
    };

    return Tooltip(
      message: statusDescription,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatus(bool isDark) {
    return Column(
      children: [
        _buildStatusRow('Database', 'Connected', Colors.green, isDark),
        const Divider(height: 24),
        _buildStatusRow('Auth Service', 'Active', Colors.green, isDark),
        const Divider(height: 24),
        _buildStatusRow('Storage', 'Operational', Colors.green, isDark),
        const Divider(height: 24),
        _buildStatusRow('API', 'Running', Colors.green, isDark),
      ],
    );
  }

  Widget _buildStatusRow(String name, String status, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        Text(
          status,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildUsersContent(bool isDark) {
    final filteredUsers = _allUsers.where((user) {
      final name = (user['full_name'] ?? '').toLowerCase();
      final email = (user['email'] ?? '').toLowerCase();
      final role = (user['role'] as String? ?? 'renter').toLowerCase();
      final isPsdc = user['is_psdc_driver'] == true;
      final verificationStatus =
          (user['display_verification_status'] ??
                  user['verification_status'] ??
                  '')
              .toString()
              .toLowerCase();
      final isVerified =
          user['id_verified'] == true ||
          user['is_verified'] == true ||
          verificationStatus == 'verified' ||
          verificationStatus == 'approved';

      final matchesSearch =
          name.contains(_userSearchQuery.toLowerCase()) ||
          email.contains(_userSearchQuery.toLowerCase());

      final matchesRole =
          _userRoleFilter == 'all' ||
          role == _userRoleFilter ||
          (_userRoleFilter == 'psdc' && isPsdc) ||
          (_userRoleFilter == 'verified' && isVerified) ||
          (_userRoleFilter == 'unverified' && !isVerified);

      final matchesVerification =
          _userVerificationFilter == 'all' ||
          (_userVerificationFilter == 'verified' && isVerified) ||
          (_userVerificationFilter == 'unverified' && !isVerified);

      return matchesSearch && matchesRole && matchesVerification;
    }).toList();

    final totalPages = (filteredUsers.length / _usersPerPage).ceil();
    final startIndex = (_currentUserPage - 1) * _usersPerPage;
    final endIndex = (startIndex + _usersPerPage).clamp(
      0,
      filteredUsers.length,
    );
    final paginatedUsers = filteredUsers.sublist(startIndex, endIndex.toInt());

    final partnersCount = _allUsers.where((u) => u['role'] == 'partner').length;
    final operatorsCount = _allUsers
        .where((u) => u['role'] == 'operator')
        .length;
    final psdcDriversCount = _allUsers
        .where((u) => u['is_psdc_driver'] == true)
        .length;
    final verifiedCount = _allUsers.where((u) {
      final status =
          (u['display_verification_status'] ?? u['verification_status'] ?? '')
              .toString()
              .toLowerCase();
      return u['id_verified'] == true ||
          u['is_verified'] == true ||
          status == 'verified' ||
          status == 'approved';
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildUserStatCard(
                  'Total Users',
                  _allUsers.length.toString(),
                  Icons.people_rounded,
                  Colors.blue,
                  isDark,
                  onTap: () {
                    setState(() {
                      _userRoleFilter = 'all';
                      _userVerificationFilter = 'all';
                      _currentUserPage = 1;
                    });
                  },
                  isSelected:
                      _userRoleFilter == 'all' &&
                      _userVerificationFilter == 'all',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Verified',
                  verifiedCount.toString(),
                  Icons.verified_rounded,
                  Colors.green,
                  isDark,
                  onTap: () {
                    setState(() {
                      _userVerificationFilter =
                          _userVerificationFilter == 'verified'
                          ? 'all'
                          : 'verified';
                      _currentUserPage = 1;
                    });
                  },
                  isSelected: _userVerificationFilter == 'verified',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Partners',
                  partnersCount.toString(),
                  Icons.business_rounded,
                  Colors.purple,
                  isDark,
                  onTap: () {
                    setState(() {
                      _userRoleFilter = _userRoleFilter == 'partner'
                          ? 'all'
                          : 'partner';
                      _currentUserPage = 1;
                    });
                  },
                  isSelected: _userRoleFilter == 'partner',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Operators',
                  operatorsCount.toString(),
                  Icons.admin_panel_settings_rounded,
                  Colors.orange,
                  isDark,
                  onTap: () {
                    setState(() {
                      _userRoleFilter = _userRoleFilter == 'operator'
                          ? 'all'
                          : 'operator';
                      _currentUserPage = 1;
                    });
                  },
                  isSelected: _userRoleFilter == 'operator',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'PSDC Drivers',
                  psdcDriversCount.toString(),
                  Icons.badge_rounded,
                  const Color(0xFFF59E0B),
                  isDark,
                  onTap: () {
                    setState(() {
                      _userRoleFilter = _userRoleFilter == 'psdc'
                          ? 'all'
                          : 'psdc';
                      _currentUserPage = 1;
                    });
                  },
                  isSelected: _userRoleFilter == 'psdc',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 260, maxWidth: 380),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _userSearchQuery = value;
                      _currentUserPage = 1;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? Colors.grey : Colors.grey.shade500,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderColor
                        : Colors.grey.shade200,
                  ),
                ),
                child: DropdownButton<String>(
                  value: _userRoleFilter,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'All Roles',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'renter',
                      child: Text(
                        'Renters',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'partner',
                      child: Text(
                        'Partners',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'operator',
                      child: Text(
                        'Operators',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'driver',
                      child: Text(
                        'Drivers',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'psdc',
                      child: _buildUserFilterOption(
                        icon: Icons.badge_rounded,
                        label: 'PSDC Drivers',
                        color: isDark
                            ? Colors.amber.shade300
                            : Colors.amber.shade900,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'verified',
                      child: _buildUserFilterOption(
                        icon: Icons.verified_rounded,
                        label: 'Verified Users',
                        color: isDark
                            ? Colors.green.shade300
                            : Colors.green.shade800,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'unverified',
                      child: _buildUserFilterOption(
                        icon: Icons.pending_outlined,
                        label: 'Unverified Users',
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _userRoleFilter = value ?? 'all';
                      _currentUserPage = 1;
                    });
                  },
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderColor
                        : Colors.grey.shade200,
                  ),
                ),
                child: DropdownButton<String>(
                  value: _userVerificationFilter,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'All Verification',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'verified',
                      child: _buildUserFilterOption(
                        icon: Icons.verified_rounded,
                        label: 'Verified Only',
                        color: isDark
                            ? Colors.green.shade300
                            : Colors.green.shade800,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'unverified',
                      child: _buildUserFilterOption(
                        icon: Icons.pending_outlined,
                        label: 'Unverified Only',
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _userVerificationFilter = value ?? 'all';
                      _currentUserPage = 1;
                    });
                  },
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddOperatorDialog(isDark),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
                label: const Text('Add Operator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 17,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Email',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Role',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            'Verified',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            'Actions',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (paginatedUsers.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: isDark
                                ? Colors.white30
                                : Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No users found',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...paginatedUsers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final user = entry.value;
                    final role = user['role'] as String? ?? 'renter';
                    final isPsdcDriver = user['is_psdc_driver'] == true;
                    final isVerified = user['id_verified'] as bool? ?? false;
                    final isLast = index == paginatedUsers.length - 1;

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: !isLast
                                ? Border(
                                    bottom: BorderSide(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.grey.shade200,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    _buildUserAvatarCell(user, isPsdcDriver),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            user['full_name'] ?? 'User',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if ((user['phone'] as String? ?? '')
                                              .isNotEmpty)
                                            Text(
                                              user['phone'].toString(),
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.grey.shade600,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  user['email'] ?? '',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildRoleBadge(
                                    role,
                                    isPsdcDriver: isPsdcDriver,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: _buildVerificationBadge(isVerified),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteUser(user['id']);
                                      } else if (value == 'toggle_psdc') {
                                        _togglePsdcDriverStatus(user);
                                      } else {
                                        _updateUserRole(user['id'], value);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'toggle_psdc',
                                        child: Row(
                                          children: [
                                            Icon(
                                              isPsdcDriver
                                                  ? Icons
                                                        .remove_moderator_outlined
                                                  : Icons.badge_rounded,
                                              size: 18,
                                              color: isPsdcDriver
                                                  ? Colors.orange
                                                  : AppColors.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isPsdcDriver
                                                  ? 'Unflag as PSDC Driver'
                                                  : 'Flag as PSDC Driver',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: isPsdcDriver
                                                    ? Colors.orange
                                                    : AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'renter',
                                        child: Text('Set as Renter'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'partner',
                                        child: Text('Set as Partner'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'operator',
                                        child: Text('Set as Operator'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'driver',
                                        child: Text('Set as Driver'),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          'Delete User',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),

                if (totalPages > 1)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${startIndex + 1} to $endIndex of ${filteredUsers.length} users',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _currentUserPage > 1
                                  ? () => setState(() => _currentUserPage--)
                                  : null,
                              icon: const Icon(Icons.chevron_left, size: 18),
                              label: const Text('Previous'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                disabledBackgroundColor: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black26
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Page $_currentUserPage of $totalPages',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _currentUserPage < totalPages
                                  ? () => setState(() => _currentUserPage++)
                                  : null,
                              icon: const Icon(Icons.chevron_right, size: 18),
                              label: const Text('Next'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                disabledBackgroundColor: Colors.grey.shade400,
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
        ],
      ),
    );
  }

  Widget _buildUserFilterOption({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildUserStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Tooltip(
      message: 'Filter user table by $title ($value total accounts)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppColors.borderColor : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  String _getUserAvatarUrl(Map<String, dynamic> user) {
    final direct =
        user['avatar_url']?.toString().trim() ??
        user['profile_picture_url']?.toString().trim() ??
        user['profile_image']?.toString().trim() ??
        user['photo_url']?.toString().trim() ??
        user['image_url']?.toString().trim() ??
        '';
    if (direct.isNotEmpty &&
        (direct.startsWith('http') || direct.startsWith('gs://'))) {
      return direct;
    }
    return '';
  }

  Widget _buildUserAvatarCell(Map<String, dynamic> user, bool isPsdcDriver) {
    final avatarUrl = _getUserAvatarUrl(user);
    final fullName = user['full_name']?.toString().trim() ?? 'User';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

    if (avatarUrl.isNotEmpty) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isPsdcDriver
                ? const Color(0xFFF59E0B)
                : AppColors.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: OptimizedNetworkImage(
            imageUrl: avatarUrl,
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorWidget: Container(
              color: isPsdcDriver
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                  : Colors.blue.withValues(alpha: 0.2),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: isPsdcDriver ? const Color(0xFFF59E0B) : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 19,
      backgroundColor: isPsdcDriver
          ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
          : Colors.blue.withValues(alpha: 0.2),
      child: Text(
        initial,
        style: TextStyle(
          color: isPsdcDriver ? const Color(0xFFF59E0B) : Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(bool isVerified) {
    if (isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: Colors.green, size: 14),
            SizedBox(width: 5),
            Text(
              'Verified',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pending_outlined, color: Color(0xFFF59E0B), size: 14),
          SizedBox(width: 5),
          Text(
            'Unverified',
            style: TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role, {bool isPsdcDriver = false}) {
    if (isPsdcDriver) {
      return Tooltip(
        message: 'PSDC Dedicated In-House Fleet Driver',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706).withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_rounded, size: 13, color: Color(0xFFF59E0B)),
              SizedBox(width: 4),
              Text(
                'PSDC DRIVER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF59E0B),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Color color;
    switch (role) {
      case 'partner':
        color = Colors.blue;
        break;
      case 'operator':
        color = Colors.purple;
        break;
      case 'admin':
        color = Colors.red;
        break;
      case 'driver':
        color = Colors.teal;
        break;
      default:
        color = Colors.green;
    }

    final roleDescription = switch (role.toLowerCase()) {
      'partner' => 'Partner: Vehicle fleet owner registered on platform',
      'operator' => 'Operator: Operations desk managing bookings and fleet',
      'admin' => 'Administrator: Full system privileges and settings',
      'driver' => 'Driver: Assigned trip driver for chauffeur bookings',
      'renter' => 'Renter: Customer booking and renting vehicles',
      _ => 'Role: ${role.toUpperCase()}',
    };

    return Tooltip(
      message: roleDescription,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          role.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildVehiclesContent(bool isDark) {
    // 1. Separate PSDC vs Partner vehicles based on source & database origin
    final psdcVehicles = _allVehicles.where((v) {
      final source = (v['source']?.toString() ?? 'company').toLowerCase();
      return source != 'partner' && v['is_partner_vehicle'] != true;
    }).toList();

    final partnerVehicles = _allVehicles.where((v) {
      final source = (v['source']?.toString() ?? '').toLowerCase();
      return source == 'partner' || v['is_partner_vehicle'] == true;
    }).toList();

    final totalCount = _allVehicles.length;
    final psdcCount = psdcVehicles.length;
    final partnerCount = partnerVehicles.length;

    // 2. Select target list by active tab
    List<Map<String, dynamic>> activeList;
    if (_vehicleTabFilter == 'psdc') {
      activeList = psdcVehicles;
    } else if (_vehicleTabFilter == 'partner') {
      activeList = partnerVehicles;
    } else {
      activeList = _allVehicles;
    }

    // 3. Search query filter
    final query = _vehicleSearchQuery.trim().toLowerCase();
    final filteredVehicles = activeList.where((v) {
      if (query.isEmpty) return true;
      final brand = (v['brand']?.toString() ?? '').toLowerCase();
      final model = (v['model']?.toString() ?? '').toLowerCase();
      final plate = (v['plate_number']?.toString() ?? '').toLowerCase();
      final year = (v['year']?.toString() ?? '').toLowerCase();
      final owner = v['owner'] as Map<String, dynamic>?;
      final ownerName = (owner?['full_name']?.toString() ?? '').toLowerCase();
      final partnerName = (v['partner_name']?.toString() ?? '').toLowerCase();

      return brand.contains(query) ||
          model.contains(query) ||
          plate.contains(query) ||
          year.contains(query) ||
          ownerName.contains(query) ||
          partnerName.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Tabs & Search
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car_filled_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicles Fleet Management',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Manage company PSDC fleet vehicles and registered Partner vehicles on the platform.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  height: 1,
                ),
                const SizedBox(height: 16),

                // Search & Filter Bar
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _vehicleSearchQuery = val),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search vehicles by Brand, Model, Plate, Year, or Partner Name...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black26
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // View Mode Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Grid View',
                            icon: const Icon(Icons.grid_view_rounded, size: 18),
                            color: _vehicleViewMode == 'cards'
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            onPressed: () =>
                                setState(() => _vehicleViewMode = 'cards'),
                          ),
                          IconButton(
                            tooltip: 'Table View',
                            icon: const Icon(
                              Icons.table_rows_rounded,
                              size: 18,
                            ),
                            color: _vehicleViewMode == 'table'
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            onPressed: () =>
                                setState(() => _vehicleViewMode = 'table'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Separated Fleet Tabs
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildVehicleTabChip(
                      'all',
                      'All Vehicles',
                      totalCount,
                      Icons.directions_car_rounded,
                      isDark,
                    ),
                    _buildVehicleTabChip(
                      'psdc',
                      'PSDC Vehicles',
                      psdcCount,
                      Icons.business_rounded,
                      isDark,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    _buildVehicleTabChip(
                      'partner',
                      'Partner Vehicles',
                      partnerCount,
                      Icons.handshake_rounded,
                      isDark,
                      accentColor: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vehicle Grid View
          if (filteredVehicles.isEmpty)
            _buildCard(
              'Vehicles List (0)',
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 48,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No vehicles match your selected tab or search query.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              isDark,
            )
          else
            _buildCard(
              _vehicleTabFilter == 'psdc'
                  ? 'PSDC Company Fleet (${filteredVehicles.length})'
                  : _vehicleTabFilter == 'partner'
                  ? 'Partner Fleet Vehicles (${filteredVehicles.length})'
                  : 'All Vehicles Fleet (${filteredVehicles.length})',
              _vehicleViewMode == 'cards'
                  ? _buildAdminVehiclesGrid(filteredVehicles, isDark)
                  : _buildAdminVehiclesTable(filteredVehicles, isDark),
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildAdminVehiclesGrid(
    List<Map<String, dynamic>> vehicles,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final rows = <Widget>[];

        for (var start = 0; start < vehicles.length; start += columns) {
          final end = (start + columns).clamp(0, vehicles.length);
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = start; index < end; index++) ...[
                  if (index > start) const SizedBox(width: spacing),
                  Expanded(
                    child: _buildAdminVehicleCard(vehicles[index], isDark),
                  ),
                ],
              ],
            ),
          );
          if (end < vehicles.length) {
            rows.add(const SizedBox(height: spacing));
          }
        }

        return Column(children: rows);
      },
    );
  }

  Widget _buildAdminVehiclesTable(
    List<Map<String, dynamic>> vehicles,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 28,
              columns: [
                DataColumn(
                  label: Text(
                    'Vehicle',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Fleet',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Owner / Operator',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Specifications',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Daily Rate',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Availability',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
              rows: vehicles.map((vehicle) {
                final owner = vehicle['owner'] as Map<String, dynamic>?;
                final source =
                    vehicle['source']?.toString().toLowerCase() ?? 'company';
                final isPartner =
                    source == 'partner' ||
                    vehicle['is_partner_vehicle'] == true;
                final ownerName =
                    owner?['full_name']?.toString().trim().isNotEmpty == true
                    ? owner!['full_name'].toString().trim()
                    : (vehicle['partner_name']?.toString().trim().isNotEmpty ==
                              true
                          ? vehicle['partner_name'].toString().trim()
                          : (isPartner
                                ? 'Mobilis Partner'
                                : 'Unknown Operator'));
                final brand =
                    vehicle['brand']?.toString().trim().isNotEmpty == true
                    ? vehicle['brand'].toString().trim()
                    : 'Unknown';
                final model =
                    vehicle['model']?.toString().trim().isNotEmpty == true
                    ? vehicle['model'].toString().trim()
                    : 'Model';
                final plate =
                    vehicle['plate_number']?.toString().trim().isNotEmpty ==
                        true
                    ? vehicle['plate_number'].toString().trim()
                    : 'No plate';
                final year = vehicle['year']?.toString() ?? 'N/A';
                final transmission =
                    vehicle['transmission']?.toString() ?? 'Manual';
                final seats = vehicle['seats']?.toString() ?? '5';
                final pricePerDay =
                    (vehicle['price_per_day'] as num?)?.toDouble() ?? 0;
                final posted = isPartner
                    ? vehicle['is_available'] == true
                    : vehicle['is_posted'] == true;

                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$brand $model',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            plate,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(_buildSourceBadge(isPartner ? 'PARTNER' : 'PSDC')),
                    DataCell(
                      Text(
                        ownerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '$year  •  $transmission  •  $seats seats',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        'PHP ${pricePerDay.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DataCell(_buildPostedBadge(posted, isDark)),
                    DataCell(
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showAdminVehicleDetailsDialog(vehicle, isDark),
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: const Text('View'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleTabChip(
    String key,
    String label,
    int count,
    IconData icon,
    bool isDark, {
    Color? accentColor,
  }) {
    final isSelected = _vehicleTabFilter == key;
    final activeColor = accentColor ?? AppColors.primary;

    return Tooltip(
      message: 'Filter vehicles by $label ($count total)',
      child: InkWell(
        onTap: () => setState(() => _vehicleTabFilter = key),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white10 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildAdminVehicleCard(Map<String, dynamic> vehicle, bool isDark) {
    final owner = vehicle['owner'] as Map<String, dynamic>?;
    final source = vehicle['source']?.toString().toLowerCase() ?? 'company';
    final isPartner = source == 'partner';
    final ownerFullName = owner?['full_name']?.toString().trim() ?? '';
    final ownerName = ownerFullName.isNotEmpty
        ? ownerFullName
        : isPartner
        ? 'Mobilis Partner'
        : 'Unknown Operator';
    final ownerEmail = owner?['email']?.toString().trim() ?? '';
    final status = vehicle['status']?.toString() ?? 'pending';
    final imageUrl = _adminPrimaryVehicleImageUrl(vehicle);
    final pricePerDay = (vehicle['price_per_day'] as num?)?.toDouble() ?? 0;
    final pricePerHour = (vehicle['price_per_hour'] as num?)?.toDouble() ?? 0;
    final brand = vehicle['brand']?.toString().trim().isNotEmpty == true
        ? vehicle['brand'].toString()
        : 'Unknown';
    final model = vehicle['model']?.toString().trim().isNotEmpty == true
        ? vehicle['model'].toString()
        : 'Model';
    final year = vehicle['year']?.toString() ?? '';
    final plate = vehicle['plate_number']?.toString().trim() ?? '';
    final vehicleType =
        vehicle['vehicle_type']?.toString().trim().isNotEmpty == true
        ? vehicle['vehicle_type'].toString()
        : vehicle['category']?.toString() ?? 'Standard';
    final transmission = vehicle['transmission']?.toString() ?? 'Manual';
    final fuelType = vehicle['fuel_type']?.toString() ?? 'Gasoline';
    final seats = vehicle['seats']?.toString() ?? '5';
    final posted = isPartner
        ? vehicle['is_available'] == true
        : vehicle['is_posted'] == true;

    return InkWell(
      onTap: () => _showAdminVehicleDetailsDialog(vehicle, isDark),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF021F35) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                height: 168,
                width: double.infinity,
                color: isDark ? AppColors.darkBgTertiary : Colors.grey.shade200,
                child: imageUrl.isEmpty
                    ? Icon(
                        Icons.directions_car,
                        size: 52,
                        color: isDark ? Colors.grey[600] : Colors.grey.shade500,
                      )
                    : OptimizedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: Icon(
                          Icons.directions_car,
                          size: 52,
                          color: isDark
                              ? Colors.grey[600]
                              : Colors.grey.shade500,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildSourceBadge(
                        isPartner ? 'PARTNER FLEET' : 'PSDC FLEET',
                      ),
                      const SizedBox(width: 8),
                      _buildPostedBadge(posted, isDark),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$brand $model${year.isNotEmpty ? ' ($year)' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (plate.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Plate number  -  $plate',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildAdminVehicleInfoRow(
                    Icons.person_outline_rounded,
                    isPartner ? 'Applied by partner' : 'Added by operator',
                    ownerName,
                    isDark,
                  ),
                  if (ownerEmail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 28, top: 2),
                      child: Text(
                        ownerEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey[500]
                              : Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth < 330
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _buildVehicleAttributeCard(
                              'Vehicle Type',
                              vehicleType,
                              Icons.category_outlined,
                              isDark,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildVehicleAttributeCard(
                              'Capacity',
                              '$seats seats',
                              Icons.event_seat_outlined,
                              isDark,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildVehicleAttributeCard(
                              'Transmission',
                              transmission,
                              Icons.settings_outlined,
                              isDark,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildVehicleAttributeCard(
                              'Fuel Type',
                              fuelType,
                              Icons.local_gas_station_outlined,
                              isDark,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRateBox(
                          'Price/Day',
                          'PHP ${pricePerDay.toStringAsFixed(0)}',
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildRateBox(
                          'Price/Hour',
                          'PHP ${pricePerHour.toStringAsFixed(0)}',
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          _showAdminVehicleDetailsDialog(vehicle, isDark),
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: const Text('View details'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
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

  void _showAdminVehicleDetailsDialog(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final owner = vehicle['owner'] as Map<String, dynamic>?;
    final source = vehicle['source']?.toString().toLowerCase() ?? 'company';
    final isPartner =
        source == 'partner' || vehicle['is_partner_vehicle'] == true;
    final ownerFullName = owner?['full_name']?.toString().trim() ?? '';
    final ownerName = ownerFullName.isNotEmpty
        ? ownerFullName
        : (vehicle['partner_name']?.toString().trim() ??
              (isPartner ? 'Mobilis Partner' : 'PSDC Fleet Operator'));
    final ownerEmail =
        owner?['email']?.toString().trim() ??
        vehicle['partner_email']?.toString().trim() ??
        '';
    final ownerPhone =
        owner?['phone']?.toString().trim() ??
        vehicle['partner_phone']?.toString().trim() ??
        '';

    final imageUrl = _adminPrimaryVehicleImageUrl(vehicle);
    final rawImages = vehicle['vehicle_images'];
    final imageList = <String>[];
    if (imageUrl.isNotEmpty) imageList.add(imageUrl);
    if (rawImages is List) {
      for (final img in rawImages) {
        if (img is Map) {
          final url = img['image_url']?.toString().trim() ?? '';
          if (url.isNotEmpty && !imageList.contains(url)) {
            imageList.add(url);
          }
        }
      }
    }

    final pricePerDay = (vehicle['price_per_day'] as num?)?.toDouble() ?? 0;
    final pricePerHour = (vehicle['price_per_hour'] as num?)?.toDouble() ?? 0;
    final brand = vehicle['brand']?.toString().trim().isNotEmpty == true
        ? vehicle['brand'].toString()
        : 'Unknown';
    final model = vehicle['model']?.toString().trim().isNotEmpty == true
        ? vehicle['model'].toString()
        : 'Model';
    final year = vehicle['year']?.toString() ?? '';
    final plate = vehicle['plate_number']?.toString().trim() ?? 'N/A';
    final vehicleType =
        vehicle['vehicle_type']?.toString().trim().isNotEmpty == true
        ? vehicle['vehicle_type'].toString()
        : vehicle['category']?.toString() ?? 'Standard';
    final transmission = vehicle['transmission']?.toString() ?? 'Manual';
    final fuelType = vehicle['fuel_type']?.toString() ?? 'Gasoline';
    final seats = vehicle['seats']?.toString() ?? '5';
    final posted = isPartner
        ? vehicle['is_available'] == true
        : vehicle['is_posted'] == true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        String activeImage = imageList.isNotEmpty ? imageList.first : '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF021F35) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Container(
                width: 840,
                constraints: const BoxConstraints(maxHeight: 740),
                child: Column(
                  children: [
                    // Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.directions_car_filled_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '$brand $model ${year.isNotEmpty ? "($year)" : ""}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildSourceBadge(
                                      isPartner ? 'PARTNER' : 'PSDC',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildPostedBadge(posted, isDark),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Plate Number: $plate • Category: $vehicleType',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Gallery Preview Box
                            Container(
                              height: 250,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkBgTertiary
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: activeImage.isEmpty
                                    ? Center(
                                        child: Icon(
                                          Icons.directions_car,
                                          size: 64,
                                          color: isDark
                                              ? Colors.white30
                                              : Colors.grey.shade400,
                                        ),
                                      )
                                    : OptimizedNetworkImage(
                                        imageUrl: activeImage,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 250,
                                      ),
                              ),
                            ),

                            if (imageList.length > 1) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: imageList.length,
                                  itemBuilder: (context, index) {
                                    final img = imageList[index];
                                    final isSelected = img == activeImage;
                                    return GestureDetector(
                                      onTap: () => setModalState(
                                        () => activeImage = img,
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        width: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: OptimizedNetworkImage(
                                            imageUrl: img,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Specifications Grid (4 Columns)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 650;
                                final colWidth = isNarrow
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 24) / 2;

                                return Wrap(
                                  spacing: 24,
                                  runSpacing: 20,
                                  children: [
                                    // Section 1: Spec details
                                    SizedBox(
                                      width: colWidth,
                                      child: _buildVehicleSpecSectionCard(
                                        'VEHICLE SPECIFICATIONS',
                                        Icons.tune_rounded,
                                        isDark,
                                        [
                                          _buildModalDetailRow(
                                            'Brand & Model',
                                            '$brand $model',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Model Year',
                                            year.isNotEmpty ? year : 'N/A',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Plate Number',
                                            plate,
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Vehicle Category',
                                            vehicleType,
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Seating Capacity',
                                            '$seats Seats',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Transmission',
                                            transmission,
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Fuel Type',
                                            fuelType,
                                            isDark,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section 2: Pricing & Rates
                                    SizedBox(
                                      width: colWidth,
                                      child: _buildVehicleSpecSectionCard(
                                        'PRICING & RENTAL RATES',
                                        Icons.payments_rounded,
                                        isDark,
                                        [
                                          _buildModalDetailRow(
                                            'Price Per Day',
                                            'PHP ${pricePerDay.toStringAsFixed(0)}',
                                            isDark,
                                            highlight: true,
                                          ),
                                          _buildModalDetailRow(
                                            'Price Per Hour',
                                            'PHP ${pricePerHour.toStringAsFixed(0)}',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Delivery Fee',
                                            '₱75 / km delivery rate',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Posting Status',
                                            posted
                                                ? 'Available for Rent'
                                                : 'Unposted / Maintenance',
                                            isDark,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section 3: Owner & Fleet Operator
                                    SizedBox(
                                      width: colWidth,
                                      child: _buildVehicleSpecSectionCard(
                                        'OWNERSHIP & OPERATOR',
                                        Icons.person_pin_rounded,
                                        isDark,
                                        [
                                          _buildModalDetailRow(
                                            'Owner / Partner',
                                            ownerName,
                                            isDark,
                                          ),
                                          if (ownerEmail.isNotEmpty)
                                            _buildModalDetailRow(
                                              'Contact Email',
                                              ownerEmail,
                                              isDark,
                                            ),
                                          if (ownerPhone.isNotEmpty)
                                            _buildModalDetailRow(
                                              'Contact Phone',
                                              ownerPhone,
                                              isDark,
                                            ),
                                          _buildModalDetailRow(
                                            'Fleet Type',
                                            isPartner
                                                ? 'Mobilis Partner Fleet'
                                                : 'PSDC Company Fleet',
                                            isDark,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section 4: Vehicle Features & Amenities
                                    SizedBox(
                                      width: colWidth,
                                      child: _buildVehicleSpecSectionCard(
                                        'FEATURES & AMENITIES',
                                        Icons.auto_awesome_rounded,
                                        isDark,
                                        [
                                          _buildModalDetailRow(
                                            'Air Conditioning',
                                            'Equipped',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'GPS & Map Tracking',
                                            'Live GPS Active',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Bluetooth Audio',
                                            'Supported',
                                            isDark,
                                          ),
                                          _buildModalDetailRow(
                                            'Sanitization',
                                            'Verified Clean',
                                            isDark,
                                          ),
                                        ],
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

                    // Footer Action Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton.icon(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                            ),
                            label: const Text('Close Overview'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
    );
  }

  Widget _buildVehicleSpecSectionCard(
    String title,
    IconData icon,
    bool isDark,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
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
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModalDetailRow(
    String label,
    String value,
    bool isDark, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w900 : FontWeight.bold,
                color: highlight
                    ? Colors.green
                    : (isDark ? Colors.white : Colors.black87),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(String label) {
    final isPartner = label.trim().toUpperCase() == 'PARTNER';
    final tooltip = isPartner
        ? 'Vehicle supplied and managed by a verified Partner'
        : 'In-House PSDC Company-owned Fleet';

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildPostedBadge(bool posted, bool isDark) {
    final tooltip = posted
        ? 'Vehicle is published and visible in the public rental catalog'
        : 'Vehicle is currently unpublished / hidden from public catalog';

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: posted
              ? Colors.green.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          posted ? 'POSTED' : 'NOT POSTED',
          style: TextStyle(
            color: posted
                ? Colors.green
                : (isDark ? Colors.white70 : Colors.grey.shade700),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildForwardStatusBadge(bool forwarded) {
    final color = forwarded ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forwarded
                ? Icons.check_circle_outline_rounded
                : Icons.pending_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            forwarded ? 'FORWARDED' : 'PENDING',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminVehicleInfoRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniVehicleChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.grey.shade800,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVehicleAttributeCard(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
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
  }

  Widget _buildRateBox(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _adminPrimaryVehicleImageUrl(Map<String, dynamic> vehicle) {
    final direct = vehicle['image_url']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final images = vehicle['vehicle_images'];
    if (images is! List) return '';
    for (final image in images) {
      if (image is! Map) continue;
      final url = image['image_url']?.toString().trim() ?? '';
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  Widget _buildBookingsContent(bool isDark) {
    // 1. Calculate status counts
    final allCount = _allBookings.length;
    int pendingCount = 0;
    int confirmedCount = 0;
    int activeCount = 0;
    int completedCount = 0;
    int cancelledCount = 0;

    for (final b in _allBookings) {
      final st = (b['status']?.toString() ?? 'pending').toLowerCase();
      if (st == 'pending') {
        pendingCount++;
      } else if (st == 'confirmed' || st == 'approved') {
        confirmedCount++;
      } else if (st == 'active' || st == 'in_trip' || st == 'in-trip') {
        activeCount++;
      } else if (st == 'completed') {
        completedCount++;
      } else if (st == 'cancelled' || st == 'rejected') {
        cancelledCount++;
      }
    }

    // 2. Filter bookings by search query & status chip
    final query = _bookingSearchQuery.trim().toLowerCase();
    final filteredBookings = _allBookings.where((booking) {
      final status = (booking['status']?.toString() ?? 'pending').toLowerCase();

      // Status filter
      if (_bookingStatusFilter != 'all') {
        if (_bookingStatusFilter == 'pending' && status != 'pending') {
          return false;
        }
        if (_bookingStatusFilter == 'confirmed' &&
            status != 'confirmed' &&
            status != 'approved') {
          return false;
        }
        if (_bookingStatusFilter == 'active' &&
            status != 'active' &&
            status != 'in_trip' &&
            status != 'in-trip') {
          return false;
        }
        if (_bookingStatusFilter == 'completed' && status != 'completed') {
          return false;
        }
        if (_bookingStatusFilter == 'cancelled' &&
            status != 'cancelled' &&
            status != 'rejected') {
          return false;
        }
      }

      // Search query
      if (query.isEmpty) return true;
      final bookingId = booking['id']?.toString().toLowerCase() ?? '';
      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final vehicleTitle =
          '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''} ${vehicle?['plate_number'] ?? ''}'
              .toLowerCase();
      final renter = booking['renter'] as Map<String, dynamic>?;
      final renterName = renter?['full_name']?.toString().toLowerCase() ?? '';
      final renterEmail = renter?['email']?.toString().toLowerCase() ?? '';
      final driver = booking['drivers'] as Map<String, dynamic>?;
      final driverUser = driver?['users'] as Map<String, dynamic>?;
      final driverName =
          driverUser?['full_name']?.toString().toLowerCase() ?? '';
      final pickup = booking['pickup_location']?.toString().toLowerCase() ?? '';
      final dropoff =
          booking['dropoff_location']?.toString().toLowerCase() ?? '';

      return bookingId.contains(query) ||
          vehicleTitle.contains(query) ||
          renterName.contains(query) ||
          renterEmail.contains(query) ||
          driverName.contains(query) ||
          pickup.contains(query) ||
          dropoff.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.book_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bookings & Trip Operations',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Search, monitor, and manage all trip bookings, driver assignments, payment details, and live GPS tracking.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  height: 1,
                ),
                const SizedBox(height: 16),

                // Controls Row: Search Bar, Status Filter Chips & View Mode Toggle
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _bookingSearchQuery = val),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search by Booking ID, Renter, Vehicle, Plate, Driver, or Destination...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black26
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // View Mode Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Cards View',
                            icon: const Icon(Icons.grid_view_rounded, size: 18),
                            color: _bookingViewMode == 'cards'
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            onPressed: () =>
                                setState(() => _bookingViewMode = 'cards'),
                          ),
                          IconButton(
                            tooltip: 'Table View',
                            icon: const Icon(
                              Icons.table_rows_rounded,
                              size: 18,
                            ),
                            color: _bookingViewMode == 'table'
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            onPressed: () =>
                                setState(() => _bookingViewMode = 'table'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Status Filter Chips
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildBookingFilterChip(
                      'all',
                      'All Bookings',
                      allCount,
                      isDark,
                    ),
                    _buildBookingFilterChip(
                      'pending',
                      'Pending',
                      pendingCount,
                      isDark,
                      color: Colors.orange,
                    ),
                    _buildBookingFilterChip(
                      'confirmed',
                      'Confirmed',
                      confirmedCount,
                      isDark,
                      color: Colors.blue,
                    ),
                    _buildBookingFilterChip(
                      'active',
                      'Active / In-Trip',
                      activeCount,
                      isDark,
                      color: Colors.green,
                    ),
                    _buildBookingFilterChip(
                      'completed',
                      'Completed',
                      completedCount,
                      isDark,
                      color: Colors.teal,
                    ),
                    _buildBookingFilterChip(
                      'cancelled',
                      'Cancelled',
                      cancelledCount,
                      isDark,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Bookings List or Cards View
          if (filteredBookings.isEmpty)
            _buildCard(
              'Bookings List (0)',
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 48,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No bookings match your current search or filter criteria.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              isDark,
            )
          else if (_bookingViewMode == 'cards')
            Column(
              children: filteredBookings
                  .map((b) => _buildDetailedBookingCard(b, isDark))
                  .toList(),
            )
          else
            _buildBookingsMasterTable(filteredBookings, isDark),
        ],
      ),
    );
  }

  Widget _buildBookingFilterChip(
    String key,
    String label,
    int count,
    bool isDark, {
    Color? color,
  }) {
    final isSelected = _bookingStatusFilter == key;
    final chipColor = color ?? AppColors.primary;

    return InkWell(
      onTap: () => setState(() => _bookingStatusFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.2)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? chipColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor
                    : (isDark ? Colors.white10 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedBookingCard(Map<String, dynamic> booking, bool isDark) {
    final bookingId = booking['id']?.toString() ?? 'N/A';
    final refCode = bookingId.length > 8
        ? '#BK-${bookingId.substring(0, 8).toUpperCase()}'
        : '#BK-$bookingId';
    final status = (booking['status'] as String? ?? 'pending').toLowerCase();
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['renter'] as Map<String, dynamic>?;
    final driver = booking['drivers'] as Map<String, dynamic>?;
    final driverUser = driver?['users'] as Map<String, dynamic>?;
    final withDriver = booking['with_driver'] == true;

    final vBrand = vehicle?['brand']?.toString().trim() ?? '';
    final vModel = vehicle?['model']?.toString().trim() ?? '';
    final vCombo = [vBrand, vModel].where((part) => part.isNotEmpty).join(' ');
    final rawVName = vehicle?['vehicle_name']?.toString().trim() ?? '';
    final vehicleTitle = vCombo.isNotEmpty
        ? vCombo
        : (rawVName.isNotEmpty &&
                rawVName.toLowerCase() != 'partner vehicle' &&
                rawVName.toLowerCase() != 'unknown vehicle'
            ? rawVName
            : (vehicle?['plate_number']?.toString().isNotEmpty == true
                ? 'Vehicle (${vehicle!['plate_number']})'
                : 'Partner Vehicle'));
    final plateNumber = vehicle?['plate_number']?.toString().trim() ?? '';
    final renterName =
        renter?['full_name']?.toString().trim() ?? 'Unknown Renter';
    final renterPhone = renter?['phone']?.toString().trim() ?? '';
    final driverName = driverUser?['full_name']?.toString().trim() ?? 'N/A';
    final driverPhone = driverUser?['phone']?.toString().trim() ?? '';

    final startDate = _formatDate(booking['start_date']);
    final endDate = _formatDate(booking['end_date']);
    final pickup =
        booking['pickup_location']?.toString().trim() ?? 'Not specified';
    final dropoff =
        booking['dropoff_location']?.toString().trim() ??
        booking['delivery_address']?.toString().trim() ??
        'Not specified';

    final totalCost =
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0;
    final deposit = (booking['deposit_amount'] as num?)?.toDouble() ?? 0;
    final paymentStatus = (booking['payment_status'] as String? ?? 'pending')
        .toLowerCase();

    final canTrack = _canTrackBooking(booking);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF021F35) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                SelectableText(
                  refCode,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.primary : Colors.blue.shade800,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Copy Booking ID',
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: bookingId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Booking ID copied to clipboard'),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  '• Booked ${_formatDate(booking['created_at'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(status),
              ],
            ),
          ),

          // Main 4-Column Data Grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 900;
                final colWidth = isNarrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 36) / 4;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Column 1: Vehicle & Owner
                    SizedBox(
                      width: colWidth,
                      child: _buildBookingFieldBox(
                        'Vehicle & License',
                        vehicleTitle,
                        isDark,
                        subtitle: plateNumber.isNotEmpty
                            ? 'Plate: $plateNumber'
                            : 'No plate specified',
                        icon: Icons.directions_car_filled_rounded,
                      ),
                    ),

                    // Column 2: Renter & Driver
                    SizedBox(
                      width: colWidth,
                      child: _buildBookingFieldBox(
                        'Renter & Driver',
                        renterName,
                        isDark,
                        subtitle: withDriver
                            ? 'Driver: $driverName ${driverPhone.isNotEmpty ? "($driverPhone)" : ""}'
                            : 'Self-Drive (No Driver)',
                        icon: Icons.person_pin_rounded,
                        highlightColor: withDriver ? Colors.blue : null,
                      ),
                    ),

                    // Column 3: Rental Schedule & Locations
                    SizedBox(
                      width: colWidth,
                      child: _buildBookingFieldBox(
                        'Schedule & Route',
                        '$startDate → $endDate',
                        isDark,
                        subtitle: 'Pickup: $pickup\nDropoff: $dropoff',
                        icon: Icons.route_rounded,
                      ),
                    ),

                    // Column 4: Financial Summary & Payment
                    SizedBox(
                      width: colWidth,
                      child: _buildBookingFieldBox(
                        'Financial Breakdown',
                        'PHP ${totalCost.toStringAsFixed(0)}',
                        isDark,
                        subtitle:
                            'Deposit: PHP ${deposit.toStringAsFixed(0)} • Delivery: ₱75/km\nPayment: ${paymentStatus.toUpperCase()}',
                        icon: Icons.payments_rounded,
                        highlightColor: Colors.green,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Footer Action Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                if (renterPhone.isNotEmpty) ...[
                  Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Renter Contact: $renterPhone',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
                const Spacer(),

                // Actions
                if (canTrack)
                  FilledButton.icon(
                    onPressed: () => _openTrackingForBooking(booking),
                    icon: const Icon(Icons.location_on_rounded, size: 16),
                    label: const Text('Live GPS Track'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
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

  Widget _buildBookingFieldBox(
    String label,
    String value,
    bool isDark, {
    String? subtitle,
    IconData? icon,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              highlightColor?.withValues(alpha: 0.4) ??
              (isDark ? AppColors.borderColor : Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color:
                      highlightColor ??
                      (isDark ? Colors.white54 : Colors.grey.shade600),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _getBookingCommissionBreakdown(
    Map<String, dynamic> booking,
  ) {
    final total =
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final rentalSubtotal =
        (booking['rental_subtotal'] as num?)?.toDouble() ?? total;
    final vehicle = booking['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    final isPartner =
        booking['is_partner_vehicle'] == true ||
        vehicle['is_partner_vehicle'] == true ||
        vehicle['owner_role']?.toString().toLowerCase() == 'partner';

    // 5% platform commission on rental, 95% partner net
    final partnerCommission = isPartner ? rentalSubtotal * 0.05 : 0.0;
    final partnerNet = isPartner
        ? (rentalSubtotal - partnerCommission).clamp(0.0, double.infinity)
        : 0.0;

    final rawCommissionStatus =
        booking['commission_status']?.toString().toLowerCase();
    final settlement = booking['settlement'] as Map<String, dynamic>?;
    final isSettlementReleased =
        settlement?['status']?.toString().toLowerCase() == 'released';

    String statusKey = 'not_applicable';
    String statusLabel = 'PSDC Fleet';
    if (isPartner) {
      if (rawCommissionStatus == 'released' || isSettlementReleased) {
        statusKey = 'released';
        statusLabel = 'Disbursed';
      } else if (rawCommissionStatus == 'processing') {
        statusKey = 'processing';
        statusLabel = 'Processing';
      } else if (rawCommissionStatus == 'settlement_failed') {
        statusKey = 'failed';
        statusLabel = 'Failed';
      } else {
        final bookingStatus =
            (booking['status']?.toString() ?? '').toLowerCase();
        if (bookingStatus == 'completed') {
          statusKey = 'pending_release';
          statusLabel = 'Pending Disbursement';
        } else if (bookingStatus == 'cancelled' ||
            bookingStatus == 'rejected') {
          statusKey = 'cancelled';
          statusLabel = 'Cancelled';
        } else {
          statusKey = 'on_trip';
          statusLabel = 'In Progress';
        }
      }
    }

    final releasedAtRaw =
        settlement?['released_at'] ??
        booking['commission_eligible_at'] ??
        booking['updated_at'];
    DateTime? releasedAt;
    if (releasedAtRaw != null) {
      releasedAt = DateTime.tryParse(releasedAtRaw.toString());
    }

    return {
      'is_partner': isPartner,
      'partner_name': booking['partner_name'] ?? 'Partner',
      'partner_business_name': booking['partner_business_name'],
      'partner_email': booking['partner_email'],
      'partner_phone': booking['partner_phone'],
      'total_amount': total,
      'rental_amount': rentalSubtotal,
      'partner_commission': partnerCommission,
      'partner_net': partnerNet,
      'status_key': statusKey,
      'status_label': statusLabel,
      'released_at': releasedAt,
    };
  }

  Widget _buildCommissionDisbursementBadge(
    Map<String, dynamic> breakdown,
    bool isDark,
  ) {
    final isPartner = breakdown['is_partner'] == true;
    if (!isPartner) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.blueGrey.withValues(alpha: 0.2)
              : Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? Colors.blueGrey.shade700 : Colors.blueGrey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.apartment_rounded,
              size: 13,
              color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700,
            ),
            const SizedBox(width: 5),
            Text(
              'PSDC Fleet (100%)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? Colors.blueGrey.shade300
                    : Colors.blueGrey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    final statusKey = breakdown['status_key'] as String;
    final partnerNet = (breakdown['partner_net'] as num?)?.toDouble() ?? 0.0;
    final commission =
        (breakdown['partner_commission'] as num?)?.toDouble() ?? 0.0;
    final releasedAt = breakdown['released_at'] as DateTime?;

    if (statusKey == 'released') {
      final dateStr = releasedAt != null
          ? DateFormat('MMM d, h:mm a').format(releasedAt)
          : '';
      return Tooltip(
        message:
            'Partner Net: ₱${partnerNet.toStringAsFixed(0)} | Platform Commission (5%): ₱${commission.toStringAsFixed(0)}${dateStr.isNotEmpty ? '\nDisbursed: $dateStr' : ''}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 13,
                color: Color(0xFF10B981),
              ),
              const SizedBox(width: 5),
              Text(
                'Disbursed (₱${partnerNet.toStringAsFixed(0)})',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (statusKey == 'pending_release') {
      return Tooltip(
        message:
            'Trip completed. Ready for payout disbursement (Partner: ₱${partnerNet.toStringAsFixed(0)})',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 13,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 5),
              const Text(
                'Pending Disbursement',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (statusKey == 'on_trip' || statusKey == 'processing') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 13,
              color: Color(0xFF3B82F6),
            ),
            const SizedBox(width: 5),
            Text(
              statusKey == 'processing' ? 'Processing' : 'In Progress',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.withValues(alpha: 0.15)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        breakdown['status_label']?.toString() ?? 'N/A',
        style: TextStyle(
          fontSize: 10,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildBookingsMasterTable(
    List<Map<String, dynamic>> sortedBookings,
    bool isDark,
  ) {
    return _buildCard(
      'Bookings Master Table (${sortedBookings.length})',
      LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                horizontalMargin: 16,
                columnSpacing: 24,
                columns: [
                  DataColumn(
                    label: Text(
                      'Booking ID & Dates',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Vehicle & Fleet',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Renter & Driver',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Trip Status',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Partner Disbursement',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Total Amount',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                rows: sortedBookings.map((booking) {
                  final bookingId = booking['id']?.toString() ?? 'N/A';
                  final refCode = bookingId.length > 8
                      ? '#BK-${bookingId.substring(0, 8).toUpperCase()}'
                      : '#BK-$bookingId';
                  final vehicle = booking['vehicles'] as Map<String, dynamic>?;
                  final user = booking['renter'] as Map<String, dynamic>?;
                  final driver = booking['drivers'] as Map<String, dynamic>?;
                  final driverUser = driver?['users'] as Map<String, dynamic>?;
                  final driverName = driverUser?['full_name']?.toString();
                  final status = booking['status'] as String? ?? 'pending';
                  final canTrack = _canTrackBooking(booking);
                  final breakdown = _getBookingCommissionBreakdown(booking);
                  final total = breakdown['total_amount'] as double;
                  final isPartner = breakdown['is_partner'] == true;
                  final partnerName = breakdown['partner_name'] as String;

                  final startDateRaw =
                      booking['start_date'] ?? booking['start_at'];
                  final endDateRaw = booking['end_date'] ?? booking['end_at'];
                  String dateRangeText = 'Dates not set';
                  if (startDateRaw != null) {
                    final startDt = DateTime.tryParse(startDateRaw.toString());
                    final endDt = endDateRaw != null
                        ? DateTime.tryParse(endDateRaw.toString())
                        : null;
                    if (startDt != null && endDt != null) {
                      dateRangeText =
                          '${DateFormat('MMM d').format(startDt)} - ${DateFormat('MMM d, yyyy').format(endDt)}';
                    } else if (startDt != null) {
                      dateRangeText = DateFormat('MMM d, yyyy').format(startDt);
                    }
                  }

                  return DataRow(
                    cells: [
                      DataCell(
                        InkWell(
                          onTap: () =>
                              _showAdminBookingDetailsModal(booking, isDark),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                refCode,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.primary
                                      : Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateRangeText,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              vehicle != null
                                  ? '${vehicle['brand']} ${vehicle['model']} ${vehicle['plate_number'] != null ? "(${vehicle['plate_number']})" : ""}'
                                  : 'Unknown Vehicle',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isPartner
                                    ? const Color(0xFF0284C7).withValues(
                                        alpha: 0.15,
                                      )
                                    : AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPartner
                                    ? '🤝 Partner: $partnerName'
                                    : '🏢 PSDC Fleet',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isPartner
                                      ? const Color(0xFF0284C7)
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user?['full_name'] ?? 'Unknown Renter',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                            if (driverName != null && driverName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 11,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Driver: $driverName',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(_buildStatusBadge(status)),
                      DataCell(
                        _buildCommissionDisbursementBadge(breakdown, isDark),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'PHP ${total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 13,
                              ),
                            ),
                            if (isPartner) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Net ₱${(breakdown['partner_net'] as double).toStringAsFixed(0)} / Comm ₱${(breakdown['partner_commission'] as double).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              tooltip: 'View Booking & Disbursement Details',
                              color: isDark
                                  ? AppColors.primary
                                  : Colors.blue.shade800,
                              onPressed: () => _showAdminBookingDetailsModal(
                                booking,
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton.icon(
                              onPressed: canTrack
                                  ? () => _openTrackingForBooking(booking)
                                  : null,
                              icon: const Icon(Icons.location_on, size: 14),
                              label: const Text(
                                'Track',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(60, 32),
                                disabledBackgroundColor: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                                disabledForegroundColor: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
      isDark,
    );
  }

  void _showAdminBookingDetailsModal(
    Map<String, dynamic> booking,
    bool isDark,
  ) {
    final bookingId = booking['id']?.toString() ?? 'N/A';
    final refCode = bookingId.length > 8
        ? '#BK-${bookingId.substring(0, 8).toUpperCase()}'
        : '#BK-$bookingId';
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final user = booking['renter'] as Map<String, dynamic>?;
    final driver = booking['drivers'] as Map<String, dynamic>?;
    final driverUser = driver?['users'] as Map<String, dynamic>?;
    final status = booking['status'] as String? ?? 'pending';
    final breakdown = _getBookingCommissionBreakdown(booking);
    final isPartner = breakdown['is_partner'] == true;
    final canTrack = _canTrackBooking(booking);

    final pickup =
        booking['pickup_location']?.toString() ?? 'Garage Pickup / PSDC';
    final dropoff =
        booking['dropoff_location']?.toString() ?? 'Return to Garage';

    final startDateRaw = booking['start_date'] ?? booking['start_at'];
    final endDateRaw = booking['end_date'] ?? booking['end_at'];
    DateTime? startDt = startDateRaw != null
        ? DateTime.tryParse(startDateRaw.toString())
        : null;
    DateTime? endDt = endDateRaw != null
        ? DateTime.tryParse(endDateRaw.toString())
        : null;

    final createdAtRaw = booking['created_at'];
    DateTime? createdDt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw.toString())
        : null;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isReleasing = false;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Details $refCode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (createdDt != null)
                        Text(
                          'Booked on ${DateFormat('MMMM d, yyyy • h:mm a').format(createdDt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Partner Commission & Disbursement Breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isPartner
                            ? (isDark
                                ? const Color(0xFF0284C7).withValues(alpha: 0.1)
                                : const Color(0xFFF0F9FF))
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isPartner
                              ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                              : (isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200),
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
                                    isPartner
                                        ? Icons.handshake_rounded
                                        : Icons.apartment_rounded,
                                    size: 18,
                                    color: isPartner
                                        ? const Color(0xFF0284C7)
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isPartner
                                        ? 'Partner Vehicle & Commission Accounting'
                                        : 'PSDC Fleet Direct Revenue',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              _buildCommissionDisbursementBadge(
                                breakdown,
                                isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isPartner) ...[
                            Text(
                              'Partner: ${breakdown['partner_name']} ${breakdown['partner_business_name'] != null ? "(${breakdown['partner_business_name']})" : ""}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            if (breakdown['partner_email'] != null ||
                                breakdown['partner_phone'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Contact: ${breakdown['partner_email'] ?? ''} ${breakdown['partner_phone'] != null ? "• ${breakdown['partner_phone']}" : ""}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            // 3-box financial stat cards
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.black26
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'GROSS TOTAL',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₱${(breakdown['total_amount'] as double).toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF10B981).withValues(
                                              alpha: 0.1,
                                            )
                                          : const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'PARTNER NET (90%)',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₱${(breakdown['partner_net'] as double).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFFD4AF37).withValues(
                                              alpha: 0.1,
                                            )
                                          : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFD4AF37,
                                        ).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'PLATFORM COMM (10%)',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₱${(breakdown['partner_commission'] as double).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (breakdown['status_key'] ==
                                'pending_release') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: isReleasing
                                      ? null
                                      : () async {
                                          setModalState(
                                            () => isReleasing = true,
                                          );
                                          try {
                                            await TripRatingService()
                                                .reconcileCompletedBooking(
                                                  bookingId,
                                                );
                                            await _loadAllBookings();
                                            if (dialogCtx.mounted) {
                                              Navigator.pop(dialogCtx);
                                            }
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Partner commission disbursed successfully!',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.success,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            setModalState(
                                              () => isReleasing = false,
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor:
                                                      AppColors.error,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.payments_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    isReleasing
                                        ? 'Disbursing...'
                                        : 'Disburse & Settle Commission Now',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            Text(
                              'This vehicle is directly owned & managed by PSDC. 100% of revenue (₱${(breakdown['total_amount'] as double).toStringAsFixed(0)}) is retained as internal company revenue.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Section 2: Vehicle & Trip Information
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.directions_car_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Vehicle Info',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  vehicle != null
                                      ? '${vehicle['brand']} ${vehicle['model']} ${vehicle['year'] ?? ''}'
                                      : 'Unknown Vehicle',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Plate Number: ${vehicle?['plate_number'] ?? 'No Plate'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Schedule & Route',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start: ${startDt != null ? DateFormat('MMM d, yyyy • h:mm a').format(startDt) : 'Not set'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'End: ${endDt != null ? DateFormat('MMM d, yyyy • h:mm a').format(endDt) : 'Not set'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pickup: $pickup\nDestination: $dropoff',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 3: Renter & Driver Info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Renter Details',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user?['full_name'] ?? 'Unknown Renter',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Email: ${user?['email'] ?? 'No email'}\nPhone: ${user?['phone'] ?? 'No phone'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.badge_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Driver Details',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  driverUser?['full_name'] ??
                                      'Self-Drive (No Driver)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  driverUser != null
                                      ? 'Email: ${driverUser['email'] ?? 'N/A'}\nPhone: ${driverUser['phone'] ?? 'N/A'}'
                                      : 'Trip is self-driven by renter.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (canTrack)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _openTrackingForBooking(booking);
                  },
                  icon: const Icon(Icons.location_on, size: 16),
                  label: const Text('Live GPS Track'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  final Map<String, List<MobilisMapPoint>> _trackingRoadRouteCache = {};

  List<MobilisMapPoint> _getTrackingRoutePoints(
    MobilisMapPoint? carPoint,
    MobilisMapPoint? destPoint,
  ) {
    if (carPoint == null) return const [];
    if (destPoint == null) return [carPoint];

    final cacheKey =
        '${carPoint.latitude.toStringAsFixed(3)},${carPoint.longitude.toStringAsFixed(3)}->${destPoint.latitude.toStringAsFixed(3)},${destPoint.longitude.toStringAsFixed(3)}';

    if (_trackingRoadRouteCache.containsKey(cacheKey)) {
      return _trackingRoadRouteCache[cacheKey]!;
    }

    // Trigger async fetch in background
    _fetchRoadPathway(cacheKey, carPoint, destPoint);

    // Fallback straight line while road pathway is loading
    return [carPoint, destPoint];
  }

  Future<void> _fetchRoadPathway(
    String cacheKey,
    MobilisMapPoint fromPoint,
    MobilisMapPoint toPoint,
  ) async {
    if (_trackingRoadRouteCache.containsKey(cacheKey)) return;
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${fromPoint.longitude},${fromPoint.latitude};'
        '${toPoint.longitude},${toPoint.latitude}'
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
            _trackingRoadRouteCache[cacheKey] = roadPoints;
            if (mounted) setState(() {});
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Unable to fetch OSRM road route points: $e');
    }
    _trackingRoadRouteCache[cacheKey] = [fromPoint, toPoint];
  }

  MobilisMapPoint? _resolveTrackingLocationPoint(
    dynamic latVal,
    dynamic lngVal,
    String address,
  ) {
    final normalized = address.toLowerCase().trim();

    if (normalized.contains('bayambang')) {
      return const MobilisMapPoint(latitude: 15.8127, longitude: 120.4557);
    }
    if (normalized.contains('san carlos')) {
      return const MobilisMapPoint(latitude: 15.9281, longitude: 120.3488);
    }
    if (normalized.contains('dagupan')) {
      return const MobilisMapPoint(latitude: 16.0433, longitude: 120.3333);
    }
    if (normalized.contains('malasiqui')) {
      return const MobilisMapPoint(latitude: 15.9197, longitude: 120.4144);
    }
    if (normalized.contains('lingayen')) {
      return const MobilisMapPoint(latitude: 16.0218, longitude: 120.2307);
    }
    if (normalized.contains('rosales')) {
      return const MobilisMapPoint(latitude: 15.8925, longitude: 120.6328);
    }
    if (normalized.contains('villasis')) {
      return const MobilisMapPoint(latitude: 15.9011, longitude: 120.5878);
    }
    if (normalized.contains('calasiao')) {
      return const MobilisMapPoint(latitude: 16.0125, longitude: 120.3608);
    }
    if (normalized.contains('binmaley')) {
      return const MobilisMapPoint(latitude: 16.0306, longitude: 120.2689);
    }
    if (normalized.contains('santa barbara')) {
      return const MobilisMapPoint(latitude: 15.9981, longitude: 120.4042);
    }
    if (normalized.contains('bolinao')) {
      return const MobilisMapPoint(latitude: 16.3883, longitude: 119.8949);
    }
    if (normalized.contains('alaminos')) {
      return const MobilisMapPoint(latitude: 16.1558, longitude: 119.9819);
    }
    if (normalized.contains('sison')) {
      return const MobilisMapPoint(latitude: 16.1733, longitude: 120.5089);
    }
    if (normalized.contains('binalonan')) {
      return const MobilisMapPoint(latitude: 16.0489, longitude: 120.5947);
    }
    if (normalized.contains('urdaneta') ||
        normalized.contains('psdc garage') ||
        normalized.contains('xgfw+jq')) {
      return const MobilisMapPoint(latitude: 15.9758, longitude: 120.5719);
    }

    final lat = latVal is num
        ? latVal.toDouble()
        : double.tryParse(latVal?.toString() ?? '');
    final lng = lngVal is num
        ? lngVal.toDouble()
        : double.tryParse(lngVal?.toString() ?? '');

    if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
      return MobilisMapPoint(latitude: lat, longitude: lng);
    }

    return null;
  }

  Map<String, dynamic> _getVehicleMotionInfo(Map<String, dynamic> location) {
    final speedMps = (location['speed_mps'] as num?)?.toDouble() ?? 0.0;
    final speedKph = (speedMps * 3.6).round();
    final recordedAtStr = location['recorded_at']?.toString();
    DateTime? recordedAt;
    if (recordedAtStr != null && recordedAtStr.isNotEmpty) {
      recordedAt = DateTime.tryParse(recordedAtStr)?.toUtc();
    }
    final now = DateTime.now().toUtc();
    final isStale =
        recordedAt == null || now.difference(recordedAt).inMinutes >= 5;
    final isMoving = speedKph >= 3;

    if (isMoving) {
      return {
        'status': 'moving',
        'label': 'MOVING • $speedKph km/h',
        'short_label': '$speedKph km/h',
        'color': const Color(0xFF00E676),
        'icon': Icons.speed_rounded,
        'speedKph': speedKph,
        'isMoving': true,
        'isParked': false,
        'isStopped': false,
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
        'label': 'STOPPED • IDLING',
        'short_label': 'STOPPED',
        'color': const Color(0xFFFF9100),
        'icon': Icons.pause_circle_filled_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': false,
        'isStopped': true,
      };
    }
  }

  Widget _buildMovementStatusChip({
    required Map<String, dynamic> location,
    required bool isDark,
    bool isCompact = false,
  }) {
    final motion = _getVehicleMotionInfo(location);
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

  Widget _buildTrackingContent(bool isDark) {
    final visibleLocations = _visibleTrackingLocations();
    final isFocused = _focusedTrackingBookingId != null &&
        _focusedTrackingBookingId!.isNotEmpty;

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
        pickupPoint = _resolveTrackingLocationPoint(
          fBooking?['pickup_latitude'],
          fBooking?['pickup_longitude'],
          fBooking?['pickup_location']?.toString() ?? '',
        );
        destPoint = _resolveTrackingLocationPoint(
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
      final fBooking = focusedLocation['bookings'] as Map<String, dynamic>?;
      final fVehicle = (fBooking?['vehicles'] ?? focusedLocation['vehicle'])
          as Map<String, dynamic>?;
      final vehicleName = [
        fVehicle?['brand'],
        fVehicle?['model'],
        fVehicle?['plate_number'] == null
            ? null
            : '(${fVehicle?['plate_number']})',
      ].where((part) => part != null && part.toString().isNotEmpty).join(' ');

      final carLat = (focusedLocation['latitude'] as num?)?.toDouble();
      final carLng = (focusedLocation['longitude'] as num?)?.toDouble();
      final motion = _getVehicleMotionInfo(focusedLocation);
      final motionColor = motion['color'] as Color;

      if (focusedHasActiveBooking && pickupPoint != null) {
        mapMarkers.add(
          MobilisMapMarker(
            latitude: pickupPoint.latitude,
            longitude: pickupPoint.longitude,
            icon: Icons.trip_origin_rounded,
            color: Colors.greenAccent.shade700,
            size: 36,
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
            size: 46,
            tooltip: vehicleName.isNotEmpty
                ? '$vehicleName • ${motion['label']}'
                : 'Tracked Vehicle • ${motion['label']}',
            label: vehicleName.isNotEmpty
                ? '$vehicleName (${motion['short_label']})'
                : motion['label'],
          ),
        );

        // Fetch real road routing pathway only when there is an active destination
        if (focusedHasActiveBooking && destPoint != null) {
          routePoints = _getTrackingRoutePoints(carPoint, destPoint);
        }
      }

      if (focusedHasActiveBooking && destPoint != null) {
        mapMarkers.add(
          MobilisMapMarker(
            latitude: destPoint.latitude,
            longitude: destPoint.longitude,
            icon: Icons.flag_rounded,
            color: Colors.redAccent,
            size: 44,
            tooltip: 'Declared Destination',
          ),
        );
      }
    } else {
      // Show all car markers with hover tooltip and name label
      for (final loc in visibleLocations) {
        final lat = (loc['latitude'] as num?)?.toDouble();
        final lng = (loc['longitude'] as num?)?.toDouble();
        final booking = loc['bookings'] as Map<String, dynamic>?;
        final vehicle = (booking?['vehicles'] ?? loc['vehicle'])
            as Map<String, dynamic>?;
        final vehicleName = [
          vehicle?['brand'],
          vehicle?['model'],
          vehicle?['plate_number'] == null
              ? null
              : '(${vehicle?['plate_number']})',
        ].where((part) => part != null && part.toString().isNotEmpty).join(' ');

        final locId =
            booking?['id']?.toString() ?? loc['id']?.toString() ?? '';
        final motion = _getVehicleMotionInfo(loc);
        final motionColor = motion['color'] as Color;

        if (lat != null && lng != null) {
          mapMarkers.add(
            MobilisMapMarker(
              latitude: lat,
              longitude: lng,
              icon: Icons.directions_car_filled_rounded,
              color: motionColor,
              size: 42,
              tooltip: vehicleName.isNotEmpty
                  ? '$vehicleName • ${motion['label']}'
                  : 'Tracked Vehicle • ${motion['label']}',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            isFocused
                ? 'Live Tracking (Focused Vehicle / Trip)'
                : 'Live Tracking (${visibleLocations.length} Vehicles)',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isFocused) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _focusedTrackingBookingId = null);
                        },
                        icon: const Icon(Icons.view_carousel_rounded),
                        label: const Text('Show All Vehicles'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.grey[800] : Colors.grey[200],
                          foregroundColor:
                              isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        isFocused
                            ? (focusedHasActiveBooking
                                ? '🎯 Focused on trip with declared destination route. Click "Show All Vehicles" to reset.'
                                : '🎯 Focused on available vehicle live GPS position. Click "Show All Vehicles" to reset.')
                            : '💡 Hover over any car icon to view its name, or click any card below to focus on its position.',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isFocused &&
                    focusedLocation != null &&
                    focusedHasActiveBooking) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Destination Compliance & Route Monitor',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Green Pin: Pickup | 🚕 Yellow Pin: Live Car | 🚩 Red Flag: Declared Destination',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (remainingDistanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: remainingDistanceKm <= 5.0
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : (remainingDistanceKm > 60.0
                                      ? Colors.orange.withValues(alpha: 0.2)
                                      : AppColors.primary
                                          .withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: remainingDistanceKm <= 5.0
                                    ? Colors.green
                                    : (remainingDistanceKm > 60.0
                                        ? Colors.orange
                                        : AppColors.primary),
                              ),
                            ),
                            child: Text(
                              '${remainingDistanceKm.toStringAsFixed(1)} km to destination',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: remainingDistanceKm <= 5.0
                                    ? Colors.green
                                    : (remainingDistanceKm > 60.0
                                        ? Colors.orange
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 400,
                    width: double.infinity,
                    color: isDark ? AppColors.darkBg : Colors.grey.shade100,
                    child: mapMarkers.isEmpty
                        ? Center(
                            child: Text(
                              _focusedTrackingBookingId == null
                                  ? 'No active tracking locations yet'
                                  : 'No live location yet for this vehicle',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                          )
                        : MobilisLeafletMap(
                            key: ValueKey(
                              '${_focusedTrackingBookingId ?? "all"}_' +
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
                                : (mapMarkers.length > 1 ? 10 : 14),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (visibleLocations.isEmpty)
                  Text(
                    'No tracked vehicles or active trips found.',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  )
                else
                  ...visibleLocations.map(
                    (location) => _buildTrackingRow(location, isDark),
                  ),
              ],
            ),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingRow(Map<String, dynamic> location, bool isDark) {
    final booking = location['bookings'] as Map<String, dynamic>?;
    final bStatus = (booking?['status'] ?? '').toString().toLowerCase();
    final hasActiveBooking = location['has_active_booking'] == true &&
        booking != null &&
        {'ongoing', 'active', 'in_progress', 'picked_up'}.contains(bStatus) &&
        booking['returned_at'] == null &&
        booking['completed_at'] == null;
    final vehicle = (booking?['vehicles'] ?? location['vehicle'])
        as Map<String, dynamic>?;
    final tracker = location['tracker'] as Map<String, dynamic>?;
    final driver = booking?['drivers'] as Map<String, dynamic>?;
    final driverUser = driver?['users'] as Map<String, dynamic>?;
    final renter = booking?['renter'] as Map<String, dynamic>?;
    final rowId = booking?['id']?.toString() ??
        location['id']?.toString() ??
        'vehicle_${location['vehicle_id']}';
    final pickup = booking?['pickup_location']?.toString().trim() ?? '';
    final dropoff = booking?['dropoff_location']?.toString().trim() ?? '';
    final vehicleName = [
      vehicle?['brand'],
      vehicle?['model'],
      vehicle?['plate_number'] == null
          ? null
          : '(${vehicle?['plate_number']})',
    ].where((part) => part != null && part.toString().isNotEmpty).join(' ');
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    final speedKph = (((location['speed_mps'] as num?) ?? 0) * 3.6).round();

    final isFocused = _focusedTrackingBookingId == rowId;

    // Resolve destination coordinates to compute live distance (for active trips only)
    MobilisMapPoint? destPoint;
    double? distanceToDestinationKm;
    if (hasActiveBooking) {
      destPoint = _resolveTrackingLocationPoint(
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
            ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark ? AppColors.darkBg : Colors.grey.shade50),
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
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? AppColors.primary
                            : (hasActiveBooking
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Colors.teal.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        color: isFocused
                            ? Colors.black
                            : (hasActiveBooking
                                ? AppColors.primary
                                : Colors.teal),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                vehicleName.isEmpty
                                    ? (hasActiveBooking
                                        ? 'Tracked Trip'
                                        : 'Tracked Vehicle')
                                    : vehicleName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: hasActiveBooking
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: hasActiveBooking
                                        ? AppColors.primary.withValues(alpha: 0.5)
                                        : Colors.green.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  hasActiveBooking
                                      ? 'ON TRIP'
                                      : 'AVAILABLE • IDLE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                    color: hasActiveBooking
                                        ? AppColors.primary
                                        : Colors.green,
                                  ),
                                ),
                              ),
                              if (booking?['is_partner_vehicle'] == true ||
                                  booking?['partner_id'] != null ||
                                  (vehicle?['owner']?['role']?.toString().toLowerCase() == 'partner') ||
                                  vehicle?['is_partner_vehicle'] == true ||
                                  vehicle?['partner_id'] != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.purple.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    'PARTNER CAR',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                      color: Colors.purpleAccent,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              _buildMovementStatusChip(
                                location: location,
                                isDark: isDark,
                                isCompact: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasActiveBooking
                                ? 'Booking: ${booking?['id'] ?? 'N/A'} | Driver: ${driverUser?['full_name'] ?? 'N/A (Self-Drive)'} | Renter: ${renter?['full_name'] ?? 'N/A'} • Speed: $speedKph km/h'
                                : 'Tracker ID: ${tracker?['device_identifier'] ?? location['device_identifier'] ?? 'GPS Connected'} • Speed: $speedKph km/h',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _focusedTrackingBookingId = isFocused ? null : rowId;
                        });
                      },
                      icon: Icon(
                        isFocused
                            ? Icons.close_rounded
                            : Icons.center_focus_strong_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isFocused
                            ? 'Unfocus'
                            : (hasActiveBooking
                                ? 'Focus Trip'
                                : 'Focus Vehicle'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isFocused
                            ? (isDark ? Colors.white : Colors.black87)
                            : AppColors.primary,
                        side: BorderSide(
                          color: isFocused
                              ? (isDark ? Colors.white38 : Colors.grey.shade400)
                              : AppColors.primary,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasActiveBooking) ...[
                  const SizedBox(height: 12),
                  // Declared Destination & Route Compliance Box (Only for active trips)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.trip_origin_rounded,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pickup: ${pickup.isEmpty ? 'N/A' : pickup}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.flag_rounded,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Declared Destination: ${dropoff.isEmpty ? 'N/A' : dropoff}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (distanceToDestinationKm != null) ...[
                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            color:
                                isDark ? Colors.white10 : Colors.grey.shade200,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    distanceToDestinationKm <= 5.0
                                        ? Icons.check_circle_rounded
                                        : (distanceToDestinationKm > 75.0
                                            ? Icons.warning_amber_rounded
                                            : Icons.navigation_rounded),
                                    size: 14,
                                    color: distanceToDestinationKm <= 5.0
                                        ? Colors.green
                                        : (distanceToDestinationKm > 75.0
                                            ? Colors.orange
                                            : AppColors.primary),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    distanceToDestinationKm <= 5.0
                                        ? 'Within Destination Area (< 5 km)'
                                        : (distanceToDestinationKm > 75.0
                                            ? 'Destination Route Warning (> 75 km)'
                                            : 'En Route to Destination'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: distanceToDestinationKm <= 5.0
                                          ? Colors.green
                                          : (distanceToDestinationKm > 75.0
                                              ? Colors.orange
                                              : (isDark
                                                  ? Colors.white70
                                                  : Colors.black87)),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${distanceToDestinationKm.toStringAsFixed(1)} km away',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Coordinates: ${lat?.toStringAsFixed(5) ?? 'N/A'}, ${lng?.toStringAsFixed(5) ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Last Sync: ${location['recorded_at'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (hasActiveBooking && booking?['id'] != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        TripRouteHistoryDialog.show(
                          context: context,
                          bookingId: booking!['id'].toString(),
                          vehicleName: vehicleName,
                          plateNumber: vehicle?['plate_number']?.toString(),
                          renterName: renter?['full_name']?.toString(),
                        );
                      },
                      icon: const Icon(Icons.route_rounded, size: 16),
                      label: const Text(
                        'Audit Traveled Route & Destination Deviation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.7),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationsContent(bool isDark) {
    // 1. Calculate role stats for badges
    int allCount = _verificationRecords.length;
    int renterCount = 0;
    int driverCount = 0;
    int partnerCount = 0;

    for (final r in _verificationRecords) {
      final user = r['users'] as Map<String, dynamic>?;
      final role = (user?['role']?.toString() ?? r['role']?.toString() ?? '')
          .toLowerCase()
          .trim();
      if (role == 'partner') {
        partnerCount++;
      } else if (role == 'driver') {
        driverCount++;
      } else {
        renterCount++;
      }
    }

    // 2. Filter records based on search query and selected role sub-tab
    final filteredRecords = _verificationRecords.where((r) {
      if (_verificationRoleFilter != 'all') {
        final user = r['users'] as Map<String, dynamic>?;
        final role = (user?['role']?.toString() ?? r['role']?.toString() ?? '')
            .toLowerCase()
            .trim();

        if (_verificationRoleFilter == 'renter') {
          if (role != 'renter' && role.isNotEmpty && role != 'customer') {
            return false;
          }
        } else if (_verificationRoleFilter == 'driver') {
          if (role != 'driver') return false;
        } else if (_verificationRoleFilter == 'partner') {
          if (role != 'partner') return false;
        }
      }

      if (_verificationSearchQuery.trim().isNotEmpty) {
        final q = _verificationSearchQuery.toLowerCase().trim();
        final user = r['users'] as Map<String, dynamic>?;
        final name =
            (user?['full_name']?.toString() ?? r['full_name']?.toString() ?? '')
                .toLowerCase();
        final email =
            (user?['email']?.toString() ?? r['email']?.toString() ?? '')
                .toLowerCase();
        final role = (user?['role']?.toString() ?? r['role']?.toString() ?? '')
            .toLowerCase();
        final idType = (r['id_type']?.toString() ?? '').toLowerCase();
        final status = (r['verification_status']?.toString() ?? '')
            .toLowerCase();

        return name.contains(q) ||
            email.contains(q) ||
            role.contains(q) ||
            idType.contains(q) ||
            status.contains(q);
      }
      return true;
    }).toList();

    // 3. Separate filtered records into pending, approved, rejected
    final pendingVerifications = filteredRecords
        .where(
          (r) =>
              (r['verification_status']?.toString().toLowerCase() ?? '') ==
              'pending',
        )
        .toList();
    final approvedVerifications = filteredRecords
        .where(
          (r) =>
              (r['verification_status']?.toString().toLowerCase() ?? '') ==
                  'verified' ||
              (r['verification_status']?.toString().toLowerCase() ?? '') ==
                  'approved',
        )
        .toList();
    final rejectedVerifications = filteredRecords
        .where(
          (r) =>
              (r['verification_status']?.toString().toLowerCase() ?? '') ==
              'rejected',
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Search & Role Filter Sub-Tabs
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fact_check_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Identity & Document Verifications',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Filter and review identity verification submissions by user role (Renters, Drivers, Partners).',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  height: 1,
                ),
                const SizedBox(height: 16),

                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _verificationSearchQuery = val),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search verifications by Name, Email, Role, ID Type, or Status...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black26
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Role Filter Sub-Tabs Chips (Matching Image 2)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildVerificationRoleTab(
                      'all',
                      'All Users',
                      allCount,
                      isDark,
                      icon: Icons.fact_check_rounded,
                    ),
                    _buildVerificationRoleTab(
                      'renter',
                      'Renters',
                      renterCount,
                      isDark,
                      icon: Icons.directions_car_rounded,
                      color: AppColors.primary,
                    ),
                    _buildVerificationRoleTab(
                      'driver',
                      'Drivers',
                      driverCount,
                      isDark,
                      icon: Icons.badge_rounded,
                      color: AppColors.primary,
                    ),
                    _buildVerificationRoleTab(
                      'partner',
                      'Partners',
                      partnerCount,
                      isDark,
                      icon: Icons.handshake_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Verification Sections
          _buildVerificationSection(
            title: 'Pending Approvals',
            records: pendingVerifications,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildVerificationSection(
            title: 'Approved Verifications',
            records: approvedVerifications,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildVerificationSection(
            title: 'Rejected Verifications',
            records: rejectedVerifications,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationRoleTab(
    String key,
    String label,
    int count,
    bool isDark, {
    IconData? icon,
    Color? color,
  }) {
    final isSelected = _verificationRoleFilter == key;
    final activeColor = color ?? AppColors.primary;
    final displayIcon = icon ?? Icons.verified_user_rounded;

    return InkWell(
      onTap: () => setState(() => _verificationRoleFilter = key),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              displayIcon,
              size: 17,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white10 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationsContent(bool isDark) {
    final records = _pendingPartnerVehicleApplications;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'Partner Vehicle Applications (${records.length})',
        records.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No pending vehicle applications.',
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              )
            : Column(
                children: records.map((record) {
                  final partner = record['partner'] as Map<String, dynamic>?;
                  final title =
                      '${record['brand'] ?? 'Unknown'} ${record['model'] ?? ''}'
                          .trim();
                  final pricePerDay =
                      (record['price_per_day'] as num?)?.toDouble() ?? 0;
                  final pricePerHour =
                      (record['price_per_hour'] as num?)?.toDouble() ?? 0;
                  final submittedAt = record['created_at']?.toString() ?? '';
                  final orUrl = record['or_document_url']?.toString() ?? '';
                  final crUrl = record['cr_document_url']?.toString() ?? '';
                  final vehiclePhotoUrl =
                      record['vehicle_photo_url']?.toString() ?? '';
                  final subtitle = [
                    if (record['year'] != null) record['year'].toString(),
                    if ((record['plate_number'] ?? '').toString().isNotEmpty)
                      'Plate: ${record['plate_number']}',
                  ].join('  •  ');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Partner: ${partner?['full_name'] ?? 'Unknown'} (${partner?['email'] ?? ''})',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 900;
                            final cardWidth = isNarrow
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 24) / 3;

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildDetailCard(
                                    'Price Per Day',
                                    'PHP ${pricePerDay.toStringAsFixed(0)}',
                                    isDark,
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildDetailCard(
                                    'Price Per Hour',
                                    'PHP ${pricePerHour.toStringAsFixed(0)}',
                                    isDark,
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildDetailCard(
                                    'Submitted',
                                    _formatDate(submittedAt),
                                    isDark,
                                  ),
                                ),
                                if (orUrl.isNotEmpty)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildDocumentPreview(
                                      title: 'OR Document',
                                      url: orUrl,
                                      isDark: isDark,
                                      context: context,
                                    ),
                                  ),
                                if (crUrl.isNotEmpty)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildDocumentPreview(
                                      title: 'CR Document',
                                      url: crUrl,
                                      isDark: isDark,
                                      context: context,
                                    ),
                                  ),
                                if (vehiclePhotoUrl.isNotEmpty)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildDocumentPreview(
                                      title: 'Vehicle Photo',
                                      url: vehiclePhotoUrl,
                                      isDark: isDark,
                                      context: context,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () =>
                                  _approvePartnerVehicleApplication(record),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Approve'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _rejectPartnerVehicleApplication(record),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
        isDark,
      ),
    );
  }

  Widget _buildApplicationsContentEnhanced(bool isDark) {
    var vehicleRecords = _pendingPartnerVehicleApplications;
    var driverRecords = _verificationRecords.where((r) {
      final user = r['users'] as Map<String, dynamic>?;
      final role = (user?['role']?.toString() ?? r['role']?.toString() ?? '')
          .toLowerCase()
          .trim();
      return role == 'driver';
    }).toList();

    if (_applicationSearchQuery.trim().isNotEmpty) {
      final q = _applicationSearchQuery.toLowerCase().trim();
      vehicleRecords = vehicleRecords.where((v) {
        final brand = (v['brand']?.toString() ?? '').toLowerCase();
        final model = (v['model']?.toString() ?? '').toLowerCase();
        final plate = (v['plate_number']?.toString() ?? '').toLowerCase();
        final partner =
            (v['partner_name']?.toString() ??
                    v['partner_email']?.toString() ??
                    '')
                .toLowerCase();
        return brand.contains(q) ||
            model.contains(q) ||
            plate.contains(q) ||
            partner.contains(q);
      }).toList();

      driverRecords = driverRecords.where((d) {
        final user = d['users'] as Map<String, dynamic>?;
        final name =
            (user?['full_name']?.toString() ?? d['full_name']?.toString() ?? '')
                .toLowerCase();
        final email =
            (user?['email']?.toString() ?? d['email']?.toString() ?? '')
                .toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    final showVehicles =
        _applicationTypeFilter == 'all' || _applicationTypeFilter == 'vehicle';
    final showDrivers =
        _applicationTypeFilter == 'all' || _applicationTypeFilter == 'driver';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Search & Sub-Tabs
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle & Driver Applications',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Review and manage incoming Partner vehicle listings and Driver onboarding applications.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  height: 1,
                ),
                const SizedBox(height: 16),

                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _applicationSearchQuery = val),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search applications by Partner, Brand, Model, Plate, Year, or Driver Name...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black26
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Application Sub-Tab Chips (Matching Image 2)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildApplicationTypeTab(
                      'all',
                      'All Applications',
                      vehicleRecords.length + driverRecords.length,
                      isDark,
                      icon: Icons.assignment_rounded,
                    ),
                    _buildApplicationTypeTab(
                      'vehicle',
                      'Partner Vehicle Listings',
                      vehicleRecords.length,
                      isDark,
                      icon: Icons.directions_car_rounded,
                      color: AppColors.primary,
                    ),
                    _buildApplicationTypeTab(
                      'driver',
                      'Driver Onboarding',
                      driverRecords.length,
                      isDark,
                      icon: Icons.badge_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Partner Vehicle Applications Section
          if (showVehicles) ...[
            _buildPartnerVehicleApplicationsSection(vehicleRecords, isDark),
            if (showDrivers && driverRecords.isNotEmpty)
              const SizedBox(height: 24),
          ],

          // Driver Applications Section
          if (showDrivers) ...[
            _buildDriverApplicationsSection(driverRecords, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildApplicationTypeTab(
    String key,
    String label,
    int count,
    bool isDark, {
    IconData? icon,
    Color? color,
  }) {
    final isSelected = _applicationTypeFilter == key;
    final activeColor = color ?? AppColors.primary;
    final displayIcon = icon ?? Icons.assignment_rounded;

    return InkWell(
      onTap: () => setState(() => _applicationTypeFilter = key),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              displayIcon,
              size: 17,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white10 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverApplicationsSection(
    List<Map<String, dynamic>> driverRecords,
    bool isDark,
  ) {
    return _buildCard(
      'Driver Onboarding Applications (${driverRecords.length})',
      driverRecords.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No pending driver applications.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          : Column(
              children: driverRecords
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildVerificationCard(record, isDark),
                    ),
                  )
                  .toList(),
            ),
      isDark,
    );
  }

  Widget _buildPartnerVehicleApplicationsSection(
    List<Map<String, dynamic>> records,
    bool isDark,
  ) {
    return _buildCard(
      'Partner Vehicle Applications (${records.length})',
      records.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No pending vehicle applications.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          : Column(
              children: records.map((record) {
                final partner = record['partner'] as Map<String, dynamic>?;
                final title =
                    '${record['brand'] ?? 'Unknown'} ${record['model'] ?? ''}'
                        .trim();
                final subtitle = [
                  if (record['year'] != null) record['year'].toString(),
                  if ((record['plate_number'] ?? '').toString().isNotEmpty)
                    'Plate: ${record['plate_number']}',
                ].join('  •  ');
                final photoUrls = List<String>.from(
                  (record['photo_urls'] as List?) ?? const <String>[],
                );
                final detailPairs = <MapEntry<String, String>>[
                  MapEntry(
                    'Price Per Day',
                    'PHP ${((record['price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                  ),
                  MapEntry(
                    'Price Per Hour',
                    'PHP ${((record['price_per_hour'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                  ),
                  MapEntry('Seats', record['seats']?.toString() ?? 'N/A'),
                  MapEntry(
                    'Fuel Type',
                    record['fuel_type']?.toString() ?? 'N/A',
                  ),
                  MapEntry(
                    'Transmission',
                    record['transmission']?.toString() ?? 'N/A',
                  ),
                  MapEntry(
                    'Driver Setup',
                    record['owner_is_driver'] == true
                        ? 'Owner will drive'
                        : 'Vehicle only',
                  ),
                  MapEntry(
                    'Submitted',
                    _formatDate(record['created_at']?.toString() ?? ''),
                  ),
                  MapEntry(
                    'Application Status',
                    record['application_status']?.toString() ?? 'pending',
                  ),
                ];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderColor
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Partner: ${partner?['full_name'] ?? 'Unknown'} (${partner?['email'] ?? ''})',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800,
                        ),
                      ),
                      if (photoUrls.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 150,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photoUrls.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) => InkWell(
                              onTap: () => _showImageLightbox(
                                context,
                                'Vehicle Photo ${index + 1}',
                                photoUrls[index],
                                isDark,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 220,
                                  color: isDark
                                      ? AppColors.darkBg
                                      : Colors.grey.shade100,
                                  child: OptimizedNetworkImage(
                                    imageUrl: photoUrls[index],
                                    fit: BoxFit.cover,
                                    errorWidget: const Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 900;
                          final cardWidth = isNarrow
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 24) / 3;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ...detailPairs.map(
                                (detail) => SizedBox(
                                  width: cardWidth,
                                  child: _buildDetailCard(
                                    detail.key,
                                    detail.value,
                                    isDark,
                                  ),
                                ),
                              ),
                              if ((record['or_document_url'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildDocumentPreview(
                                    title: 'OR Document',
                                    url:
                                        record['or_document_url']?.toString() ??
                                        '',
                                    isDark: isDark,
                                    context: context,
                                  ),
                                ),
                              if ((record['cr_document_url'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildDocumentPreview(
                                    title: 'CR Document',
                                    url:
                                        record['cr_document_url']?.toString() ??
                                        '',
                                    isDark: isDark,
                                    context: context,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                _approvePartnerVehicleApplication(record),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _rejectPartnerVehicleApplication(record),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
      isDark,
    );
  }

  Widget _buildVerificationSection({
    required String title,
    required List<Map<String, dynamic>> records,
    required bool isDark,
  }) {
    return _buildCard(
      '$title (${records.length})',
      records.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No ${title.toLowerCase()}.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          : Column(
              children: records
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildVerificationCard(record, isDark),
                    ),
                  )
                  .toList(),
            ),
      isDark,
    );
  }

  Widget _buildVerificationCard(Map<String, dynamic> record, bool isDark) {
    final user = record['users'] as Map<String, dynamic>?;
    final role =
        (user?['role']?.toString() ?? record['role']?.toString() ?? 'renter')
            .trim()
            .toLowerCase();
    final submittedName = (record['full_name'] as String?)?.trim();
    final profileName = (user?['full_name'] as String?)?.trim();
    final displayName = submittedName?.isNotEmpty == true
        ? submittedName!
        : (profileName?.isNotEmpty == true ? profileName! : 'Unknown User');

    final userEmail = user?['email']?.toString().trim() ?? '';
    final userPhone = (record['phone'] as String?)?.trim().isNotEmpty == true
        ? record['phone'].toString().trim()
        : (user?['phone']?.toString().trim() ?? '');
    final userLocation =
        (record['location'] as String?)?.trim().isNotEmpty == true
        ? record['location'].toString().trim()
        : '';
    final avatarUrl = user?['avatar_url']?.toString().trim();
    final joinedAt =
        user?['created_at']?.toString() ?? record['created_at']?.toString();

    final idParts = (record['id_document_url'] as String? ?? '').split('|');
    final legacyIdUrls = idParts
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.trim())
        .toList();
    final idFrontUrl =
        record['id_front_url']?.toString().trim().isNotEmpty == true
        ? record['id_front_url'].toString().trim()
        : legacyIdUrls.isNotEmpty
        ? legacyIdUrls.first
        : '';
    final idBackUrl =
        record['id_back_url']?.toString().trim().isNotEmpty == true
        ? record['id_back_url'].toString().trim()
        : legacyIdUrls.length > 1
        ? legacyIdUrls[1]
        : '';
    final faceSelfieUrl = record['face_selfie_url']?.toString().trim() ?? '';
    final selfieWithIdUrl =
        record['selfie_with_id_url']?.toString().trim() ?? '';
    final driverSignatureUrl =
        record['driver_signature_url']?.toString().trim() ?? '';
    final driverNbiUrl = record['driver_nbi_url']?.toString().trim() ?? '';
    final driverYearsExperience =
        record['driver_years_experience']?.toString().trim() ?? '';
    final driverPreviousCompanies =
        record['driver_previous_companies']?.toString().trim() ?? '';
    final driverLicenseExpiry =
        record['driver_license_expiry']?.toString().trim() ?? '';
    final rejectionReason = record['rejection_reason']?.toString().trim() ?? '';

    final status = (record['verification_status'] as String? ?? 'pending')
        .toLowerCase();

    Color statusBadgeColor;
    IconData statusIcon;
    switch (status) {
      case 'verified':
      case 'approved':
        statusBadgeColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusBadgeColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusBadgeColor = Colors.orange;
        statusIcon = Icons.hourglass_top_rounded;
    }

    Color roleBg = Colors.purple.withValues(alpha: 0.15);
    Color roleText = Colors.purple;
    IconData roleIcon = Icons.directions_car_rounded;
    String roleTag = 'RENTER';

    if (role == 'driver') {
      roleTag = 'DRIVER';
      roleBg = Colors.blue.withValues(alpha: 0.15);
      roleText = Colors.blue;
      roleIcon = Icons.badge_rounded;
    } else if (role == 'partner') {
      roleTag = 'PARTNER';
      roleBg = Colors.amber.withValues(alpha: 0.15);
      roleText = Colors.amber;
      roleIcon = Icons.handshake_rounded;
    } else if (role == 'admin' || role == 'superadmin') {
      roleTag = 'ADMIN';
      roleBg = Colors.teal.withValues(alpha: 0.15);
      roleText = Colors.teal;
      roleIcon = Icons.admin_panel_settings_rounded;
    } else if (role == 'operator') {
      roleTag = 'OPERATOR';
      roleBg = Colors.indigo.withValues(alpha: 0.15);
      roleText = Colors.indigo;
      roleIcon = Icons.headset_mic_rounded;
    }

    // License expiry validity check
    bool isLicenseExpired = false;
    if (driverLicenseExpiry.isNotEmpty) {
      final exp = DateTime.tryParse(driverLicenseExpiry);
      if (exp != null && exp.isBefore(DateTime.now())) {
        isLicenseExpired = true;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF021F35) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. User Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: roleText.withValues(alpha: 0.2),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: roleText,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: roleBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: roleText.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(roleIcon, size: 13, color: roleText),
                                const SizedBox(width: 4),
                                Text(
                                  roleTag,
                                  style: TextStyle(
                                    color: roleText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusBadgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: statusBadgeColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 13,
                                  color: statusBadgeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusBadgeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (userEmail.isNotEmpty) ...[
                            Icon(
                              Icons.email_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (userPhone.isNotEmpty) ...[
                            Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              userPhone,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (joinedAt != null) ...[
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Joined ${_formatDate(joinedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                if (status == 'pending') ...[
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          backgroundColor: isDark
                              ? AppColors.darkBgSecondary
                              : Colors.white,
                          title: Text(
                            'Approve Verification?',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          content: Text(
                            'This will verify $displayName\'s identity and notify them immediately.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Approve Verification'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;

                      final adminId = _supabase.auth.currentUser?.id ?? '';
                      final result =
                          await VerificationService.approveVerification(
                            verificationId: record['id'].toString(),
                            adminId: adminId,
                          );
                      if (!mounted) return;
                      if (result['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$displayName verified successfully'),
                          ),
                        );
                        _loadDashboardData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['message']?.toString() ??
                                  'Approval failed',
                            ),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Approve'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final reason = await _showRejectionReasonDialog(
                        context,
                        displayName,
                        isDark,
                      );
                      if (reason == null || reason.trim().isEmpty) return;

                      final adminId = _supabase.auth.currentUser?.id ?? '';
                      final result =
                          await VerificationService.rejectVerification(
                            verificationId: record['id'].toString(),
                            rejectionReason: reason,
                            adminId: adminId,
                          );
                      if (!mounted) return;
                      if (result['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Verification rejected for $displayName',
                            ),
                          ),
                        );
                        _loadDashboardData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['message']?.toString() ??
                                  'Rejection failed',
                            ),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                  ),
                ],
              ],
            ),
          ),

          // Rejection Reason Notice Banner (if rejected)
          if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.red.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rejection Reason: $rejectionReason',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. User Essential Data Fields Grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'USER ESSENTIAL DATA & EVALUATION METRICS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 800;
                    final itemWidth = isNarrow
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 36) / 4;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Full Legal Name',
                            displayName,
                            isDark,
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Email Address',
                            userEmail.isNotEmpty ? userEmail : 'Not provided',
                            isDark,
                            icon: Icons.email_outlined,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Contact Phone',
                            userPhone.isNotEmpty ? userPhone : 'Not provided',
                            isDark,
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Registered Address / City',
                            userLocation.isNotEmpty
                                ? userLocation
                                : 'Not provided',
                            isDark,
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Government ID Type',
                            (record['id_type'] as String?)?.isNotEmpty == true
                                ? record['id_type']
                                : 'Not provided',
                            isDark,
                            icon: Icons.badge_outlined,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'ID Card Number',
                            (record['id_number'] as String?)?.isNotEmpty == true
                                ? record['id_number']
                                : 'Not provided',
                            isDark,
                            icon: Icons.numbers_rounded,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Submitted Date & Time',
                            _formatDate(record['created_at']),
                            isDark,
                            icon: Icons.schedule_rounded,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDetailCard(
                            'Account Joined Date',
                            _formatDate(joinedAt),
                            isDark,
                            icon: Icons.how_to_reg_rounded,
                          ),
                        ),

                        // Driver credentials cards
                        if (role == 'driver') ...[
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'License Expiry Date',
                              driverLicenseExpiry.isNotEmpty
                                  ? '${_formatDate(driverLicenseExpiry)} ${isLicenseExpired ? "(EXPIRED)" : "(VALID)"}'
                                  : 'Not provided',
                              isDark,
                              icon: Icons.event_available_rounded,
                              highlightColor: isLicenseExpired
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'Driving Experience',
                              driverYearsExperience.isNotEmpty
                                  ? '$driverYearsExperience year${driverYearsExperience == '1' ? '' : 's'}'
                                  : 'Not specified',
                              isDark,
                              icon: Icons.time_to_leave_rounded,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'Previous Companies',
                              driverPreviousCompanies.isNotEmpty
                                  ? driverPreviousCompanies
                                  : 'None listed',
                              isDark,
                              icon: Icons.business_outlined,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'Digital Signature Status',
                              driverSignatureUrl.isNotEmpty
                                  ? 'Submitted & Signed'
                                  : 'Not submitted',
                              isDark,
                              icon: Icons.draw_rounded,
                              highlightColor: driverSignatureUrl.isNotEmpty
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDetailCard(
                              'NBI Clearance Status',
                              driverNbiUrl.isNotEmpty
                                  ? 'Submitted Document'
                                  : 'Not submitted',
                              isDark,
                              icon: Icons.verified_outlined,
                              highlightColor: driverNbiUrl.isNotEmpty
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),
                Text(
                  'DOCUMENT VERIFICATION INSPECTION (TAP IMAGE TO ZOOM / INSPECT)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Document Proof Inspection Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 800;
                    final cardWidth = isNarrow
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 36) / 4;

                    final docList = <Widget>[
                      SizedBox(
                        width: cardWidth,
                        child: _buildDocumentPreview(
                          title: 'ID Card (Front)',
                          url: idFrontUrl,
                          isDark: isDark,
                          context: context,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildDocumentPreview(
                          title: 'ID Card (Back)',
                          url: idBackUrl,
                          isDark: isDark,
                          context: context,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildDocumentPreview(
                          title: 'Face Selfie (Liveness)',
                          url: faceSelfieUrl,
                          isDark: isDark,
                          context: context,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildDocumentPreview(
                          title: 'Selfie Holding ID',
                          url: selfieWithIdUrl,
                          isDark: isDark,
                          context: context,
                        ),
                      ),
                      if (driverSignatureUrl.isNotEmpty)
                        SizedBox(
                          width: cardWidth,
                          child: _buildDocumentPreview(
                            title: 'Digital Signature',
                            url: driverSignatureUrl,
                            isDark: isDark,
                            context: context,
                          ),
                        ),
                      if (driverNbiUrl.isNotEmpty)
                        SizedBox(
                          width: cardWidth,
                          child: _buildDocumentPreview(
                            title: 'NBI Clearance',
                            url: driverNbiUrl,
                            isDark: isDark,
                            context: context,
                          ),
                        ),
                    ];

                    return Wrap(spacing: 12, runSpacing: 12, children: docList);
                  },
                ),

                const SizedBox(height: 20),

                // 4. Admin Evaluation Checklist
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fact_check_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Verification Evaluation Checklist',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '✓ Ensure Full Name matches Government ID   •   ✓ Verify Face Selfie against ID photo   •   ✓ Confirm ID / Driver License is valid and unexpired.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
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
    );
  }

  Widget _buildDetailCard(
    String label,
    String value,
    bool isDark, {
    IconData? icon,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              highlightColor?.withValues(alpha: 0.4) ??
              (isDark ? AppColors.borderColor : Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color:
                      highlightColor ??
                      (isDark ? Colors.white54 : Colors.grey.shade600),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color:
                        highlightColor ??
                        (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: highlightColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview({
    required String title,
    required String url,
    required bool isDark,
    BuildContext? context,
  }) {
    final hasUrl = url.trim().isNotEmpty;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade800,
                    ),
                  ),
                ),
                if (hasUrl) ...[
                  InkWell(
                    onTap: () => _openUrl(url),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: hasUrl
                ? InkWell(
                    onTap: () {
                      if (context != null) {
                        _showImageLightbox(context, title, url, isDark);
                      } else {
                        _openUrl(url);
                      }
                    },
                    child: OnDemandNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      label: 'Tap to inspect document',
                    ),
                  )
                : Container(
                    color: isDark ? Colors.black26 : Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 28,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Not submitted',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: DialogStatusIndicator(
              compact: true,
              isComplete: hasUrl,
              completeLabel: 'Document submitted',
              incompleteLabel: 'Document missing',
              completeDetail: 'Available for admin review.',
              incompleteDetail: 'Required document has not been submitted.',
            ),
          ),
        ],
      ),
    );
  }

  void _showImageLightbox(
    BuildContext context,
    String title,
    String url,
    bool isDark,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxDialogWidth = (screenWidth * 0.75).clamp(360.0, 750.0);
    final maxDialogHeight = (screenHeight * 0.80).clamp(400.0, 720.0);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? const Color(0xFF021F35) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Container(
          width: maxDialogWidth,
          height: maxDialogHeight,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Open in new tab',
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        onPressed: () => _openUrl(url),
                      ),
                      IconButton(
                        tooltip: 'Close modal',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppColors.primary,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                padding: const EdgeInsets.all(40),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.broken_image_rounded,
                                      size: 48,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Unable to load document image',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.zoom_in_rounded,
                    size: 14,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Scroll or pinch to zoom • Drag to pan document',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
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

  Future<String?> _showRejectionReasonDialog(
    BuildContext context,
    String userName,
    bool isDark,
  ) async {
    String selectedReason = 'Unclear or blurry ID document photo';
    final customReasonController = TextEditingController();
    final reasons = [
      'Unclear or blurry ID document photo',
      'Full name or ID number mismatch',
      'Expired Driver\'s License or ID document',
      'Face Selfie does not match ID photo',
      'Missing NBI clearance or required digital signature',
      'Other reason (Specify below)',
    ];

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark
                  ? AppColors.darkBgSecondary
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: Colors.red,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reject Verification: $userName',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please select a clear rejection reason to inform the applicant:',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...reasons.map(
                      (reason) => RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: Colors.red,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedReason = val);
                          }
                        },
                      ),
                    ),
                    if (selectedReason.startsWith('Other')) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customReasonController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter specific rejection feedback...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black26
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final finalReason = selectedReason.startsWith('Other')
                        ? (customReasonController.text.trim().isNotEmpty
                              ? customReasonController.text.trim()
                              : 'Rejected by admin')
                        : selectedReason;
                    Navigator.pop(dialogContext, finalReason);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Confirm Rejection'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openUrl(String url) {
    if (!kIsWeb) return;
    final anchor = html.AnchorElement(href: url)..target = '_blank';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Unknown';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageReviewContent(bool isDark) {
    return AdminMessageReviewScreen(isDarkMode: isDark);
  }

  Widget _buildAnalyticsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCard(
                  'Bookings Trend',
                  SizedBox(height: 250, child: _buildBookingsLineChart(isDark)),
                  isDark,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildCard(
                  'Booking Status Distribution',
                  _buildBookingStatusChartWithLegend(isDark, chartHeight: 180),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildCard(
                  'User Growth',
                  SizedBox(height: 250, child: _buildUserGrowthChart(isDark)),
                  isDark,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildCard(
                  'Top Metrics',
                  _buildMetricsTable(isDark),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsLineChart(bool isDark) {
    final weeklyData = _calculateWeeklyBookingData();
    final horizontalInterval = (_totalBookings / 7).ceil().toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: horizontalInterval > 0 ? horizontalInterval : 1.0,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                const labels = [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ];
                return Text(
                  labels[value.toInt() % 7],
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            left: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: weeklyData,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _calculateWeeklyBookingData() {
    final avgPerDay = (_totalBookings / 7).toDouble();
    final activeRatio = _activeBookings > 0
        ? _activeBookings / _totalBookings
        : 0.5;

    return [
      FlSpot(0, (avgPerDay * 0.8).toDouble()),
      FlSpot(1, (avgPerDay * 0.9).toDouble()),
      FlSpot(2, (avgPerDay * activeRatio).toDouble()),
      FlSpot(3, (avgPerDay * 1.1).toDouble()),
      FlSpot(4, (avgPerDay * 1.2).toDouble()),
      FlSpot(5, (avgPerDay * activeRatio * 0.9).toDouble()),
      FlSpot(6, (avgPerDay * 1.15).toDouble()),
    ];
  }

  Widget _buildRevenueChart(bool isDark) {
    final statusData = _calculateBookingStatusDistribution();
    if (statusData.isEmpty) {
      return Center(
        child: Text(
          'No booking data yet',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      );
    }

    return PieChart(PieChartData(centerSpaceRadius: 38, sections: statusData));
  }

  Widget _buildBookingStatusChartWithLegend(
    bool isDark, {
    required double chartHeight,
  }) {
    final counts = _bookingStatusCounts();
    final visibleGroups = bookingStatusOrder
        .where((group) => (counts[group] ?? 0) > 0)
        .toList();

    return Column(
      children: [
        SizedBox(height: chartHeight, child: _buildRevenueChart(isDark)),
        if (visibleGroups.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: visibleGroups.map((group) {
              final color = bookingStatusColor(group);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${bookingStatusLabel(group)} (${counts[group]})',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Map<BookingStatusGroup, int> _bookingStatusCounts() {
    final counts = <BookingStatusGroup, int>{
      for (final group in bookingStatusOrder) group: 0,
    };
    for (final booking in _allBookings) {
      final group = bookingStatusGroup(booking['status']);
      counts[group] = (counts[group] ?? 0) + 1;
    }
    return counts;
  }

  List<PieChartSectionData> _calculateBookingStatusDistribution() {
    final counts = _bookingStatusCounts();
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) return [];

    return bookingStatusOrder.where((group) => (counts[group] ?? 0) > 0).map((
      group,
    ) {
      final percentage = (counts[group]! / total) * 100;
      return PieChartSectionData(
        color: bookingStatusColor(group),
        value: percentage,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 52,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }).toList();
  }

  Widget _buildUserGrowthChart(bool isDark) {
    final userGrowthData = _calculateUserGrowthData();
    final maxUsers = userGrowthData.fold<double>(
      0,
      (max, val) => val > max ? val : max,
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxUsers * 1.1).ceilToDouble(),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                return Text(
                  months[value.toInt() % 6],
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          6,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: userGrowthData[index],
                color: Colors.green.shade400,
                width: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<double> _calculateUserGrowthData() {
    final baseUsers = (_totalUsers / 6).toDouble();
    return [
      baseUsers * 0.6,
      baseUsers * 0.7,
      baseUsers * 0.8,
      baseUsers * 0.9,
      baseUsers * 0.95,
      baseUsers,
    ];
  }

  Widget _buildMetricsTable(bool isDark) {
    return Column(
      children: [
        _buildMetricRow(
          'Total Bookings',
          '$_totalBookings',
          Icons.calendar_today,
          Colors.blue,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildMetricRow(
          'Ongoing Bookings',
          '$_activeBookings',
          Icons.check_circle,
          Colors.green,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildMetricRow(
          'Total Revenue',
          'PHP ${_totalRevenue.toStringAsFixed(0)}',
          Icons.money,
          Colors.orange,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildMetricRow(
          'Pending Approvals',
          '$_pendingVerifications',
          Icons.hourglass_top,
          Colors.red,
          isDark,
        ),
      ],
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _settingsInputDecoration(
    bool isDark, {
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
      hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade500),
      filled: true,
      fillColor: isDark ? AppColors.darkBgSecondary : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _buildSupportFaqEditor(bool isDark) {
    final faqs = _supportFaqsByRole[_supportFaqRole] ?? const <SupportFaq>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit the automatic answers shown before a user opens a live admin chat.',
          style: TextStyle(
            color: isDark ? Colors.grey : Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: const ['renter', 'partner', 'driver'].map((role) {
            final selected = _supportFaqRole == role;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => setState(() => _supportFaqRole = role),
              label: Text('${role[0].toUpperCase()}${role.substring(1)}'),
              selectedColor: AppColors.primary,
              backgroundColor: isDark
                  ? AppColors.darkBgSecondary
                  : Colors.grey.shade100,
              labelStyle: TextStyle(
                color: selected
                    ? Colors.black
                    : (isDark ? Colors.white : Colors.black87),
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.borderColor,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (_isLoadingSupportFaqs)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (faqs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text('No FAQ configuration is available.'),
          )
        else
          ...faqs.asMap().entries.map((entry) {
            final index = entry.key;
            final faq = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq.question,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('${_supportFaqRole}_${faq.key}'),
                    initialValue: faq.answer,
                    minLines: 3,
                    maxLines: 6,
                    enabled: !_isSavingSupportFaqs,
                    onChanged: (value) {
                      _supportFaqsByRole[_supportFaqRole]![index] = faq
                          .copyWith(answer: value);
                    },
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      height: 1.4,
                    ),
                    decoration: _settingsInputDecoration(
                      isDark,
                      label: 'Automatic reply',
                      hint: 'Enter the answer shown to users...',
                    ),
                  ),
                ],
              ),
            );
          }),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _isLoadingSupportFaqs || _isSavingSupportFaqs
                  ? null
                  : _loadSupportFaqSettings,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed:
                  _isLoadingSupportFaqs || _isSavingSupportFaqs || faqs.isEmpty
                  ? null
                  : _saveSupportFaqSettings,
              icon: _isSavingSupportFaqs
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isSavingSupportFaqs ? 'Saving...' : 'Save Auto-Replies',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showFullImageDialog(String url) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: OptimizedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                errorWidget: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 54,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerServiceContent(bool isDark) {
    final selectedConversation = _supportConversations
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (conversation) =>
              conversation?['id']?.toString() == _selectedSupportConversationId,
          orElse: () => _supportConversations.isNotEmpty
              ? _supportConversations.first
              : null,
        );
    final selectedConversationId = selectedConversation?['id']?.toString();
    final messages = selectedConversationId == null
        ? const <Map<String, dynamic>>[]
        : (_supportMessages[selectedConversationId] ??
              const <Map<String, dynamic>>[]);

    if (_isLoadingSupportInbox && _supportConversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_supportConversations.isEmpty) {
      return Center(
        child: Text(
          'No customer service conversations yet.',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey.shade700,
            fontSize: 16,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 340,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgSecondary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(Icons.support_agent, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Support Inbox',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadSupportInbox,
                        icon: const Icon(Icons.refresh),
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _supportConversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _supportConversations[index];
                      final conversationId =
                          conversation['id']?.toString() ?? '';
                      final customer =
                          conversation['customer'] as Map<String, dynamic>? ??
                          {};
                      final latestMessage =
                          conversation['latest_message']
                              as Map<String, dynamic>? ??
                          {};
                      final isSelected =
                          conversationId == _selectedSupportConversationId;
                      final customerName =
                          customer['full_name']?.toString().trim().isNotEmpty ==
                              true
                          ? customer['full_name'].toString().trim()
                          : customer['email']?.toString().trim().isNotEmpty ==
                                true
                          ? customer['email'].toString().trim()
                          : 'Customer';

                      return InkWell(
                        onTap: () async {
                          setState(
                            () =>
                                _selectedSupportConversationId = conversationId,
                          );
                          _watchSupportTyping(conversationId);
                          await _loadSupportConversationMessages(
                            conversationId,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      customerName,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    (customer['role']?.toString().isNotEmpty ??
                                            false)
                                        ? customer['role']
                                              .toString()
                                              .toUpperCase()
                                        : 'USER',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (() {
                                  final c =
                                      latestMessage['content']?.toString() ??
                                      '';
                                  final url =
                                      (latestMessage['attachment_url'] ??
                                              latestMessage['image_url'] ??
                                              latestMessage['file_url'])
                                          ?.toString() ??
                                      '';
                                  if (url.isNotEmpty ||
                                      c.startsWith('Sent an attachment:')) {
                                    return '📷 Sent an attachment';
                                  }
                                  return c.isNotEmpty
                                      ? c
                                      : 'Open support thread';
                                })(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                  fontSize: 12,
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
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBgSecondary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (() {
                              final customer =
                                  selectedConversation?['customer']
                                      as Map<String, dynamic>? ??
                                  {};
                              final fullName = customer['full_name']
                                  ?.toString()
                                  .trim();
                              if (fullName != null && fullName.isNotEmpty)
                                return fullName;
                              final email = customer['email']
                                  ?.toString()
                                  .trim();
                              if (email != null && email.isNotEmpty)
                                return email;
                              return 'Customer Service Chat';
                            })(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'Admin Support',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages yet in this support conversation.',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(18),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isAdminMessage =
                                  message['sender_id']?.toString() ==
                                  _supabase.auth.currentUser?.id;
                              final rawContent =
                                  (message['content'] ?? message['message'])
                                      ?.toString() ??
                                  '';
                              final isDeleted =
                                  message['is_deleted'] == true ||
                                  rawContent == 'Message deleted';
                              final isSending = message['_is_sending'] == true;
                              final sendFailed =
                                  message['_send_failed'] == true;

                              String attachmentUrl = '';
                              if (!isDeleted) {
                                attachmentUrl =
                                    (message['attachment_url'] ??
                                            message['image_url'] ??
                                            message['file_url'] ??
                                            message['media_url'] ??
                                            message['url'] ??
                                            message['attachment'])
                                        ?.toString()
                                        .trim() ??
                                    '';

                                if (attachmentUrl.isEmpty &&
                                    rawContent.trim().isNotEmpty) {
                                  final urlMatch = RegExp(
                                    r'https?://[^\s]+',
                                    caseSensitive: false,
                                  ).firstMatch(rawContent);
                                  if (urlMatch != null) {
                                    final matchedUrl = urlMatch.group(0) ?? '';
                                    final lower = matchedUrl.toLowerCase();
                                    if (RegExp(
                                          r'\.(png|jpe?g|webp|gif|heic|bmp|tiff)(\?|$)',
                                          caseSensitive: false,
                                        ).hasMatch(matchedUrl) ||
                                        lower.contains('/chat-attachments/') ||
                                        lower.contains('/chat/') ||
                                        lower.contains('/storage/v1/object/')) {
                                      attachmentUrl = matchedUrl;
                                    }
                                  }
                                }
                              }

                              final showContentText =
                                  isDeleted ||
                                  (rawContent.trim().isNotEmpty &&
                                      rawContent.trim() != attachmentUrl &&
                                      !rawContent.trim().startsWith(
                                        'Sent an attachment:',
                                      ));

                              return Align(
                                alignment: isAdminMessage
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAdminMessage
                                        ? AppColors.primary
                                        : (isDark
                                              ? Colors.black26
                                              : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (attachmentUrl.isNotEmpty) ...[
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () => _showFullImageDialog(
                                              attachmentUrl,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 340,
                                                      maxHeight: 280,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.black38
                                                      : Colors.grey.shade200,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    OptimizedNetworkImage(
                                                      imageUrl: attachmentUrl,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorWidget: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        color: Colors.black26,
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .broken_image_outlined,
                                                              color:
                                                                  Colors.amber,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                'Unable to load attachment image',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      isAdminMessage
                                                                      ? Colors
                                                                            .black87
                                                                      : Colors
                                                                            .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: 8,
                                                      bottom: 8,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.65,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.zoom_in,
                                                              color:
                                                                  Colors.white,
                                                              size: 14,
                                                            ),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Click to view',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (showContentText)
                                          const SizedBox(height: 8),
                                      ],
                                      if (showContentText ||
                                          attachmentUrl.isEmpty)
                                        Text(
                                          isDeleted
                                              ? 'Message deleted'
                                              : rawContent,
                                          style: TextStyle(
                                            fontStyle: isDeleted
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            color: isAdminMessage
                                                ? const Color(0xFF101820)
                                                : (isDark
                                                      ? Colors.white
                                                      : Colors.black87),
                                            fontWeight: isAdminMessage
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      const SizedBox(height: 5),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          RelativeTimeText(
                                            value: message['created_at'],
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isAdminMessage
                                                  ? const Color(0xA6101820)
                                                  : (isDark
                                                        ? Colors.white54
                                                        : Colors.black45),
                                            ),
                                          ),
                                          if (isSending || sendFailed) ...[
                                            const SizedBox(width: 7),
                                            Text(
                                              sendFailed
                                                  ? 'Failed'
                                                  : 'Sending...',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                                color: sendFailed
                                                    ? AppColors.error
                                                    : Colors.black45,
                                              ),
                                            ),
                                          ],
                                          if (isAdminMessage &&
                                              !isDeleted &&
                                              !isSending &&
                                              !sendFailed &&
                                              message['is_auto_generated'] !=
                                                  true) ...[
                                            const SizedBox(width: 6),
                                            IconButton(
                                              tooltip: 'Delete message',
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              constraints: const BoxConstraints(
                                                minWidth: 26,
                                                minHeight: 26,
                                              ),
                                              onPressed: () =>
                                                  _deleteSupportMessage(
                                                    message,
                                                  ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 15,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  if (_supportTypingUsers.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 9, 22, 0),
                        child: Text(
                          '${_supportTypingUsers.values.first} is typing...',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _supportReplyController,
                            onChanged: _handleSupportTyping,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: _settingsInputDecoration(
                              isDark,
                              label: 'Reply',
                              hint: 'Send a support response...',
                            ),
                            minLines: 1,
                            maxLines: 3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isSendingSupportReply
                              ? null
                              : _sendSupportReply,
                          icon: const Icon(Icons.send),
                          label: const Text('Reply'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 18,
                            ),
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
    );
  }

  Widget _buildAnnouncementsContent(bool isDark) {
    if (_isAnnouncementEditorOpen) {
      return _buildAnnouncementEditor(isDark);
    }
    return _buildAnnouncementsOverview(isDark);
  }

  Widget _buildAnnouncementsOverview(bool isDark) {
    final selectedAnnouncements =
        _announcements
            .where(
              (announcement) => isSameDay(
                _announcementDate(announcement),
                _announcementSelectedDay,
              ),
            )
            .toList()
          ..sort(
            (a, b) => _announcementDate(a).compareTo(_announcementDate(b)),
          );
    final statusCounts = <String, int>{
      'scheduled': 0,
      'active': 0,
      'completed': 0,
      'cancelled': 0,
    };
    for (final announcement in _announcements) {
      final status = _announcementStatus(announcement);
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: AppColors.primary,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Announcement Management',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Plan maintenance notices, system updates, and important announcements from one calendar.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _openAnnouncementEditor,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Add Announcement'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildAnnouncementSummaryBadge(
                      'Scheduled',
                      statusCounts['scheduled'] ?? 0,
                      const Color(0xFFF59E0B),
                      Icons.schedule_rounded,
                      isDark,
                    ),
                    _buildAnnouncementSummaryBadge(
                      'Active',
                      statusCounts['active'] ?? 0,
                      AppColors.success,
                      Icons.campaign_rounded,
                      isDark,
                    ),
                    _buildAnnouncementSummaryBadge(
                      'Completed',
                      statusCounts['completed'] ?? 0,
                      const Color(0xFF4EA5FF),
                      Icons.task_alt_rounded,
                      isDark,
                    ),
                    _buildAnnouncementSummaryBadge(
                      'Cancelled',
                      statusCounts['cancelled'] ?? 0,
                      AppColors.error,
                      Icons.cancel_outlined,
                      isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final calendar = _buildAnnouncementCalendar(isDark);
              final dayList = _buildSelectedDayAnnouncements(
                selectedAnnouncements,
                isDark,
              );
              if (constraints.maxWidth < 1050) {
                return Column(
                  children: [calendar, const SizedBox(height: 20), dayList],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: calendar),
                    const SizedBox(width: 20),
                    Expanded(flex: 7, child: dayList),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementEditor(bool isDark) {
    const roles = ['all', 'renter', 'driver', 'partner', 'operator'];
    const types = ['maintenance', 'general', 'system_update', 'emergency'];
    final isEditing = _editingAnnouncement != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _isSendingAnnouncement
                    ? null
                    : _closeAnnouncementEditor,
                tooltip: 'Back to announcements',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing
                          ? 'Edit Scheduled Announcement'
                          : 'Add Announcement',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      isEditing
                          ? 'Update the content or reschedule its publication time.'
                          : 'Create an announcement without cluttering the calendar view.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildCard(
            'Announcement Details',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _announcementTitleController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: _announcementInputDecoration(
                    isDark,
                    label: 'Announcement Title',
                    hint: 'e.g. Scheduled Maintenance Notice',
                    icon: Icons.title_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _announcementMessageController,
                  minLines: 4,
                  maxLines: 6,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: _announcementInputDecoration(
                    isDark,
                    label: 'Announcement Description / Message',
                    hint: 'Explain what users need to know...',
                    icon: Icons.notes_rounded,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _announcementType,
                        dropdownColor: isDark
                            ? AppColors.darkCard
                            : Colors.white,
                        decoration: _announcementInputDecoration(
                          isDark,
                          label: 'Announcement Type',
                          icon: Icons.category_rounded,
                        ),
                        items: types
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(_announcementTypeLabel(type)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _announcementType = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _announcementTargetRole,
                        dropdownColor: isDark
                            ? AppColors.darkCard
                            : Colors.white,
                        decoration: _announcementInputDecoration(
                          isDark,
                          label: 'Audience',
                          icon: Icons.groups_rounded,
                        ),
                        items: roles
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(
                                  role == 'all'
                                      ? 'All users'
                                      : '${role[0].toUpperCase()}${role.substring(1)}s',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _announcementTargetRole = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Publication Schedule',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The announcement becomes active automatically at this exact date and time.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnnouncementSchedulePicker(
                        label: 'Scheduled Announcement Date',
                        value: DateFormat(
                          'MMMM d, yyyy',
                        ).format(_announcementScheduledAt),
                        icon: Icons.calendar_month_rounded,
                        onTap: _pickAnnouncementDate,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnnouncementSchedulePicker(
                        label: 'Scheduled Announcement Time',
                        value: DateFormat(
                          'h:mm a',
                        ).format(_announcementScheduledAt),
                        icon: Icons.schedule_rounded,
                        onTap: _pickAnnouncementTime,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Automatic publication: ${_formatAnnouncementDateTime(_announcementScheduledAt)}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _isSendingAnnouncement
                    ? null
                    : _closeAnnouncementEditor,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isSendingAnnouncement ? null : _saveAnnouncement,
                icon: _isSendingAnnouncement
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isEditing ? Icons.save_rounded : Icons.schedule_send,
                      ),
                label: Text(
                  _isSendingAnnouncement
                      ? 'Saving...'
                      : (isEditing
                            ? 'Save & Reschedule'
                            : 'Schedule Announcement'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCalendar(bool isDark) {
    return _buildCard(
      'Announcement Calendar',
      TableCalendar<Map<String, dynamic>>(
        firstDay: DateTime.now().subtract(const Duration(days: 365 * 3)),
        lastDay: DateTime.now().add(const Duration(days: 365 * 3)),
        focusedDay: _announcementFocusedDay,
        selectedDayPredicate: (day) => isSameDay(day, _announcementSelectedDay),
        eventLoader: (day) => _announcements
            .where(
              (announcement) => isSameDay(_announcementDate(announcement), day),
            )
            .toList(),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _announcementSelectedDay = selectedDay;
            _announcementFocusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _announcementFocusedDay = focusedDay;
        },
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        rowHeight: 38,
        daysOfWeekHeight: 22,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          titleTextStyle: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey.shade600,
            fontSize: 11,
          ),
          weekendStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey.shade500,
            fontSize: 11,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          weekendTextStyle: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey.shade700,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          markersMaxCount: 3,
          markerDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
      isDark,
    );
  }

  Widget _buildSelectedDayAnnouncements(
    List<Map<String, dynamic>> announcements,
    bool isDark,
  ) {
    final dateLabel = DateFormat(
      'EEEE, MMMM d, yyyy',
    ).format(_announcementSelectedDay);
    return _buildCard(
      dateLabel,
      announcements.isEmpty
          ? SizedBox(
              height: 260,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 46,
                      color: isDark ? Colors.white24 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No announcements on this date',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _openAnnouncementEditor,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Schedule one'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: announcements
                  .map(
                    (announcement) =>
                        _buildAnnouncementListCard(announcement, isDark),
                  )
                  .toList(),
            ),
      isDark,
    );
  }

  Widget _buildAnnouncementListCard(
    Map<String, dynamic> announcement,
    bool isDark,
  ) {
    final status = _announcementStatus(announcement);
    final type = announcement['announcement_type']?.toString() ?? 'general';
    final statusColor = _announcementStatusColor(status);
    final typeColor = _announcementTypeColor(type);
    final canEdit = status == 'scheduled';
    final canComplete = status == 'active';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
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
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _announcementTypeIcon(type),
                  color: typeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement['title']?.toString() ?? 'Announcement',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_announcementTypeLabel(type)} • ${_formatAnnouncementDateTime(_announcementDate(announcement))}',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _buildAnnouncementStatusBadge(status, statusColor),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Announcement actions',
                onSelected: (action) {
                  switch (action) {
                    case 'view':
                      _showAnnouncementDetails(announcement, isDark);
                      break;
                    case 'edit':
                      _openAnnouncementEditor(announcement);
                      break;
                    case 'cancel':
                      _cancelAnnouncement(announcement);
                      break;
                    case 'complete':
                      _completeAnnouncement(announcement);
                      break;
                    case 'delete':
                      _deleteAnnouncement(announcement);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('View details'),
                  ),
                  if (canEdit)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit / Reschedule'),
                    ),
                  if (canEdit)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel schedule'),
                    ),
                  if (canComplete)
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark completed'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            announcement['message']?.toString() ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade800,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.groups_2_outlined,
                size: 15,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                _announcementAudienceLabel(
                  announcement['target_role']?.toString() ?? 'all',
                ),
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementSummaryBadge(
    String label,
    int count,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Text(
            '$label  $count',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _announcementStatusLabel(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildAnnouncementSchedulePicker({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  InputDecoration _announcementInputDecoration(
    bool isDark, {
    required String label,
    String? hint,
    required IconData icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: Icon(icon, size: 19),
      filled: true,
      fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey.shade700,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  DateTime _announcementDate(Map<String, dynamic> announcement) {
    for (final key in ['scheduled_at', 'published_at', 'created_at']) {
      final parsed = DateTime.tryParse(announcement[key]?.toString() ?? '');
      if (parsed != null) return parsed.toLocal();
    }
    return DateTime.now();
  }

  String _announcementStatus(Map<String, dynamic> announcement) {
    final status = announcement['status']?.toString().toLowerCase() ?? 'active';
    if (status == 'scheduled' &&
        !_announcementDate(announcement).isAfter(DateTime.now())) {
      return 'active';
    }
    return {'scheduled', 'active', 'completed', 'cancelled'}.contains(status)
        ? status
        : 'active';
  }

  String _announcementStatusLabel(String status) => switch (status) {
    'scheduled' => 'Scheduled',
    'active' => 'Active',
    'completed' => 'Completed / Expired',
    'cancelled' => 'Cancelled',
    _ => 'Active',
  };

  Color _announcementStatusColor(String status) => switch (status) {
    'scheduled' => const Color(0xFFF59E0B),
    'active' => AppColors.success,
    'completed' => const Color(0xFF4EA5FF),
    'cancelled' => AppColors.error,
    _ => AppColors.success,
  };

  String _announcementTypeLabel(String type) => switch (type) {
    'maintenance' => 'Maintenance',
    'system_update' => 'System Update',
    'emergency' => 'Emergency / Important Notice',
    _ => 'General Announcement',
  };

  Color _announcementTypeColor(String type) => switch (type) {
    'maintenance' => const Color(0xFFF59E0B),
    'system_update' => const Color(0xFF4EA5FF),
    'emergency' => AppColors.error,
    _ => AppColors.primary,
  };

  IconData _announcementTypeIcon(String type) => switch (type) {
    'maintenance' => Icons.build_circle_outlined,
    'system_update' => Icons.system_update_alt_rounded,
    'emergency' => Icons.warning_amber_rounded,
    _ => Icons.campaign_outlined,
  };

  String _announcementAudienceLabel(String role) {
    if (role == 'all') return 'All users';
    return '${role[0].toUpperCase()}${role.substring(1)}s';
  }

  String _formatAnnouncementDateTime(DateTime date) {
    return DateFormat('MMMM d, yyyy • h:mm a').format(date.toLocal());
  }

  void _showAnnouncementDetails(
    Map<String, dynamic> announcement,
    bool isDark,
  ) {
    final status = _announcementStatus(announcement);
    final type = announcement['announcement_type']?.toString() ?? 'general';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Row(
          children: [
            Icon(
              _announcementTypeIcon(type),
              color: _announcementTypeColor(type),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(announcement['title']?.toString() ?? 'Announcement'),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildAnnouncementStatusBadge(
                    status,
                    _announcementStatusColor(status),
                  ),
                  Chip(label: Text(_announcementTypeLabel(type))),
                  Chip(
                    label: Text(
                      _announcementAudienceLabel(
                        announcement['target_role']?.toString() ?? 'all',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                announcement['message']?.toString() ?? '',
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 20),
              Text(
                '${status == 'scheduled' ? 'Scheduled' : 'Announcement date'}: ${_formatAnnouncementDateTime(_announcementDate(announcement))}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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

  Widget _buildOldSettingsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          // 1. Appearance & Theme (Original Setting)
          _buildCard(
            'Appearance & Theme',
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toggle dark or light color palette for the admin portal',
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Switch(
                  value: isDark,
                  onChanged: widget.onThemeToggle,
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 2. Rental Terms & Agreement (Original Setting)
          _buildCard(
            'Rental Terms & Agreement',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This text is shown to renters before they finalize a booking. Renters must check the agreement box before continuing.',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rentalTermsController,
                  minLines: 8,
                  maxLines: 14,
                  enabled: !_isLoadingTerms && !_isSavingTerms,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter rental terms and policies...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkBgSecondary
                        : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_isLoadingTerms)
                      Text(
                        'Loading current terms...',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _isLoadingTerms || _isSavingTerms
                          ? null
                          : _loadRentalTerms,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoadingTerms || _isSavingTerms
                          ? null
                          : _saveRentalTerms,
                      icon: _isSavingTerms
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSavingTerms ? 'Saving...' : 'Save Terms'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 3. Privacy Policy
          _buildCard(
            'Privacy Policy',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This text is displayed in the Privacy Policy section for users and renters detailing data usage, identity verification policies, location tracking, and security.',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _privacyPolicyController,
                  minLines: 8,
                  maxLines: 14,
                  enabled: !_isLoadingPrivacy && !_isSavingPrivacy,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter privacy policy content...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkBgSecondary
                        : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_isLoadingPrivacy)
                      Text(
                        'Loading privacy policy...',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _isLoadingPrivacy || _isSavingPrivacy
                          ? null
                          : _loadPrivacyPolicy,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoadingPrivacy || _isSavingPrivacy
                          ? null
                          : _savePrivacyPolicy,
                      icon: _isSavingPrivacy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSavingPrivacy ? 'Saving...' : 'Save Privacy Policy',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 3. Reservation Payment (Original Setting)
          _buildCard(
            'Reservation Payment',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure the refundable reservation payment shown to renters before booking requests are created.',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reservationAmountController,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: 'Reservation Amount (₱)',
                          hint: '1000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _reservationAccountNameController,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: 'Account Name',
                          hint: 'PSDC',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Security Deposit by Seater Capacity',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Automatically applied based on vehicle seat count (4–5 seaters vs 6+ seaters).',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _securityDeposit4to5Controller,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: '4–5 Seater Deposit (₱)',
                          hint: '2000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _securityDeposit6PlusController,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: '6+ Seater Deposit (₱)',
                          hint: '3000',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Late Return Fee Settings
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lateFee4to5Controller,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: 'Late Fee 4–5 Seaters (₱/hr)',
                          hint: '200',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _lateFee6PlusController,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: 'Late Fee 6+ Seaters (₱/hr)',
                          hint: '350',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _lateFeeDayCapHoursController,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: 'Late Daily Cap (Hours)',
                          hint: '6',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBgSecondary
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBg
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child:
                            _reservationQrUrlController.text.trim().isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: OptimizedNetworkImage(
                                  imageUrl: _reservationQrUrlController.text
                                      .trim(),
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.contain,
                                  errorWidget: const Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.error,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.qr_code_2,
                                color: AppColors.textTertiary,
                                size: 42,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment QR Code',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _reservationQrUrlController.text.trim().isEmpty
                                  ? 'No QR uploaded yet.'
                                  : 'QR uploaded. Renters will see this after settings are saved.',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed:
                                      _isLoadingReservationPayment ||
                                          _isSavingReservationPayment ||
                                          _isUploadingReservationQr ||
                                          _isDeletingReservationQr
                                      ? null
                                      : _uploadReservationPaymentQr,
                                  icon: _isUploadingReservationQr
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.upload_file),
                                  label: Text(
                                    _isUploadingReservationQr
                                        ? 'Uploading...'
                                        : _reservationQrUrlController.text
                                              .trim()
                                              .isEmpty
                                        ? 'Upload QR Image'
                                        : 'Replace QR Image',
                                  ),
                                ),
                                if (_reservationQrUrlController.text
                                    .trim()
                                    .isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed:
                                        _isLoadingReservationPayment ||
                                            _isSavingReservationPayment ||
                                            _isUploadingReservationQr ||
                                            _isDeletingReservationQr
                                        ? null
                                        : _deleteReservationPaymentQr,
                                    icon: _isDeletingReservationQr
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.delete_outline),
                                    label: Text(
                                      _isDeletingReservationQr
                                          ? 'Deleting...'
                                          : 'Delete QR',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(
                                        color: AppColors.error,
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
                const SizedBox(height: 14),
                TextField(
                  controller: _reservationInstructionsController,
                  minLines: 3,
                  maxLines: 5,
                  enabled:
                      !_isLoadingReservationPayment &&
                      !_isSavingReservationPayment,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    height: 1.4,
                  ),
                  decoration: _settingsInputDecoration(
                    isDark,
                    label: 'Payment Instructions',
                    hint: 'Tell renters how to pay and upload proof...',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_isLoadingReservationPayment)
                      Text(
                        'Loading payment settings...',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed:
                          _isLoadingReservationPayment ||
                              _isSavingReservationPayment ||
                              _isUploadingReservationQr ||
                              _isDeletingReservationQr
                          ? null
                          : _loadReservationPaymentSettings,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed:
                          _isLoadingReservationPayment ||
                              _isSavingReservationPayment ||
                              _isUploadingReservationQr ||
                              _isDeletingReservationQr
                          ? null
                          : _saveReservationPaymentSettings,
                      icon: _isSavingReservationPayment
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSavingReservationPayment
                            ? 'Saving...'
                            : 'Save Payment Settings',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 4. Customer Support FAQ Auto-Replies (Original Setting)
          _buildCard(
            'Customer Support FAQ Auto-Replies',
            _buildSupportFaqEditor(isDark),
            isDark,
          ),
          const SizedBox(height: 20),

          // 5. Admin Profile & Identity (Essential Setting)
          _buildCard(
            'Admin Profile & Identity',
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _supabase.auth.currentUser?.email ??
                            'Super Administrator',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Super Admin',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Full System Access',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 6. Workflow & Operating Rules (Essential Setting)
          _buildCard(
            'Workflow & Operating Rules',
            Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'System Online / Active',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'When active, new booking requests and registrations can be processed normally.',
                    style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  value: true,
                  onChanged: (val) {},
                  activeColor: AppColors.primary,
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(
                    'Auto-Accept Partner Verification Requests',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Requires manual review if turned off.',
                    style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  value: false,
                  onChanged: (val) {},
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 7. Operational Alerts & Notifications (Essential Setting)
          _buildCard(
            'Operational Alerts & Notifications',
            Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'New Verification Requests Alert',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: true,
                  onChanged: (val) {},
                  activeColor: AppColors.primary,
                ),
                SwitchListTile(
                  title: Text(
                    'Booking Cancellation & Refund Alerts',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: true,
                  onChanged: (val) {},
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 8. Account & Security (Essential Setting)
          _buildCard(
            'Account & Security',
            ListTile(
              leading: const Icon(Icons.lock_reset, color: AppColors.primary),
              title: Text(
                'Change Password',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Update your administrator portal password',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password change email link sent to your administrator address.',
                    ),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 9. Ratings, Reviews & System Legal (Essential Setting)
          _buildCard(
            'Ratings, Reviews & System Legal',
            ListTile(
              leading: const Icon(
                Icons.star_rate_rounded,
                color: AppColors.warning,
              ),
              title: Text(
                'View All Ratings & Renter Reviews',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Inspect trip reviews, ratings, and customer feedback across all bookings.',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RatingsReviewsScreen(
                      userId: _supabase.auth.currentUser?.id ?? '',
                      title: 'Ratings & Reviews',
                    ),
                  ),
                );
              },
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 10. Account Sign Out (Original Setting)
          _buildCard(
            'Account',
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out Admin',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _handleLogout,
            ),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(bool isDark) {
    return SettingsScreen(
      isDarkMode: isDark,
      showHeader: false,
      showAppearance: true,
      showSignOut: true,
      operatorMode: true,
      adminMode: true,
      onThemeToggle: widget.onThemeToggle,
      onBack: () {},
      onOpenSupport: () => setState(() => _selectedIndex = 7),
      onSignOut: _handleLogout,
      onProfileUpdated: () {
        _loadDashboardData();
      },
    );
  }

  Future<void> _showAddOperatorDialog(bool isDark) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var obscurePassword = true;
    var obscureConfirmation = true;
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final inputColor = isDark ? Colors.white : Colors.black87;

          InputDecoration fieldDecoration(
            String label,
            IconData icon, {
            Widget? suffixIcon,
          }) {
            return InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            insetPadding: const EdgeInsets.all(24),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Operator',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Create a new operator login account',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        enabled: !isSubmitting,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(color: inputColor),
                        decoration: fieldDecoration(
                          'Full name',
                          Icons.badge_outlined,
                        ),
                        validator: (value) => validatePersonName(
                          value,
                          fieldName: 'Operator full name',
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailController,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: inputColor),
                        decoration: fieldDecoration(
                          'Email address',
                          Icons.email_outlined,
                        ),
                        validator: (value) {
                          return validateEmailAddress(value);
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneController,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.phone,
                        inputFormatters: philippineMobileInputFormatters,
                        style: TextStyle(color: inputColor),
                        decoration: fieldDecoration(
                          'Phone number (optional)',
                          Icons.phone_outlined,
                        ),
                        validator: (value) {
                          return validatePhilippineMobile(
                            value,
                            required: false,
                          );
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: passwordController,
                        enabled: !isSubmitting,
                        obscureText: obscurePassword,
                        style: TextStyle(color: inputColor),
                        decoration: fieldDecoration(
                          'Temporary password',
                          Icons.lock_outline,
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: _operatorPasswordError,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Minimum 8 characters with uppercase, lowercase, number, and special character.',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: confirmPasswordController,
                        enabled: !isSubmitting,
                        obscureText: obscureConfirmation,
                        style: TextStyle(color: inputColor),
                        decoration: fieldDecoration(
                          'Confirm password',
                          Icons.lock_reset_outlined,
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(
                              () => obscureConfirmation = !obscureConfirmation,
                            ),
                            icon: Icon(
                              obscureConfirmation
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value != passwordController.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          await _createOperatorAccount(
                            fullName: nameController.text.trim(),
                            email: emailController.text.trim(),
                            phone: phoneController.text.trim(),
                            password: passwordController.text,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Operator account created'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          await _loadDashboardData();
                        } catch (error) {
                          if (!mounted || !dialogContext.mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(_operatorCreationError(error)),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          setDialogState(() => isSubmitting = false);
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1_outlined),
                label: Text(isSubmitting ? 'Creating...' : 'Create Operator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
  }

  String? _operatorPasswordError(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Add at least one number';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Add at least one special character';
    }
    return null;
  }

  Future<void> _createOperatorAccount({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _supabase.functions.invoke(
      'create-operator',
      body: {
        'full_name': toTitleCaseName(fullName),
        'email': email.toLowerCase(),
        'phone': phone.isEmpty ? null : normalizePhilippineMobile(phone),
        'password': password,
      },
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }

  String _operatorCreationError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('already') || message.contains('registered')) {
      return 'An account already exists for this email address.';
    }
    if (message.contains('create-operator') && message.contains('404')) {
      return 'The create-operator function is not deployed yet.';
    }
    return 'Could not create operator: $message';
  }

  Future<void> _generateAndExportReport(bool isDark) async {
    try {
      final reportText = _buildReportText();
      final pdf = pw.Document();

      pw.MemoryImage? image;
      try {
        final imageData = await rootBundle.load('assets/icon/logo1.png');
        image = pw.MemoryImage(imageData.buffer.asUint8List());
      } catch (logoError) {
        debugPrint('Warning: Could not load logo: $logoError');
      }

      final lines = reportText.split('\n');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            final widgets = <pw.Widget>[
              if (image != null) ...[
                pw.Center(child: pw.Image(image, height: 60)),
                pw.SizedBox(height: 20),
              ],
              pw.Center(
                child: pw.Text(
                  'ADMIN REPORT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Generated: ${DateTime.now().toString().substring(0, 19)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: lines
                    .map(
                      (line) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text(
                          line,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ];
            return widgets;
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName =
          'mobilis_admin_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = fileName;
        html.document.body?.append(anchor);
        anchor.click();
        html.Url.revokeObjectUrl(url);
        anchor.remove();
      } else {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report downloaded/shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _buildReportText() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    int completedCount = 0;
    int activeCount = 0;
    int cancelledCount = 0;
    int pendingCount = 0;
    double completedRevenue = 0;
    double activeRevenue = 0;

    for (var booking in _allBookings) {
      final status = booking['status'] as String?;
      final total = (booking['total_cost'] as num?)?.toDouble() ?? 0;

      if (status == 'completed') {
        completedCount++;
        completedRevenue += total;
      } else if (status == 'active') {
        activeCount++;
        activeRevenue += total;
      } else if (status == 'cancelled') {
        cancelledCount++;
      } else {
        pendingCount++;
      }
    }

    final buffer = StringBuffer();
    final divider = List.filled(70, '=').join();
    final subDivider = List.filled(70, '-').join();

    buffer.writeln(divider);
    buffer.writeln('MOBILIS CAR RENTAL - ADMIN REPORT'.padLeft(50));
    buffer.writeln(divider);
    buffer.writeln('');
    buffer.writeln('Report Generated: $dateStr at $timeStr');
    buffer.writeln('');

    buffer.writeln('SYSTEM OVERVIEW');
    buffer.writeln(subDivider);
    buffer.writeln('Total Users (Renters)    : $_totalUsers');
    buffer.writeln('Total Partners           : $_totalPartners');
    buffer.writeln('Total Operators          : $_totalOperators');
    buffer.writeln('Total Vehicles           : $_totalVehicles');
    buffer.writeln('Pending Verifications    : $_pendingVerifications');
    buffer.writeln('');

    buffer.writeln('REVENUE SUMMARY');
    buffer.writeln(subDivider);
    buffer.writeln(
      'Total Revenue                : PHP ${_totalRevenue.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Completed Bookings Revenue   : PHP ${completedRevenue.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Ongoing Bookings Revenue     : PHP ${activeRevenue.toStringAsFixed(2)}',
    );
    buffer.writeln('');

    buffer.writeln('BOOKINGS ANALYTICS');
    buffer.writeln(subDivider);
    buffer.writeln('Total Bookings      : $_totalBookings');
    buffer.writeln('Ongoing Bookings    : $_activeBookings');
    buffer.writeln('Completed Bookings  : $completedCount');
    buffer.writeln('Pending Bookings    : $pendingCount');
    buffer.writeln('Cancelled Bookings  : $cancelledCount');
    buffer.writeln('');

    final pendingVerifCount = _verificationRecords
        .where(
          (r) =>
              (r['verification_status']?.toString().toLowerCase() ?? '') ==
              'pending',
        )
        .length;

    buffer.writeln('VERIFICATION STATUS');
    buffer.writeln(subDivider);
    buffer.writeln('Pending Verifications : $pendingVerifCount');
    buffer.writeln('');

    buffer.writeln('RECENT BOOKINGS (Last 6)');
    buffer.writeln(subDivider);
    if (_allBookings.isEmpty) {
      buffer.writeln('No bookings found.');
    } else {
      buffer.writeln('');
      for (var i = 0; i < _allBookings.take(6).length; i++) {
        final booking = _allBookings.take(6).elementAt(i);
        final vehicle = booking['vehicles'] as Map<String, dynamic>?;
        final user = booking['users'] as Map<String, dynamic>?;
        final status = booking['status'] as String? ?? 'pending';
        final total = (booking['total_cost'] as num?)?.toDouble() ?? 0;

        final vehicleName = vehicle != null
            ? '${vehicle['brand']} ${vehicle['model']}'
            : 'Unknown Vehicle';
        final userName = user?['full_name'] ?? 'Unknown User';

        buffer.writeln('Booking ${i + 1}:');
        buffer.writeln('  Vehicle: $vehicleName');
        buffer.writeln('  Renter: $userName');
        buffer.writeln('  Status: $status');
        buffer.writeln('  Amount: PHP ${total.toStringAsFixed(2)}');
        buffer.writeln('');
      }
    }

    buffer.writeln('ALL VEHICLES (${_allVehicles.length})');
    buffer.writeln(subDivider);
    if (_allVehicles.isEmpty) {
      buffer.writeln('No vehicles found.');
    } else {
      buffer.writeln('');
      for (var i = 0; i < _allVehicles.take(10).length; i++) {
        final vehicle = _allVehicles.take(10).elementAt(i);
        final owner = vehicle['owner'] as Map<String, dynamic>?;
        final status = vehicle['status'] as String? ?? 'pending';
        final price = vehicle['price_per_day'] ?? 0;

        final vehicleName = '${vehicle['brand']} ${vehicle['model']}';
        final ownerName = owner?['full_name'] ?? 'Unknown';

        buffer.writeln('Vehicle ${i + 1}: $vehicleName');
        buffer.writeln('  Owner: $ownerName');
        buffer.writeln('  Price per Day: PHP $price');
        buffer.writeln('  Status: $status');
        buffer.writeln('');
      }
    }

    final pendingRecords = _verificationRecords
        .where(
          (r) =>
              (r['verification_status']?.toString().toLowerCase() ?? '') ==
              'pending',
        )
        .toList();

    buffer.writeln('PENDING VERIFICATIONS (${pendingRecords.length})');
    buffer.writeln(subDivider);
    if (pendingRecords.isEmpty) {
      buffer.writeln('All verifications have been reviewed!');
    } else {
      buffer.writeln('');
      for (var i = 0; i < pendingRecords.take(10).length; i++) {
        final app = pendingRecords.take(10).elementAt(i);
        final user = app['users'] as Map<String, dynamic>?;
        final appId = app['id'] ?? 'N/A';
        final partnerName = user?['full_name'] ?? 'Unknown';

        buffer.writeln('Verification ${i + 1}: $appId');
        buffer.writeln('  User: $partnerName');
        buffer.writeln('  Status: Pending Review');
        buffer.writeln('');
      }
    }

    buffer.writeln(divider);
    buffer.writeln('End of Report');
    buffer.writeln(divider);

    return buffer.toString();
  }

  Widget _buildActionLogsContent(bool isDark) {
    final search = _actionLogSearchQuery.trim().toLowerCase();
    final category = _actionLogCategoryFilter;
    final roleFilter = _actionLogRoleFilter.toLowerCase();

    final filteredLogs = _actionLogs.where((log) {
      final matchesSearch =
          search.isEmpty ||
          (log['notes']?.toString().toLowerCase().contains(search) ?? false) ||
          (log['actor_name']?.toString().toLowerCase().contains(search) ??
              false) ||
          (log['actor_role']?.toString().toLowerCase().contains(search) ??
              false) ||
          (log['booking_id']?.toString().toLowerCase().contains(search) ??
              false) ||
          (log['action_type']?.toString().toLowerCase().contains(search) ??
              false) ||
          (log['category']?.toString().toLowerCase().contains(search) ?? false);

      if (!matchesSearch) return false;

      if (roleFilter != 'all') {
        final logRole = (log['actor_role']?.toString() ?? '').toLowerCase();
        if (logRole != roleFilter) return false;
      }

      if (category == 'all') return true;
      final logCat = log['category']?.toString() ?? '';
      if (category == 'refunds_payouts') {
        return logCat == 'REFUNDS & PAYOUTS';
      }
      if (category == 'desk_payments') {
        return logCat == 'DESK PAYMENT MPIN' || logCat == 'OPERATOR MPIN';
      }
      if (category == 'extensions') {
        return logCat == 'TRIP EXTENSION';
      }
      if (category == 'approvals') {
        return logCat == 'BOOKING APPROVAL' || logCat == 'PARTNER APPROVAL';
      }
      if (category == 'drivers') return logCat == 'DRIVER ASSIGNMENT';
      if (category == 'pricing_vehicles') {
        return logCat == 'PRICING & VEHICLES' || logCat == 'PARTNER FLEET';
      }
      if (category == 'renters') return logCat == 'RENTER REQUEST';
      if (category == 'payments') {
        return logCat == 'PAYMENT CONFIRMED' ||
            logCat == 'RETURN INSPECTION' ||
            logCat == 'RELEASE INSPECTION' ||
            logCat == 'TRIP PICKUP' ||
            logCat == 'TRIP RETURN' ||
            logCat == 'TRIP COMPLETED';
      }
      if (category == 'verifications') return logCat == 'USER VERIFICATION';

      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fact_check_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Action & Audit Logs',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      color: Colors.green,
                                      size: 8,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'REALTIME AUDIT',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Comprehensive audit trail tracking operator actions, partner approvals, driver payouts, security deposit refunds, desk MPINs, and renter requests across Mobilis.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (val) =>
                      setState(() => _actionLogSearchQuery = val),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by Booking ID, Actor, Operator, Partner, Driver, Reference...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Role Filters
                Row(
                  children: [
                    Text(
                      'FILTER BY ROLE:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildActionLogRoleChip('all', 'All Roles', isDark),
                            const SizedBox(width: 8),
                            _buildActionLogRoleChip('operator', 'Operator', isDark),
                            const SizedBox(width: 8),
                            _buildActionLogRoleChip('partner', 'Partner', isDark),
                            const SizedBox(width: 8),
                            _buildActionLogRoleChip('driver', 'Driver', isDark),
                            const SizedBox(width: 8),
                            _buildActionLogRoleChip('admin', 'Admin', isDark),
                            const SizedBox(width: 8),
                            _buildActionLogRoleChip('renter', 'Renter', isDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Category Filters
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionLogCategoryChip('all', 'All Activity', isDark),
                    _buildActionLogCategoryChip(
                      'refunds_payouts',
                      'Refunds & Disbursements',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'desk_payments',
                      'Desk MPIN Payments',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'extensions',
                      'Trip Extensions',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'approvals',
                      'Approvals',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'drivers',
                      'Driver Assignments',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'pricing_vehicles',
                      'Pricing & Fleet',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'renters',
                      'Renter Requests',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'payments',
                      'Returns & Payments',
                      isDark,
                    ),
                    _buildActionLogCategoryChip(
                      'verifications',
                      'Verifications',
                      isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logs List
          Expanded(
            child: _isLoadingActionLogs
                ? const Center(child: CircularProgressIndicator())
                : filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 48,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No action logs found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          search.isNotEmpty
                              ? 'Try clearing your search query'
                              : 'System action logs will appear here live in real-time.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final item = filteredLogs[index];
                      return _buildActionLogCard(item, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionLogRoleChip(String key, String label, bool isDark) {
    final isSelected = _actionLogRoleFilter.toLowerCase() == key.toLowerCase();
    return InkWell(
      onTap: () => setState(() => _actionLogRoleFilter = key),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActionLogCategoryChip(String key, String label, bool isDark) {
    final isSelected = _actionLogCategoryFilter == key;
    return InkWell(
      onTap: () => setState(() => _actionLogCategoryFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActionLogCard(Map<String, dynamic> item, bool isDark) {
    final category = item['category']?.toString() ?? 'SYSTEM';
    final notes = item['notes']?.toString() ?? '';
    final actorName = item['actor_name']?.toString() ?? 'System';
    final actorRole = item['actor_role']?.toString() ?? 'operator';
    final timestampStr = item['timestamp']?.toString() ?? '';
    final bookingId = item['booking_id']?.toString() ?? '';

    Color iconColor = AppColors.primary;
    IconData iconData = Icons.info_rounded;
    Color badgeBg = AppColors.primary.withValues(alpha: 0.15);
    Color badgeText = AppColors.primary;

    if (category == 'REFUNDS & PAYOUTS') {
      iconColor = const Color(0xFF059669);
      iconData = Icons.account_balance_wallet_rounded;
      badgeBg = const Color(0xFF059669).withValues(alpha: 0.18);
      badgeText = const Color(0xFF059669);
    } else if (category == 'PRICING & VEHICLES' || category == 'PARTNER FLEET') {
      iconColor = const Color(0xFF6366F1);
      iconData = Icons.sell_rounded;
      badgeBg = const Color(0xFF6366F1).withValues(alpha: 0.18);
      badgeText = const Color(0xFF6366F1);
    } else if (category == 'TRIP PICKUP') {
      iconColor = const Color(0xFF0891B2);
      iconData = Icons.key_rounded;
      badgeBg = const Color(0xFF0891B2).withValues(alpha: 0.18);
      badgeText = const Color(0xFF0891B2);
    } else if (category == 'TRIP RETURN') {
      iconColor = const Color(0xFF0D9488);
      iconData = Icons.assignment_turned_in_rounded;
      badgeBg = const Color(0xFF0D9488).withValues(alpha: 0.18);
      badgeText = const Color(0xFF0D9488);
    } else if (category == 'DESK PAYMENT MPIN') {
      iconColor = const Color(0xFFD97706);
      iconData = Icons.pin_outlined;
      badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.18);
      badgeText = const Color(0xFFD97706);
    } else if (category == 'OPERATOR MPIN') {
      iconColor = const Color(0xFFF59E0B);
      iconData = Icons.shield_outlined;
      badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.18);
      badgeText = const Color(0xFFF59E0B);
    } else if (category == 'TRIP EXTENSION') {
      iconColor = const Color(0xFF0284C7);
      iconData = Icons.update_rounded;
      badgeBg = const Color(0xFF0284C7).withValues(alpha: 0.18);
      badgeText = const Color(0xFF0284C7);
    } else if (category == 'BOOKING APPROVAL' || category == 'PARTNER APPROVAL') {
      iconColor = Colors.green;
      iconData = Icons.check_circle_rounded;
      badgeBg = Colors.green.withValues(alpha: 0.15);
      badgeText = Colors.green;
    } else if (category == 'DRIVER ASSIGNMENT') {
      iconColor = Colors.blue;
      iconData = Icons.badge_rounded;
      badgeBg = Colors.blue.withValues(alpha: 0.15);
      badgeText = Colors.blue;
    } else if (category == 'RENTER REQUEST') {
      iconColor = Colors.purple;
      iconData = Icons.directions_car_rounded;
      badgeBg = Colors.purple.withValues(alpha: 0.15);
      badgeText = Colors.purple;
    } else if (category == 'PAYMENT CONFIRMED') {
      iconColor = Colors.amber.shade700;
      iconData = Icons.payments_rounded;
      badgeBg = Colors.amber.withValues(alpha: 0.18);
      badgeText = Colors.amber.shade700;
    } else if (category == 'RETURN INSPECTION' || category == 'RELEASE INSPECTION') {
      iconColor = Colors.orange;
      iconData = Icons.fact_check_rounded;
      badgeBg = Colors.orange.withValues(alpha: 0.15);
      badgeText = Colors.orange;
    } else if (category == 'USER VERIFICATION') {
      iconColor = Colors.teal;
      iconData = Icons.verified_user_rounded;
      badgeBg = Colors.teal.withValues(alpha: 0.15);
      badgeText = Colors.teal;
    }

    final parsedTime = DateTime.tryParse(timestampStr);

    return InkWell(
      onTap: () => _showActionLogDetailModal(context, item, isDark),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgSecondary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Avatar
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: badgeText,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        actorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          actorRole.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (bookingId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Booking ID: ${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Timestamp
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (parsedTime != null)
                  RelativeTimeText(
                    value: parsedTime,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 2),
                if (parsedTime != null)
                  Text(
                    '${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showActionLogDetailModal(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
  ) {
    final metadata = item['metadata'] is Map ? Map<String, dynamic>.from(item['metadata']) : <String, dynamic>{};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Audit Log Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAuditDetailRow('Category', item['category']?.toString() ?? 'SYSTEM', isDark),
                _buildAuditDetailRow('Action Type', item['action_type']?.toString() ?? 'N/A', isDark),
                _buildAuditDetailRow('Actor Name', item['actor_name']?.toString() ?? 'System', isDark),
                _buildAuditDetailRow('Actor Role', (item['actor_role']?.toString() ?? 'Operator').toUpperCase(), isDark),
                _buildAuditDetailRow('Timestamp', item['timestamp']?.toString() ?? 'N/A', isDark),
                if (item['booking_id'] != null && item['booking_id'].toString().isNotEmpty)
                  _buildAuditDetailRow('Booking ID', item['booking_id'].toString(), isDark),
                const Divider(height: 24),
                const Text(
                  'Event Description',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item['notes']?.toString() ?? 'No description provided.',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
                if (metadata.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Metadata Payload',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black38 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: metadata.entries
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e.key}: ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${e.value}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade700),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Safety & Incident Reports ─────────────────────────────────────────────

  Future<void> _loadUserReports({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoadingReports = true);
    }
    try {
      final reports = await ReportService().getPendingReports();
      if (!mounted) return;
      setState(() {
        _userReports = reports;
        _pendingReportsCount = reports.where((r) => r['status'] == 'pending').length;
      });
    } catch (e) {
      debugPrint('Error loading user reports: $e');
    } finally {
      if (mounted && showLoading) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  Future<void> _banUserFromReportDialog(Map<String, dynamic> report, bool isDark) async {
    final reportedUser = report['reported_user'] as Map<String, dynamic>?;
    final reportedName = reportedUser?['full_name']?.toString() ?? 'User';
    final reportedEmail = reportedUser?['email']?.toString() ?? '';
    final reportedRole = reportedUser?['role']?.toString().toUpperCase() ?? 'PARTICIPANT';
    final reportedUserId = report['reported_user_id']?.toString() ?? '';
    final reportId = report['id']?.toString() ?? '';
    final category = report['category']?.toString() ?? 'General Incident';
    final description = report['description']?.toString() ?? '';

    final reasonController = TextEditingController(
      text: 'Incident violation ($category): $description',
    );

    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          final bg = isDark ? _adminNavyDeep : Colors.white;
          final cardBg = isDark ? const Color(0xFF021F35) : const Color(0xFFF8FAFC);
          final textColor = isDark ? Colors.white : _adminInk;

          return Dialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.gavel_rounded,
                            color: Colors.red,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ban User Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Immediate suspension of app access & bookings',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                reportedName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  reportedRole,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (reportedEmail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              reportedEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Report Category: $category\n"$description"',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Reason for Ban (Logged in Audit Trail):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      style: TextStyle(fontSize: 13, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Enter specific justification for banning this account...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final reason = reasonController.text.trim();
                                  if (reason.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please provide a reason for the ban.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final currentAdminId = _supabase.auth.currentUser?.id ?? '';
                                    await ReportService().banReportedUser(
                                      reportId: reportId,
                                      reportedUserId: reportedUserId,
                                      adminId: currentAdminId,
                                      banReason: reason,
                                    );
                                    if (mounted) {
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Account for $reportedName has been permanently banned.'),
                                          backgroundColor: Colors.red.shade700,
                                        ),
                                      );
                                      await _loadUserReports(showLoading: false);
                                      await _loadAllUsers();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (dialogContext.mounted) {
                                      setModalState(() => isSubmitting = false);
                                    }
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.block_rounded, size: 16),
                          label: Text(isSubmitting ? 'Banning...' : 'Confirm Ban'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
      ),
    );
  }

  Future<void> _resolveReportDialog(Map<String, dynamic> report, bool isDark) async {
    final reportId = report['id']?.toString() ?? '';
    final notesController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          final bg = isDark ? _adminNavyDeep : Colors.white;
          final textColor = isDark ? Colors.white : _adminInk;

          return AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Resolve Incident Report',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mark this report as resolved or settled with the involved parties.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    style: TextStyle(fontSize: 13, color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Resolution Notes / Settlement Details',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setModalState(() => isSubmitting = true);
                        try {
                          final currentAdminId = _supabase.auth.currentUser?.id ?? '';
                          await ReportService().resolveReport(
                            reportId: reportId,
                            adminId: currentAdminId,
                            resolutionNotes: notesController.text.trim().isNotEmpty
                                ? notesController.text.trim()
                                : 'Resolved by Admin after review',
                          );
                          if (mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report marked as resolved.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await _loadUserReports(showLoading: false);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setModalState(() => isSubmitting = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(isSubmitting ? 'Saving...' : 'Mark Resolved'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReportEvidenceDialog(Map<String, dynamic> report, bool isDark) {
    final evidenceUrls = report['evidence_urls'];
    final List<String> urls = [];
    if (evidenceUrls is List) {
      for (final u in evidenceUrls) {
        if (u != null && u.toString().isNotEmpty) {
          urls.add(u.toString());
        }
      }
    } else if (evidenceUrls is String && evidenceUrls.isNotEmpty) {
      urls.add(evidenceUrls);
    }

    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No evidence files attached to this report.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? _adminNavyDeep : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Report Attached Evidence',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: urls.length,
                    itemBuilder: (context, index) {
                      final url = urls[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: OptimizedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: Colors.grey.shade300,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
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
    );
  }

  Widget _buildReportsContent(bool isDark) {
    final search = _reportSearchQuery.trim().toLowerCase();
    final filter = _reportStatusFilter;

    final filteredReports = _userReports.where((report) {
      final category = report['category']?.toString().toLowerCase() ?? '';
      final description = report['description']?.toString().toLowerCase() ?? '';
      final status = report['status']?.toString().toLowerCase() ?? '';
      final bookingId = report['booking_id']?.toString().toLowerCase() ?? '';
      final reporter = report['reporter'] as Map<String, dynamic>?;
      final reportedUser = report['reported_user'] as Map<String, dynamic>?;
      final reporterName = reporter?['full_name']?.toString().toLowerCase() ?? '';
      final reportedName = reportedUser?['full_name']?.toString().toLowerCase() ?? '';

      final matchesSearch = search.isEmpty ||
          category.contains(search) ||
          description.contains(search) ||
          bookingId.contains(search) ||
          reporterName.contains(search) ||
          reportedName.contains(search);

      if (!matchesSearch) return false;

      if (filter == 'pending') return status == 'pending';
      if (filter == 'resolved') return status == 'resolved' || status == 'dismissed';
      if (filter == 'banned') return status == 'banned' || reportedUser?['is_blocked'] == true || reportedUser?['is_active'] == false;

      return true;
    }).toList();

    final pendingCount = _userReports.where((r) => r['status'] == 'pending').length;
    final resolvedCount = _userReports.where((r) => r['status'] == 'resolved' || r['status'] == 'dismissed').length;
    final bannedCount = _userReports.where((r) {
      final user = r['reported_user'] as Map<String, dynamic>?;
      return r['status'] == 'banned' || user?['is_blocked'] == true || user?['is_active'] == false;
    }).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Safety & Incident Reports',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (pendingCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.amber.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.amber,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$pendingCount PENDING ACTION',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Review participant complaints regarding unreturned security deposits, fraudulent post-trip damage claims, and take immediate ban actions.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Reports',
                      onPressed: () => _loadUserReports(showLoading: true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _reportSearchQuery = val),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by reporter, violator, booking ID, reason...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildReportCategoryChip('all', 'All (${_userReports.length})', isDark),
                      const SizedBox(width: 8),
                      _buildReportCategoryChip('pending', 'Pending ($pendingCount)', isDark),
                      const SizedBox(width: 8),
                      _buildReportCategoryChip('resolved', 'Resolved ($resolvedCount)', isDark),
                      const SizedBox(width: 8),
                      _buildReportCategoryChip('banned', 'Banned Accounts ($bannedCount)', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Reports List
          Expanded(
            child: _isLoadingReports
                ? const Center(child: CircularProgressIndicator())
                : filteredReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 56,
                              color: Colors.green.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No Safety Reports Found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              search.isNotEmpty || filter != 'all'
                                  ? 'Try clearing the filters or search keywords'
                                  : 'No disputes or violations reported yet.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredReports.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) => _buildReportCard(
                          filteredReports[index],
                          isDark,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCategoryChip(String key, String label, bool isDark) {
    final isSelected = _reportStatusFilter == key;
    return InkWell(
      onTap: () => setState(() => _reportStatusFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.red.withValues(alpha: 0.18)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.red
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.red
                : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isDark) {
    final status = report['status']?.toString().toLowerCase() ?? 'pending';
    final category = report['category']?.toString() ?? 'General Incident';
    final description = report['description']?.toString() ?? '';
    final bookingId = report['booking_id']?.toString() ?? '';
    final createdAt = report['created_at']?.toString();
    final parsedTime = createdAt != null ? DateTime.tryParse(createdAt) : null;

    final reporter = report['reporter'] as Map<String, dynamic>?;
    final reporterName = reporter?['full_name']?.toString() ?? 'Reporter';
    final reporterRole = reporter?['role']?.toString().toUpperCase() ?? 'USER';

    final reportedUser = report['reported_user'] as Map<String, dynamic>?;
    final reportedName = reportedUser?['full_name']?.toString() ?? 'Reported User';
    final reportedRole = reportedUser?['role']?.toString().toUpperCase() ?? 'USER';
    final isUserBlocked = reportedUser?['is_blocked'] == true || reportedUser?['is_active'] == false;

    final evidenceUrls = report['evidence_urls'];
    final bool hasEvidence = evidenceUrls != null &&
        ((evidenceUrls is List && evidenceUrls.isNotEmpty) ||
            (evidenceUrls is String && evidenceUrls.isNotEmpty));

    Color statusBg = Colors.amber.withValues(alpha: 0.15);
    Color statusColor = Colors.amber;
    String statusLabel = 'PENDING REVIEW';

    if (status == 'resolved') {
      statusBg = Colors.green.withValues(alpha: 0.15);
      statusColor = Colors.green;
      statusLabel = 'RESOLVED';
    } else if (status == 'banned' || isUserBlocked) {
      statusBg = Colors.red.withValues(alpha: 0.15);
      statusColor = Colors.red;
      statusLabel = 'USER BANNED';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF021F35) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUserBlocked
              ? Colors.red.withValues(alpha: 0.4)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isUserBlocked ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: category badge, status, timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.report_problem_rounded, size: 13, color: Colors.red),
                    const SizedBox(width: 6),
                    Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (parsedTime != null)
                RelativeTimeText(
                  value: parsedTime,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Parties Row
          Row(
            children: [
              // Reporter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_pin_circle_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Reported By (Victim/Complainant):',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            reporterName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              reporterRole,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Reported Violator
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUserBlocked
                        ? Colors.red.withValues(alpha: 0.08)
                        : (isDark ? Colors.black26 : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUserBlocked
                          ? Colors.red.withValues(alpha: 0.3)
                          : (isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                          const SizedBox(width: 6),
                          Text(
                            'Reported Party (Alleged Violator):',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            reportedName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isUserBlocked ? Colors.red : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isUserBlocked
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isUserBlocked ? 'BANNED' : reportedRole,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isUserBlocked ? Colors.red : Colors.orange.shade800,
                              ),
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
          const SizedBox(height: 12),

          // Incident details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              description.isNotEmpty ? description : 'No description provided.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Booking reference & actions row
          Row(
            children: [
              if (bookingId.isNotEmpty) ...[
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Booking: ${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              if (hasEvidence) ...[
                OutlinedButton.icon(
                  onPressed: () => _showReportEvidenceDialog(report, isDark),
                  icon: const Icon(Icons.attach_file_rounded, size: 14),
                  label: const Text('View Evidence Photo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const Spacer(),

              // Action buttons: Resolve and Ban
              if (status == 'pending') ...[
                OutlinedButton.icon(
                  onPressed: () => _resolveReportDialog(report, isDark),
                  icon: const Icon(Icons.check, size: 14, color: Colors.green),
                  label: const Text('Resolve', style: TextStyle(color: Colors.green)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              if (!isUserBlocked)
                ElevatedButton.icon(
                  onPressed: () => _banUserFromReportDialog(report, isDark),
                  icon: const Icon(Icons.gavel_rounded, size: 14),
                  label: const Text('Ban Violator'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 14, color: Colors.red),
                      SizedBox(width: 6),
                      Text(
                        'Account Blocked',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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

// ── Animated check/info modal used by admin settings ─────────────────────────
class _AdminCheckModal extends StatefulWidget {
  final String title;
  final String message;
  final Color accentColor;
  final IconData icon;

  const _AdminCheckModal({
    required this.title,
    required this.message,
    required this.accentColor,
    required this.icon,
  });

  @override
  State<_AdminCheckModal> createState() => _AdminCheckModalState();
}

class _AdminCheckModalState extends State<_AdminCheckModal>
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
            width: 300,
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
                      'OK',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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
