import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/handover_verification_service.dart';
import 'package:mobilis_by_psdc_app/services/partner_service.dart';

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

  group('Feature 3: Partner Vehicle Maintenance & Service Reminders', () {
    final partnerService = PartnerService();

    test('Evaluates maintenance health status correctly', () {
      final goodSettings = {
        'current_odometer_km': 40000.0,
        'next_service_odometer_km': 45000.0,
        'oil_change_due_date': '2028-12-31',
        'lto_registration_due_date': '2028-12-31',
      };

      final dueSoonSettings = {
        'current_odometer_km': 44600.0, // Within 500km
        'next_service_odometer_km': 45000.0,
        'oil_change_due_date': '2028-12-31',
      };

      final overdueSettings = {
        'current_odometer_km': 46000.0, // Exceeds 45000km target
        'next_service_odometer_km': 45000.0,
      };

      expect(partnerService.evaluateMaintenanceHealth(goodSettings), equals('good'));
      expect(partnerService.evaluateMaintenanceHealth(dueSoonSettings), equals('due_soon'));
      expect(partnerService.evaluateMaintenanceHealth(overdueSettings), equals('overdue'));
    });
  });
}
