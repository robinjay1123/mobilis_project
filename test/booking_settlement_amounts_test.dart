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

    test('calculates partner payout with 5% commission and zero deposit deduction', () {
      // Rental Total = 9000 + 700 + 300 = 10000
      // 5% PSDC Commission = 500
      // Partner Earnings = 9500
      // Security Deposit Deduction = 0
      // Final Partner Disbursement = 9500
      final amounts = BookingSettlementAmounts.calculate(
        rentalAmount: 9000,
        deliveryAmount: 700,
        lateFeeAmount: 300,
        driverGross: 0,
        isPartnerVehicle: true,
        securityDepositDeduction: 0,
      );

      expect(amounts.ownerServiceAmount, 10000);
      expect(amounts.partnerCommission, 500);
      expect(amounts.partnerEarnings, 9500);
      expect(amounts.securityDepositDeduction, 0);
      expect(amounts.partnerNet, 9500);
    });

    test('calculates partner payout with 5% commission and conditional deposit deduction', () {
      // Rental Total = 10000
      // 5% PSDC Commission = 500
      // Partner Earnings = 9500
      // Security Deposit Deduction = 1500 (withheld for damage)
      // Final Partner Disbursement = 9500 - 1500 = 8000
      final amounts = BookingSettlementAmounts.calculate(
        rentalAmount: 10000,
        deliveryAmount: 0,
        lateFeeAmount: 0,
        driverGross: 0,
        isPartnerVehicle: true,
        securityDepositDeduction: 1500,
      );

      expect(amounts.ownerServiceAmount, 10000);
      expect(amounts.partnerCommission, 500);
      expect(amounts.partnerEarnings, 9500);
      expect(amounts.securityDepositDeduction, 1500);
      expect(amounts.partnerNet, 8000);
    });

    test('clamps partner payout to zero if deposit deduction exceeds partner earnings', () {
      final amounts = BookingSettlementAmounts.calculate(
        rentalAmount: 1000,
        deliveryAmount: 0,
        lateFeeAmount: 0,
        driverGross: 0,
        isPartnerVehicle: true,
        securityDepositDeduction: 2000,
      );

      expect(amounts.ownerServiceAmount, 1000);
      expect(amounts.partnerCommission, 50);
      expect(amounts.partnerEarnings, 950);
      expect(amounts.securityDepositDeduction, 2000);
      expect(amounts.partnerNet, 0);
    });
  });
}
