import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_service.dart';

class FavoriteVehicleService {
  static final FavoriteVehicleService _instance =
      FavoriteVehicleService._internal();

  factory FavoriteVehicleService() => _instance;

  FavoriteVehicleService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final VehicleService _vehicleService = VehicleService();

  String _localKey(String userId) => 'favorite_vehicle_ids_$userId';

  Future<Set<String>> getFavoriteVehicleIds(String userId) async {
    if (userId.isEmpty) return {};

    try {
      final rows = await _supabase
          .from('favorite_vehicles')
          .select('vehicle_id')
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(rows)
          .map((row) => row['vehicle_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
    } on PostgrestException catch (e) {
      debugPrint('Favorite vehicles table unavailable: ${e.message}');
      return _getLocalFavoriteIds(userId);
    } catch (e) {
      debugPrint('Error loading favorite vehicle ids: $e');
      return _getLocalFavoriteIds(userId);
    }
  }

  Future<List<Map<String, dynamic>>> getFavoriteVehicles(String userId) async {
    final ids = await getFavoriteVehicleIds(userId);
    if (ids.isEmpty) return [];

    final vehicles = <Map<String, dynamic>>[];
    for (final id in ids) {
      final vehicle = await _vehicleService.getVehicleById(id);
      if (vehicle != null) vehicles.add(vehicle);
    }
    return vehicles;
  }

  Future<bool> isFavorite({
    required String userId,
    required String vehicleId,
  }) async {
    final ids = await getFavoriteVehicleIds(userId);
    return ids.contains(vehicleId);
  }

  Future<bool> toggleFavorite({
    required String userId,
    required String vehicleId,
  }) async {
    final ids = await getFavoriteVehicleIds(userId);
    final shouldFavorite = !ids.contains(vehicleId);

    if (shouldFavorite) {
      await _addFavorite(userId: userId, vehicleId: vehicleId);
    } else {
      await _removeFavorite(userId: userId, vehicleId: vehicleId);
    }

    return shouldFavorite;
  }

  Future<void> _addFavorite({
    required String userId,
    required String vehicleId,
  }) async {
    try {
      await _supabase.from('favorite_vehicles').upsert({
        'user_id': userId,
        'vehicle_id': vehicleId,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,vehicle_id');
    } on PostgrestException catch (e) {
      debugPrint('Favorite add using local fallback: ${e.message}');
    } catch (e) {
      debugPrint('Favorite add using local fallback: $e');
    }

    final ids = await _getLocalFavoriteIds(userId);
    ids.add(vehicleId);
    await _setLocalFavoriteIds(userId, ids);
  }

  Future<void> _removeFavorite({
    required String userId,
    required String vehicleId,
  }) async {
    try {
      await _supabase
          .from('favorite_vehicles')
          .delete()
          .eq('user_id', userId)
          .eq('vehicle_id', vehicleId);
    } on PostgrestException catch (e) {
      debugPrint('Favorite remove using local fallback: ${e.message}');
    } catch (e) {
      debugPrint('Favorite remove using local fallback: $e');
    }

    final ids = await _getLocalFavoriteIds(userId);
    ids.remove(vehicleId);
    await _setLocalFavoriteIds(userId, ids);
  }

  Future<Set<String>> _getLocalFavoriteIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_localKey(userId)) ?? []).toSet();
  }

  Future<void> _setLocalFavoriteIds(String userId, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_localKey(userId), ids.toList()..sort());
  }
}
