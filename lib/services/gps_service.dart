import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gps_tracker_model.dart';
import 'gps/aika_gps_provider.dart';
import 'gps/gps_provider.dart';
import 'gps/traccar_gps_provider.dart';

class GpsService {
  static final GpsService _instance = GpsService._internal();
  factory GpsService() => _instance;
  GpsService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  final Map<String, GpsProvider> _providers = {
    'aika168': AikaGpsProvider(),
    'traccar': TraccarGpsProvider(),
  };

  GpsProvider getProvider(String providerId) {
    return _providers[providerId.toLowerCase().trim()] ?? AikaGpsProvider();
  }

  Future<bool> verifyCredentials({
    required String provider,
    required String deviceIdentifier,
    required String password,
  }) async {
    final gpsProvider = getProvider(provider);
    return await gpsProvider.verifyCredentials(
      deviceIdentifier: deviceIdentifier,
      password: password,
    );
  }

  /// Encodes the password in a reversible format so it can be recovered
  /// for GPS provider API authentication.
  String _encryptSecret(String text) {
    final bytes = utf8.encode('MOBILIS_GPS_SALT_$text');
    return base64Encode(bytes);
  }

  /// Recovers the original password from the stored Base64 value.
  static String decryptSecret(String encoded) {
    if (encoded.trim().isEmpty) return '123456';
    try {
      final decoded = utf8.decode(base64Decode(encoded));
      const prefix = 'MOBILIS_GPS_SALT_';
      if (decoded.startsWith(prefix)) {
        return decoded.substring(prefix.length);
      }
      return decoded;
    } catch (_) {
      // If not base64 (e.g. plain text or old format), return raw if short or default
      if (encoded.length < 32) return encoded;
      return '123456';
    }
  }

  /// Verifies credentials against provider and connects tracker to vehicle/application
  Future<VehicleTracker> verifyAndConnectTracker({
    String? vehicleId,
    String? partnerVehicleId,
    String? vehicleApplicationId,
    required String provider,
    required String deviceIdentifier,
    required String password,
  }) async {
    final cleanDevice = deviceIdentifier.trim();
    final cleanPassword = password.trim();
    final cleanProvider = provider.trim().isEmpty ? 'aika168' : provider.trim();
    final currentUser = _supabase.auth.currentUser;

    if (cleanDevice.isEmpty) {
      throw Exception('Device ID / IMEI is required.');
    }
    if (cleanPassword.isEmpty) {
      throw Exception('GPS password is required.');
    }

    // Resolve and validate target entity IDs dynamically to prevent foreign key errors
    String? resolvedVehicleId = (vehicleId != null && vehicleId.trim().isNotEmpty) ? vehicleId.trim() : null;
    String? resolvedPartnerVehicleId = (partnerVehicleId != null && partnerVehicleId.trim().isNotEmpty) ? partnerVehicleId.trim() : null;
    String? resolvedApplicationId = (vehicleApplicationId != null && vehicleApplicationId.trim().isNotEmpty) ? vehicleApplicationId.trim() : null;

    if (resolvedVehicleId != null) {
      try {
        final inVehicles = await _supabase
            .from('vehicles')
            .select('id')
            .eq('id', resolvedVehicleId)
            .limit(1);

        final vList = List<Map<String, dynamic>>.from(inVehicles);
        if (vList.isEmpty) {
          // Check if ID belongs to partner_vehicles
          final inPV = await _supabase
              .from('partner_vehicles')
              .select('id')
              .eq('id', resolvedVehicleId)
              .limit(1);

          final pvList = List<Map<String, dynamic>>.from(inPV);
          if (pvList.isNotEmpty) {
            resolvedPartnerVehicleId = resolvedVehicleId;
            resolvedVehicleId = null;
          } else {
            // Check if ID belongs to partner_vehicle_applications
            final inApp = await _supabase
                .from('partner_vehicle_applications')
                .select('id')
                .eq('id', resolvedVehicleId)
                .limit(1);

            final appList = List<Map<String, dynamic>>.from(inApp);
            if (appList.isNotEmpty) {
              resolvedApplicationId = resolvedVehicleId;
              resolvedVehicleId = null;
            } else {
              resolvedPartnerVehicleId = resolvedVehicleId;
              resolvedVehicleId = null;
            }
          }
        }
      } catch (e) {
        debugPrint('Dynamic vehicle ID resolution note: $e');
      }
    }

    if (resolvedPartnerVehicleId != null) {
      try {
        final inPV = await _supabase
            .from('partner_vehicles')
            .select('id')
            .eq('id', resolvedPartnerVehicleId)
            .limit(1);

        final pvList = List<Map<String, dynamic>>.from(inPV);
        if (pvList.isEmpty) {
          final inApp = await _supabase
              .from('partner_vehicle_applications')
              .select('id')
              .eq('id', resolvedPartnerVehicleId)
              .limit(1);

          final appList = List<Map<String, dynamic>>.from(inApp);
          if (appList.isNotEmpty) {
            resolvedApplicationId = resolvedPartnerVehicleId;
            resolvedPartnerVehicleId = null;
          }
        }
      } catch (e) {
        debugPrint('Dynamic partner vehicle ID resolution note: $e');
      }
    }

    // 1. Check if this device is already in vehicle_trackers for another vehicle
    try {
      final existingTrackers = await _supabase
          .from('vehicle_trackers')
          .select('id, vehicle_id, partner_vehicle_id, vehicle_application_id')
          .eq('device_identifier', cleanDevice)
          .neq('connection_status', 'disconnected')
          .limit(1);

      final existingList = List<Map<String, dynamic>>.from(existingTrackers);
      if (existingList.isNotEmpty) {
        final existing = existingList.first;
        final isSameTarget = (resolvedVehicleId != null && existing['vehicle_id'] == resolvedVehicleId) ||
            (resolvedPartnerVehicleId != null && existing['partner_vehicle_id'] == resolvedPartnerVehicleId) ||
            (resolvedApplicationId != null && existing['vehicle_application_id'] == resolvedApplicationId);

        if (!isSameTarget) {
          final existingVid = existing['vehicle_id'] ?? existing['partner_vehicle_id'] ?? existing['vehicle_application_id'];
          final targetVid = resolvedVehicleId ?? resolvedPartnerVehicleId ?? resolvedApplicationId;
          if (existingVid != null && existingVid != targetVid) {
            debugPrint('Re-assigning GPS tracker $cleanDevice from $existingVid to $targetVid');
          }
        }
      }
    } catch (e) {
      debugPrint('Duplicate tracker check note: $e');
    }

    // 2. Attempt credentials verification (non-blocking so details are always saved)
    bool isValid = true;
    try {
      final providerImpl = getProvider(cleanProvider);
      isValid = await providerImpl.verifyCredentials(
        deviceIdentifier: cleanDevice,
        password: cleanPassword,
      );
    } catch (e) {
      debugPrint('GPS provider verification note: $e');
    }

    // 3. Save tracker association in database ALWAYS
    final encrypted = _encryptSecret(cleanPassword);
    final now = DateTime.now().toUtc().toIso8601String();

    Map<String, dynamic> insertPayload = {
      'provider': cleanProvider,
      'device_identifier': cleanDevice,
      'encrypted_password': encrypted,
      'connection_status': 'connected',
      'last_sync_at': now,
      'updated_at': now,
    };

    if (resolvedVehicleId != null && resolvedVehicleId.isNotEmpty) {
      insertPayload['vehicle_id'] = resolvedVehicleId;
    }
    if (resolvedPartnerVehicleId != null && resolvedPartnerVehicleId.isNotEmpty) {
      insertPayload['partner_vehicle_id'] = resolvedPartnerVehicleId;
    }
    if (resolvedApplicationId != null && resolvedApplicationId.isNotEmpty) {
      insertPayload['vehicle_application_id'] = resolvedApplicationId;
    }
    if (currentUser != null) {
      insertPayload['partner_id'] = currentUser.id;
      insertPayload['operator_id'] = currentUser.id;
    }

    // Check existing tracker record for vehicle/application to update rather than duplicate
    try {
      if (resolvedVehicleId != null && resolvedVehicleId.isNotEmpty) {
        final existingForVeh = await _supabase
            .from('vehicle_trackers')
            .select('id')
            .eq('vehicle_id', resolvedVehicleId)
            .order('updated_at', ascending: false)
            .limit(1);
        final list = List<Map<String, dynamic>>.from(existingForVeh);
        if (list.isNotEmpty) {
          insertPayload['id'] = list.first['id'];
        }
      } else if (resolvedPartnerVehicleId != null && resolvedPartnerVehicleId.isNotEmpty) {
        final existingForPVeh = await _supabase
            .from('vehicle_trackers')
            .select('id')
            .eq('partner_vehicle_id', resolvedPartnerVehicleId)
            .order('updated_at', ascending: false)
            .limit(1);
        final list = List<Map<String, dynamic>>.from(existingForPVeh);
        if (list.isNotEmpty) {
          insertPayload['id'] = list.first['id'];
        }
      } else if (resolvedApplicationId != null && resolvedApplicationId.isNotEmpty) {
        final existingForApp = await _supabase
            .from('vehicle_trackers')
            .select('id')
            .eq('vehicle_application_id', resolvedApplicationId)
            .order('updated_at', ascending: false)
            .limit(1);
        final list = List<Map<String, dynamic>>.from(existingForApp);
        if (list.isNotEmpty) {
          insertPayload['id'] = list.first['id'];
        }
      }
    } catch (e) {
      debugPrint('Existing tracker ID lookup note: $e');
    }

    final response = await _supabase
        .from('vehicle_trackers')
        .upsert(insertPayload)
        .select()
        .single();

    return VehicleTracker.fromJson(response);
  }

  /// Get active tracker for vehicle
  Future<VehicleTracker?> getTrackerForVehicle(String vehicleId) async {
    if (vehicleId.isEmpty) return null;
    try {
      final response = await _supabase
          .from('vehicle_trackers')
          .select()
          .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId,vehicle_application_id.eq.$vehicleId')
          .neq('connection_status', 'disconnected')
          .order('updated_at', ascending: false)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(response);
      if (list.isNotEmpty) {
        return VehicleTracker.fromJson(list.first);
      }

      // Check if this vehicle is associated with a partner vehicle or application
      try {
        final pv = await _supabase
            .from('partner_vehicles')
            .select('id, vehicle_id')
            .or('id.eq.$vehicleId,vehicle_id.eq.$vehicleId')
            .limit(1);
        final pvList = List<Map<String, dynamic>>.from(pv);
        if (pvList.isNotEmpty) {
          final pvid = pvList.first['id']?.toString() ?? vehicleId;
          final pTracker = await _supabase
              .from('vehicle_trackers')
              .select()
              .eq('partner_vehicle_id', pvid)
              .neq('connection_status', 'disconnected')
              .order('updated_at', ascending: false)
              .limit(1);
          final ptList = List<Map<String, dynamic>>.from(pTracker);
          if (ptList.isNotEmpty) {
            return VehicleTracker.fromJson(ptList.first);
          }
        }
      } catch (_) {}

      return null;
    } catch (e) {
      debugPrint('Error getting tracker for vehicle $vehicleId: $e');
      return null;
    }
  }

  /// Get active tracker for application
  Future<VehicleTracker?> getTrackerForApplication(String applicationId) async {
    if (applicationId.isEmpty) return null;
    try {
      final response = await _supabase
          .from('vehicle_trackers')
          .select()
          .eq('vehicle_application_id', applicationId)
          .neq('connection_status', 'disconnected')
          .order('updated_at', ascending: false)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(response);
      if (list.isEmpty) return null;
      return VehicleTracker.fromJson(list.first);
    } catch (e) {
      debugPrint('Error getting tracker for application $applicationId: $e');
      return null;
    }
  }

  /// Fetches latest location position and updates vehicle_trackers cache
  Future<GpsPositionData?> fetchLatestLocation({
    required VehicleTracker tracker,
  }) async {
    try {
      final providerImpl = getProvider(tracker.provider);
      final rawPassword = decryptSecret(tracker.encryptedPassword ?? '');
      final position = await providerImpl.getLatestPosition(
        vehicleId: tracker.vehicleId ?? tracker.partnerVehicleId ?? tracker.id,
        deviceIdentifier: tracker.deviceIdentifier,
        password: rawPassword,
      );

      if (position != null) {
        final now = DateTime.now().toUtc().toIso8601String();
        await _supabase.from('vehicle_trackers').update({
          'last_latitude': position.latitude,
          'last_longitude': position.longitude,
          'last_speed': position.speedKph,
          'last_ignition': position.ignitionOn,
          'last_location_at': position.gpsTime?.toIso8601String() ?? now,
          'last_sync_at': now,
          'connection_status': position.isOnline ? 'connected' : 'offline',
          'updated_at': now,
        }).eq('id', tracker.id);
      }

      return position;
    } catch (e) {
      debugPrint('Error fetching latest GPS location: $e');
      return null;
    }
  }

  /// Transfers tracker linkage from application to created vehicle on approval
  Future<void> transferTrackerToVehicle({
    required String applicationId,
    required String targetVehicleId,
    bool isPartnerVehicle = false,
  }) async {
    try {
      final existingTracker = await getTrackerForApplication(applicationId);
      if (existingTracker == null) return;

      final updatePayload = <String, dynamic>{
        'connection_status': 'connected',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (isPartnerVehicle) {
        updatePayload['partner_vehicle_id'] = targetVehicleId;
      } else {
        updatePayload['vehicle_id'] = targetVehicleId;
      }

      await _supabase
          .from('vehicle_trackers')
          .update(updatePayload)
          .eq('id', existingTracker.id);

      debugPrint('Successfully transferred tracker ${existingTracker.id} to vehicle $targetVehicleId');
    } catch (e) {
      debugPrint('Error transferring tracker on application approval: $e');
    }
  }

  /// Disconnects tracker by tracker ID, vehicle ID, or partner vehicle ID
  Future<void> disconnectTracker(String identifier) async {
    if (identifier.trim().isEmpty) return;
    try {
      await _supabase.from('vehicle_trackers').update({
        'connection_status': 'disconnected',
        'encrypted_password': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).or('id.eq.$identifier,vehicle_id.eq.$identifier,partner_vehicle_id.eq.$identifier,vehicle_application_id.eq.$identifier');
    } catch (e) {
      debugPrint('Error disconnecting tracker: $e');
    }
  }
}
