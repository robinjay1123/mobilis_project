import '../../models/gps_tracker_model.dart';

abstract class GpsProvider {
  String get providerId;
  String get providerName;

  /// Verifies credentials against the GPS server.
  /// Returns true if authentication succeeds.
  Future<bool> verifyCredentials({
    required String deviceIdentifier,
    required String password,
  });

  /// Fetches the latest normalized GPS position from the provider server.
  Future<GpsPositionData?> getLatestPosition({
    required String vehicleId,
    required String deviceIdentifier,
    required String password,
  });
}
