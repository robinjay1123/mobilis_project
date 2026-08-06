import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/input_validation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../mobile_ui/theme/app_colors.dart';
import '../../../mobile_ui/widgets/optimized_network_image.dart';
import '../../../mobile_ui/widgets/leaflet_map.dart';
import '../../../mobile_ui/widgets/relative_time_text.dart';
import '../../../services/reservation_payment_service.dart';
import '../../../services/terms_service.dart';
import '../../../services/tracking_service.dart';
import '../../../services/verification_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/gps_service.dart';
import '../../../services/admin_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/support_faq_service.dart';
import '../../../mobile_ui/screens/admin/message_review_screen.dart';
import '../../../mobile_ui/screens/profile/settings_screen.dart';
import '../../../utils/web_html.dart' as html;
import '../../theme/web_portal_theme.dart';
import '../../../utils/booking_status.dart';

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

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _sidebarExpanded = true;

  // Stats
  int _totalUsers = 0;
  int _totalPartners = 0;
  int _totalOperators = 0;
  int _totalVehicles = 0;

  int _pendingVerifications = 0;
  int _activeBookings = 0;
  int _totalBookings = 0;
  double _totalRevenue = 0;

  // Lists
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allBookings = [];
  List<Map<String, dynamic>> _allVehicles = [];
  List<Map<String, dynamic>> _verificationRecords = [];
  List<Map<String, dynamic>> _pendingPartnerVehicleApplications = [];
  List<Map<String, dynamic>> _priceChangeRequests = [];
  List<Map<String, dynamic>> _trackingLocations = [];
  String? _focusedTrackingBookingId;
  Timer? _trackingRefreshTimer;
  List<Map<String, dynamic>> _announcements = [];
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

  // Action Logs state & timers
  List<Map<String, dynamic>> _actionLogs = [];
  bool _isLoadingActionLogs = false;
  String _actionLogSearchQuery = '';
  String _actionLogCategoryFilter = 'all';
  Timer? _actionLogsRefreshTimer;
  RealtimeChannel? _actionLogsSubscription;

  // Verifications & Applications tab filters
  String _verificationRoleFilter = 'all'; // 'all', 'renter', 'driver', 'partner'
  String _applicationTypeFilter = 'all'; // 'all', 'vehicle', 'driver'

  // Pagination & Search
  int _currentUserPage = 1;
  final int _usersPerPage = 10;
  String _userSearchQuery = '';
  String _userRoleFilter = 'all';
  final TextEditingController _announcementTitleController =
      TextEditingController();
  final TextEditingController _announcementMessageController =
      TextEditingController();
  final TextEditingController _supportReplyController = TextEditingController();
  String _announcementTargetRole = 'all';
  bool _isSendingAnnouncement = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupSupportMessagesListener();
    _loadActionLogs(showLoading: false);
    _setupActionLogsRealtimeListener();
    _trackingRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshTrackingLocations(),
    );
    _actionLogsRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadActionLogs(showLoading: false),
    );
  }

  @override
  void dispose() {
    _trackingRefreshTimer?.cancel();
    _actionLogsRefreshTimer?.cancel();
    _actionLogsSubscription?.unsubscribe();
    _supportMessagesSubscription?.unsubscribe();
    _supportTypingChannel?.unsubscribe();
    _supportTypingStopTimer?.cancel();
    for (final timer in _supportTypingExpiryTimers.values) {
      timer.cancel();
    }
    _announcementTitleController.dispose();
    _announcementMessageController.dispose();
    _supportReplyController.dispose();
    super.dispose();
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
      await _loadAllUsers();
      await Future.wait([
        _loadStats(),
        _loadAllBookings(),
        _loadAllVehicles(),
        _loadTrackingLocations(),
        _loadAnnouncements(),
        _loadSupportInbox(),
        _loadPendingVerifications(),
        _loadPendingPartnerVehicleApplications(),
        _loadPriceChangeRequests(),
        _loadActionLogs(showLoading: false),
      ]);
    } catch (e) {
      debugPrint('Error loading admin dashboard: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadActionLogs({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoadingActionLogs = true);
    }
    try {
      final logs = await AdminService().getSystemActionLogs(limit: 200);
      if (mounted) {
        setState(() {
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

  Future<void> _sendAnnouncement() async {
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

    setState(() => _isSendingAnnouncement = true);
    try {
      final delivered = await AdminService().publishAnnouncement(
        title: title,
        message: message,
        targetRole: _announcementTargetRole,
      );
      await _loadAnnouncements();
      if (!mounted) return;
      _announcementTitleController.clear();
      _announcementMessageController.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Announcement sent to $delivered ${_announcementTargetRole == 'all' ? 'users' : '$_announcementTargetRole users'}',
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



  Future<void> _loadStats() async {
    try {
      if (_allUsers.isNotEmpty) {
        _totalUsers = _allUsers.length;
        _totalPartners = _allUsers
            .where((user) => (user['role'] as String? ?? '').toLowerCase() == 'partner')
            .length;
        _totalOperators = _allUsers
            .where((user) => (user['role'] as String? ?? '').toLowerCase() == 'operator')
            .length;
      } else {
        final usersResponse = await _supabase.from('users').select('id, role');
        final users = List<Map<String, dynamic>>.from(usersResponse);
        _totalUsers = users.length;
        _totalPartners = users
            .where((user) => (user['role'] as String? ?? '').toLowerCase() == 'partner')
            .length;
        _totalOperators = users
            .where((user) => (user['role'] as String? ?? '').toLowerCase() == 'operator')
            .length;
      }

      final vehiclesResponse = await _supabase.from('vehicles').select('id');
      final partnerVehiclesResponse = await _supabase
          .from('partner_vehicles')
          .select('id');
      _totalVehicles =
          (vehiclesResponse as List).length +
          (partnerVehiclesResponse as List).length;

      final pendingResponse = await _supabase
          .from('user_verifications')
          .select('id')
          .eq('verification_status', 'pending');
      _pendingVerifications = (pendingResponse as List).length;

      final activeBookingsResponse = await _supabase
          .from('bookings')
          .select('id')
          .eq('status', 'active');
      _activeBookings = (activeBookingsResponse as List).length;

      final totalBookingsResponse = await _supabase
          .from('bookings')
          .select('id, total_cost');
      _totalBookings = (totalBookingsResponse as List).length;

      _totalRevenue = 0;
      for (var booking in totalBookingsResponse) {
        _totalRevenue += (booking['total_cost'] as num?)?.toDouble() ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      List<dynamic> response = [];

      // 1. Try safe select with fallback
      try {
        response = await _supabase
            .from('users')
            .select(
              'id, email, full_name, phone, role, created_at, id_verified, '
              'verification_status, updated_at, avatar_url',
            )
            .order('created_at', ascending: false);
      } catch (e1) {
        debugPrint('Detailed users query skipped, trying basic fields: $e1');
        try {
          response = await _supabase
              .from('users')
              .select('id, email, full_name, phone, role, created_at')
              .order('created_at', ascending: false);
        } catch (e2) {
          debugPrint('Basic users query error: $e2');
        }
      }

      // 2. Fetch driver data for PSDC driver merge
      List<Map<String, dynamic>> driversResponse = [];
      try {
        driversResponse = List<Map<String, dynamic>>.from(
          await _supabase
              .from('drivers')
              .select('id, user_id, is_psdc_driver, driver_tier'),
        );
      } catch (driverErr) {
        debugPrint('Could not load drivers for PSDC merge: $driverErr');
      }

      final driversMap = <String, Map<String, dynamic>>{
        for (final d in driversResponse)
          d['user_id']?.toString() ?? '': d,
      };

      final userList = <Map<String, dynamic>>[];
      final seenUserIds = <String>{};

      for (final user in List<Map<String, dynamic>>.from(response)) {
        final userId = user['id']?.toString() ?? '';
        if (userId.isEmpty) continue;
        seenUserIds.add(userId);

        final driverData = driversMap[userId];
        final isPsdcDriver = user['is_psdc_driver'] == true ||
            driverData?['is_psdc_driver'] == true ||
            driverData?['driver_tier'] == 'psdc';

        userList.add({
          ...user,
          'is_psdc_driver': isPsdcDriver,
          'driver_id': driverData?['id'],
        });
      }

      // 3. Fallback: Check if any users exist in user_verifications or bookings missing from main user query
      try {
        final verificationUsers = await _supabase
            .from('user_verifications')
            .select('user_id, users:user_id(id, email, full_name, phone, role, created_at)');
        for (final v in List<Map<String, dynamic>>.from(verificationUsers)) {
          final uMap = v['users'] as Map<String, dynamic>?;
          final uid = uMap?['id']?.toString() ?? v['user_id']?.toString() ?? '';
          if (uid.isNotEmpty && !seenUserIds.contains(uid)) {
            seenUserIds.add(uid);
            userList.add({
              'id': uid,
              'email': uMap?['email'] ?? 'User Email',
              'full_name': uMap?['full_name'] ?? 'User ($uid)',
              'phone': uMap?['phone'] ?? '',
              'role': uMap?['role'] ?? 'renter',
              'created_at': uMap?['created_at'] ?? DateTime.now().toIso8601String(),
              'id_verified': true,
            });
          }
        }
      } catch (e) {
        debugPrint('Verification users merge note: $e');
      }

      _allUsers = userList;
      _totalUsers = _allUsers.length;
      _totalPartners = _allUsers
          .where((user) => (user['role'] as String? ?? '').toLowerCase() == 'partner')
          .length;
      _totalOperators = _allUsers
          .where((user) => (user['role'] as String? ?? '').toLowerCase() == 'operator')
          .length;

      debugPrint('Admin: successfully loaded ${_allUsers.length} users');
    } on PostgrestException catch (e) {
      debugPrint('Admin _loadAllUsers Postgrest error: ${e.message} code=${e.code}');
      _allUsers = [];
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
            vehicles:vehicle_id (id, brand, model, year, plate_number, owner_id, operator_id),
            renter:renter_id (id, full_name, email),
            drivers:drivers!bookings_driver_id_fkey (
              id,
              user_id,
              users:users!drivers_user_id_fkey (id, full_name, email)
            )
          ''')
          .order('created_at', ascending: false);

      _allBookings = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      _allBookings = [];
    }
  }

  Future<void> _loadAllVehicles() async {
    try {
      final companyResponse = await _supabase
          .from('vehicles')
          .select('''
            *,
            owner:owner_id (full_name, email, role)
          ''')
          .order('created_at', ascending: false);

      final companyVehicles = List<Map<String, dynamic>>.from(companyResponse)
          .map((vehicle) {
            final merged = Map<String, dynamic>.from(vehicle);
            merged['source'] = 'company';
            merged['source_label'] = 'Company';
            return merged;
          })
          .toList();

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
      final images = await _supabase
          .from('vehicle_images')
          .select('partner_vehicle_id,image_url,display_order')
          .inFilter('partner_vehicle_id', partnerVehicleIds);
      final grouped = _groupImagesByKey(
        List<Map<String, dynamic>>.from(images),
        'partner_vehicle_id',
      );
      for (final vehicle in partnerVehicles) {
        vehicle['vehicle_images'] = grouped[vehicle['id']?.toString()] ?? [];
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

  Future<void> _loadTrackingLocations() async {
    _trackingLocations = await TrackingService().getActiveTrackingLocations();
  }

  Future<void> _refreshTrackingLocations() async {
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
    if (_focusedTrackingBookingId == null ||
        _focusedTrackingBookingId!.isEmpty) {
      return _trackingLocations;
    }

    return _trackingLocations.where((location) {
      final booking = location['bookings'] as Map<String, dynamic>?;
      return booking?['id']?.toString() == _focusedTrackingBookingId;
    }).toList();
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

  Future<void> _loadPriceChangeRequests() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      _priceChangeRequests = [];
      return;
    }

    try {
      final response = await _supabase
          .from('notifications')
          .select('id, title, message, type, data, is_read, created_at')
          .eq('user_id', currentUserId)
          .eq('type', 'price_change_request')
          .order('created_at', ascending: false);
      _priceChangeRequests = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading price change requests: $e');
      _priceChangeRequests = [];
    }
  }

  Future<void> _forwardPriceChangeRequestToOperators(
    Map<String, dynamic> request,
  ) async {
    try {
      final data = request['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(request['data'])
          : <String, dynamic>{};
      final vehicleTitle =
          data['vehicle_title']?.toString().trim().isNotEmpty == true
          ? data['vehicle_title'].toString().trim()
          : 'Partner vehicle';

      final operators = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'operator');
      final operatorIds = List<Map<String, dynamic>>.from(operators)
          .map((row) => row['id']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (operatorIds.isEmpty) {
        throw Exception('No operator account is available');
      }

      for (final operatorId in operatorIds) {
        await NotificationService().createNotification(
          userId: operatorId,
          title: 'Price Update Request',
          message:
              'Admin forwarded a partner price request for $vehicleTitle. Update price only and keep the details/images unchanged.',
          type: 'price_change_request_forwarded',
          data: {
            ...data,
            'event': 'operator_partner_price_change_request',
            'forwarded_by_admin': _supabase.auth.currentUser?.id,
            'forwarded_at': DateTime.now().toIso8601String(),
          },
        );
      }

      await _supabase
          .from('notifications')
          .update({
            'data': {
              ...data,
              'forwarded_to_operator': true,
              'forwarded_at': DateTime.now().toIso8601String(),
            },
          })
          .eq('id', request['id']);

      await _loadPriceChangeRequests();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price request forwarded to operator'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to forward request: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _approvePartnerVehicleApplication(
    Map<String, dynamic> application,
  ) async {
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
          .select('id')
          .eq('user_id', partnerId)
          .maybeSingle();

      partnerProfile ??= await _supabase
          .from('partners')
          .insert({
            'user_id': partnerId,
            'verification_status': 'approved',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final partnerProfileId = partnerProfile['id']?.toString();
      if (partnerProfileId == null || partnerProfileId.isEmpty) {
        throw Exception('Partner profile could not be resolved');
      }

      final createdVehicle = await _supabase
          .from('vehicles')
          .insert({
            'owner_id': partnerId,
            'owner_role': 'partner',
            'vehicle_name':
                '${application['brand'] ?? ''} ${application['model'] ?? ''}'
                    .trim(),
            'brand': application['brand'],
            'model': application['model'],
            'year': application['year'],
            'plate_number': application['plate_number'],
            'seats': application['seats'] ?? 5,
            'price_per_day': application['price_per_day'] ?? 0,
            'price_per_hour': application['price_per_hour'] ?? 0,
            'fuel_type': application['fuel_type'] ?? 'Gasoline',
            'transmission': application['transmission'] ?? 'Manual',
            'owner_is_driver': application['owner_is_driver'] ?? false,
            'is_available': true,
            'is_posted': true,
            'status': 'available',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();
      final vehicleId = createdVehicle['id'];

      final createdPartnerVehicle = await _supabase
          .from('partner_vehicles')
          .insert({
            'partner_id': partnerProfileId,
            'brand': application['brand'],
            'model': application['model'],
            'year': application['year'],
            'plate_number': application['plate_number'],
            'seats': application['seats'] ?? 5,
            'price_per_day': application['price_per_day'] ?? 0,
            'price_per_hour': application['price_per_hour'] ?? 0,
            'fuel_type': application['fuel_type'] ?? 'Gasoline',
            'transmission': application['transmission'] ?? 'Manual',
            'owner_is_driver': application['owner_is_driver'] ?? false,
            'is_available': true,
            'vehicle_id': vehicleId,
            'status': 'available',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final partnerVehicleId = createdPartnerVehicle['id'];
      final vehiclePhotoUrl = application['vehicle_photo_url']?.toString();
      final photoUrls = <String>[
        if (vehiclePhotoUrl != null && vehiclePhotoUrl.isNotEmpty)
          vehiclePhotoUrl,
      ];
      final photoDocs = await _supabase
          .from('partner_vehicle_documents')
          .select('file_url')
          .eq('partner_vehicle_application_id', appId)
          .eq('document_type', 'vehicle_photo');
      for (final doc in List<Map<String, dynamic>>.from(photoDocs)) {
        final url = doc['file_url']?.toString();
        if (url != null && url.isNotEmpty && !photoUrls.contains(url)) {
          photoUrls.add(url);
        }
      }
      if (photoUrls.isNotEmpty) {
        await _supabase
            .from('vehicle_images')
            .insert(
              List.generate(photoUrls.length, (index) {
                return {
                  'partner_vehicle_id': partnerVehicleId,
                  'vehicle_id': vehicleId,
                  'image_url': photoUrls[index],
                  'display_order': index,
                };
              }),
            );
      }

      final orUrl = application['or_document_url']?.toString();
      final crUrl = application['cr_document_url']?.toString();

      if (partnerVehicleId != null) {
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
            'created_vehicle_id': vehicleId,
            'rejection_reason': null,
          })
          .eq('id', appId);

      try {
        await GpsService().transferTrackerToVehicle(
          applicationId: appId,
          targetVehicleId: partnerVehicleId?.toString() ?? vehicleId.toString(),
          isPartnerVehicle: partnerVehicleId != null,
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
            'rejection_reason': 'Rejected by admin',
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
          await _supabase.from('renters').insert({'user_id': userId});
        }
      }

      if (newRole == 'driver') {
        final driverRow = await _supabase
            .from('drivers')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (driverRow == null) {
          await _supabase.from('drivers').insert({
            'user_id': userId,
            'license_number': _placeholderLicenseNumber(userId),
            'license_expiry': _placeholderLicenseExpiry,
            'license_verified': false,
            'nbi_verified': false,
            'verification_status': 'pending',
            'driver_tier': 'standard',
            'rating': 0.0,
            'total_trips': 0,
          });
        }
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
          debugPrint('Driver insert with is_psdc_driver failed, trying driver_tier: $insertErr');
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
          await _supabase.from('drivers').update({
            'is_psdc_driver': newStatus,
            'driver_tier': newStatus ? 'psdc' : 'standard',
            'verification_status': 'verified',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('user_id', userId);
        } catch (updateErr) {
          debugPrint('Driver update with is_psdc_driver failed, trying driver_tier: $updateErr');
          await _supabase.from('drivers').update({
            'driver_tier': newStatus ? 'psdc' : 'standard',
            'verification_status': 'verified',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('user_id', userId);
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
      default:
        return _buildDashboardContent(isDark);
    }
  }

  Widget _buildSidebar(bool isDark) {
    const adminNavy = Color(0xFF032A46);
    const adminNavyDeep = Color(0xFF021F35);
    const adminGold = Color(0xFFFFD740);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarExpanded ? 260 : 70,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
          SizedBox(
            height: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Logo with gold border
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: adminGold,
                      shape: BoxShape.circle,
                      border: Border.all(color: adminGold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: adminGold.withOpacity(0.35),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/icon/logo-black.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (_sidebarExpanded) ...[
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mobilis',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Admin Portal',
                          style: TextStyle(
                            color: adminGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
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
            badge: _allUsers.length,
          ),
          _buildNavItem(2, Icons.directions_car_rounded, 'Vehicles', isDark),
          _buildNavItem(3, Icons.book_rounded, 'Bookings', isDark),
          _buildNavItem(
            4,
            Icons.verified_user_rounded,
            'Verifications',
            isDark,
            badge: _pendingVerifications > 0 ? _pendingVerifications : null,
          ),
          _buildNavItem(
            5,
            Icons.assignment_outlined,
            'Applications',
            isDark,
            badge: _pendingPartnerVehicleApplications.isNotEmpty
                ? _pendingPartnerVehicleApplications.length
                : null,
          ),
          _buildNavItem(6, Icons.mail_rounded, 'Message Review', isDark),
          _buildNavItem(
            7,
            Icons.support_agent_rounded,
            'Customer Service',
            isDark,
            badge: _supportConversations.isNotEmpty
                ? _supportConversations.length
                : null,
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
            badge: _actionLogs.isNotEmpty ? _actionLogs.length : null,
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
          InkWell(
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
    const adminGold = Color(0xFFFFD740);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
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
              Icon(
                icon,
                color: isSelected ? const Color(0xFF021F35) : Colors.white54,
                size: 22,
              ),
              if (_sidebarExpanded) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF021F35)
                          : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      fontSize: 13.5,
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
                      color: isSelected
                          ? const Color(0xFF021F35).withOpacity(0.18)
                          : Colors.red.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge.toString(),
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF021F35)
                            : Colors.white,
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

  Widget _buildTopBar(bool isDark) {
    const adminNavyDeep = Color(0xFF021F35);
    const adminGold = Color(0xFFFFD740);

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
              color: isDark ? Colors.white : const Color(0xFF021F35),
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          _buildQuickAction('Export', Icons.download_rounded, Colors.green, () {
            _generateAndExportReport(isDark);
          }),
          const SizedBox(width: 16),
          Tooltip(
            message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            child: IconButton(
              onPressed: () => widget.onThemeToggle?.call(!isDark),
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF032A46),
              ),
            ),
          ),
          Tooltip(
            message: 'Refresh',
            child: IconButton(
              onPressed: _loadDashboardData,
              icon: Icon(
                Icons.refresh_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF032A46),
              ),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
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
    return InkWell(
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
                colors: [Color(0xFFFFD600), Color(0xFFFFC400)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.22),
                  blurRadius: 20,
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
                      const Text(
                        'Total Revenue',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PHP ${_totalRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'From $_totalBookings total bookings',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Stats Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 2,
            children: [
              _buildStatCard(
                'Total Renters',
                _totalUsers.toString(),
                Icons.person,
                Colors.blue,
                isDark,
              ),
              _buildStatCard(
                'Partners',
                _totalPartners.toString(),
                Icons.business,
                Colors.green,
                isDark,
              ),
              _buildStatCard(
                'Operators',
                _totalOperators.toString(),
                Icons.admin_panel_settings,
                Colors.purple,
                isDark,
              ),
              _buildStatCard(
                'Ongoing Bookings',
                _activeBookings.toString(),
                Icons.event_available,
                Colors.teal,
                isDark,
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
                  'System Status',
                  _buildSystemStatus(isDark),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, Widget content, bool isDark) {
    return Container(
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

    return DataTable(
      columns: [
        DataColumn(
          label: Text(
            'Vehicle',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        DataColumn(
          label: Text(
            'Renter',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        DataColumn(
          label: Text(
            'Status',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        DataColumn(
          label: Text(
            'Amount',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
      ],
      rows: _allBookings.take(6).map((booking) {
        final vehicle = booking['vehicles'] as Map<String, dynamic>?;
        final user = booking['users'] as Map<String, dynamic>?;
        final status = booking['status'] as String? ?? 'pending';
        final total = (booking['total_cost'] as num?)?.toDouble() ?? 0;

        return DataRow(
          cells: [
            DataCell(
              Text(
                vehicle != null
                    ? '${vehicle['brand']} ${vehicle['model']}'
                    : 'Unknown',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            DataCell(
              Text(
                user?['full_name'] ?? 'Unknown',
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
    );
  }

  Widget _buildStatusBadge(String status) {
    final group = bookingStatusGroup(status);
    final color = bookingStatusColor(group);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        bookingStatusLabel(group).toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
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
      final matchesSearch =
          name.contains(_userSearchQuery.toLowerCase()) ||
          email.contains(_userSearchQuery.toLowerCase());
      final matchesRole = _userRoleFilter == 'all' ||
          role == _userRoleFilter ||
          (_userRoleFilter == 'psdc' && isPsdc);
      return matchesSearch && matchesRole;
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
    final verifiedCount = _allUsers
        .where((u) => u['id_verified'] == true)
        .length;

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
                  Icons.people,
                  Colors.blue,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Verified',
                  verifiedCount.toString(),
                  Icons.verified_user,
                  Colors.green,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Partners',
                  partnersCount.toString(),
                  Icons.business,
                  Colors.purple,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'Operators',
                  operatorsCount.toString(),
                  Icons.admin_panel_settings,
                  Colors.orange,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserStatCard(
                  'PSDC Drivers',
                  psdcDriversCount.toString(),
                  Icons.verified_outlined,
                  const Color(0xFFF59E0B),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
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
              const SizedBox(width: 12),
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
                      child: Text(
                        '🛡️ PSDC Drivers',
                        style: TextStyle(
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                        ),
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
              const SizedBox(width: 12),
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
                        flex: 2,
                        child: Text(
                          'Name',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Email',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Role',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Verified',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Actions',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
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
                          padding: const EdgeInsets.all(16),
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
                                flex: 2,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isPsdcDriver
                                          ? const Color(0xFFF59E0B).withOpacity(0.2)
                                          : Colors.blue.withOpacity(0.2),
                                      child: Text(
                                        (user['full_name'] as String?)?[0]
                                                .toString()
                                                .toUpperCase() ??
                                            'U',
                                        style: TextStyle(
                                          color: isPsdcDriver
                                              ? const Color(0xFFF59E0B)
                                              : Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        user['full_name'] ?? 'User',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  user['email'] ?? '',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _buildRoleBadge(
                                  role,
                                  isPsdcDriver: isPsdcDriver,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Tooltip(
                                    message: isVerified
                                        ? 'ID Verified'
                                        : 'Not Verified',
                                    child: Icon(
                                      isVerified
                                          ? Icons.verified_user
                                          : Icons.pending,
                                      color: isVerified
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
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
                                                  ? Icons.remove_moderator_outlined
                                                  : Icons.verified_outlined,
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

  Widget _buildUserStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
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
                  color: color.withOpacity(0.2),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role, {bool isPsdcDriver = false}) {
    if (isPsdcDriver) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFD97706).withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, size: 13, color: Color(0xFFF59E0B)),
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

    return Container(
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
    );
  }

  Widget _buildVehiclesContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'All Vehicles (${_allVehicles.length})',
        _allVehicles.isEmpty
            ? const Center(child: Text('No vehicles found'))
            : LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 16.0;
                  final crossAxisCount = constraints.maxWidth >= 1200
                      ? 3
                      : constraints.maxWidth >= 760
                      ? 2
                      : 1;
                  final cardWidth =
                      (constraints.maxWidth -
                          (spacing * (crossAxisCount - 1))) /
                      crossAxisCount;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: _allVehicles
                        .map(
                          (vehicle) => SizedBox(
                            width: cardWidth,
                            child: _buildAdminVehicleCard(vehicle, isDark),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
        isDark,
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 150,
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
                        color: isDark ? Colors.grey[600] : Colors.grey.shade500,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildSourceBadge(isPartner ? 'PARTNER' : 'COMPANY'),
                    const SizedBox(width: 8),
                    _buildPostedBadge(posted, isDark),
                    const Spacer(),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$brand $model${year.isNotEmpty ? ' ($year)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (plate.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Plate: $plate',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _buildAdminVehicleInfoRow(
                  Icons.person_outline,
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
                        color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMiniVehicleChip(vehicleType, isDark),
                    _buildMiniVehicleChip('$seats seats', isDark),
                    _buildMiniVehicleChip(transmission, isDark),
                    _buildMiniVehicleChip(fuelType, isDark),
                  ],
                ),
                const SizedBox(height: 12),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(String label) {
    return Container(
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
    );
  }

  Widget _buildPostedBadge(bool posted, bool isDark) {
    return Container(
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
              : (isDark ? Colors.grey[400] : Colors.grey),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
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
    final sortedBookings = [..._allBookings]
      ..sort((a, b) {
        return bookingStatusOrder
            .indexOf(bookingStatusGroup(a['status']))
            .compareTo(
              bookingStatusOrder.indexOf(bookingStatusGroup(b['status'])),
            );
      });
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'All Bookings (${_allBookings.length})',
        _allBookings.isEmpty
            ? const Center(child: Text('No bookings found'))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
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
                        'Total',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Tracking',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                  rows: sortedBookings.map((booking) {
                    final vehicle =
                        booking['vehicles'] as Map<String, dynamic>?;
                    final user = booking['renter'] as Map<String, dynamic>?;
                    final status = booking['status'] as String? ?? 'pending';
                    final canTrack = _canTrackBooking(booking);
                    final total =
                        (booking['total_price'] as num?)?.toDouble() ??
                        (booking['total_cost'] as num?)?.toDouble() ??
                        0;

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            vehicle != null
                                ? '${vehicle['brand']} ${vehicle['model']}'
                                : 'Unknown',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            user?['full_name'] ?? 'Unknown',
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
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: canTrack
                                ? () => _openTrackingForBooking(booking)
                                : null,
                            icon: const Icon(Icons.location_on, size: 16),
                            label: const Text('Track'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                              disabledForegroundColor: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
        isDark,
      ),
    );
  }

  Widget _buildTrackingContent(bool isDark) {
    final visibleLocations = _visibleTrackingLocations();
    final mapMarkers = visibleLocations
        .where(
          (location) =>
              location['latitude'] is num && location['longitude'] is num,
        )
        .take(50)
        .map(
          (location) => MobilisMapMarker(
            latitude: (location['latitude'] as num).toDouble(),
            longitude: (location['longitude'] as num).toDouble(),
            icon: Icons.directions_car_filled_rounded,
            color: AppColors.primary,
            size: 40,
          ),
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            'Live Tracking (${visibleLocations.length})',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _loadTrackingLocations();
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_focusedTrackingBookingId != null) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _focusedTrackingBookingId = null);
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Show all bookings'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.black87,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.borderColor
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        _focusedTrackingBookingId == null
                            ? 'Tracks each active booking from the driver app. Click Track from Bookings to focus one trip.'
                            : 'Showing only the selected booking from the Bookings table.',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 360,
                    width: double.infinity,
                    color: isDark ? AppColors.darkBg : Colors.grey.shade100,
                    child: mapMarkers.isEmpty
                        ? Center(
                            child: Text(
                              _focusedTrackingBookingId == null
                                  ? 'No active tracking locations yet'
                                  : 'No live location yet for this booking',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                          )
                        : MobilisLeafletMap(
                            markers: mapMarkers,
                            initialZoom: mapMarkers.length > 1 ? 10 : 14,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (visibleLocations.isEmpty)
                  Text(
                    _focusedTrackingBookingId == null
                        ? 'Tracking starts from the driver app on an active trip.'
                        : 'Ask the assigned driver to start location tracking for this booking.',
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
    final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
    final driver = booking?['drivers'] as Map<String, dynamic>?;
    final driverUser = driver?['users'] as Map<String, dynamic>?;
    final renter = booking?['renter'] as Map<String, dynamic>?;
    final bookingId = booking?['id']?.toString() ?? 'N/A';
    final pickup = booking?['pickup_location']?.toString().trim() ?? '';
    final dropoff = booking?['dropoff_location']?.toString().trim() ?? '';
    final vehicleName = [
      vehicle?['brand'],
      vehicle?['model'],
      vehicle?['plate_number'] == null ? null : '(${vehicle?['plate_number']})',
    ].where((part) => part != null && part.toString().isNotEmpty).join(' ');
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicleName.isEmpty ? 'Tracked booking' : vehicleName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Booking: $bookingId | Driver: ${driverUser?['full_name'] ?? 'N/A'} | Renter: ${renter?['full_name'] ?? 'N/A'}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                if (pickup.isNotEmpty || dropoff.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Pickup: ${pickup.isEmpty ? 'N/A' : pickup} | Destination: ${dropoff.isEmpty ? 'N/A' : dropoff}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Lat/Lng: ${lat?.toStringAsFixed(5) ?? 'N/A'}, ${lng?.toStringAsFixed(5) ?? 'N/A'} | Updated: ${location['recorded_at'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
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
      final role = (user?['role']?.toString() ?? r['role']?.toString() ?? '').toLowerCase().trim();
      final isDriver = role == 'driver' || (r['id_type']?.toString().toLowerCase().contains('driver') ?? false);
      if (role == 'renter') {
        renterCount++;
      } else if (isDriver) {
        driverCount++;
      } else if (role == 'partner') {
        partnerCount++;
      }
    }

    // 2. Filter records based on selected role sub-tab
    final filteredRecords = _verificationRecords.where((r) {
      if (_verificationRoleFilter == 'all') return true;
      final user = r['users'] as Map<String, dynamic>?;
      final role = (user?['role']?.toString() ?? r['role']?.toString() ?? '').toLowerCase().trim();
      final isDriver = role == 'driver' || (r['id_type']?.toString().toLowerCase().contains('driver') ?? false);

      if (_verificationRoleFilter == 'renter') return role == 'renter';
      if (_verificationRoleFilter == 'driver') return isDriver;
      if (_verificationRoleFilter == 'partner') return role == 'partner';
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
          // Header Card with Role Filter Sub-Tabs
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
                        Icons.verified_user_rounded,
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
                            'User Verifications',
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

                // Role Filter Sub-Tabs Chips
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildVerificationRoleTab(
                      'all',
                      'All Users',
                      allCount,
                      isDark,
                    ),
                    _buildVerificationRoleTab(
                      'renter',
                      'Renters',
                      renterCount,
                      isDark,
                      icon: Icons.directions_car_rounded,
                      color: Colors.purple,
                    ),
                    _buildVerificationRoleTab(
                      'driver',
                      'Drivers',
                      driverCount,
                      isDark,
                      icon: Icons.badge_rounded,
                      color: Colors.blue,
                    ),
                    _buildVerificationRoleTab(
                      'partner',
                      'Partners',
                      partnerCount,
                      isDark,
                      icon: Icons.handshake_rounded,
                      color: Colors.amber,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Verification Sections
          _buildVerificationSection(
            title: 'Pending Verifications',
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

    return ChoiceChip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : activeColor,
            )
          : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.black.withValues(alpha: 0.2)
                  : activeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : activeColor,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _verificationRoleFilter = key);
        }
      },
      selectedColor: activeColor,
      backgroundColor:
          isDark ? AppColors.darkBgSecondary : Colors.grey.shade200,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.black
            : (isDark ? Colors.white : Colors.black87),
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                                    ),
                                  ),
                                if (crUrl.isNotEmpty)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildDocumentPreview(
                                      title: 'CR Document',
                                      url: crUrl,
                                      isDark: isDark,
                                    ),
                                  ),
                                if (vehiclePhotoUrl.isNotEmpty)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildDocumentPreview(
                                      title: 'Vehicle Photo',
                                      url: vehiclePhotoUrl,
                                      isDark: isDark,
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
    final vehicleRecords = _pendingPartnerVehicleApplications;
    final driverRecords = _verificationRecords.where((r) {
      final user = r['users'] as Map<String, dynamic>?;
      final role = (user?['role']?.toString() ?? r['role']?.toString() ?? '').toLowerCase().trim();
      return role == 'driver' || (r['id_type']?.toString().toLowerCase().contains('driver') ?? false);
    }).toList();

    final showVehicles =
        _applicationTypeFilter == 'all' || _applicationTypeFilter == 'vehicle';
    final showDrivers =
        _applicationTypeFilter == 'all' || _applicationTypeFilter == 'driver';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Sub-Tabs
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
                        Icons.assignment_outlined,
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
                            'Application Management',
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

                // Application Sub-Tab Chips
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildApplicationTypeTab(
                      'all',
                      'All Applications',
                      vehicleRecords.length + driverRecords.length,
                      isDark,
                    ),
                    _buildApplicationTypeTab(
                      'vehicle',
                      'Partner Vehicle Listings',
                      vehicleRecords.length,
                      isDark,
                      icon: Icons.directions_car_rounded,
                      color: Colors.amber,
                    ),
                    _buildApplicationTypeTab(
                      'driver',
                      'Driver Onboarding',
                      driverRecords.length,
                      isDark,
                      icon: Icons.badge_rounded,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Partner Vehicle Applications Section
          if (showVehicles) ...[
            _buildPartnerVehicleApplicationsSection(vehicleRecords, isDark),
            const SizedBox(height: 24),
            _buildPriceChangeRequestsSection(isDark),
            if (showDrivers && driverRecords.isNotEmpty) const SizedBox(height: 24),
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

    return ChoiceChip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : activeColor,
            )
          : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.black.withValues(alpha: 0.2)
                  : activeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : activeColor,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _applicationTypeFilter = key);
        }
      },
      selectedColor: activeColor,
      backgroundColor:
          isDark ? AppColors.darkBgSecondary : Colors.grey.shade200,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.black
            : (isDark ? Colors.white : Colors.black87),
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: records.map((record) {
                      final partner =
                          record['partner'] as Map<String, dynamic>?;
                      final title =
                          '${record['brand'] ?? 'Unknown'} ${record['model'] ?? ''}'
                              .trim();
                      final subtitle = [
                        if (record['year'] != null) record['year'].toString(),
                        if ((record['plate_number'] ?? '')
                            .toString()
                            .isNotEmpty)
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
                                  itemBuilder: (context, index) => ClipRRect(
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
                                              record['or_document_url']
                                                  ?.toString() ??
                                              '',
                                          isDark: isDark,
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
                                              record['cr_document_url']
                                                  ?.toString() ??
                                              '',
                                          isDark: isDark,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
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
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
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

  Widget _buildPriceChangeRequestsSection(bool isDark) {
    return _buildCard(
      'Price Change Requests (${_priceChangeRequests.length})',
            _priceChangeRequests.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No partner price requests right now.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: _priceChangeRequests.map((request) {
                      final data = request['data'] is Map<String, dynamic>
                          ? Map<String, dynamic>.from(request['data'])
                          : <String, dynamic>{};
                      final forwarded = data['forwarded_to_operator'] == true;

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
                              data['vehicle_title']?.toString() ??
                                  'Partner vehicle',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              request['message']?.toString() ?? '',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildDetailCard(
                                  'Current Daily',
                                  'PHP ${((data['current_price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                  isDark,
                                ),
                                _buildDetailCard(
                                  'Requested Daily',
                                  'PHP ${((data['requested_price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                  isDark,
                                ),
                                _buildDetailCard(
                                  'Current Hourly',
                                  'PHP ${((data['current_price_per_hour'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                  isDark,
                                ),
                                _buildDetailCard(
                                  'Requested Hourly',
                                  'PHP ${((data['requested_price_per_hour'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                  isDark,
                                ),
                              ],
                            ),
                            if ((data['note'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Note: ${data['note']}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: forwarded
                                  ? null
                                  : () => _forwardPriceChangeRequestToOperators(
                                      request,
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                              ),
                              icon: const Icon(
                                Icons.forward_to_inbox,
                                size: 16,
                              ),
                              label: Text(
                                forwarded
                                    ? 'Forwarded to Operator'
                                    : 'Forward to Operator',
                              ),
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
    final role = user?['role']?.toString().trim().toLowerCase() ?? '';
    final isDriverRecord =
        role == 'driver' ||
        (record['id_type']?.toString().toLowerCase().contains('driver') ??
            false);
    final submittedName = (record['full_name'] as String?)?.trim();
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
        : null;
    final idBackUrl =
        record['id_back_url']?.toString().trim().isNotEmpty == true
        ? record['id_back_url'].toString().trim()
        : legacyIdUrls.length > 1
        ? legacyIdUrls[1]
        : null;
    final faceSelfieUrl = record['face_selfie_url']?.toString().trim();
    final selfieWithIdUrl = record['selfie_with_id_url']?.toString().trim();
    final driverSignatureUrl = record['driver_signature_url']
        ?.toString()
        .trim();
    final driverNbiUrl = record['driver_nbi_url']?.toString().trim();
    final driverYearsExperience = record['driver_years_experience']
        ?.toString()
        .trim();
    final driverPreviousCompanies = record['driver_previous_companies']
        ?.toString()
        .trim();
    final driverLicenseExpiry = record['driver_license_expiry']
        ?.toString()
        .trim();
    final status = (record['verification_status'] as String? ?? 'pending')
        .toLowerCase();

    Color badgeColor;
    switch (status) {
      case 'verified':
        badgeColor = Colors.green;
        break;
      case 'rejected':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.orange;
    }

    final userRole = (user?['role']?.toString() ?? record['role']?.toString() ?? 'renter').toLowerCase().trim();
    Color roleBg = Colors.purple.withValues(alpha: 0.15);
    Color roleText = Colors.purple;
    String roleTag = 'RENTER';

    if (userRole == 'driver' || isDriverRecord) {
      roleTag = 'DRIVER';
      roleBg = Colors.blue.withValues(alpha: 0.15);
      roleText = Colors.blue;
    } else if (userRole == 'partner') {
      roleTag = 'PARTNER';
      roleBg = Colors.amber.withValues(alpha: 0.15);
      roleText = Colors.amber;
    } else if (userRole == 'admin') {
      roleTag = 'ADMIN';
      roleBg = Colors.teal.withValues(alpha: 0.15);
      roleText = Colors.teal;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
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
                      children: [
                        Flexible(
                          child: Text(
                            submittedName?.isNotEmpty == true
                                ? submittedName!
                                : (user?['full_name'] ?? 'Unknown User'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: roleBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            roleTag,
                            style: TextStyle(
                              color: roleText,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?['email'] ?? '',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (status == 'pending') ...[
                const SizedBox(width: 12),
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
                          'This will mark this user as verified and notify them.',
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
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Approve'),
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
                        const SnackBar(content: Text('Verification approved')),
                      );
                      _loadDashboardData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result['message']?.toString() ?? 'Approval failed',
                          ),
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Approve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final adminId = _supabase.auth.currentUser?.id ?? '';
                    final result = await VerificationService.rejectVerification(
                      verificationId: record['id'].toString(),
                      rejectionReason: 'Rejected by admin',
                      adminId: adminId,
                    );
                    if (!mounted) return;
                    if (result['success'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verification rejected')),
                      );
                      _loadDashboardData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result['message']?.toString() ?? 'Rejection failed',
                          ),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              final imageWidgets = <Widget>[
                if (idFrontUrl?.isNotEmpty == true)
                  _buildDocumentPreview(
                    title: 'ID Front',
                    url: idFrontUrl!,
                    isDark: isDark,
                  ),
                if (idBackUrl?.isNotEmpty == true)
                  _buildDocumentPreview(
                    title: 'ID Back',
                    url: idBackUrl!,
                    isDark: isDark,
                  ),
                if (faceSelfieUrl?.isNotEmpty == true)
                  _buildDocumentPreview(
                    title: 'Face Selfie',
                    url: faceSelfieUrl!,
                    isDark: isDark,
                  ),
                if (selfieWithIdUrl?.isNotEmpty == true)
                  _buildDocumentPreview(
                    title: 'Selfie Holding ID',
                    url: selfieWithIdUrl!,
                    isDark: isDark,
                  ),
                if (driverSignatureUrl?.isNotEmpty == true)
                  _buildDocumentPreview(
                    title: 'Digital Signature',
                    url: driverSignatureUrl!,
                    isDark: isDark,
                  ),
                if (driverNbiUrl?.isNotEmpty == true)
                  _buildDocumentPreview(
                    title: 'NBI Clearance',
                    url: driverNbiUrl!,
                    isDark: isDark,
                  ),
              ];

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: isNarrow ? constraints.maxWidth : 240,
                    child: _buildDetailCard(
                      'Name',
                      submittedName?.isNotEmpty == true
                          ? submittedName!
                          : (user?['full_name'] ?? 'Unknown User'),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: isNarrow ? constraints.maxWidth : 240,
                    child: _buildDetailCard(
                      'ID Type',
                      (record['id_type'] as String?)?.isNotEmpty == true
                          ? record['id_type']
                          : 'Not provided',
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: isNarrow ? constraints.maxWidth : 240,
                    child: _buildDetailCard(
                      'ID Number',
                      (record['id_number'] as String?)?.isNotEmpty == true
                          ? record['id_number']
                          : 'Not provided',
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: isNarrow ? constraints.maxWidth : 240,
                    child: _buildDetailCard(
                      'Submitted',
                      _formatDate(record['created_at']),
                      isDark,
                    ),
                  ),
                  if (isDriverRecord &&
                      (driverSignatureUrl == null ||
                          driverSignatureUrl.isEmpty))
                    SizedBox(
                      width: isNarrow ? constraints.maxWidth : 240,
                      child: _buildDetailCard(
                        'Digital Signature',
                        'Not submitted',
                        isDark,
                      ),
                    ),
                  if (isDriverRecord &&
                      (driverNbiUrl == null || driverNbiUrl.isEmpty))
                    SizedBox(
                      width: isNarrow ? constraints.maxWidth : 240,
                      child: _buildDetailCard(
                        'NBI Clearance',
                        'Not submitted',
                        isDark,
                      ),
                    ),
                  if (isDriverRecord &&
                      driverYearsExperience?.isNotEmpty == true)
                    SizedBox(
                      width: isNarrow ? constraints.maxWidth : 240,
                      child: _buildDetailCard(
                        'Driving Experience',
                        '$driverYearsExperience year${driverYearsExperience == '1' ? '' : 's'}',
                        isDark,
                      ),
                    ),
                  if (isDriverRecord && driverLicenseExpiry?.isNotEmpty == true)
                    SizedBox(
                      width: isNarrow ? constraints.maxWidth : 240,
                      child: _buildDetailCard(
                        "License Expiry",
                        _formatDate(driverLicenseExpiry),
                        isDark,
                      ),
                    ),
                  if (isDriverRecord &&
                      driverPreviousCompanies?.isNotEmpty == true)
                    SizedBox(
                      width: isNarrow ? constraints.maxWidth : 240,
                      child: _buildDetailCard(
                        'Previous Companies',
                        driverPreviousCompanies!,
                        isDark,
                      ),
                    ),
                  if ((record['location'] as String?)?.trim().isNotEmpty ==
                      true)
                    SizedBox(
                      width: isNarrow ? constraints.maxWidth : 240,
                      child: _buildDetailCard(
                        'Location',
                        record['location'] as String,
                        isDark,
                      ),
                    ),
                  if ((record['phone'] as String?)?.trim().isNotEmpty == true)
                    SizedBox(
                      width: isNarrow ? constraints.maxWidth : 240,
                      child: _buildDetailCard(
                        'Phone',
                        record['phone'] as String,
                        isDark,
                      ),
                    ),
                  ...imageWidgets
                      .map(
                        (widget) => SizedBox(
                          width: isNarrow ? constraints.maxWidth : 240,
                          child: widget,
                        ),
                      )
                      .toList(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.4,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
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
  }) {
    return InkWell(
      onTap: () => _openUrl(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? Colors.black12 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: OnDemandNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                label: 'Tap to load document',
              ),
            ),
          ],
        ),
      ),
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
                  'Revenue Distribution',
                  SizedBox(height: 250, child: _buildRevenueChart(isDark)),
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
    final revenueData = _calculateRevenueDistribution();
    return PieChart(PieChartData(centerSpaceRadius: 60, sections: revenueData));
  }

  List<PieChartSectionData> _calculateRevenueDistribution() {
    int completedCount = 0;
    int activeCount = 0;
    int cancelledCount = 0;
    int pendingCount = 0;

    for (var booking in _allBookings) {
      final status = booking['status'] as String?;
      if (status == 'completed') {
        completedCount++;
      } else if (status == 'active') {
        activeCount++;
      } else if (status == 'cancelled') {
        cancelledCount++;
      } else {
        pendingCount++;
      }
    }

    final total = _totalBookings > 0 ? _totalBookings : 1;
    final completedPct = (completedCount / total * 100).toStringAsFixed(0);
    final activePct = (activeCount / total * 100).toStringAsFixed(0);
    final cancelledPct = (cancelledCount / total * 100).toStringAsFixed(0);
    final pendingPct = (pendingCount / total * 100).toStringAsFixed(0);

    return [
      PieChartSectionData(
        color: Colors.green,
        value: (completedCount / total * 100),
        title: '$completedPct%',
        radius: 80,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      PieChartSectionData(
        color: Colors.blue,
        value: (activeCount / total * 100),
        title: '$activePct%',
        radius: 80,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      PieChartSectionData(
        color: Colors.orange,
        value: (pendingCount / total * 100),
        title: '$pendingPct%',
        radius: 80,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      if (cancelledCount > 0)
        PieChartSectionData(
          color: Colors.red,
          value: (cancelledCount / total * 100),
          title: '$cancelledPct%',
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
    ];
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
                                ? AppColors.primary.withOpacity(0.14)
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
                                latestMessage['content']?.toString() ??
                                    'Open support thread',
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
                              final isDeleted =
                                  message['is_deleted'] == true ||
                                  (message['content'] ?? message['message'])
                                          ?.toString() ==
                                      'Message deleted';
                              final isSending = message['_is_sending'] == true;
                              final sendFailed =
                                  message['_send_failed'] == true;
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
                                      Text(
                                        isDeleted
                                            ? 'Message deleted'
                                            : message['content']?.toString() ??
                                                  '',
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
    const roles = ['all', 'renter', 'driver', 'partner', 'operator'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            'Send Announcement',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _announcementTitleController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _announcementMessageController,
                  minLines: 4,
                  maxLines: 6,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    labelStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _announcementTargetRole,
                      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
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
                        if (value == null) return;
                        setState(() => _announcementTargetRole = value);
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSendingAnnouncement
                          ? null
                          : _sendAnnouncement,
                      icon: _isSendingAnnouncement
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        _isSendingAnnouncement
                            ? 'Sending...'
                            : 'Send Announcement',
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
          _buildCard(
            'Announcement History',
            _announcements.isEmpty
                ? Text(
                    'No announcements sent yet.',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                    ),
                  )
                : Column(
                    children: _announcements.map((announcement) {
                      final target =
                          announcement['target_role']?.toString() ?? 'all';
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderColor
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    announcement['title']?.toString() ??
                                        'Announcement',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    target == 'all' ? 'All users' : target,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              announcement['message']?.toString() ?? '',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey.shade800,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              announcement['created_at']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
      adminMode: true,
      onThemeToggle: widget.onThemeToggle,
      onBack: () {},
      onOpenSupport: () => setState(() => _selectedIndex = 6),
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

    final filteredLogs = _actionLogs.where((log) {
      final matchesSearch = search.isEmpty ||
          (log['notes']?.toString().toLowerCase().contains(search) ?? false) ||
          (log['actor_name']?.toString().toLowerCase().contains(search) ?? false) ||
          (log['booking_id']?.toString().toLowerCase().contains(search) ?? false) ||
          (log['action_type']?.toString().toLowerCase().contains(search) ?? false) ||
          (log['category']?.toString().toLowerCase().contains(search) ?? false);

      if (!matchesSearch) return false;

      if (category == 'all') return true;
      final logCat = log['category']?.toString() ?? '';
      if (category == 'approvals') {
        return logCat == 'BOOKING APPROVAL' || logCat == 'PARTNER APPROVAL';
      }
      if (category == 'drivers') return logCat == 'DRIVER ASSIGNMENT';
      if (category == 'renters') return logCat == 'RENTER REQUEST';
      if (category == 'payments') {
        return logCat == 'PAYMENT CONFIRMED' || logCat == 'RETURN INSPECTION' || logCat == 'TRIP COMPLETED';
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
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
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
                                  'REALTIME LIVE',
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
                        'Audit trail of all booking approvals, driver assignments, renter requests, partner actions, inspections, and payment confirmations.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _loadActionLogs(showLoading: true),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Action Logs',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.darkBgSecondary
                        : Colors.grey.shade200,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Filters row
          Row(
            children: [
              // Search Input
              Expanded(
                child: TextField(
                  onChanged: (val) =>
                      setState(() => _actionLogSearchQuery = val),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by Booking ID, Actor, Renter, Driver...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkBgSecondary
                        : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Category chips
              Wrap(
                spacing: 8,
                children: [
                  _buildActionLogCategoryChip('all', 'All Activity', isDark),
                  _buildActionLogCategoryChip('approvals', 'Approvals', isDark),
                  _buildActionLogCategoryChip('drivers', 'Driver Assign', isDark),
                  _buildActionLogCategoryChip('renters', 'Renter Requests', isDark),
                  _buildActionLogCategoryChip('payments', 'Returns & Payment', isDark),
                ],
              ),
            ],
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

  Widget _buildActionLogCategoryChip(
    String key,
    String label,
    bool isDark,
  ) {
    final isSelected = _actionLogCategoryFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _actionLogCategoryFilter = key);
        }
      },
      selectedColor: AppColors.primary,
      backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.grey.shade200,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black87),
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

    if (category == 'BOOKING APPROVAL') {
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
      iconColor = Colors.amber;
      iconData = Icons.payments_rounded;
      badgeBg = Colors.amber.withValues(alpha: 0.15);
      badgeText = Colors.amber;
    } else if (category == 'RETURN INSPECTION') {
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

    return Container(
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
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
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
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
