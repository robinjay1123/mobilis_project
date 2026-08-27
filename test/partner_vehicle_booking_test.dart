import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/vehicle_service.dart';

void main() {
  group('Partner vehicle booking & availability validation', () {
    final vehicleService = VehicleService();

    test('isVehicleBookable evaluates partner vehicle status correctly', () async {
      final isValid = await vehicleService.isVehicleBookable('');
      expect(isValid, isFalse);
    });
  });
}
