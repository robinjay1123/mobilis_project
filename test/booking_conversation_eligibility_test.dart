import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/booking_service.dart';

void main() {
  group('BookingService isEligibleForBookingChat', () {
    final bookingService = BookingService();

    test('returns false for pending or unapproved status', () {
      final booking = {
        'status': 'pending',
        'start_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      };
      expect(bookingService.isEligibleForBookingChat(booking), isFalse);
    });

    test('returns false for terminal statuses like cancelled or rejected', () {
      final booking1 = {
        'status': 'cancelled',
        'start_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      };
      final booking2 = {
        'status': 'rejected',
        'start_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      };
      expect(bookingService.isEligibleForBookingChat(booking1), isFalse);
      expect(bookingService.isEligibleForBookingChat(booking2), isFalse);
    });

    test('returns false for approved booking starting more than 3 days in advance', () {
      final booking = {
        'status': 'approved',
        'start_at': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      };
      expect(bookingService.isEligibleForBookingChat(booking), isFalse);
    });

    test('returns true for approved booking starting within 3 days', () {
      final booking = {
        'status': 'approved',
        'start_at': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      };
      expect(bookingService.isEligibleForBookingChat(booking), isTrue);
    });

    test('returns true for confirmed booking starting in 1 hour', () {
      final booking = {
        'status': 'confirmed',
        'start_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      };
      expect(bookingService.isEligibleForBookingChat(booking), isTrue);
    });

    test('returns true for active, ongoing, or pending inspection trips', () {
      final activeBooking = {
        'status': 'active',
        'start_at': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
      };
      final ongoingBooking = {
        'status': 'ongoing',
        'start_at': DateTime.now().toIso8601String(),
      };
      expect(bookingService.isEligibleForBookingChat(activeBooking), isTrue);
      expect(bookingService.isEligibleForBookingChat(ongoingBooking), isTrue);
    });
  });
}
