import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final supabase = Supabase.instance.client;

  // Get all notifications for a user
  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    try {
      debugPrint('Fetching notifications for user: $userId');

      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} notifications');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching notifications: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching notifications: $e');
      rethrow;
    }
  }

  // Get unread notifications
  Future<List<Map<String, dynamic>>> getUnreadNotifications(
    String userId,
  ) async {
    try {
      debugPrint('Fetching unread notifications for user: $userId');

      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} unread notifications');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching unread notifications: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching unread notifications: $e');
      rethrow;
    }
  }

  // Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      debugPrint('Getting unread notification count for user: $userId');

      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      final count = response.length;
      debugPrint('Unread count: $count');
      return count;
    } on PostgrestException catch (e) {
      debugPrint('Database error getting unread count: ${e.message}');
      return 0;
    } catch (e) {
      debugPrint('Unexpected error getting unread count: $e');
      return 0;
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      debugPrint('Marking notification as read: $notificationId');

      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      debugPrint('Notification marked as read');
    } on PostgrestException catch (e) {
      debugPrint('Database error marking notification read: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error marking notification read: $e');
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      debugPrint('Marking all notifications as read for user: $userId');

      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      debugPrint('All notifications marked as read');
    } on PostgrestException catch (e) {
      debugPrint('Database error marking all read: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error marking all read: $e');
      rethrow;
    }
  }

  // Create a notification (for system use)
  Future<Map<String, dynamic>> createNotification({
    required String userId,
    required String title,
    required String message,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('Creating notification for user: $userId');

      final response = await supabase
          .from('notifications')
          .insert({
            'user_id': userId,
            'title': title,
            'message': message,
            'type': type ?? 'general',
            'data': data,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      await _queuePushForUsers(
        userIds: [userId],
        title: title,
        message: message,
        type: type ?? 'general',
        data: data,
      );

      debugPrint('Notification created successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating notification: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error creating notification: $e');
      rethrow;
    }
  }

  Future<bool> notifyBookingApproved({
    required String renterId,
    required String bookingId,
    required String vehicleTitle,
  }) {
    return _safeCreate(
      userId: renterId,
      title: 'Booking Approved',
      message: 'Your booking for $vehicleTitle has been approved.',
      type: 'booking',
      data: {
        'booking_id': bookingId,
        'status': 'approved',
        'event': 'booking_approved',
      },
    );
  }

  Future<bool> notifyVerificationApproved({
    required String userId,
    required String role,
    String? verificationId,
  }) {
    final cleanRole = role.trim().toLowerCase();
    final label = _roleLabel(cleanRole);
    return _safeCreate(
      userId: userId,
      title: '$label Verification Approved',
      message:
          'Your $label verification has been approved. You can now use verified features in the app.',
      type: 'verification',
      data: {
        if (verificationId != null) 'verification_id': verificationId,
        'status': 'verified',
        'role': cleanRole,
        'event': '${cleanRole}_verification_approved',
      },
    );
  }

  Future<bool> notifyDriverJobAssigned({
    required String driverId,
    required String bookingId,
    required String renterName,
    String? renterId,
    String? renterPhone,
    String? pickupLocation,
    String? dropoffLocation,
    String? startDate,
    String? endDate,
    String? startAt,
    String? endAt,
    double? tripFee,
  }) {
    return _safeCreate(
      userId: driverId,
      title: 'New Driver Job Assigned',
      message:
          'You have a new assigned booking. Renter: $renterName${renterPhone != null && renterPhone.trim().isNotEmpty ? " - ${renterPhone.trim()}" : ""}',
      type: 'driver_assignment',
      data: {
        'booking_id': bookingId,
        if (renterId != null) 'renter_id': renterId,
        'renter_name': renterName,
        if (renterPhone != null) 'renter_phone': renterPhone,
        if (pickupLocation != null) 'pickup_location': pickupLocation,
        if (dropoffLocation != null) 'dropoff_location': dropoffLocation,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (startAt != null) 'start_at': startAt,
        if (endAt != null) 'end_at': endAt,
        if (tripFee != null) 'trip_fee': tripFee,
        'event': 'driver_job_assigned',
      },
    );
  }

  Future<bool> notifyDriverApplicationApproved({required String driverId}) {
    return _safeCreate(
      userId: driverId,
      title: 'Driver Application Approved',
      message:
          'Your driver application has been approved. You can now receive driver job assignments.',
      type: 'application',
      data: {
        'status': 'approved',
        'role': 'driver',
        'event': 'driver_application_approved',
      },
    );
  }

  Future<bool> notifyDriverApplicationSubmitted({
    required String driverId,
  }) async {
    final driverNotified = await _safeCreate(
      userId: driverId,
      title: 'Driver Application Submitted',
      message:
          'Your driver application has been submitted and is now under admin review.',
      type: 'application',
      data: {
        'status': 'pending',
        'role': 'driver',
        'event': 'driver_application_submitted',
      },
    );

    await _notifyAdmins(
      title: 'New Driver Application',
      message: 'A driver submitted an application for review.',
      type: 'application',
      data: {
        'driver_id': driverId,
        'status': 'pending',
        'role': 'driver',
        'event': 'admin_driver_application_submitted',
      },
    );

    return driverNotified;
  }

  Future<bool> notifyDriverApplicationRejected({
    required String driverId,
    required String reason,
  }) {
    return _safeCreate(
      userId: driverId,
      title: 'Driver Application Rejected',
      message: 'Your driver application was rejected. Reason: $reason',
      type: 'application',
      data: {
        'status': 'rejected',
        'role': 'driver',
        'reason': reason,
        'event': 'driver_application_rejected',
      },
    );
  }

  Future<bool> notifyDriverLicenseRenewalDue({
    required String driverId,
    required DateTime licenseExpiry,
    required int daysUntilExpiry,
  }) async {
    if (await _hasDocumentExpiryNotificationToday(
      userId: driverId,
      documentType: 'driver_license',
    )) {
      return false;
    }

    final dateText = licenseExpiry.toIso8601String().split('T').first;
    final title = daysUntilExpiry < 0
        ? 'Driver License Expired'
        : daysUntilExpiry == 0
        ? 'Driver License Expires Today'
        : 'Driver License Renewal Needed';
    final message = daysUntilExpiry < 0
        ? 'Your driver license expired on $dateText. Please renew and re-apply.'
        : 'Your driver license expires on $dateText. Please prepare renewal and re-application.';

    final driverNotified = await _safeCreate(
      userId: driverId,
      title: title,
      message: message,
      type: 'document_expiry',
      data: {
        'document_type': 'driver_license',
        'license_expiry': dateText,
        'days_until_expiry': daysUntilExpiry,
        'event': 'driver_license_renewal_due',
      },
    );

    await _notifyAdmins(
      title: title,
      message: 'Driver $driverId: $message',
      type: 'document_expiry',
      data: {
        'driver_id': driverId,
        'document_type': 'driver_license',
        'license_expiry': dateText,
        'days_until_expiry': daysUntilExpiry,
        'event': 'admin_driver_license_renewal_due',
      },
    );

    return driverNotified;
  }

  Future<bool> notifyPartnerApplicationApproved({
    required String partnerId,
    String? applicationId,
    String? vehicleTitle,
  }) {
    final vehicleText = vehicleTitle == null || vehicleTitle.trim().isEmpty
        ? 'Your partner application has been approved.'
        : 'Your application for ${vehicleTitle.trim()} has been approved.';
    return _safeCreate(
      userId: partnerId,
      title: 'Partner Application Approved',
      message: '$vehicleText You can manage it from your partner dashboard.',
      type: 'application',
      data: {
        if (applicationId != null) 'application_id': applicationId,
        if (vehicleTitle != null) 'vehicle_title': vehicleTitle,
        'status': 'approved',
        'role': 'partner',
        'event': 'partner_application_approved',
      },
    );
  }

  Future<bool> notifyPartnerPaymentReleased({
    required String partnerId,
    required double amount,
    String? bookingId,
    String? payoutId,
    String? reference,
  }) {
    return _safeCreate(
      userId: partnerId,
      title: 'Payment Released',
      message:
          'Your partner payout of PHP ${amount.toStringAsFixed(2)} has been released.',
      type: 'payment_release',
      data: {
        'amount': amount,
        if (bookingId != null) 'booking_id': bookingId,
        if (payoutId != null) 'payout_id': payoutId,
        if (reference != null) 'reference': reference,
        'event': 'partner_payment_released',
      },
    );
  }

  Future<int> broadcastAnnouncement({
    required String title,
    required String message,
    String targetRole = 'all',
    String? announcementId,
  }) async {
    try {
      final normalizedRole = targetRole.trim().toLowerCase();
      var query = supabase.from('users').select('id, role');
      if (normalizedRole != 'all') {
        query = query.eq('role', normalizedRole);
      }

      final users = await query;
      final recipients = List<Map<String, dynamic>>.from(users)
          .where((user) => (user['id']?.toString().trim().isNotEmpty ?? false))
          .toList();
      if (recipients.isEmpty) return 0;

      final nowIso = DateTime.now().toIso8601String();
      final rows = recipients
          .map(
            (user) => {
              'user_id': user['id'],
              'title': title,
              'message': message,
              'type': 'announcement',
              'data': {
                'announcement_id': announcementId,
                'target_role': normalizedRole,
                'event': 'admin_announcement',
              },
              'is_read': false,
              'created_at': nowIso,
            },
          )
          .toList();

      await supabase.from('notifications').insert(rows);
      await _queuePushForUsers(
        userIds: recipients.map((user) => user['id'].toString()).toList(),
        title: title,
        message: message,
        type: 'announcement',
        data: {
          'announcement_id': announcementId,
          'target_role': normalizedRole,
          'event': 'admin_announcement',
        },
      );
      return rows.length;
    } catch (e) {
      debugPrint('Announcement broadcast failed: $e');
      rethrow;
    }
  }

  Future<void> _queuePushForUsers({
    required List<String> userIds,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final cleanIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (cleanIds.isEmpty) return;

    try {
      final tokens = await supabase
          .from('user_push_tokens')
          .select('user_id, token, platform')
          .inFilter('user_id', cleanIds)
          .eq('is_active', true);

      final tokenRows = List<Map<String, dynamic>>.from(tokens);
      if (tokenRows.isEmpty) return;

      final queueRows = tokenRows
          .map(
            (tokenRow) => {
              'user_id': tokenRow['user_id'],
              'push_token': tokenRow['token'],
              'platform': tokenRow['platform'],
              'title': title,
              'message': message,
              'type': type,
              'payload': data,
            },
          )
          .toList();

      await supabase.from('push_notification_queue').insert(queueRows);
    } catch (e) {
      debugPrint('Push queue insert skipped: $e');
    }
  }

  Future<List<String>> _adminUserIds() async {
    try {
      final admins = await supabase.from('users').select('id, role').inFilter(
        'role',
        ['admin', 'super_admin'],
      );
      return List<Map<String, dynamic>>.from(admins)
          .map((admin) => admin['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Admin notification lookup skipped: $e');
      return [];
    }
  }

  Future<int> _notifyAdmins({
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final ids = await _adminUserIds();
    if (ids.isEmpty) return 0;

    final nowIso = DateTime.now().toIso8601String();
    final rows = ids
        .map(
          (id) => {
            'user_id': id,
            'title': title,
            'message': message,
            'type': type,
            'data': data,
            'is_read': false,
            'created_at': nowIso,
          },
        )
        .toList();

    try {
      await supabase.from('notifications').insert(rows);
      await _queuePushForUsers(
        userIds: ids,
        title: title,
        message: message,
        type: type,
        data: data,
      );
      return rows.length;
    } catch (e) {
      debugPrint('Admin notification skipped: $e');
      return 0;
    }
  }

  Future<bool> _hasDocumentExpiryNotificationToday({
    required String userId,
    required String documentType,
  }) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    try {
      final existingToday = await supabase
          .from('notifications')
          .select('id, data, created_at')
          .eq('user_id', userId)
          .eq('type', 'document_expiry')
          .gte('created_at', todayStart.toIso8601String());
      return List<Map<String, dynamic>>.from(existingToday).any((item) {
        final data = item['data'];
        final existingType = data is Map
            ? data['document_type']?.toString()
            : '';
        return existingType == documentType;
      });
    } catch (e) {
      debugPrint('Document expiry duplicate check skipped: $e');
      return false;
    }
  }

  Future<bool> _safeCreate({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    if (userId.trim().isEmpty) return false;
    try {
      await createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
        data: data,
      );
      return true;
    } catch (e) {
      debugPrint('Notification skipped: $e');
      return false;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'driver':
        return 'Driver';
      case 'partner':
        return 'Partner';
      case 'renter':
      case 'user':
        return 'Renter';
      case 'operator':
        return 'Operator';
      default:
        return role.isEmpty
            ? 'Account'
            : role[0].toUpperCase() + role.substring(1);
    }
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      debugPrint('Deleting notification: $notificationId');

      await supabase.from('notifications').delete().eq('id', notificationId);

      debugPrint('Notification deleted');
    } on PostgrestException catch (e) {
      debugPrint('Database error deleting notification: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error deleting notification: $e');
      rethrow;
    }
  }

  // Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      debugPrint('Deleting all notifications for user: $userId');

      await supabase.from('notifications').delete().eq('user_id', userId);

      debugPrint('All notifications deleted');
    } on PostgrestException catch (e) {
      debugPrint('Database error deleting all notifications: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error deleting all notifications: $e');
      rethrow;
    }
  }

  // Subscribe to notifications in real-time
  Stream<List<Map<String, dynamic>>> subscribeToNotifications(String userId) {
    debugPrint('Subscribing to notifications for: $userId');

    return supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  // ================== DOCUMENT EXPIRY NOTIFICATIONS ==================

  /// Create document expiry notification for a user
  Future<bool> createDocumentExpiryNotification({
    required String userId,
    required String
    documentType, // 'license', 'nbi', 'insurance', 'registration', 'verification'
    required int daysUntilExpiry,
    String? documentId,
  }) async {
    try {
      debugPrint(
        'Creating document expiry notification for user: $userId, document: $documentType, days until expiry: $daysUntilExpiry',
      );

      String title = '';
      String body = '';

      if (daysUntilExpiry < 0) {
        title = '$documentType Expired!';
        body = 'Your $documentType has expired. Please renew it immediately.';
      } else if (daysUntilExpiry == 0) {
        title = '$documentType Expires Today';
        body = 'Your $documentType expires today. Renew it now.';
      } else {
        title = '$documentType Expiring Soon';
        body =
            'Your $documentType expires in $daysUntilExpiry days. Renew before it expires.';
      }

      final alreadyNotified = await _hasDocumentExpiryNotificationToday(
        userId: userId,
        documentType: documentType,
      );
      if (alreadyNotified) return false;

      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': body,
        'type': 'document_expiry',
        'data': {
          'document_type': documentType,
          'document_id': documentId,
          'days_until_expiry': daysUntilExpiry,
        },
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });

      await _queuePushForUsers(
        userIds: [userId],
        title: title,
        message: body,
        type: 'document_expiry',
        data: {
          'document_type': documentType,
          'document_id': documentId,
          'days_until_expiry': daysUntilExpiry,
        },
      );

      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating expiry notification: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error creating expiry notification: $e');
      return false;
    }
  }

  /// Check and notify all users with expiring documents
  Future<int> checkAndNotifyExpiringDocuments({int daysThreshold = 30}) async {
    try {
      debugPrint(
        'Checking for expiring documents and creating notifications (threshold: $daysThreshold days)',
      );

      int notificationsCreated = 0;
      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      // Check driver profile license expiry from the certification application.
      final drivers = await supabase
          .from('drivers')
          .select('id, user_id, license_expiry, license_number')
          .not('license_expiry', 'is', null)
          .lte(
            'license_expiry',
            thresholdDate.toIso8601String().split('T').first,
          );

      for (final driver in List<Map<String, dynamic>>.from(drivers)) {
        final userId = driver['user_id']?.toString() ?? '';
        final expiryRaw = driver['license_expiry']?.toString() ?? '';
        final expiryDate = DateTime.tryParse(expiryRaw);
        if (userId.isEmpty || expiryDate == null) continue;

        final daysUntilExpiry = expiryDate.difference(now).inDays;
        final created = await notifyDriverLicenseRenewalDue(
          driverId: userId,
          licenseExpiry: expiryDate,
          daysUntilExpiry: daysUntilExpiry,
        );
        if (created) notificationsCreated++;
      }

      // Check driver licenses
      final driverDocs = await supabase
          .from('driver_documents')
          .select('id, driver_id, document_type, expiry_date, users(id, role)')
          .not('expiry_date', 'is', null)
          .gte('expiry_date', now.toIso8601String())
          .lte('expiry_date', thresholdDate.toIso8601String());

      for (var doc in driverDocs) {
        final driverId = doc['driver_id'] as String;
        final docType = doc['document_type'] as String;
        final expiryDate = DateTime.parse(doc['expiry_date'] as String);
        final daysUntilExpiry = expiryDate.difference(now).inDays;

        final created = await createDocumentExpiryNotification(
          userId: driverId,
          documentType: docType,
          daysUntilExpiry: daysUntilExpiry,
          documentId: doc['id'],
        );

        if (created) notificationsCreated++;
      }

      // Check vehicle documents
      final vehicleDocs = await supabase
          .from('vehicle_documents')
          .select(
            'id, vehicle_id, document_type, expiry_date, vehicles(owner_id)',
          )
          .not('expiry_date', 'is', null)
          .gte('expiry_date', now.toIso8601String())
          .lte('expiry_date', thresholdDate.toIso8601String());

      for (var doc in vehicleDocs) {
        final ownerId = doc['vehicles']['owner_id'] as String;
        final docType = doc['document_type'] as String;
        final expiryDate = DateTime.parse(doc['expiry_date'] as String);
        final daysUntilExpiry = expiryDate.difference(now).inDays;

        final created = await createDocumentExpiryNotification(
          userId: ownerId,
          documentType: docType,
          daysUntilExpiry: daysUntilExpiry,
          documentId: doc['id'],
        );

        if (created) notificationsCreated++;
      }

      // Check renter verification documents
      final renterDocs = await supabase
          .from('renter_verification_documents')
          .select('id, user_id, document_type, expiry_date')
          .not('expiry_date', 'is', null)
          .gte('expiry_date', now.toIso8601String())
          .lte('expiry_date', thresholdDate.toIso8601String());

      for (var doc in renterDocs) {
        final userId = doc['user_id'] as String;
        final docType = doc['document_type'] as String;
        final expiryDate = DateTime.parse(doc['expiry_date'] as String);
        final daysUntilExpiry = expiryDate.difference(now).inDays;

        final created = await createDocumentExpiryNotification(
          userId: userId,
          documentType: docType,
          daysUntilExpiry: daysUntilExpiry,
          documentId: doc['id'],
        );

        if (created) notificationsCreated++;
      }

      debugPrint('Created $notificationsCreated document expiry notifications');
      return notificationsCreated;
    } catch (e) {
      debugPrint('Error checking and notifying expiring documents: $e');
      return 0;
    }
  }

  /// Get badge count for expiring documents
  Future<int> getExpiringDocumentsBadgeCount({
    required String userId,
    int daysThreshold = 30,
  }) async {
    try {
      debugPrint('Getting expiring documents badge count for user: $userId');

      // Count unread document expiry notifications
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('type', 'document_expiry')
          .eq('is_read', false);

      return response.length;
    } on PostgrestException catch (e) {
      debugPrint('Database error getting badge count: ${e.message}');
      return 0;
    } catch (e) {
      debugPrint('Error getting badge count: $e');
      return 0;
    }
  }

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
