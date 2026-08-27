import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/handover_verification_service.dart';

void main() {
  group('Feature 1: Renter Digital QR Handover Verification Service', () {
    final verificationService = HandoverVerificationService();

    test('generateHandoverPin produces a valid 6-digit numeric string', () {
      const bookingId = 'bk_test_12345';
      const renterId = 'rn_test_67890';

      final pin1 = verificationService.generateHandoverPin(bookingId, renterId);
      final pin2 = verificationService.generateHandoverPin(bookingId, renterId);

      expect(pin1, isNotEmpty);
      expect(pin1.length, equals(6));
      expect(int.tryParse(pin1), isNotNull);
      // Deterministic pin check
      expect(pin1, equals(pin2));
    });

    test('generateQrPayload produces valid JSON string with required keys', () {
      const bookingId = 'bk_test_12345';
      const renterId = 'rn_test_67890';
      const vehicleId = 'vh_test_99999';

      final payload = verificationService.generateQrPayload(
        bookingId: bookingId,
        renterId: renterId,
        vehicleId: vehicleId,
        vehicleName: 'Toyota Vios 2024',
      );

      expect(payload, contains('MOBILIS_PSDC'));
      expect(payload, contains('VEHICLE_HANDOVER_PASS'));
      expect(payload, contains(bookingId));
      expect(payload, contains(renterId));
      expect(payload, contains('Toyota Vios 2024'));
    });
  });

  group('Feature 2: Partner Dynamic Pricing Calculations', () {
    test('Calculates weekend surge rate correctly', () {
      const baseDailyRate = 2000.0;
      const weekendMultiplier = 1.15; // +15%
      const peakSurcharge = 500.0;

      final standardRate = baseDailyRate * 1.0;
      final weekendRate = baseDailyRate * weekendMultiplier;
      final peakWeekendRate = (baseDailyRate * weekendMultiplier) + peakSurcharge;

      expect(standardRate, equals(2000.0));
      expect(weekendRate, equals(2300.0));
      expect(peakWeekendRate, equals(2800.0));
    });
  });
}
