import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/booking_settlement_service.dart';

void main() {
  group('BookingSettlementAmounts', () {
    test('deducts partner and driver commissions from their payouts', () {
      final amounts = BookingSettlementAmounts.calculate(
        rentalAmount: 5000,
        deliveryAmount: 750,
        lateFeeAmount: 300,
        driverGross: 1000,
        isPartnerVehicle: true,
      );

      expect(amounts.ownerServiceAmount, 6050);
      expect(amounts.partnerCommission, 302.5);
      expect(amounts.partnerNet, 5747.5);
      expect(amounts.driverCommission, 50);
      expect(amounts.driverNet, 950);
      expect(amounts.grossAmount, 7050);
    });

    test('keeps PSDC-managed vehicle revenue under the operator ledger', () {
      final amounts = BookingSettlementAmounts.calculate(
        rentalAmount: 3600,
        deliveryAmount: 0,
        lateFeeAmount: 0,
        driverGross: 0,
        isPartnerVehicle: false,
      );

      expect(amounts.ownerServiceAmount, 3600);
      expect(amounts.partnerCommission, 0);
      expect(amounts.partnerNet, 0);
      expect(amounts.grossAmount, 3600);
    });
  });
}
