import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/booking_service.dart';
import 'package:mobilis_by_psdc_app/services/reservation_payment_service.dart';
import 'package:mobilis_by_psdc_app/utils/pricing_policy.dart';

void main() {
  group('Late Return Fee Calculation & Rules Tests', () {
    test('Approved Extension: 4-5 seater vehicle charges PHP 200 per hour for hours 1 to 5', () {
      // 1 hour late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 4,
          lateHours: 1,
          dailyRate: 1800.0,
          isApproved: true,
        ),
        200.0,
      );

      // 3 hours late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 5,
          lateHours: 3,
          dailyRate: 1800.0,
          isApproved: true,
        ),
        600.0,
      );

      // 5 hours late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 4,
          lateHours: 5,
          dailyRate: 1800.0,
          isApproved: true,
        ),
        1000.0,
      );
    });

    test('Approved Extension: 6+ seater (7-seater tier) charges PHP 350 per hour for hours 1 to 5', () {
      // 1 hour late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 6,
          lateHours: 1,
          dailyRate: 3500.0,
          isApproved: true,
        ),
        350.0,
      );

      // 4 hours late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 7,
          lateHours: 4,
          dailyRate: 3500.0,
          isApproved: true,
        ),
        1400.0,
      );

      // 5 hours late
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 12,
          lateHours: 5,
          dailyRate: 4500.0,
          isApproved: true,
        ),
        1750.0,
      );
    });

    test('Approved Extension: 6 hours pataas consider as whole day na (e.g. 1,800/day -> 1,800 fee)', () {
      // 4-5 seater 6 hours late with daily rate of 1800 -> 1800
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 4,
          lateHours: 6,
          dailyRate: 1800.0,
          isApproved: true,
        ),
        1800.0,
      );

      // 4-5 seater 10 hours late with daily rate of 1800 -> 1800
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 5,
          lateHours: 10,
          dailyRate: 1800.0,
          isApproved: true,
        ),
        1800.0,
      );

      // 7 seater 8 hours late with daily rate of 3000 -> 3000
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 7,
          lateHours: 8,
          dailyRate: 3000.0,
          isApproved: true,
        ),
        3000.0,
      );

      // 24 hours late with daily rate of 2500 -> 2500
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 5,
          lateHours: 24,
          dailyRate: 2500.0,
          isApproved: true,
        ),
        2500.0,
      );
    });

    test('Unapproved Extension: kahit 1 hour man yan or what 5k parin since hindi nga approve', () {
      // 1 hour late unapproved -> flat 5000 penalty
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 4,
          lateHours: 1,
          dailyRate: 1800.0,
          isApproved: false,
        ),
        5000.0,
      );

      // 2 hours late unapproved -> 5000
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 7,
          lateHours: 2,
          dailyRate: 3500.0,
          isApproved: false,
        ),
        5000.0,
      );

      // 5 hours late unapproved -> 5000
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 5,
          lateHours: 5,
          dailyRate: 1800.0,
          isApproved: false,
        ),
        5000.0,
      );

      // 12 hours late unapproved -> 5000
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 4,
          lateHours: 12,
          dailyRate: 2000.0,
          isApproved: false,
        ),
        5000.0,
      );

      // 24 hours late unapproved -> 5000
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 7,
          lateHours: 24,
          dailyRate: 3000.0,
          isApproved: false,
        ),
        5000.0,
      );

      // Multi-day unapproved (e.g. 26 hours = 1 day (1800) + 5000 penalty = 6800)
      expect(
        PricingPolicy.calculateLateReturnFee(
          seats: 4,
          lateHours: 26,
          dailyRate: 1800.0,
          isApproved: false,
        ),
        6800.0,
      );
    });

    test('ExceededReturnBreakdown provides accurate breakdown objects and descriptions', () {
      // Approved 3 hours 4-seater
      final b1 = PricingPolicy.getExceededReturnBreakdown(
        seats: 4,
        lateHours: 3,
        dailyRate: 1800.0,
        isApproved: true,
      );
      expect(b1.totalFee, 600.0);
      expect(b1.isApproved, true);
      expect(b1.isWholeDayCap, false);
      expect(b1.isUnapprovedPenalty, false);
      expect(b1.tierDescription, '1–5 Seater Tier (₱200/hr)');

      // Approved 7 hours 7-seater (cap applied)
      final b2 = PricingPolicy.getExceededReturnBreakdown(
        seats: 7,
        lateHours: 7,
        dailyRate: 3000.0,
        isApproved: true,
      );
      expect(b2.totalFee, 3000.0);
      expect(b2.isApproved, true);
      expect(b2.isWholeDayCap, true);
      expect(b2.isUnapprovedPenalty, false);

      // Unapproved 2 hours
      final b3 = PricingPolicy.getExceededReturnBreakdown(
        seats: 5,
        lateHours: 2,
        dailyRate: 1800.0,
        isApproved: false,
      );
      expect(b3.totalFee, 5000.0);
      expect(b3.isApproved, false);
      expect(b3.isUnapprovedPenalty, true);
      expect(b3.tierDescription, 'Unapproved Extension (Flat ₱5,000 Penalty)');
    });

    test('Custom admin late fee settings are respected in ReservationPaymentSettings', () {
      const settings = ReservationPaymentSettings(
        amount: 1000.0,
        lateFee4to5Seater: 250.0,
        lateFee6PlusSeater: 400.0,
        lateFeeDayCapHours: 5,
        unapprovedLateFee: 6000.0,
        qrUrl: '',
        accountName: 'PSDC',
        instructions: '',
      );

      // Custom approved 4-5 seater rate: 2 hrs * 250 = 500
      expect(
        settings.calculateLateFee(
          seats: 4,
          lateHours: 2,
          dailyRate: 3000.0,
          isApproved: true,
        ),
        500.0,
      );

      // Custom approved 6+ seater rate: 3 hrs * 400 = 1200
      expect(
        settings.calculateLateFee(
          seats: 7,
          lateHours: 3,
          dailyRate: 4500.0,
          isApproved: true,
        ),
        1200.0,
      );

      // Custom cap at 5 hours: 5 hrs late -> dailyRate (3000)
      expect(
        settings.calculateLateFee(
          seats: 4,
          lateHours: 5,
          dailyRate: 3000.0,
          isApproved: true,
        ),
        3000.0,
      );

      // Custom unapproved fee: 1 hr late -> 6000.0
      expect(
        settings.calculateLateFee(
          seats: 4,
          lateHours: 1,
          dailyRate: 3000.0,
          isApproved: false,
        ),
        6000.0,
      );
    });

    test('BookingService getLateReturnDetails accurately computes approved vs unapproved fees', () {
      final bookingService = BookingService();
      final now = DateTime.now();
      final scheduledReturn = now.subtract(const Duration(hours: 3));

      // Approved booking
      final approvedBooking = {
        'id': 'booking-test-approved',
        'end_at': scheduledReturn.toIso8601String(),
        'total_price': 5000.0,
        'days': 2,
        'extension_status': 'finalized',
        'vehicles': {
          'seats': 5,
          'daily_rate': 2500.0,
        },
      };

      final approvedDetails = bookingService.getLateReturnDetails(approvedBooking, now);
      expect(approvedDetails['late_return_hours'], 3);
      expect(approvedDetails['late_return_fee'], 600.0); // 3 hrs * 200
      expect(approvedDetails['total_price'], 5600.0);

      // Unapproved booking (no approved extension)
      final unapprovedBooking = {
        'id': 'booking-test-unapproved',
        'end_at': scheduledReturn.toIso8601String(),
        'total_price': 5000.0,
        'days': 2,
        'extension_status': 'none',
        'vehicles': {
          'seats': 5,
          'daily_rate': 2500.0,
        },
      };

      final unapprovedDetails = bookingService.getLateReturnDetails(unapprovedBooking, now);
      expect(unapprovedDetails['late_return_hours'], 3);
      expect(unapprovedDetails['late_return_fee'], 5000.0); // Flat 5,000 penalty
      expect(unapprovedDetails['total_price'], 10000.0);
    });
  });
}
