import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Calls the Supabase Edge Function `gps-tracker-poll` which handles
  /// the AIKA168 server communication server-side (no CORS issues).
  Future<Map<String, dynamic>?> _callEdgeFunction({
    required String deviceIdentifier,
    required String password,
    String action = 'location',
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'gps-tracker-poll',
        body: {
          'device_identifier': deviceIdentifier.trim(),
          'password': password.trim(),
          'provider': 'aika168',
          'action': action,
        },
      );

      if (response.status != 200) {
        debugPrint(
          '[AikaGPS] Edge function returned status ${response.status}',
        );
        return null;
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }

      // Try parsing string response
      if (data is String) {
        try {
          return jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          debugPrint('[AikaGPS] Could not parse edge function response');
          return null;
        }
      }

      return null;
    } catch (e) {
      debugPrint('[AikaGPS] Edge function call failed: $e');
      return null;
    }
  }

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

    debugPrint(
      '[AikaGPS] Starting authentication for device: ${cleanDevice.length > 4 ? '****${cleanDevice.substring(cleanDevice.length - 4)}' : cleanDevice}',
    );

    final result = await _callEdgeFunction(
      deviceIdentifier: cleanDevice,
      password: cleanPassword,
      action: 'verify',
    );

    if (result == null) {
      debugPrint('[AikaGPS] Verification: No response from edge function');
      return false;
    }

    final success = result['success'] == true;
    debugPrint(
      '[AikaGPS] Authentication ${success ? 'successful' : 'failed'}',
    );
    return success;
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

    final result = await _callEdgeFunction(
      deviceIdentifier: cleanDevice,
      password: password,
      action: 'location',
    );

    if (result == null) {
      debugPrint('[AikaGPS] No response from edge function');
      return null;
    }

    if (result['success'] != true || result['position'] == null) {
      debugPrint(
        '[AikaGPS] Position fetch failed: ${result['error'] ?? 'Unknown error'}',
      );
      return null;
    }

    final position = result['position'] as Map<String, dynamic>;
    final lat = (position['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (position['longitude'] as num?)?.toDouble() ?? 0.0;

    if (lat == 0.0 && lng == 0.0) {
      debugPrint('[AikaGPS] Position returned zero coordinates');
      return null;
    }

    debugPrint('[AikaGPS] Position received: $lat, $lng');

    final gpsTimeStr = position['gps_time']?.toString();
    DateTime? gpsTime;
    if (gpsTimeStr != null && gpsTimeStr.isNotEmpty) {
      gpsTime = DateTime.tryParse(gpsTimeStr);
    }

    return GpsPositionData(
      vehicleId: vehicleId,
      latitude: lat,
      longitude: lng,
      speedKph: (position['speed_kph'] as num?)?.toDouble() ?? 0.0,
      ignitionOn: position['ignition'] == true,
      isOnline: position['online'] != false,
      statusText: position['status_text']?.toString() ?? 'GPS Online',
      gpsTime: gpsTime ?? DateTime.now().toUtc(),
      receivedAt: DateTime.now(),
    );
  }
}
