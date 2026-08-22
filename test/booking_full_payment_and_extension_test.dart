import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/booking_service.dart';

void main() {
  group('Booking Full Payment & Key Release Tests', () {
    final bookingService = BookingService();

    test('isBookingFullyPaid returns true when payment_status is paid', () {
      final booking = {
        'id': 'booking-1',
        'status': 'approved',
        'payment_status': 'paid',
        'total_price': 5000.0,
        'paid_amount': 5000.0,
      };

      expect(bookingService.isBookingFullyPaid(booking), isTrue);
      expect(bookingService.getBookingRemainingBalance(booking), 0.0);
    });

    test('isBookingFullyPaid returns false when only partial reservation fee was paid', () {
      final booking = {
        'id': 'booking-2',
        'status': 'approved',
        'payment_status': 'pending',
        'total_price': 6000.0,
        'paid_amount': 1000.0,
        'reservation_fee': 1000.0,
      };

      expect(bookingService.isBookingFullyPaid(booking), isFalse);
      expect(bookingService.getBookingRemainingBalance(booking), 5000.0);
    });

    test('isBookingFullyPaid returns true when final_payment_status is paid', () {
      final booking = {
        'id': 'booking-3',
        'status': 'approved',
        'final_payment_status': 'paid',
        'total_price': 4500.0,
      };

      expect(bookingService.isBookingFullyPaid(booking), isTrue);
      expect(bookingService.getBookingRemainingBalance(booking), 0.0);
    });

    test('getBookingRemainingBalance calculates exact remaining balance', () {
      final booking = {
        'id': 'booking-4',
        'total_price': 7500.0,
        'paid_amount': 2500.0,
      };

      expect(bookingService.getBookingRemainingBalance(booking), 5000.0);
    });

    test('getBookingRemainingBalance falls back to reservation_fee if paid_amount is missing', () {
      final booking = {
        'id': 'booking-5',
        'total_price': 8000.0,
        'reservation_fee': 2000.0,
      };

      expect(bookingService.getBookingRemainingBalance(booking), 6000.0);
    });
  });
}
