import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/notification_service.dart';

void main() {
  group('Notification Deduplication Tests', () {
    final notificationService = NotificationService();

    test('deduplicates identical notifications created around the same time', () {
      final now = DateTime.now();
      final notifications = [
        {
          'id': 'notif-1',
          'user_id': 'user-123',
          'title': 'Price Change Approved',
          'message': 'Your price change request for Hanabishi Honda Civic was approved!',
          'type': 'price_change',
          'created_at': now.toIso8601String(),
          'is_read': false,
        },
        {
          'id': 'notif-2',
          'user_id': 'user-123',
          'title': 'Price Change Approved',
          'message': 'Your price change request for Hanabishi Honda Civic was approved!',
          'type': 'price_change',
          'created_at': now.add(const Duration(seconds: 5)).toIso8601String(),
          'is_read': false,
        },
        {
          'id': 'notif-3',
          'user_id': 'user-123',
          'title': 'Booking Finalized',
          'message': 'Your booking for Hanabishi Honda Civic is confirmed.',
          'type': 'booking',
          'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
          'is_read': true,
        },
      ];

      final result = notificationService.deduplicateNotifications(notifications);
      expect(result.length, equals(2));
      expect(result[0]['id'], equals('notif-1'));
      expect(result[1]['id'], equals('notif-3'));
    });

    test('retains notifications with different titles or messages', () {
      final now = DateTime.now();
      final notifications = [
        {
          'id': 'notif-1',
          'user_id': 'user-123',
          'title': 'Price Change Declined',
          'message': 'Your price change request was declined.',
          'type': 'price_change',
          'created_at': now.toIso8601String(),
        },
        {
          'id': 'notif-2',
          'user_id': 'user-123',
          'title': 'Price Change Approved',
          'message': 'Your price change request was approved!',
          'type': 'price_change',
          'created_at': now.toIso8601String(),
        },
      ];

      final result = notificationService.deduplicateNotifications(notifications);
      expect(result.length, equals(2));
    });
  });
}
