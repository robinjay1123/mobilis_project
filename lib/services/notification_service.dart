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

      final response = await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type ?? 'general',
        'data': data,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

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

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
