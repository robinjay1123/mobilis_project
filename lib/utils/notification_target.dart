import 'dart:convert';

enum NotificationDestination {
  booking,
  messages,
  tracking,
  application,
  verification,
  ratings,
  payment,
  announcement,
  vehicles,
  general,
}

class NotificationTarget {
  const NotificationTarget({
    required this.destination,
    required this.data,
    this.bookingId,
    this.conversationId,
    this.applicationId,
    this.actionRoute,
  });

  final NotificationDestination destination;
  final Map<String, dynamic> data;
  final String? bookingId;
  final String? conversationId;
  final String? applicationId;
  final String? actionRoute;
}

NotificationTarget resolveNotificationTarget(
  Map<String, dynamic> notification,
) {
  final data = _notificationData(notification['data']);
  String? value(String key) {
    final raw = data[key] ?? notification[key];
    final text = raw?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  final type = (value('type') ?? value('notification_type') ?? 'general')
      .toLowerCase();
  final event = (value('event') ?? '').toLowerCase();
  final title = (value('title') ?? '').toLowerCase();
  final actionRoute = value('action_route');
  final bookingId = value('booking_id');
  final conversationId = value('conversation_id');
  final applicationId = value('application_id');
  final searchable = '$type $event $title ${actionRoute ?? ''}';

  NotificationDestination destination;
  if (conversationId != null ||
      type == 'message' ||
      type == 'customer_service' ||
      searchable.contains('chat') ||
      searchable.contains('message')) {
    destination = NotificationDestination.messages;
  } else if (searchable.contains('tracking') ||
      searchable.contains('location_update') ||
      searchable.contains('trip_started') ||
      searchable.contains('ongoing trip')) {
    destination = NotificationDestination.tracking;
  } else if (searchable.contains('rating') || searchable.contains('review')) {
    destination = NotificationDestination.ratings;
  } else if (type == 'document_expiry' ||
      type == 'verification' ||
      searchable.contains('identity-verification') ||
      searchable.contains('verification')) {
    destination = NotificationDestination.verification;
  } else if (type == 'application' || searchable.contains('application')) {
    destination = NotificationDestination.application;
  } else if (type.contains('payment') ||
      searchable.contains('payment') ||
      searchable.contains('refund')) {
    destination = NotificationDestination.payment;
  } else if (type == 'announcement' || searchable.contains('announcement')) {
    destination = NotificationDestination.announcement;
  } else if (type.contains('vehicle') ||
      type.contains('marketing') ||
      searchable.contains('vehicle approval') ||
      searchable.contains('promo')) {
    destination = NotificationDestination.vehicles;
  } else if (bookingId != null ||
      type == 'booking' ||
      type == 'driver_assignment' ||
      searchable.contains('booking') ||
      searchable.contains('trip')) {
    destination = NotificationDestination.booking;
  } else {
    destination = NotificationDestination.general;
  }

  return NotificationTarget(
    destination: destination,
    data: data,
    bookingId: bookingId,
    conversationId: conversationId,
    applicationId: applicationId,
    actionRoute: actionRoute,
  );
}

Map<String, dynamic> _notificationData(dynamic raw) {
  if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // Older notification rows may contain plain text instead of JSON.
    }
  }
  return <String, dynamic>{};
}

/// Chat activity belongs in the Messages inbox, not the Notifications feed.
/// Keep this check shared so every role applies the same separation.
bool isMessageNotification(Map<String, dynamic> notification) {
  return resolveNotificationTarget(notification).destination ==
      NotificationDestination.messages;
}
