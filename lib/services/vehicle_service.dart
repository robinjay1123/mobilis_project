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

      var query = supabase
          .from('vehicles')
          .select()
          .eq('status', 'active')
          .eq('is_available', true);

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

  // ================== VEHICLE CRUD ==================

  /// Create new vehicle (partner/operator)
  Future<Map<String, dynamic>> createVehicle({
    required String ownerId,
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
    required double pricePerDay,
    String? imageUrl,
    String? description,
    String? color,
    int? seats,
    String? transmission,
    String? fuelType,
  }) async {
    try {
      debugPrint('Creating vehicle for owner: $ownerId');

      final response = await supabase.from('vehicles').insert({
        'owner_id': ownerId,
        'brand': brand,
        'model': model,
        'year': year,
        'plate_number': plateNumber,
        'price_per_day': pricePerDay,
        'image_url': imageUrl,
        'description': description,
        'color': color,
        'seats': seats,
        'transmission': transmission,
        'fuel_type': fuelType,
        'status': 'active',
        'is_available': true,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      debugPrint('Vehicle created successfully');
      return response.first;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating vehicle: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error creating vehicle: $e');
      rethrow;
    }
  }

  /// Update vehicle details (partner/operator)
  Future<void> updateVehicle(
    String vehicleId,
    Map<String, dynamic> updates,
  ) async {
    try {
      debugPrint('Updating vehicle: $vehicleId');

      await supabase
          .from('vehicles')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', vehicleId);

      debugPrint('Vehicle updated successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating vehicle: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      rethrow;
    }
  }

  /// Delete/deactivate vehicle (partner/operator)
  Future<void> deleteVehicle(String vehicleId) async {
    try {
      debugPrint('Deleting vehicle: $vehicleId');

      await supabase
          .from('vehicles')
          .update({'status': 'inactive', 'is_available': false})
          .eq('id', vehicleId);

      debugPrint('Vehicle deleted successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error deleting vehicle: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      rethrow;
    }
  }

  /// Upload vehicle document (insurance, registration, inspection)
  Future<Map<String, dynamic>> uploadVehicleDocument({
    required String vehicleId,
    required String documentType,
    required String fileUrl,
    String? expiryDate,
  }) async {
    try {
      debugPrint('Uploading $documentType document for vehicle: $vehicleId');

      // Create document record (this assumes a vehicle_documents table exists)
      final response = await supabase.from('vehicle_documents').insert({
        'vehicle_id': vehicleId,
        'document_type': documentType,
        'file_url': fileUrl,
        'expiry_date': expiryDate,
        'upload_date': DateTime.now().toIso8601String(),
        'status': 'pending',
      }).select();

      debugPrint('Vehicle document uploaded');
      return response.first;
    } on PostgrestException catch (e) {
      debugPrint('Database error uploading document: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error uploading document: $e');
      rethrow;
    }
  }

  /// Get vehicle documents
  Future<List<Map<String, dynamic>>> getVehicleDocuments(
    String vehicleId,
  ) async {
    try {
      debugPrint('Fetching documents for vehicle: $vehicleId');

      final response = await supabase
          .from('vehicle_documents')
          .select('*')
          .eq('vehicle_id', vehicleId)
          .order('upload_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching documents: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      return [];
    }
  }

  /// Update vehicle status (active, inactive, maintenance)
  Future<void> updateVehicleStatus(String vehicleId, String status) async {
    try {
      debugPrint('Updating vehicle status: $vehicleId to $status');

      await supabase
          .from('vehicles')
          .update({'status': status, 'is_available': status == 'active'})
          .eq('id', vehicleId);

      debugPrint('Vehicle status updated');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating status: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating status: $e');
      rethrow;
    }
  }

  // ================== SEARCH & FILTER ==================

  /// Search vehicles by multiple criteria
  Future<List<Map<String, dynamic>>> searchVehicles({
    String? brand,
    String? model,
    DateTime? availableFrom,
    DateTime? availableTo,
    double? maxPrice,
    double? minPrice,
    String? location,
    String? color,
    int? minSeats,
    String? fuelType,
  }) async {
    try {
      debugPrint('Searching vehicles with filters');

      var query = supabase
          .from('vehicles')
          .select(
            'id, brand, model, year, plate_number, price_per_day, color, seats, fuel_type, transmission, image_url, is_available, owner:owner_id(id, full_name, email)',
          )
          .eq('status', 'active')
          .eq('is_available', true);

      if (brand != null && brand.isNotEmpty) {
        query = query.ilike('brand', '%$brand%');
      }

      if (model != null && model.isNotEmpty) {
        query = query.ilike('model', '%$model%');
      }

      if (minPrice != null) {
        query = query.gte('price_per_day', minPrice);
      }

      if (maxPrice != null) {
        query = query.lte('price_per_day', maxPrice);
      }

      if (color != null && color.isNotEmpty) {
        query = query.eq('color', color);
      }

      if (minSeats != null) {
        query = query.gte('seats', minSeats);
      }

      if (fuelType != null && fuelType.isNotEmpty) {
        query = query.eq('fuel_type', fuelType);
      }

      if (location != null && location.isNotEmpty) {
        query = query.ilike('location', '%$location%');
      }

      // For date availability, we'd need to check vehicle_availability table
      // This is a simplified version - in production, use a more complex query
      if (availableFrom != null && availableTo != null) {
        debugPrint(
          'Date filter: ${availableFrom.toIso8601String()} to ${availableTo.toIso8601String()}',
        );
      }

      final response = await query.order('created_at', ascending: false);

      debugPrint('Found ${response.length} matching vehicles');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error searching vehicles: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error searching vehicles: $e');
      return [];
    }
  }

  /// Check vehicle availability for date range
  Future<bool> isVehicleAvailable(
    String vehicleId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint(
        'Checking availability for vehicle $vehicleId: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
      );

      // Get all unavailable dates for vehicle
      final response = await supabase
          .from('vehicle_availability')
          .select('available_date')
          .eq('vehicle_id', vehicleId)
          .eq('is_available', false)
          .gte('available_date', startDate.toIso8601String())
          .lte('available_date', endDate.toIso8601String());

      final isAvailable = response.isEmpty;
      debugPrint('Vehicle available: $isAvailable');
      return isAvailable;
    } on PostgrestException catch (e) {
      debugPrint('Database error checking availability: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error checking availability: $e');
      return false;
    }
  }

  // ==================== DOCUMENT RENEWAL ====================

  /// Renew an expired/expiring vehicle document
  Future<Map<String, dynamic>?> renewDocument({
    required String documentId,
    required String newFileUrl,
    required DateTime newExpiryDate,
  }) async {
    try {
      debugPrint('Renewing vehicle document: $documentId');

      // Get the old document
      final oldDoc = await supabase
          .from('vehicle_documents')
          .select()
          .eq('id', documentId)
          .maybeSingle();

      if (oldDoc == null) {
        throw Exception('Document not found: $documentId');
      }

      // Update the document with new file and expiry
      final updated = await supabase
          .from('vehicle_documents')
          .update({
            'file_url': newFileUrl,
            'expiry_date': newExpiryDate.toIso8601String(),
            'status': 'pending',
            'updated_at': DateTime.now().toIso8601String(),
            'renewal_count': (oldDoc['renewal_count'] ?? 0) + 1,
          })
          .eq('id', documentId)
          .select()
          .maybeSingle();

      debugPrint('Vehicle document renewed successfully: $documentId');
      return updated;
    } on PostgrestException catch (e) {
      debugPrint('Database error renewing document: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error renewing document: $e');
      rethrow;
    }
  }

  /// Get documents pending renewal for a vehicle
  Future<List<Map<String, dynamic>>> getDocumentsPendingRenewal({
    required String vehicleId,
    int daysThreshold = 7,
  }) async {
    try {
      debugPrint(
        'Getting documents pending renewal for vehicle: $vehicleId (within $daysThreshold days)',
      );

      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      final docs = await supabase
          .from('vehicle_documents')
          .select()
          .eq('vehicle_id', vehicleId);

      final pendingRenewal = docs.where((doc) {
        final expiryDate = doc['expiry_date'] as String?;
        if (expiryDate == null) return false;

        final expiry = DateTime.parse(expiryDate);
        return expiry.isBefore(thresholdDate);
      }).toList();

      return List<Map<String, dynamic>>.from(pendingRenewal);
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error getting documents pending renewal: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint('Error getting documents pending renewal: $e');
      return [];
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
