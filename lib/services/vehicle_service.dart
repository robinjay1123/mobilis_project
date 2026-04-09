import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class VehicleService {
  static final VehicleService _instance = VehicleService._internal();

  factory VehicleService() {
    return _instance;
  }

  VehicleService._internal();

  final supabase = Supabase.instance.client;

  // Get all vehicles for an owner (partner)
  // Note: vehicles table uses owner_id which references users.id
  Future<List<Map<String, dynamic>>> getPartnerVehicles(String userId) async {
    try {
      debugPrint('Fetching vehicles for owner: $userId');

      final response = await supabase
          .from('vehicles')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} vehicles');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching vehicles: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching vehicles: $e');
      rethrow;
    }
  }

  // Get vehicle by ID
  Future<Map<String, dynamic>?> getVehicleById(String vehicleId) async {
    try {
      debugPrint('Fetching vehicle: $vehicleId');

      final response = await supabase
          .from('vehicles')
          .select()
          .eq('id', vehicleId)
          .maybeSingle();

      debugPrint('Vehicle fetched: ${response != null}');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching vehicle: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching vehicle: $e');
      rethrow;
    }
  }

  // Get vehicle availability
  Future<List<Map<String, dynamic>>> getVehicleAvailability(
    String vehicleId,
  ) async {
    try {
      debugPrint('Fetching availability for vehicle: $vehicleId');

      final response = await supabase
          .from('vehicle_availability')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('date', ascending: true);

      debugPrint('Fetched ${response.length} availability records');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching availability: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching availability: $e');
      rethrow;
    }
  }

  // Get unavailable dates for a vehicle
  Future<List<DateTime>> getUnavailableDates(String vehicleId) async {
    try {
      final availability = await getVehicleAvailability(vehicleId);

      final unavailableDates = <DateTime>[];
      for (final record in availability) {
        if (record['is_available'] == false) {
          final dateStr = record['date'] as String?;
          if (dateStr != null) {
            unavailableDates.add(DateTime.parse(dateStr));
          }
        }
      }

      debugPrint('Found ${unavailableDates.length} unavailable dates');
      return unavailableDates;
    } catch (e) {
      debugPrint('Error getting unavailable dates: $e');
      return [];
    }
  }

  // Set availability for a single date
  Future<void> setAvailability({
    required String vehicleId,
    required DateTime date,
    required bool isAvailable,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      debugPrint(
        'Setting availability for $vehicleId on $dateStr: $isAvailable',
      );

      await supabase.from('vehicle_availability').upsert({
        'vehicle_id': vehicleId,
        'date': dateStr,
        'is_available': isAvailable,
      }, onConflict: 'vehicle_id,date');

      debugPrint('Availability set successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error setting availability: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error setting availability: $e');
      rethrow;
    }
  }

  // Set availability for a date range
  Future<void> setAvailabilityRange({
    required String vehicleId,
    required DateTime startDate,
    required DateTime endDate,
    required bool isAvailable,
  }) async {
    try {
      debugPrint(
        'Setting availability range for $vehicleId: $startDate to $endDate',
      );

      final records = <Map<String, dynamic>>[];
      var currentDate = startDate;

      while (!currentDate.isAfter(endDate)) {
        records.add({
          'vehicle_id': vehicleId,
          'date': currentDate.toIso8601String().split('T')[0],
          'is_available': isAvailable,
        });
        currentDate = currentDate.add(const Duration(days: 1));
      }

      await supabase
          .from('vehicle_availability')
          .upsert(records, onConflict: 'vehicle_id,date');

      debugPrint('Availability range set for ${records.length} dates');
    } on PostgrestException catch (e) {
      debugPrint('Database error setting availability range: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error setting availability range: $e');
      rethrow;
    }
  }

  // Clear availability for a date (remove record)
  Future<void> clearAvailability({
    required String vehicleId,
    required DateTime date,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      debugPrint('Clearing availability for $vehicleId on $dateStr');

      await supabase
          .from('vehicle_availability')
          .delete()
          .eq('vehicle_id', vehicleId)
          .eq('date', dateStr);

      debugPrint('Availability cleared');
    } on PostgrestException catch (e) {
      debugPrint('Database error clearing availability: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error clearing availability: $e');
      rethrow;
    }
  }

  // Get all available vehicles (for renters)
  Future<List<Map<String, dynamic>>> getAvailableVehicles({
    DateTime? date,
    String? category,
  }) async {
    try {
      debugPrint('Fetching available vehicles');

      var query = supabase.from('vehicles').select().eq('status', 'active');

      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query.order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} available vehicles');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching available vehicles: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching available vehicles: $e');
      rethrow;
    }
  }

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
