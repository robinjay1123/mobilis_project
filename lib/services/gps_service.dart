import 'dart:convert';
import 'package:crypto/crypto.dart';
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

  String _encryptSecret(String text) {
    final bytes = utf8.encode('MOBILIS_GPS_SALT_$text');
    return sha256.convert(bytes).toString();
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

    // 1. Duplicate active tracker check
    final existingTrackers = await _supabase
        .from('vehicle_trackers')
        .select('id, vehicle_id, partner_vehicle_id, vehicle_application_id')
        .eq('device_identifier', cleanDevice)
        .neq('connection_status', 'disconnected');

    final existingList = List<Map<String, dynamic>>.from(existingTrackers);
    if (existingList.isNotEmpty) {
      final existing = existingList.first;
      final existingVid = existing['vehicle_id'] ?? existing['partner_vehicle_id'] ?? existing['vehicle_application_id'];
      final targetVid = vehicleId ?? partnerVehicleId ?? vehicleApplicationId;
      if (existingVid != null && existingVid != targetVid) {
        throw Exception('This GPS tracker is already connected to another vehicle.');
      }
    }

    // 2. Verify credentials against provider
    final providerImpl = getProvider(cleanProvider);
    final isValid = await providerImpl.verifyCredentials(
      deviceIdentifier: cleanDevice,
      password: cleanPassword,
    );

    if (!isValid) {
      throw Exception('Unable to authenticate with $cleanProvider. Please check your Device ID and password.');
    }

    // 3. Save tracker association in database
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

    if (vehicleId != null && vehicleId.isNotEmpty) {
      insertPayload['vehicle_id'] = vehicleId;
    }
    if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
      insertPayload['partner_vehicle_id'] = partnerVehicleId;
    }
    if (vehicleApplicationId != null && vehicleApplicationId.isNotEmpty) {
      insertPayload['vehicle_application_id'] = vehicleApplicationId;
    }
    if (currentUser != null) {
      insertPayload['partner_id'] = currentUser.id;
      insertPayload['operator_id'] = currentUser.id;
    }

    // Upsert if existing tracker record for vehicle/application
    if (vehicleId != null && vehicleId.isNotEmpty) {
      final existingForVeh = await _supabase
          .from('vehicle_trackers')
          .select('id')
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      if (existingForVeh != null) {
        insertPayload['id'] = existingForVeh['id'];
      }
    } else if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
      final existingForPVeh = await _supabase
          .from('vehicle_trackers')
          .select('id')
          .eq('partner_vehicle_id', partnerVehicleId)
          .maybeSingle();
      if (existingForPVeh != null) {
        insertPayload['id'] = existingForPVeh['id'];
      }
    } else if (vehicleApplicationId != null && vehicleApplicationId.isNotEmpty) {
      final existingForApp = await _supabase
          .from('vehicle_trackers')
          .select('id')
          .eq('vehicle_application_id', vehicleApplicationId)
          .maybeSingle();
      if (existingForApp != null) {
        insertPayload['id'] = existingForApp['id'];
      }
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
          .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
          .neq('connection_status', 'disconnected')
          .maybeSingle();

      if (response == null) return null;
      return VehicleTracker.fromJson(response);
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
          .maybeSingle();

      if (response == null) return null;
      return VehicleTracker.fromJson(response);
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
      final position = await providerImpl.getLatestPosition(
        vehicleId: tracker.vehicleId ?? tracker.partnerVehicleId ?? tracker.id,
        deviceIdentifier: tracker.deviceIdentifier,
        password: tracker.encrypted_password ?? '',
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

  /// Disconnects tracker
  Future<void> disconnectTracker(String trackerId) async {
    try {
      await _supabase.from('vehicle_trackers').update({
        'connection_status': 'disconnected',
        'encrypted_password': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', trackerId);
    } catch (e) {
      debugPrint('Error disconnecting tracker: $e');
      rethrow;
    }
  }
}
