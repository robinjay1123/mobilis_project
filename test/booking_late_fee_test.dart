import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/booking_service.dart';
import 'package:mobilis_by_psdc_app/services/reservation_payment_service.dart';
import 'package:mobilis_by_psdc_app/utils/pricing_policy.dart';

void main() {
  group('Late Return Fee Calculation & Rules Tests', () {
    test('4-5 seater vehicle charges PHP 200 per hour for hours <= 5', () {
      // 1 hour late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 4,
          lateHours: 1,
          dailyRate: 2500.0,
        ),
        200.0,
      );

      // 3 hours late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 5,
          lateHours: 3,
          dailyRate: 2500.0,
        ),
        600.0,
      );

      // 5 hours late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 4,
          lateHours: 5,
          dailyRate: 2500.0,
        ),
        1000.0,
      );
    });

    test('6+ seater vehicle charges PHP 350 per hour for hours <= 5', () {
      // 1 hour late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 6,
          lateHours: 1,
          dailyRate: 4000.0,
        ),
        350.0,
      );

      // 4 hours late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 7,
          lateHours: 4,
          dailyRate: 4000.0,
        ),
        1400.0,
      );

      // 5 hours late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 12,
          lateHours: 5,
          dailyRate: 4500.0,
        ),
        1750.0,
      );
    });

    test('Late return duration >= 6 hours is capped at the whole 1-day rental rate', () {
      // 4-5 seater 6 hours late with daily rate of 2500 -> whole day price (2500)
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 4,
          lateHours: 6,
          dailyRate: 2500.0,
        ),
        2500.0,
      );

      // 4-5 seater 10 hours late with daily rate of 2500 -> whole day price (2500)
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 5,
          lateHours: 10,
          dailyRate: 2500.0,
        ),
        2500.0,
      );

      // 6+ seater 7 hours late with daily rate of 3500 -> whole day price (3500)
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 7,
          lateHours: 7,
          dailyRate: 3500.0,
        ),
        3500.0,
      );

      // 6+ seater 24 hours late with daily rate of 4000 -> whole day price (4000)
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 8,
          lateHours: 24,
          dailyRate: 4000.0,
        ),
        4000.0,
      );
    });

    test('Custom admin late fee settings are respected', () {
      const settings = ReservationPaymentSettings(
        amount: 1000.0,
        lateFee4to5Seater: 250.0,
        lateFee6PlusSeater: 400.0,
        lateFeeDayCapHours: 5,
        qrUrl: '',
        accountName: 'PSDC',
        instructions: '',
      );

      // Custom 4-5 seater rate: 2 hrs * 250 = 500
      expect(
        settings.calculateLateFee(
          seats: 4,
          lateHours: 2,
          dailyRate: 3000.0,
        ),
        500.0,
      );

      // Custom 6+ seater rate: 3 hrs * 400 = 1200
      expect(
        settings.calculateLateFee(
          seats: 7,
          lateHours: 3,
          dailyRate: 4500.0,
        ),
        1200.0,
      );

      // Custom cap at 5 hours: 5 hrs late -> dailyRate (3000)
      expect(
        settings.calculateLateFee(
          seats: 4,
          lateHours: 5,
          dailyRate: 3000.0,
        ),
        3000.0,
      );
    });

    test('BookingService getLateReturnDetails accurately computes late hours and fees', () {
      final bookingService = BookingService();
      final now = DateTime.now();
      final scheduledReturn = now.subtract(const Duration(hours: 3));

      final booking = {
        'id': 'booking-test-1',
        'end_at': scheduledReturn.toIso8601String(),
        'total_price': 5000.0,
        'days': 2,
        'vehicles': {
          'seats': 5,
          'daily_rate': 2500.0,
        },
      };

      final details = bookingService.getLateReturnDetails(booking, now);
      expect(details['late_return_hours'], 3);
      expect(details['late_return_fee'], 600.0); // 3 * 200
      expect(details['total_price'], 5600.0);
    });
  });
}
