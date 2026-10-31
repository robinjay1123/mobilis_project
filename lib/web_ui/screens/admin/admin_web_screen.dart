import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/input_validation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../utils/web_html.dart' as html;
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
import '../../../services/admin_report_service.dart';
import 'admin_report_dialog.dart';
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
import '../../../widgets/gps_tracker_telemetry_card.dart';
import '../../../utils/web_html.dart' as html;
import '../../theme/web_portal_theme.dart';
import '../../../utils/booking_status.dart';
import '../../../services/report_service.dart';
import '../../../services/user_restriction_service.dart';
import '../../../services/booking_viewed_service.dart';
import '../../../services/trip_rating_service.dart';
import '../../../services/audit_service.dart';
import '../../../services/voucher_service.dart';

part 'tabs/admin_reports_tab.dart';
part 'tabs/admin_action_logs_tab.dart';
part 'tabs/admin_settings_tab.dart';
part 'tabs/admin_announcements_tab.dart';
part 'tabs/admin_customer_service_tab.dart';
part 'tabs/admin_analytics_tab.dart';
part 'tabs/admin_applications_tab.dart';
part 'tabs/admin_verifications_tab.dart';
part 'tabs/admin_tracking_tab.dart';
part 'tabs/admin_bookings_tab.dart';
part 'tabs/admin_vehicles_tab.dart';
part 'tabs/admin_archived_accounts_tab.dart';
part 'tabs/admin_users_tab.dart';
part 'tabs/admin_dashboard_tab.dart';
part 'tabs/admin_vouchers_tab.dart';

const int _recentBookingsPerPage = 5;
const int _commissionHistoryPerPage = 10;

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
  List<Map<String, dynamic>> _pendingDriverApplications = [];
  List<Map<String, dynamic>> _trackingLocations = [];
  String? _focusedTrackingBookingId;
  Timer? _trackingRefreshTimer;
  Timer? _notificationsRefreshTimer;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _announcements = [];
  Timer? _announcementRefreshTimer;
  List<VoucherModel> _vouchers = [];
  bool _isLoadingVouchers = false;
  String _voucherSearchQuery = '';
  String _selectedVoucherCategoryFilter = 'all';
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
  RealtimeChannel? _bookingsSubscription;
  Timer? _bookingsSilentRefreshTimer;
  Timer? _bookingsRealtimeDebounce;

  // Vehicles tab & search state
  String _vehicleTabFilter = 'all'; // 'all', 'psdc', 'partner'
  String _vehicleSearchQuery = '';
  String _vehicleViewMode = 'cards'; // 'cards' vs 'table'

  // Commission & Disbursement History state
  String _commissionSearchQuery = '';
  String _commissionRoleFilter = 'all'; // 'all', 'partner', 'driver'
  String _commissionStatusFilter = 'all'; // 'all', 'disbursed', 'pending'
  int _commissionHistoryPage = 1;

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
  Timer? _actionLogsRealtimeDebounce;
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
  bool _revealAllApplicationDocuments = false;
  bool _revealAllVerificationDocuments = false;
  final Set<String> _revealedCardIds = {};
  Timer? _verificationsAndApplicationsRefreshTimer;
  Timer? _verificationsRealtimeDebounce;
  RealtimeChannel? _verificationsSubscription;
  RealtimeChannel? _applicationsSubscription;
  RealtimeChannel? _driversSubscription;

  // Pagination & Search
  int _currentUserPage = 1;
  final int _usersPerPage = 10;
  String _userSearchQuery = '';
  String _userRoleFilter = 'all';
  String _userVerificationFilter = 'all'; // 'all', 'verified', 'unverified'

  // Archived Accounts state
  int _currentArchivedPage = 1;
  final int _archivedPerPage = 10;
  String _archivedSearchQuery = '';
  String _archivedRoleFilter = 'all';
  int get _archivedUsersCount =>
      _allUsers.where((u) => u['is_archived'] == true).length;

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
    _setupVerificationsAndApplicationsRealtimeListener();
    // Fallback sync intervals: Supabase Realtime listeners handle instant live updates
    _bookingsSilentRefreshTimer = Timer.periodic(
      const Duration(seconds: 120),
      (_) {
        if (mounted && (_selectedIndex == 2 || _selectedIndex == 0)) {
          _loadAllBookings();
        }
      },
    );
    _verificationsAndApplicationsRefreshTimer = Timer.periodic(
      const Duration(seconds: 120),
      (_) {
        if (mounted && (_selectedIndex == 4 || _selectedIndex == 5 || _selectedIndex == 0)) {
          _refreshVerificationsAndApplicationsSilently();
        }
      },
    );
    _trackingRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (mounted && _selectedIndex == 10) {
          _refreshTrackingLocations();
        }
      },
    );
    _actionLogsRefreshTimer = Timer.periodic(
      const Duration(seconds: 120),
      (_) {
        if (mounted && (_selectedIndex == 12 || _selectedIndex == 0)) {
          _loadActionLogs(showLoading: false);
        }
      },
    );
    _announcementRefreshTimer = Timer.periodic(
      const Duration(seconds: 180),
      (_) => _refreshAnnouncementsIfVisible(),
    );
    _notificationsRefreshTimer = Timer.periodic(
      const Duration(seconds: 120),
      (_) => _loadNotifications(showLoading: false),
    );
    _userReportsRefreshTimer = Timer.periodic(
      const Duration(seconds: 180),
      (_) {
        if (mounted && (_selectedIndex == 13 || _selectedIndex == 0)) {
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
    _bookingsRealtimeDebounce?.cancel();
    _verificationsAndApplicationsRefreshTimer?.cancel();
    _verificationsRealtimeDebounce?.cancel();
    _actionLogsRealtimeDebounce?.cancel();
    _bookingsSubscription?.unsubscribe();
    _verificationsSubscription?.unsubscribe();
    _applicationsSubscription?.unsubscribe();
    _driversSubscription?.unsubscribe();
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
              _bookingsRealtimeDebounce?.cancel();
              _bookingsRealtimeDebounce = Timer(
                const Duration(milliseconds: 2000),
                () {
                  if (mounted) {
                    _loadAllBookings();
                  }
                },
              );
            }
          },
        )
        .subscribe();
  }

  void _setupVerificationsAndApplicationsRealtimeListener() {
    void handleVerificationOrAppChange(PostgresChangePayload payload) {
      if (mounted) {
        _verificationsRealtimeDebounce?.cancel();
        _verificationsRealtimeDebounce = Timer(
          const Duration(milliseconds: 2000),
          () {
            if (mounted) {
              _refreshVerificationsAndApplicationsSilently();
            }
          },
        );
      }
    }

    _verificationsSubscription = _supabase
        .channel('admin-verifications-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_verifications',
          callback: handleVerificationOrAppChange,
        )
        .subscribe();

    _applicationsSubscription = _supabase
        .channel('admin-applications-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'partner_vehicle_applications',
          callback: handleVerificationOrAppChange,
        )
        .subscribe();

    _driversSubscription = _supabase
        .channel('admin-drivers-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers',
          callback: handleVerificationOrAppChange,
        )
        .subscribe();
  }

  Future<void> _refreshVerificationsAndApplicationsSilently() async {
    if (!mounted) return;
    try {
      await Future.wait([
        _loadPendingVerifications(),
        _loadPendingPartnerVehicleApplications(),
        _loadPendingDriverApplications(),
      ]);
      if (mounted) {
        setState(() {
          _pendingVerifications = _verificationRecords
              .where((v) =>
                  (v['verification_status'] ?? '').toString().toLowerCase() ==
                  'pending')
              .length;
          _pendingApplicationsCount = _pendingPartnerVehicleApplications.length +
              _pendingDriverApplications.length;
        });
      }
    } catch (e) {
      debugPrint('Error silently refreshing verifications & applications: $e');
    }
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
      final bgHydrationTasks = <Future<void>>[
        _loadAllVehicles(),
        _loadPendingVerifications(),
        _loadPendingPartnerVehicleApplications(),
        _loadPendingDriverApplications(),
        _loadNotifications(showLoading: false),
        _loadAnnouncements(),
      ];
      if (_selectedIndex == 10) {
        bgHydrationTasks.add(_loadTrackingLocationsFast());
      }
      unawaited(
        Future.wait(bgHydrationTasks).then((_) {
          if (mounted) {
            setState(() {
              _pendingApplicationsCount =
                  _pendingPartnerVehicleApplications.length +
                      _pendingDriverApplications.length;
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
    void handleActionLogChange(PostgresChangePayload _) {
      if (mounted) {
        _actionLogsRealtimeDebounce?.cancel();
        _actionLogsRealtimeDebounce = Timer(
          const Duration(milliseconds: 1000),
          () {
            if (mounted && (_selectedIndex == 12 || _selectedIndex == 0)) {
              _loadActionLogs(showLoading: false);
            }
          },
        );
      }
    }

    _actionLogsSubscription = _supabase
        .channel('admin-action-logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'admin_audit_logs',
          callback: handleActionLogChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: handleActionLogChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'booking_events',
          callback: handleActionLogChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'booking_vehicle_inspections',
          callback: handleActionLogChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'favorite_vehicles',
          callback: handleActionLogChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'partner_vehicle_applications',
          callback: handleActionLogChange,
        )
        .subscribe();
  }

  Future<void> _loadAnnouncements() async {
    _announcements = await AdminService().getRecentAnnouncements();
  }

  Future<void> _loadVouchers() async {
    if (_isLoadingVouchers) return;
    _isLoadingVouchers = true;
    if (mounted) setState(() {});
    try {
      final list = await VoucherService().getVouchers();
      if (mounted) {
        setState(() {
          _vouchers = list;
          _isLoadingVouchers = false;
        });
      }
    } catch (e) {
      debugPrint('AdminWebScreen: Error loading vouchers: $e');
      if (mounted) {
        setState(() => _isLoadingVouchers = false);
      }
    }
  }

  void setAdminState(VoidCallback fn) {
    if (mounted) setState(fn);
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
              .select('id, total_price, status');
          final bList = List<Map<String, dynamic>>.from(totalBookingsResponse);
          _totalBookings = bList.length;
          _pendingBookingsCount =
              bList.where((b) => (b['status']?.toString() ?? '').toLowerCase() == 'pending').length;
          _activeBookings =
              bList.where((b) {
                final st = (b['status']?.toString() ?? '').toLowerCase();
                return st == 'active' || st == 'ongoing' || st == 'in_progress';
              }).length;
          final validRevenueBookings = bList.where((b) => _isValidRevenueBooking(b));
          _totalRevenue = validRevenueBookings.fold(
            0.0,
            (sum, b) => sum + ((b['total_price'] as num?)?.toDouble() ?? (b['total_cost'] as num?)?.toDouble() ?? 0),
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

  bool _isValidRevenueBooking(Map<String, dynamic> b) {
    final status = (b['status']?.toString() ?? '').toLowerCase().trim();
    if (status.isEmpty) return false;
    // Strictly EXCLUDE cancelled, rejected, declined, refunded, pending, or draft bookings
    if (status == 'cancelled' ||
        status == 'canceled' ||
        status == 'rejected' ||
        status == 'declined' ||
        status == 'refunded' ||
        status == 'pending' ||
        status == 'draft') {
      return false;
    }
    // Only count confirmed, active, ongoing, completed, paid, in_progress, returned
    return status == 'completed' ||
        status == 'active' ||
        status == 'ongoing' ||
        status == 'confirmed' ||
        status == 'paid' ||
        status == 'in_progress' ||
        status == 'returned' ||
        status == 'to_return';
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
            (b) {
              final st = (b['status'] as String? ?? '').toLowerCase();
              return st == 'active' || st == 'ongoing' || st == 'in_progress';
            },
          )
          .length;
      final validRevenueBookings = _allBookings.where((b) => _isValidRevenueBooking(b));
      _totalRevenue = validRevenueBookings.fold(
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
              'verification_status, updated_at, avatar_url, '
              'is_archived, is_active, is_blocked, restriction_level',
            )
            .order('created_at', ascending: false)
            .then((res) => List<Map<String, dynamic>>.from(res))
            .catchError((e) async {
              try {
                final fallback = await _supabase
                    .from('users')
                    .select(
                      'id, email, full_name, phone, role, created_at, id_verified, '
                      'verification_status, updated_at, avatar_url, '
                      'is_archived, is_active',
                    )
                    .order('created_at', ascending: false);
                return List<Map<String, dynamic>>.from(fallback);
              } catch (_) {
                try {
                  final fallback2 = await _supabase
                      .from('users')
                      .select(
                        'id, email, full_name, phone, role, created_at, '
                        'is_active',
                      )
                      .order('created_at', ascending: false);
                  return List<Map<String, dynamic>>.from(fallback2);
                } catch (_) {
                  try {
                    final fallback3 = await _supabase
                        .from('users')
                        .select('id, email, full_name, phone, role, created_at')
                        .order('created_at', ascending: false);
                    return List<Map<String, dynamic>>.from(fallback3);
                  } catch (_) {
                    return <Map<String, dynamic>>[];
                  }
                }
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
      final pendingUserIds = <String>{};
      for (final v in verifications) {
        final uid = v['user_id']?.toString() ?? '';
        final statusStr =
            v['verification_status']?.toString().trim().toLowerCase() ?? '';
        if (uid.isNotEmpty) {
          if (statusStr == 'approved' ||
              statusStr == 'verified' ||
              statusStr == 'certified') {
            approvedUserIds.add(uid);
          } else if (statusStr == 'pending' || statusStr == 'submitted') {
            pendingUserIds.add(uid);
          }
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
        if (uid.isNotEmpty) {
          if (isVer || statusStr == 'approved' || statusStr == 'verified') {
            approvedUserIds.add(uid);
          } else if (statusStr == 'pending' || statusStr == 'submitted') {
            pendingUserIds.add(uid);
          }
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
        final driverVerStatus =
            driverData?['verification_status']?.toString().trim().toLowerCase() ?? '';

        final isPending = !isAdminOrOperator &&
            (pendingUserIds.contains(userId) ||
                verStatus == 'pending' ||
                verStatus == 'submitted' ||
                (userRole == 'driver' &&
                    (driverVerStatus == 'pending' || driverVerStatus == 'submitted')));

        final idVerified =
            user['id_verified'] == true || user['is_verified'] == true;
        final isVerified = isAdminOrOperator ||
            (!isPending &&
                (approvedUserIds.contains(userId) ||
                    verStatus == 'approved' ||
                    verStatus == 'verified' ||
                    verStatus == 'certified' ||
                    idVerified));

        final displayVerStatus = isPending
            ? 'pending'
            : (isVerified ? 'verified' : (verStatus.isNotEmpty ? verStatus : 'unverified'));

        final isArchived = user['is_archived'] == true ||
            (user['is_active'] == false &&
                (user['restriction_reason']?.toString().toLowerCase().contains('archiv') == true ||
                 user['archive_reason']?.toString().isNotEmpty == true));

        userList.add({
          ...user,
          'id_verified': isVerified,
          'is_verified': isVerified,
          'verification_status': displayVerStatus,
          'display_verification_status': displayVerStatus,
          'is_psdc_driver': isPsdcDriver,
          'driver_id': driverData?['id'],
          'is_archived': isArchived,
          'archived_at': user['archived_at'] ??
              (isArchived ? (user['updated_at'] ?? user['created_at']) : null),
        });
      }

      for (final v in verificationUsers) {
        final uMap = v['users'] as Map<String, dynamic>?;
        final uid =
            uMap?['id']?.toString() ?? v['user_id']?.toString() ?? '';
        if (uid.isNotEmpty && !seenUserIds.contains(uid)) {
          seenUserIds.add(uid);
          final statusStr =
              v['verification_status']?.toString().trim().toLowerCase() ?? '';
          final isVer = statusStr == 'approved' ||
              statusStr == 'verified' ||
              statusStr == 'certified';
          final isPend = statusStr == 'pending' || statusStr == 'submitted';
          final displayStatus = isPend ? 'pending' : (isVer ? 'verified' : 'unverified');
          final isArchived = uMap?['is_archived'] == true ||
              (uMap?['is_active'] == false &&
                  (uMap?['restriction_reason']?.toString().toLowerCase().contains('archiv') == true ||
                   uMap?['archive_reason']?.toString().isNotEmpty == true));

          userList.add({
            'id': uid,
            'email': uMap?['email'] ?? 'User Email',
            'full_name': uMap?['full_name'] ?? 'User ($uid)',
            'phone': uMap?['phone'] ?? '',
            'role': uMap?['role'] ?? 'renter',
            'created_at':
                uMap?['created_at'] ?? DateTime.now().toIso8601String(),
            'id_verified': isVer,
            'is_verified': isVer,
            'verification_status': displayStatus,
            'display_verification_status': displayStatus,
            'avatar_url': uMap?['avatar_url'],
            'is_archived': isArchived,
            'archived_at': uMap?['archived_at'] ??
                (isArchived ? (uMap?['updated_at'] ?? uMap?['created_at']) : null),
          });
        }
      }

      _allUsers = userList;
      _totalUsers = _allUsers.where((u) => u['is_archived'] != true).length;
      _totalPartners = _allUsers
          .where(
            (user) =>
                user['is_archived'] != true &&
                (user['role'] as String? ?? '').toLowerCase() == 'partner',
          )
          .length;
      _totalOperators = _allUsers
          .where(
            (user) =>
                user['is_archived'] != true &&
                (user['role'] as String? ?? '').toLowerCase() == 'operator',
          )
          .length;

      debugPrint(
        'Admin: successfully loaded ${_allUsers.length} users (${_allUsers.where((u) => u['is_archived'] == true).length} archived)',
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
              partner_id,
              vehicle_images(image_url, display_order)
            ),
            renter:users!bookings_renter_id_fkey (id, full_name, email, phone),
            drivers:drivers!bookings_driver_id_fkey (
              id,
              user_id,
              users:users!drivers_user_id_fkey (id, full_name, email, phone)
            )
          ''')
          .order('created_at', ascending: false)
          .limit(300); // Limit prevents full-table scan as historical bookings grow

      var rawBookings = List<Map<String, dynamic>>.from(response);
      try {
        rawBookings = await BookingService().hydrateBookingVehicles(rawBookings);
      } catch (hErr) {
        debugPrint('Admin bookings vehicle hydration note: $hErr');
      }

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
            owner:users!vehicles_owner_id_fkey (full_name, email, role)
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

  Future<void> _refreshTrackingLocations() async {
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
      debugPrint('Error refreshing tracking locations: $e');
    }
  }

  bool _canTrackBooking(Map<String, dynamic> booking) {
    final status = (booking['status'] as String? ?? '').toLowerCase();
    return status == 'active' ||
        status == 'approved' ||
        status == 'confirmed' ||
        status == 'ongoing' ||
        status == 'in_progress' ||
        status == 'picked_up';
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
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _loadPendingVerifications() async {
    try {
      final response = await _supabase
          .from('user_verifications')
          .select('''
            *,
            users:user_id (id, full_name, email, role, verification_status, application_status, id_verified)
          ''')
          .order('created_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(response);

      await Future.wait(
        records.map((record) async {
          final user = record['users'] as Map<String, dynamic>?;
          final userId =
              record['user_id']?.toString() ?? user?['id']?.toString();

          final userRole = (user?['role']?.toString() ?? record['role']?.toString() ?? '')
              .toLowerCase()
              .trim();
          if (userRole.isNotEmpty) {
            record['role'] = userRole;
            if (user != null) user['role'] = userRole;
          }

          if (userId != null && userId.isNotEmpty && userRole == 'driver') {
            final docs = await Future.wait([
              _loadDriverSignatureUrl(userId),
              _loadDriverNbiUrl(userId),
            ]);
            record['driver_signature_url'] = docs[0];
            record['driver_nbi_url'] = docs[1];
          }
        }),
      );

      _verificationRecords = records;
    } catch (e) {
      debugPrint('Error loading verifications: $e');
      _verificationRecords = [];
    }
  }

  Future<void> _loadPendingDriverApplications() async {
    try {
      // 1. Fetch drivers with joined user profiles
      final driversResponse = await _supabase
          .from('drivers')
          .select('''
            *,
            users:user_id (id, full_name, email, phone, role, avatar_url, location, is_active, verification_status, application_status, id_verified, created_at)
          ''');

      // 2. Fetch user verifications for ID documents and application metrics
      final verificationsResponse = await _supabase
          .from('user_verifications')
          .select('*')
          .order('created_at', ascending: false);

      final verificationsMap = <String, Map<String, dynamic>>{};
      for (final v in List<Map<String, dynamic>>.from(verificationsResponse)) {
        final uid = v['user_id']?.toString() ?? '';
        if (uid.isNotEmpty && !verificationsMap.containsKey(uid)) {
          verificationsMap[uid] = v;
        }
      }

      final applications = <Map<String, dynamic>>[];

      for (final d in List<Map<String, dynamic>>.from(driversResponse)) {
        final user = d['users'] as Map<String, dynamic>?;
        if (user == null || user['is_active'] == false) continue;

        final userId = user['id']?.toString() ?? d['user_id']?.toString() ?? '';
        if (userId.isEmpty) continue;

        // Partner or staff accounts must never be treated as driver applicants
        final role = (user['role']?.toString() ?? '').toLowerCase().trim();
        if (role == 'partner' || role == 'admin' || role == 'operator' || role == 'superadmin') {
          continue;
        }

        final verRecord = verificationsMap[userId];

        // 1. User must be identity verified (in users table or in user_verifications)
        final userVerStatus = (user['verification_status']?.toString() ?? '').toLowerCase().trim();
        final isIdVerified = user['id_verified'] == true ||
            userVerStatus == 'verified' ||
            userVerStatus == 'approved' ||
            (verRecord?['verification_status']?.toString().toLowerCase() == 'verified');

        if (!isIdVerified) {
          continue;
        }

        // 2. Application status must be strictly pending (not approved / already verified in DB)
        final userAppStatus = (user['application_status']?.toString() ?? '').toLowerCase().trim();
        final driverVerStatus = (d['verification_status']?.toString() ?? '').toLowerCase().trim();

        // If driver is already verified/approved in database (e.g. bypassed in DB), they are not pending
        if (driverVerStatus == 'verified' ||
            driverVerStatus == 'approved' ||
            userAppStatus == 'approved' ||
            userAppStatus == 'rejected') {
          continue;
        }

        final isPending = userAppStatus == 'pending' ||
            userAppStatus == 'submitted' ||
            userAppStatus == 'under_review' ||
            driverVerStatus == 'pending' ||
            driverVerStatus == 'submitted' ||
            driverVerStatus.isEmpty;

        if (isPending) {
          final idParts = (verRecord?['id_document_url'] as String? ?? '').split('|');
          final legacyIdUrls = idParts
              .where((part) => part.trim().isNotEmpty)
              .map((part) => part.trim())
              .toList();

          final appMap = <String, dynamic>{
            'id': verRecord?['id'] ?? d['id'],
            'driver_id': d['id'],
            'user_id': userId,
            'full_name': user['full_name'] ?? verRecord?['full_name'] ?? 'Driver Applicant',
            'email': user['email'] ?? verRecord?['email'],
            'phone': user['phone'] ?? verRecord?['phone'],
            'location': user['location'] ?? verRecord?['location'],
            'avatar_url': user['avatar_url'],
            'created_at': d['created_at'] ?? verRecord?['created_at'] ?? user['created_at'],
            'application_status': userAppStatus.isNotEmpty ? userAppStatus : 'pending',
            'verification_status': 'verified',
            'id_type': verRecord?['id_type'] ?? 'Driver License',
            'id_number': verRecord?['id_number'],
            'id_document_url': verRecord?['id_document_url'],
            'id_front_url': verRecord?['id_front_url'] ?? (legacyIdUrls.isNotEmpty ? legacyIdUrls.first : ''),
            'id_back_url': verRecord?['id_back_url'] ?? (legacyIdUrls.length > 1 ? legacyIdUrls[1] : ''),
            'face_selfie_url': verRecord?['face_selfie_url'] ?? '',
            'selfie_with_id_url': verRecord?['selfie_with_id_url'] ?? '',
            'driver_years_experience': verRecord?['driver_years_experience'] ?? d['years_experience']?.toString(),
            'driver_previous_companies': verRecord?['driver_previous_companies'] ?? d['previous_companies']?.toString(),
            'driver_license_expiry': verRecord?['driver_license_expiry'] ?? d['license_expiry']?.toString(),
            'rejection_reason': verRecord?['rejection_reason'] ?? d['rejection_reason'],
            'users': user,
            'driver': d,
          };

          final docs = await Future.wait([
            _loadDriverSignatureUrl(userId),
            _loadDriverNbiUrl(userId),
          ]);
          appMap['driver_signature_url'] = docs[0];
          appMap['driver_nbi_url'] = docs[1];

          applications.add(appMap);
        }
      }

      _pendingDriverApplications = applications;
    } catch (e) {
      debugPrint('Error loading pending driver applications: $e');
      _pendingDriverApplications = [];
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
      await Future.wait(
        applications.map((application) async {
          application['photo_urls'] =
              await _loadVehicleApplicationPhotoUrls(application);
        }),
      );
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

  /// Shows an elegant, non-dismissible loading modal with a spinner and action description.
  /// Returns a dismissal callback function to be called in a finally block.
  void Function() _showActionLoadingModal(String title, [String? subtitle]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    BuildContext? modalContext;
    var isOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) {
        modalContext = dialogCtx;
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1F2D) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle ?? 'Applying changes and notifying applicant...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return () {
      if (isOpen) {
        isOpen = false;
        if (modalContext != null && Navigator.canPop(modalContext!)) {
          Navigator.pop(modalContext!);
        } else if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    };
  }

  /// Displays an aesthetic, non-intrusive action completion modal for successful operations.
  Future<void> _showActionSuccessModal({
    required String title,
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color iconColor = Colors.green,
    String buttonText = 'Done',
  }) async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1F2D) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 34,
                        color: iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: iconColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

    final appId = application['id']?.toString();
    final partnerId = application['partner_id']?.toString();
    if (appId == null ||
        appId.isEmpty ||
        partnerId == null ||
        partnerId.isEmpty) {
      throw Exception('Invalid application payload');
    }

    final vehicleTitle =
        '${application['brand'] ?? 'Vehicle'} ${application['model'] ?? ''}'.trim();
    final dismissLoading = _showActionLoadingModal(
      'Approving ${vehicleTitle.isEmpty ? 'Vehicle Application' : vehicleTitle}...',
      'Configuring vehicle profile and activating partner fleet...',
    );

    // Immediate action: optimistically update UI state
    if (mounted) {
      setState(() {
        _pendingPartnerVehicleApplications.removeWhere(
          (app) => app['id']?.toString() == appId,
        );
        _pendingApplicationsCount = _pendingPartnerVehicleApplications.length;
      });
    }

    try {
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
          'fuel_type': application['fuel_type'] ?? 'Gasoline',
          'transmission': application['transmission'] ?? 'Manual',
          'vehicle_type': application['vehicle_type'] ?? application['category'] ?? 'Partner Vehicle',
          'owner_is_driver': application['owner_is_driver'] ?? false,
          'status': 'available',
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
              'fuel_type': application['fuel_type'] ?? 'Gasoline',
              'transmission': application['transmission'] ?? 'Manual',
              'vehicle_type': application['vehicle_type'] ?? application['category'] ?? 'Partner Vehicle',
              'owner_is_driver': application['owner_is_driver'] ?? false,
              'rating': 0.0,
              'rating_count': 0,
              'status': 'available',
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

      // Audit Log: Vehicle Application Approved
      try {
        await AuditService().logAdminAction(
          action: 'vehicle_application_approved',
          category: 'PARTNER FLEET',
          entityId: partnerVehicleId.toString(),
          entityType: 'vehicle_application',
          partnerId: partnerId,
          vehicleId: partnerVehicleId.toString(),
          notes: 'Admin approved partner vehicle application: ${vehicleTitle.isNotEmpty ? vehicleTitle : 'Vehicle'} (Plate: ${application['plate_number'] ?? 'N/A'}) for Partner $partnerName',
          metadata: {
            'application_id': appId,
            'partner_id': partnerId,
            'partner_name': partnerName,
            'vehicle_name': vehicleTitle,
            'plate_number': application['plate_number'],
            'price_per_day': application['price_per_day'],
            'owner_is_driver': application['owner_is_driver'],
          },
        );
      } catch (auditErr) {
        debugPrint('Warning logging vehicle approval audit: $auditErr');
      }

      dismissLoading();
      if (!mounted) return;
      _showActionSuccessModal(
        title: 'Vehicle Application Approved',
        message:
            '${vehicleTitle.isEmpty ? 'The vehicle application' : vehicleTitle} has been successfully approved and added to the fleet.',
        icon: Icons.check_circle_rounded,
        iconColor: Colors.green,
      );
      _refreshVerificationsAndApplicationsSilently();
      _loadAllVehicles();
      _loadAllUsers();
    } catch (e) {
      // Revert optimistic removal on failure
      _refreshVerificationsAndApplicationsSilently();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approval failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      dismissLoading();
    }
  }

  Future<void> _rejectPartnerVehicleApplication(
    Map<String, dynamic> application,
  ) async {
    final rejectionReason = await _showVehicleRejectionDialog();
    if (rejectionReason == null || rejectionReason.trim().isEmpty) return;

    final appId = application['id']?.toString();
    if (appId == null || appId.isEmpty) {
      throw Exception('Invalid application payload');
    }

    final vehicleTitle =
        '${application['brand'] ?? 'Vehicle'} ${application['model'] ?? ''}'.trim();
    final dismissLoading = _showActionLoadingModal(
      'Rejecting ${vehicleTitle.isEmpty ? 'Vehicle Application' : vehicleTitle}...',
      'Updating application status and notifying partner...',
    );

    // Immediate action: optimistically update UI state
    if (mounted) {
      setState(() {
        _pendingPartnerVehicleApplications.removeWhere(
          (app) => app['id']?.toString() == appId,
        );
        _pendingApplicationsCount = _pendingPartnerVehicleApplications.length;
      });
    }

    try {
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

      // Audit Log: Vehicle Application Rejected
      try {
        final partnerId = application['partner_id']?.toString();
        await AuditService().logAdminAction(
          action: 'vehicle_application_rejected',
          category: 'PARTNER FLEET',
          entityId: appId,
          entityType: 'vehicle_application',
          partnerId: partnerId,
          vehicleId: partnerVehicleId,
          notes: 'Admin rejected vehicle application: ${vehicleTitle.isNotEmpty ? vehicleTitle : 'Vehicle'} (Plate: ${plateNumber ?? application['plate_number'] ?? 'N/A'}). Reason: ${rejectionReason.trim()}',
          metadata: {
            'application_id': appId,
            'partner_id': partnerId,
            'vehicle_name': vehicleTitle,
            'plate_number': plateNumber ?? application['plate_number'],
            'rejection_reason': rejectionReason.trim(),
          },
        );
      } catch (auditErr) {
        debugPrint('Warning logging vehicle rejection audit: $auditErr');
      }

      dismissLoading();
      if (!mounted) return;
      _showActionSuccessModal(
        title: 'Vehicle Application Rejected',
        message:
            '${vehicleTitle.isEmpty ? 'The vehicle application' : vehicleTitle} has been rejected with feedback sent to the partner.',
        icon: Icons.cancel_rounded,
        iconColor: Colors.redAccent,
      );
      _refreshVerificationsAndApplicationsSilently();
    } catch (e) {
      _refreshVerificationsAndApplicationsSilently();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rejection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      dismissLoading();
    }
  }

  Future<void> _approveDriverApplication(Map<String, dynamic> driverApp) async {
    final user = driverApp['users'] as Map<String, dynamic>?;
    final submittedName = (driverApp['full_name'] as String?)?.trim();
    final profileName = (user?['full_name'] as String?)?.trim();
    final displayName = submittedName?.isNotEmpty == true
        ? submittedName!
        : (profileName?.isNotEmpty == true ? profileName! : 'Driver Applicant');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF021F35) : Colors.white,
        title: const Text(
          'Approve Driver Application?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will approve $displayName\'s onboarding application and activate their driver profile, making them immediately eligible for dispatch job assignments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve Driver'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final rawUserId = driverApp['user_id']?.toString() ??
        user?['id']?.toString() ??
        driverApp['id']?.toString() ??
        '';
    final userId = rawUserId.replaceFirst('fallback_', '');
    if (userId.isEmpty) return;

    final dismissLoading = _showActionLoadingModal(
      'Approving $displayName as driver...',
      'Activating driver profile and dispatch eligibility...',
    );

    // Immediate action: optimistically update UI state
    if (mounted) {
      setState(() {
        driverApp['application_status'] = 'approved';
        if (user != null) user['application_status'] = 'approved';
        _pendingDriverApplications.removeWhere(
          (app) =>
              (app['user_id']?.toString() == userId) ||
              (app['id']?.toString() == driverApp['id']?.toString()) ||
              (app['driver_id']?.toString() == driverApp['driver_id']?.toString()),
        );
        _pendingApplicationsCount = _pendingPartnerVehicleApplications.length +
            _pendingDriverApplications.length;
      });
    }

    try {
      // 1. Update user record: application_status = 'approved', role = 'driver', verification_status = 'verified', id_verified = true, is_available = false
      await _supabase.from('users').update({
        'role': 'driver',
        'application_status': 'approved',
        'verification_status': 'verified',
        'id_verified': true,
        'is_available': false,
      }).eq('id', userId);

      // 2. Sync / activate driver profile in drivers table (starts as is_available: false until driver sets schedule)
      try {
        final existingDriver = await _supabase
            .from('drivers')
            .select('id, license_number')
            .eq('user_id', userId)
            .maybeSingle();

        if (existingDriver == null) {
          await _supabase.from('drivers').insert({
            'user_id': userId,
            'license_number': 'LIC-$userId',
            'license_expiry': DateTime.now().add(const Duration(days: 365 * 3)).toIso8601String().split('T').first,
            'license_verified': true,
            'nbi_verified': true,
            'verification_status': 'verified',
            'driver_tier': 'standard',
            'rating': 0.0,
            'total_trips': 0,
          });
        } else {
          await _supabase.from('drivers').update({
            'verification_status': 'verified',
            'license_verified': true,
            'nbi_verified': true,
          }).eq('id', existingDriver['id']);
        }
      } catch (driverSyncErr) {
        debugPrint('Error syncing drivers table on approval: $driverSyncErr');
      }

      // 3. If there is a user_verifications record, mark it verified
      try {
        await _supabase.from('user_verifications').update({
          'verification_status': 'verified',
          'verified_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);
      } catch (_) {}

      // 4. Send real-time notification to the driver
      try {
        await NotificationService().createNotification(
          userId: userId,
          title: 'Driver Application Approved! 🎉',
          message: 'Congratulations! Your driver onboarding application has been approved. You are now eligible for booking job assignments.',
          type: 'driver_application_approved',
          data: {'event': 'driver_approved', 'user_id': userId},
        );
      } catch (_) {}

      // Audit Log: Driver Application Approved
      try {
        await AuditService().logAdminAction(
          action: 'driver_application_approved',
          category: 'DRIVER APPLICATION',
          entityId: userId,
          entityType: 'driver_application',
          driverId: userId,
          notes: 'Admin approved driver onboarding application for $displayName ($userId)',
          metadata: {
            'driver_user_id': userId,
            'driver_name': displayName,
            'driver_tier': 'standard',
            'action': 'approved',
          },
        );
      } catch (auditErr) {
        debugPrint('Warning logging driver approval audit: $auditErr');
      }

      dismissLoading();
      if (!mounted) return;
      _showActionSuccessModal(
        title: 'Driver Application Approved',
        message:
            '$displayName has been approved as an official driver and is now eligible for job assignments.',
        icon: Icons.check_circle_rounded,
        iconColor: Colors.green,
      );
      _refreshVerificationsAndApplicationsSilently();
      _loadAllUsers();
    } catch (e) {
      debugPrint('Error approving driver application: $e');
      _refreshVerificationsAndApplicationsSilently();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approval failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      dismissLoading();
    }
  }

  Future<void> _rejectDriverApplication(Map<String, dynamic> driverApp) async {
    final user = driverApp['users'] as Map<String, dynamic>?;
    final submittedName = (driverApp['full_name'] as String?)?.trim();
    final profileName = (user?['full_name'] as String?)?.trim();
    final displayName = submittedName?.isNotEmpty == true
        ? submittedName!
        : (profileName?.isNotEmpty == true ? profileName! : 'Driver Applicant');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reason = await _showRejectionReasonDialog(
      context,
      displayName,
      isDark,
    );
    if (reason == null || reason.trim().isEmpty) return;

    final rawUserId = driverApp['user_id']?.toString() ??
        user?['id']?.toString() ??
        driverApp['id']?.toString() ??
        '';
    final userId = rawUserId.replaceFirst('fallback_', '');
    if (userId.isEmpty) return;

    final dismissLoading = _showActionLoadingModal(
      'Rejecting application for $displayName...',
      'Updating driver application status...',
    );

    // Immediate action: optimistically update UI state
    if (mounted) {
      setState(() {
        driverApp['application_status'] = 'rejected';
        driverApp['rejection_reason'] = reason;
        if (user != null) user['application_status'] = 'rejected';
        _pendingDriverApplications.removeWhere(
          (app) =>
              (app['user_id']?.toString() == userId) ||
              (app['id']?.toString() == driverApp['id']?.toString()) ||
              (app['driver_id']?.toString() == driverApp['driver_id']?.toString()),
        );
        _pendingApplicationsCount = _pendingPartnerVehicleApplications.length +
            _pendingDriverApplications.length;
      });
    }

    try {
      await _supabase.from('users').update({
        'application_status': 'rejected',
      }).eq('id', userId);

      try {
        await _supabase.from('drivers').update({
          'verification_status': 'rejected',
        }).eq('user_id', userId);
      } catch (_) {}

      try {
        await _supabase.from('user_verifications').update({
          'verification_status': 'rejected',
          'rejection_reason': reason,
          'verified_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);
      } catch (_) {}

      try {
        await NotificationService().createNotification(
          userId: userId,
          title: 'Driver Application Update',
          message: 'Your driver onboarding application was not approved. Reason: $reason',
          type: 'driver_application_rejected',
          data: {'event': 'driver_rejected', 'user_id': userId, 'reason': reason},
        );
      } catch (_) {}

      // Audit Log: Driver Application Rejected
      try {
        await AuditService().logAdminAction(
          action: 'driver_application_rejected',
          category: 'DRIVER APPLICATION',
          entityId: userId,
          entityType: 'driver_application',
          driverId: userId,
          notes: 'Admin rejected driver application for $displayName ($userId). Reason: ${reason.trim()}',
          metadata: {
            'driver_user_id': userId,
            'driver_name': displayName,
            'rejection_reason': reason.trim(),
            'action': 'rejected',
          },
        );
      } catch (auditErr) {
        debugPrint('Warning logging driver rejection audit: $auditErr');
      }

      dismissLoading();
      if (!mounted) return;
      _showActionSuccessModal(
        title: 'Driver Application Rejected',
        message:
            'The driver onboarding application for $displayName has been rejected with feedback sent.',
        icon: Icons.cancel_rounded,
        iconColor: Colors.redAccent,
      );
      _refreshVerificationsAndApplicationsSilently();
      _loadAllUsers();
    } catch (e) {
      debugPrint('Error rejecting driver application: $e');
      _refreshVerificationsAndApplicationsSilently();
    } finally {
      dismissLoading();
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
              'rating': 0.0,
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
            'rating': 0.0,
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
            'rating': 0.0,
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

  Future<void> _archiveUser(dynamic userOrId) async {
    final Map<String, dynamic>? user = userOrId is Map<String, dynamic>
        ? userOrId
        : _allUsers.firstWhere(
            (u) => u['id'] == userOrId,
            orElse: () => {'id': userOrId.toString()},
          );
    final userId = user?['id']?.toString() ?? userOrId.toString();
    final userName = user?['full_name'] ?? 'User ($userId)';
    final userEmail = user?['email'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.archive_rounded, color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Archive User Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to archive $userName${userEmail.isNotEmpty ? ' ($userEmail)' : ''}?',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The user account will be deactivated and moved to the Archived Accounts section. All historical bookings, payments, and activity logs will be safely preserved. You can restore this account at any time.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade900, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Archive Account'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dismissLoading = _showActionLoadingModal(
        'Archiving account for $userName...',
        'Deactivating user profile and preserving account history...',
      );
      final nowStr = DateTime.now().toIso8601String();

      // Optimistic in-memory update so UI reflects the archived state immediately
      setState(() {
        for (final u in _allUsers) {
          if (u['id']?.toString() == userId) {
            u['is_archived'] = true;
            u['is_active'] = false;
            u['archived_at'] = nowStr;
            u['archive_reason'] = 'Archived by admin';
            u['restriction_reason'] = 'Archived by admin';
          }
        }
        _totalUsers = _allUsers.where((u) => u['is_archived'] != true).length;
      });

      try {
        try {
          await _supabase.from('users').update({
            'is_archived': true,
            'is_active': false,
          }).eq('id', userId);
        } catch (e) {
          debugPrint('Notice: standard archive update fallback: $e');
          await _supabase.from('users').update({
            'is_active': false,
          }).eq('id', userId);
        }

        dismissLoading();
        if (!mounted) return;
        _showActionSuccessModal(
          title: 'Account Archived',
          message:
              'The account for $userName has been deactivated and moved to Archived Accounts.',
          icon: Icons.archive_rounded,
          iconColor: Colors.orange.shade800,
        );
        _loadDashboardData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error archiving user: $e'), backgroundColor: Colors.red),
        );
        _loadDashboardData();
      } finally {
        dismissLoading();
      }
    }
  }

  Future<void> _restoreUser(dynamic userOrId) async {
    final Map<String, dynamic>? user = userOrId is Map<String, dynamic>
        ? userOrId
        : _allUsers.firstWhere(
            (u) => u['id'] == userOrId,
            orElse: () => {'id': userOrId.toString()},
          );
    final userId = user?['id']?.toString() ?? userOrId.toString();
    final userName = user?['full_name'] ?? 'User ($userId)';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.unarchive_rounded, color: Colors.green, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Restore User Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to restore $userName to active status?\n\n'
          'The account will be reactivated and will reappear in the active Users list.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Restore Account'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dismissLoading = _showActionLoadingModal(
        'Restoring account for $userName...',
        'Reactivating user profile and restoring permissions...',
      );

      // Optimistic in-memory update so UI reflects the restored state immediately
      setState(() {
        for (final u in _allUsers) {
          if (u['id']?.toString() == userId) {
            u['is_archived'] = false;
            u['is_active'] = true;
            u['archived_at'] = null;
            u['archive_reason'] = null;
            u['restriction_reason'] = null;
          }
        }
        _totalUsers = _allUsers.where((u) => u['is_archived'] != true).length;
      });

      try {
        try {
          await _supabase.from('users').update({
            'is_archived': false,
            'is_active': true,
          }).eq('id', userId);
        } catch (e) {
          await _supabase.from('users').update({
            'is_active': true,
          }).eq('id', userId);
        }

        dismissLoading();
        if (!mounted) return;
        _showActionSuccessModal(
          title: 'Account Restored',
          message:
              'The account for $userName has been reactivated and restored to active status.',
          icon: Icons.unarchive_rounded,
          iconColor: Colors.green,
        );
        _loadDashboardData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring user: $e'), backgroundColor: Colors.red),
        );
        _loadDashboardData();
      } finally {
        dismissLoading();
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
      case 14:
        return 'Archived Accounts';
      case 15:
        return 'Vouchers & Loyalty';
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
      case 14:
        return _buildArchivedAccountsContent(isDark);
      case 15:
        return _buildVouchersContent(isDark);
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
          _buildNavItem(
            14,
            Icons.archive_rounded,
            'Archived Accounts',
            isDark,
            badge: _archivedUsersCount > 0 ? _archivedUsersCount : null,
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
          _buildNavItem(
            15,
            Icons.confirmation_number_rounded,
            'Vouchers & Loyalty',
            isDark,
          ),
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
              _loadActionLogs(showLoading: _actionLogs.isEmpty);
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
            } else if (index == 15) {
              if (_vouchers.isEmpty) {
                _loadVouchers();
              }
            } else if (index == 10) {
              _refreshTrackingLocations();
            } else if (index == 2) {
              if (_allVehicles.isEmpty) {
                _loadAllVehicles();
              }
            } else if (index == 4) {
              _refreshVerificationsAndApplicationsSilently();
            } else if (index == 5) {
              _refreshVerificationsAndApplicationsSilently();
            }
          });
          _persistSelectedTab(index);
          _syncWebUrl(index);
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

  static const Map<int, String> _adminTabSlugs = {
    0: 'overview',
    1: 'users',
    2: 'vehicles',
    3: 'bookings',
    4: 'verifications',
    5: 'applications',
    6: 'message-review',
    7: 'customer-service',
    8: 'analytics',
    9: 'announcements',
    10: 'tracking',
    11: 'settings',
    12: 'action-logs',
    13: 'safety-reports',
    14: 'archived-accounts',
    15: 'vouchers',
  };

  static const Map<String, int> _adminSlugToTab = {
    'home': 0,
    'overview': 0,
    'dashboard': 0,
    'users': 1,
    'user': 1,
    'vehicles': 2,
    'fleet': 2,
    'bookings': 3,
    'booking': 3,
    'verifications': 4,
    'verification': 4,
    'applications': 5,
    'application': 5,
    'message-review': 6,
    'messages': 6,
    'customer-service': 7,
    'support': 7,
    'analytics': 8,
    'revenue': 8,
    'announcements': 9,
    'tracking': 10,
    'live-tracking': 10,
    'gps': 10,
    'settings': 11,
    'action-logs': 12,
    'logs': 12,
    'safety-reports': 13,
    'reports': 13,
    'archived-accounts': 14,
    'archived': 14,
    'vouchers': 15,
    'voucher': 15,
    'loyalty': 15,
    'discounts': 15,
    'promotions': 15,
  };

  void _syncWebUrl(int index) {
    if (!kIsWeb) return;
    try {
      final slug = _adminTabSlugs[index] ?? 'overview';
      final currentUri = Uri.base;
      final newUrl = '${currentUri.origin}/#/admin-home?tab=$slug';
      html.window.history.replaceState(null, '', newUrl);
    } catch (_) {}
  }

  Future<void> _persistSelectedTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('mobilis_admin_web_tab', index);
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

        if (tabParam != null && _adminSlugToTab.containsKey(tabParam.toLowerCase().trim())) {
          initialTab = _adminSlugToTab[tabParam.toLowerCase().trim()];
        }
      } catch (_) {}
    }

    if (initialTab == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedIndex = prefs.getInt('mobilis_admin_web_tab');
        if (savedIndex != null &&
            savedIndex >= 0 &&
            savedIndex <= 15) {
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
    if (_selectedIndex == 10) {
      await _refreshTrackingLocations();
      if (mounted) setState(() {});
      return;
    }
    if (_selectedIndex == 7) {
      await _loadSupportInbox();
      return;
    }
    if (_selectedIndex == 12) {
      await _loadActionLogs(showLoading: false);
      return;
    }
    if (_selectedIndex == 15) {
      await _loadVouchers();
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

  // ── Dashboard extracted to tabs/admin_dashboard_tab.dart ──

  // ── Users extracted to tabs/admin_users_tab.dart ──

  // ── Archived Accounts extracted to tabs/admin_archived_accounts_tab.dart ──

  // ── Vehicles extracted to tabs/admin_vehicles_tab.dart ──

  // ── Bookings extracted to tabs/admin_bookings_tab.dart ──

  String _adminVehicleImageUrl(Map<String, dynamic>? vehicle, [Map<String, dynamic>? booking]) {
    if (vehicle == null && booking == null) return '';
    final direct = (vehicle?['image_url'] ??
            vehicle?['imageUrl'] ??
            vehicle?['photo_url'] ??
            vehicle?['vehicle_image_url'] ??
            vehicle?['thumbnail_url'] ??
            booking?['vehicle_image_url'] ??
            booking?['image_url'] ??
            booking?['photo_url'])
        ?.toString()
        .trim() ??
        '';
    if (direct.isNotEmpty) return direct;

    final rawImages = (vehicle?['vehicle_images'] ??
            vehicle?['images'] ??
            vehicle?['photos']) as List? ??
        const [];
    final images = List<Map<String, dynamic>>.from(
      rawImages.whereType<Map<String, dynamic>>(),
    )..sort((a, b) {
        final aOrder = (a['display_order'] as num?)?.toInt() ?? 999;
        final bOrder = (b['display_order'] as num?)?.toInt() ?? 999;
        return aOrder.compareTo(bOrder);
      });
    for (final image in images) {
      final url = (image['image_url'] ?? image['url'] ?? image['image'])
          ?.toString()
          .trim() ?? '';
      if (url.isNotEmpty) return url;
    }
    return '';
  }

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
      final real = _allVehicles.firstWhere(
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

    var title = '';
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

    if (title.isEmpty || title == 'Partner Vehicle' || title == 'Vehicle') {
      if (deviceId.isNotEmpty) {
        title = 'GPS Tracker $deviceId (Standby)';
      } else {
        title = loc['has_active_booking'] == true ? 'Tracked Trip' : 'Tracked Vehicle';
      }
    }

    final plate = vehicle?['plate_number']?.toString().trim() ?? '';
    if (plate.isNotEmpty && !title.contains(plate) && !title.startsWith('GPS Tracker')) {
      return '$title ($plate)';
    }
    return title;
  }

  // ── Tracking extracted to tabs/admin_tracking_tab.dart ──

  // ── Verifications extracted to tabs/admin_verifications_tab.dart ──

  // ── Applications extracted to tabs/admin_applications_tab.dart ──

  Widget _buildMessageReviewContent(bool isDark) {
    return AdminMessageReviewScreen(isDarkMode: isDark);
  }

  // ── Analytics extracted to tabs/admin_analytics_tab.dart ──

  // ── Customer Service extracted to tabs/admin_customer_service_tab.dart ──

  // ── Announcements extracted to tabs/admin_announcements_tab.dart ──

  // ── Settings extracted to tabs/admin_settings_tab.dart ──


  // ── Action Logs extracted to tabs/admin_action_logs_tab.dart ──

  // ── Safety & Incident Reports ─────────────────────────────────────────────

  // ── Safety & Incident Reports extracted to tabs/admin_reports_tab.dart ──
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

class AdminSpecItem {
  final String label;
  final String value;
  final IconData? icon;
  final Color? highlightColor;

  const AdminSpecItem({
    required this.label,
    required this.value,
    this.icon,
    this.highlightColor,
  });
}

class AdminCollageItem {
  final String title;
  final String? url;
  final String? subtitle;
  final IconData placeholderIcon;

  const AdminCollageItem({
    required this.title,
    this.url,
    this.subtitle,
    this.placeholderIcon = Icons.insert_drive_file_outlined,
  });

  bool get hasUrl => (url ?? '').trim().isNotEmpty;
}
