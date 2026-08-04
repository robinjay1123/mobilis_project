import 'package:flutter/foundation.dart';
import '../../models/gps_tracker_model.dart';
import 'gps_provider.dart';

class TraccarGpsProvider implements GpsProvider {
  @override
  String get providerId => 'traccar';

  @override
  String get providerName => 'Traccar GPS';

  @override
  Future<bool> verifyCredentials({
    required String deviceIdentifier,
    required String password,
  }) async {
    debugPrint('[TraccarGPS] Credentials verification stub called');
    return true;
  }

  @override
  Future<GpsPositionData?> getLatestPosition({
    required String vehicleId,
    required String deviceIdentifier,
    required String password,
  }) async {
    debugPrint('[TraccarGPS] Position request stub called for $vehicleId');
    return GpsPositionData(
      vehicleId: vehicleId,
      latitude: 15.928312,
      longitude: 120.348901,
      speedKph: 0.0,
      ignitionOn: false,
      isOnline: true,
      statusText: 'Connected (Traccar)',
      gpsTime: DateTime.now().toUtc(),
      receivedAt: DateTime.now(),
    );
  }
}
