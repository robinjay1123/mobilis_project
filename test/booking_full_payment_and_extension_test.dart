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

    test('isBookingFullyPaid returns true when reservation_payment_covers_total is true', () {
      final booking = {
        'id': 'booking-6',
        'status': 'approved',
        'reservation_payment_covers_total': true,
        'total_price': 14400.0,
      };

      expect(bookingService.isBookingFullyPaid(booking), isTrue);
      expect(bookingService.getBookingRemainingBalance(booking), 0.0);
    });

    test('isBookingFullyPaid returns true when reservation_payment_type is full_payment', () {
      final booking = {
        'id': 'booking-7',
        'status': 'approved',
        'reservation_payment_type': 'full_payment',
        'total_price': 14400.0,
      };

      expect(bookingService.isBookingFullyPaid(booking), isTrue);
      expect(bookingService.getBookingRemainingBalance(booking), 0.0);
    });

    test('isBookingFullyPaid returns false when reservation fee only and reservation_payment_type is reservation_only', () {
      final booking = {
        'id': 'booking-8',
        'status': 'approved',
        'reservation_payment_type': 'reservation_only',
        'reservation_payment_covers_total': false,
        'reservation_fee_amount': 1000.0,
        'total_price': 14400.0,
      };

      expect(bookingService.isBookingFullyPaid(booking), isFalse);
      expect(bookingService.getBookingRemainingBalance(booking), 13400.0);
    });
  });
}

