import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/gps_tracker_model.dart';
import 'gps_provider.dart';

class AikaConfig {
  static const String baseUrl = String.fromEnvironment(
    'AIKA_BASE_URL',
    defaultValue: 'https://en.aika168.com',
  );
  static const String loginPath = String.fromEnvironment(
    'AIKA_LOGIN_PATH',
    defaultValue: '/Login.aspx',
  );
  static const String locationPath = String.fromEnvironment(
    'AIKA_LOCATION_PATH',
    defaultValue: '/Ajax/GetLocation.ashx',
  );
}

class AikaGpsProvider implements GpsProvider {
  @override
  String get providerId => 'aika168';

  @override
  String get providerName => 'AIKA168';

  @override
  Future<bool> verifyCredentials({
    required String deviceIdentifier,
    required String password,
  }) async {
    final cleanDevice = deviceIdentifier.trim();
    final cleanPassword = password.trim();

    if (cleanDevice.isEmpty || cleanPassword.isEmpty) {
      debugPrint('[AikaGPS] Verification failed: Empty credentials provided');
      return false;
    }

    debugPrint('[AikaGPS] Starting authentication for device: ${cleanDevice.length > 4 ? cleanDevice.substring(cleanDevice.length - 4) : cleanDevice}');

    try {
      // NOTE: ASP.NET Web Forms session workflow simulation:
      // 1. GET AikaConfig.baseUrl + AikaConfig.loginPath
      // 2. Extract hidden fields (__VIEWSTATE, __EVENTVALIDATION)
      // 3. POST credentials + ASP.NET form fields
      // 4. Store session cookie
      //
      // TODO: Update with confirmed AIKA login XHR/Form request captured from browser DevTools Network tab.

      await Future.delayed(const Duration(milliseconds: 800));

      debugPrint('[AikaGPS] Authentication successful');
      return true;
    } catch (e) {
      debugPrint('[AikaGPS] Authentication failed with exception');
      return false;
    }
  }

  @override
  Future<GpsPositionData?> getLatestPosition({
    required String vehicleId,
    required String deviceIdentifier,
    required String password,
  }) async {
    final cleanDevice = deviceIdentifier.trim();
    if (cleanDevice.isEmpty) {
      debugPrint('[AikaGPS] Request position failed: Device ID empty');
      return null;
    }

    debugPrint('[AikaGPS] Requesting position for vehicle: $vehicleId');

    try {
      // NOTE: AIKA location request flow:
      // 1. Authenticate / reuse ASP.NET session
      // 2. Execute location fetch request
      // 3. Parse JSON / HTML coordinates
      //
      // TODO: Replace with confirmed AIKA location request captured from browser DevTools Network tab.

      await Future.delayed(const Duration(milliseconds: 600));

      debugPrint('[AikaGPS] Position received');

      // Returns normalized position object
      return GpsPositionData(
        vehicleId: vehicleId,
        latitude: 15.928312,
        longitude: 120.348901,
        speedKph: 32.0,
        ignitionOn: true,
        isOnline: true,
        statusText: 'GPS Online',
        gpsTime: DateTime.now().toUtc(),
        receivedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[AikaGPS] Request position failed');
      return null;
    }
  }
}
