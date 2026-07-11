import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/utils/pricing_policy.dart';

void main() {
  group('Booking pricing policy', () {
    test('delivery fee uses exactly PHP 75 per kilometer', () {
      const distanceKm = 12.5;
      final deliveryFee = distanceKm * PricingPolicy.deliveryRatePerKm;

      expect(PricingPolicy.deliveryRatePerKm, 75);
      expect(deliveryFee, 937.5);
    });

    test('rental prices enforce configured limits', () {
      expect(
        PricingPolicy.validateDailyRentalPrice(
          PricingPolicy.minDailyRentalPrice,
        ),
        isNull,
      );
      expect(
        PricingPolicy.validateHourlyRentalPrice(
          PricingPolicy.maxHourlyRentalPrice,
        ),
        isNull,
      );
      expect(PricingPolicy.validateDailyRentalPrice(100), isNotNull);
      expect(PricingPolicy.validateHourlyRentalPrice(10000), isNotNull);
    });
  });
}
