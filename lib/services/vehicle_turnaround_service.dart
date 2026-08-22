import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

/// Service to handle automated vehicle unlisting upon return for cleaning and inspection,
/// configurable turnaround buffers (dropdown), and immediate manual relisting.
class VehicleTurnaroundService {
  static final VehicleTurnaroundService _instance =
      VehicleTurnaroundService._internal();

  factory VehicleTurnaroundService() => _instance;

  VehicleTurnaroundService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _globalTurnaroundPrefKey = 'global_vehicle_turnaround_minutes';
  static const String _vehicleTurnaroundPrefPrefix = 'vehicle_turnaround_minutes_';
  static const String _activeTurnaroundsPrefKey = 'active_vehicle_turnarounds_map';

  /// Standard dropdown options in minutes
  static const List<int> turnaroundOptions = [
    0, // Instant
    30, // 30 mins
    60, // 1 hr
    120, // 2 hrs
    180, // 3 hrs
    240, // 4 hrs
    360, // 6 hrs
    720, // 12 hrs
    1440, // 24 hrs
  ];

  static const Map<int, String> turnaroundLabels = {
    0: 'Instant (No buffer)',
    30: '30 minutes',
    60: '1 hour',
    120: '2 hours',
    180: '3 hours',
    240: '4 hours',
    360: '6 hours',
    720: '12 hours',
    1440: '24 hours (1 day)',
  };

  static String getLabelForMinutes(int minutes) {
    if (turnaroundLabels.containsKey(minutes)) {
      return turnaroundLabels[minutes]!;
    }
    if (minutes <= 0) return 'Instant (No buffer)';
    if (minutes < 60) return '$minutes minutes';
    final hours = (minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1);
    return '$hours hour${hours == '1' ? '' : 's'}';
  }

  // ---------------------------------------------------------------------------
  // CONFIGURATION GETTERS & SETTERS
  // ---------------------------------------------------------------------------

  /// Get the global default turnaround buffer in minutes (default: 60 mins / 1 hr)
  Future<int> getGlobalTurnaroundMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_globalTurnaroundPrefKey) ?? 60;
    } catch (e) {
      debugPrint('Error getting global turnaround minutes: $e');
      return 60;
    }
  }

  /// Set the global default turnaround buffer in minutes
  Future<void> setGlobalTurnaroundMinutes(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_globalTurnaroundPrefKey, minutes);
      debugPrint('Global turnaround set to $minutes minutes');
    } catch (e) {
      debugPrint('Error saving global turnaround minutes: $e');
    }
  }

  /// Get the configured turnaround buffer for a specific vehicle (in minutes)
  Future<int> getVehicleTurnaroundMinutes(String vehicleId) async {
    if (vehicleId.trim().isEmpty) return await getGlobalTurnaroundMinutes();
    try {
      final prefs = await SharedPreferences.getInstance();
      final localVal = prefs.getInt('$_vehicleTurnaroundPrefPrefix$vehicleId');
      if (localVal != null) return localVal;

      // Check DB vehicles table if column exists
      try {
        final res = await _supabase
            .from('vehicles')
            .select('turnaround_buffer_minutes,turnaround_minutes')
            .eq('id', vehicleId)
            .maybeSingle();
        if (res != null) {
          final minutes = res['turnaround_buffer_minutes'] ?? res['turnaround_minutes'];
          if (minutes is num) {
            final val = minutes.toInt();
            await prefs.setInt('$_vehicleTurnaroundPrefPrefix$vehicleId', val);
            return val;
          }
        }
      } catch (_) {}

      return await getGlobalTurnaroundMinutes();
    } catch (e) {
      debugPrint('Error getting vehicle turnaround minutes: $e');
      return await getGlobalTurnaroundMinutes();
    }
  }

  /// Set the configured turnaround buffer for a specific vehicle
  Future<void> setVehicleTurnaroundMinutes({
    required String vehicleId,
    required int minutes,
    String? partnerVehicleId,
  }) async {
    if (vehicleId.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_vehicleTurnaroundPrefPrefix$vehicleId', minutes);
      if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
        await prefs.setInt('$_vehicleTurnaroundPrefPrefix$partnerVehicleId', minutes);
      }

      // Best effort DB sync
      try {
        await _supabase
            .from('vehicles')
            .update({'turnaround_buffer_minutes': minutes})
            .eq('id', vehicleId);
      } catch (_) {}

      if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
        try {
          await _supabase
              .from('partner_vehicles')
              .update({'turnaround_buffer_minutes': minutes})
              .eq('id', partnerVehicleId);
        } catch (_) {}
      }
      debugPrint('Vehicle $vehicleId turnaround buffer set to $minutes minutes');
    } catch (e) {
      debugPrint('Error saving vehicle turnaround minutes: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIVE TURNAROUND STATE (Unlist & Relist)
  // ---------------------------------------------------------------------------

  /// Checks if a vehicle is currently in cleaning & inspection turnaround
  Future<Map<String, dynamic>?> getActiveTurnaround(String vehicleId) async {
    if (vehicleId.trim().isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activeTurnaroundsPrefKey);
      if (raw == null || raw.isEmpty) return null;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final item = map[vehicleId];
      if (item == null) return null;

      final data = Map<String, dynamic>.from(item as Map);
      final relistAtRaw = data['auto_relist_at']?.toString();
      if (relistAtRaw != null) {
        final relistAt = DateTime.tryParse(relistAtRaw);
        if (relistAt != null && DateTime.now().isAfter(relistAt)) {
          // Expired, trigger auto-relist
          await relistVehicleImmediately(vehicleId: vehicleId);
          return null;
        }
      }
      return data;
    } catch (e) {
      debugPrint('Error getting active turnaround for $vehicleId: $e');
      return null;
    }
  }

  /// Automatically triggered upon vehicle return to unlist the car for cleaning & inspection
  Future<bool> handleVehicleReturn({
    required String vehicleId,
    String? partnerVehicleId,
    String? bookingId,
    String? vehicleTitle,
    String? partnerId,
  }) async {
    if (vehicleId.trim().isEmpty) return false;
    try {
      // Process any existing expired turnarounds first
      await processExpiredTurnarounds();

      final turnaroundMinutes = await getVehicleTurnaroundMinutes(vehicleId);

      // If buffer is 0 (Instant), no unlist is needed
      if (turnaroundMinutes <= 0) {
        debugPrint('Turnaround buffer is 0 (Instant). Vehicle $vehicleId remains available.');
        await relistVehicleImmediately(
          vehicleId: vehicleId,
          partnerVehicleId: partnerVehicleId,
        );
        return false;
      }

      final now = DateTime.now();
      final relistAt = now.add(Duration(minutes: turnaroundMinutes));
      final relistAtIso = relistAt.toIso8601String();

      // 1. Mark vehicle unlisted in database
      try {
        await _supabase
            .from('vehicles')
            .update({
              'is_available': false,
              'status': 'cleaning',
              'cleaning_until': relistAtIso,
              'auto_relist_at': relistAtIso,
            })
            .eq('id', vehicleId);
      } catch (e) {
        // Fallback without new columns if DB doesn't have cleaning_until
        try {
          await _supabase
              .from('vehicles')
              .update({'is_available': false})
              .eq('id', vehicleId);
        } catch (_) {}
      }

      if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
        try {
          await _supabase
              .from('partner_vehicles')
              .update({
                'is_available': false,
                'status': 'cleaning',
                'cleaning_until': relistAtIso,
                'auto_relist_at': relistAtIso,
              })
              .eq('id', partnerVehicleId);
        } catch (e) {
          try {
            await _supabase
                .from('partner_vehicles')
                .update({'is_available': false})
                .eq('id', partnerVehicleId);
          } catch (_) {}
        }
      }

      // 2. Save turnaround record in persistent storage
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activeTurnaroundsPrefKey);
      final map = raw != null && raw.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : <String, dynamic>{};

      final turnaroundData = {
        'vehicle_id': vehicleId,
        'partner_vehicle_id': partnerVehicleId,
        'booking_id': bookingId,
        'vehicle_title': vehicleTitle ?? 'Vehicle',
        'started_at': now.toIso8601String(),
        'turnaround_minutes': turnaroundMinutes,
        'auto_relist_at': relistAtIso,
      };

      map[vehicleId] = turnaroundData;
      if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
        map[partnerVehicleId] = turnaroundData;
      }
      await prefs.setString(_activeTurnaroundsPrefKey, jsonEncode(map));

      // 3. Notify partner and operator
      try {
        final label = getLabelForMinutes(turnaroundMinutes);
        final title = vehicleTitle ?? 'Vehicle';
        final message =
            '$title returned. Automated unlist activated for cleaning & inspection ($label, auto-relists at ${_formatTime(relistAt)}). You can relist anytime if cleaned earlier.';

        if (partnerId != null && partnerId.isNotEmpty) {
          await NotificationService().createNotification(
            userId: partnerId,
            title: '🧹 Vehicle in Cleaning & Inspection',
            message: message,
            type: 'vehicle_turnaround',
            data: {
              'vehicle_id': vehicleId,
              'auto_relist_at': relistAtIso,
            },
          );
        }
      } catch (notifErr) {
        debugPrint('Could not send turnaround notification: $notifErr');
      }

      debugPrint(
        'Vehicle $vehicleId unlisted for cleaning until $relistAtIso ($turnaroundMinutes mins)',
      );
      return true;
    } catch (e) {
      debugPrint('Error handling vehicle return turnaround: $e');
      return false;
    }
  }

  /// Immediate manual relist:
  /// When Admin, Partner, or Operator completes cleaning early and turns the vehicle ON.
  Future<void> relistVehicleImmediately({
    required String vehicleId,
    String? partnerVehicleId,
  }) async {
    if (vehicleId.trim().isEmpty) return;
    try {
      // 1. Mark vehicle available in database
      try {
        await _supabase
            .from('vehicles')
            .update({
              'is_available': true,
              'status': 'active',
              'cleaning_until': null,
              'auto_relist_at': null,
            })
            .eq('id', vehicleId);
      } catch (e) {
        try {
          await _supabase
              .from('vehicles')
              .update({'is_available': true, 'status': 'active'})
              .eq('id', vehicleId);
        } catch (_) {}
      }

      if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
        try {
          await _supabase
              .from('partner_vehicles')
              .update({
                'is_available': true,
                'status': 'available',
                'cleaning_until': null,
                'auto_relist_at': null,
              })
              .eq('id', partnerVehicleId);
        } catch (e) {
          try {
            await _supabase
                .from('partner_vehicles')
                .update({'is_available': true, 'status': 'available'})
                .eq('id', partnerVehicleId);
          } catch (_) {}
        }
      }

      // 2. Remove from active turnaround persistent map
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activeTurnaroundsPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        map.remove(vehicleId);
        if (partnerVehicleId != null) map.remove(partnerVehicleId);
        await prefs.setString(_activeTurnaroundsPrefKey, jsonEncode(map));
      }

      debugPrint('Vehicle $vehicleId manually relisted immediately.');
    } catch (e) {
      debugPrint('Error relisting vehicle immediately: $e');
    }
  }

  /// Process any active turnarounds whose timer has expired and relist them automatically
  Future<void> processExpiredTurnarounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activeTurnaroundsPrefKey);
      if (raw == null || raw.isEmpty) return;

      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final now = DateTime.now();
      final expiredIds = <String>[];

      for (final entry in map.entries) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        final relistAtRaw = data['auto_relist_at']?.toString();
        if (relistAtRaw != null) {
          final relistAt = DateTime.tryParse(relistAtRaw);
          if (relistAt != null && now.isAfter(relistAt)) {
            final vId = data['vehicle_id']?.toString() ?? entry.key;
            final pvId = data['partner_vehicle_id']?.toString();
            await relistVehicleImmediately(
              vehicleId: vId,
              partnerVehicleId: pvId,
            );
            expiredIds.add(entry.key);
          }
        }
      }

      if (expiredIds.isNotEmpty) {
        for (final id in expiredIds) {
          map.remove(id);
        }
        await prefs.setString(_activeTurnaroundsPrefKey, jsonEncode(map));
      }
    } catch (e) {
      debugPrint('Error processing expired turnarounds: $e');
    }
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
