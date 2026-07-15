import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/utils/notification_target.dart';

void main() {
  group('resolveNotificationTarget', () {
    test('opens the exact conversation from a message notification', () {
      final target = resolveNotificationTarget({
        'type': 'message',
        'data': {'conversation_id': 'conversation-1'},
      });

      expect(target.destination, NotificationDestination.messages);
      expect(target.conversationId, 'conversation-1');
    });

    test('supports JSON encoded payloads from older notification rows', () {
      final target = resolveNotificationTarget({
        'type': 'booking',
        'data': '{"booking_id":"booking-1","event":"trip_started"}',
      });

      expect(target.destination, NotificationDestination.tracking);
      expect(target.bookingId, 'booking-1');
    });

    test('routes ordinary booking updates to booking details', () {
      final target = resolveNotificationTarget({
        'type': 'driver_assignment',
        'data': {'booking_id': 'booking-2', 'event': 'driver_assigned'},
      });

      expect(target.destination, NotificationDestination.booking);
      expect(target.bookingId, 'booking-2');
    });

    test('routes document renewal notices to verification', () {
      final target = resolveNotificationTarget({
        'type': 'document_expiry',
        'data': {
          'document_type': 'driver_license',
          'action_route': '/driver-identity-verification',
        },
      });

      expect(target.destination, NotificationDestination.verification);
      expect(target.actionRoute, '/driver-identity-verification');
    });

    test('routes application and announcement notifications', () {
      expect(
        resolveNotificationTarget({
          'type': 'application',
          'data': {'application_id': 'application-1'},
        }).destination,
        NotificationDestination.application,
      );
      expect(
        resolveNotificationTarget({'type': 'announcement'}).destination,
        NotificationDestination.announcement,
      );
    });
  });
}
