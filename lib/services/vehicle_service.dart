import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class VehicleService {
  static final VehicleService _instance = VehicleService._internal();
  static const String _vehicleImagesBucket = 'vehicle_images';

  // Single clean select string — no extra whitespace or newlines
  static const String _vehicleSelect =
      'id,brand,model,year,plate_number,price_per_day,price_per_hour,'
      'category,vehicle_type,vehicle_name,description,color,location,'
      'latitude,longitude,seats,is_available,is_posted,status,owner_id,'
      'vehicle_images(image_url,display_order),'
      'owner:owner_id(id,full_name,email,role)';

  factory VehicleService() => _instance;
  VehicleService._internal();

  final supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Image URL — stored as full public URL, just return it as-is
  // ---------------------------------------------------------------------------
  String? _normalizeImageUrl(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    // Relative path fallback
    final path = raw.startsWith('/') ? raw.substring(1) : raw;
    if (path.isEmpty) return null;
    return supabase.storage.from(_vehicleImagesBucket).getPublicUrl(path);
  }

  // ---------------------------------------------------------------------------
  // Normalize a single vehicle record
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _normalizeVehicleRecord(Map<String, dynamic> vehicle) {
    final merged = Map<String, dynamic>.from(vehicle);

    // Sort vehicle_images by display_order, normalize each image_url
    final rawImages = merged['vehicle_images'];
    final imageList = rawImages is List
        ? List<Map<String, dynamic>>.from(
            rawImages.whereType<Map<String, dynamic>>())
        : <Map<String, dynamic>>[];

    imageList.sort((a, b) {
      final aOrder = (a['display_order'] as num?)?.toInt() ?? 9999;
      final bOrder = (b['display_order'] as num?)?.toInt() ?? 9999;
      return aOrder.compareTo(bOrder);
    });

    final normalizedImages = imageList.map((img) {
      final copy = Map<String, dynamic>.from(img);
      copy['image_url'] = _normalizeImageUrl(copy['image_url']);
      return copy;
    }).toList();

    merged['vehicle_images'] = normalizedImages;

    // Pick primary image_url — prefer vehicle_images relation, fall back to column
    String? primaryUrl;
    for (final img in normalizedImages) {
      final candidate = img['image_url']?.toString();
      if (candidate != null && candidate.isNotEmpty) {
        primaryUrl = candidate;
        break;
      }
    }
    primaryUrl ??= _normalizeImageUrl(merged['image_url']);
    merged['image_url'] = primaryUrl;

    debugPrint('Vehicle ${merged['id']}: image=$primaryUrl');

    // Compatibility shims
    merged['transmission'] = merged['vehicle_type'] ?? 'Standard';
    merged['fuel_type'] = merged['category'] ?? 'Standard';

    try {
      final ownerValue = merged['owner'];
      if (ownerValue is Map<String, dynamic>) {
        merged['owner_name'] = ownerValue['full_name'] ?? ownerValue['email'];
      } else if (ownerValue is String && ownerValue.isNotEmpty) {
        merged['owner_name'] = ownerValue;
      }
    } catch (_) {}

    return merged;
  }

  List<Map<String, dynamic>> _normalizeList(List<Map<String, dynamic>> list) =>
      list.map(_normalizeVehicleRecord).toList();

  // ---------------------------------------------------------------------------
  // Visibility filter
  // ---------------------------------------------------------------------------
  bool _isVisibleForRent(Map<String, dynamic> v) {
    if (v['is_available'] == false) return false;
    final status = (v['status'] ?? '').toString().toLowerCase();
    return status != 'inactive' && status != 'archived' && status != 'deleted';
  }

  // ---------------------------------------------------------------------------
  // Category matching
  // ---------------------------------------------------------------------------
  bool _matchesCategory(String vehicleCategory, String requested) {
    final a = vehicleCategory.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final b = requested.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (b.isEmpty) return true;
    if (a.isEmpty) return false;
    return a.contains(b) || b.contains(a);
  }

  String _categoryOf(Map<String, dynamic> v) {
    final vt = v['vehicle_type']?.toString() ?? '';
    return vt.trim().isNotEmpty ? vt : (v['category']?.toString() ?? '');
  }

  // ---------------------------------------------------------------------------
  // GET PARTNER VEHICLES
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getPartnerVehicles(String userId) async {
    try {
      final response = await supabase
          .from('vehicles')
          .select(_vehicleSelect)
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      return _normalizeList(List<Map<String, dynamic>>.from(response));
    } on PostgrestException catch (e) {
      debugPrint('getPartnerVehicles error: ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // GET VEHICLE BY ID
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> getVehicleById(String vehicleId) async {
    try {
      final response = await supabase
          .from('vehicles')
          .select(_vehicleSelect)
          .eq('id', vehicleId)
          .maybeSingle();

      if (response == null) return null;
      return _normalizeVehicleRecord(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      debugPrint('getVehicleById error: ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // GET AVAILABLE VEHICLES (renter view)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAvailableVehicles({
    DateTime? date,
    String? category,
  }) async {
    debugPrint('getAvailableVehicles: category=$category');

    try {
      final response = await supabase
          .from('vehicles')
          .select(_vehicleSelect)
          .order('created_at', ascending: false);

      debugPrint('Raw rows returned: ${response.length}');

      final normalized = _normalizeList(List<Map<String, dynamic>>.from(response))
          .where(_isVisibleForRent)
          .toList();

      if (category == null || category.isEmpty) return normalized;

      return normalized
          .where((v) => _matchesCategory(_categoryOf(v), category))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('getAvailableVehicles error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('getAvailableVehicles unexpected error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH VEHICLES
  // ---------------------------------------------------------------------------
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
    String? category,
  }) async {
    try {
      var query = supabase.from('vehicles').select(_vehicleSelect);

      if (brand != null && brand.isNotEmpty) query = query.ilike('brand', '%$brand%');
      if (model != null && model.isNotEmpty) query = query.ilike('model', '%$model%');
      if (minPrice != null) query = query.gte('price_per_day', minPrice);
      if (maxPrice != null) query = query.lte('price_per_day', maxPrice);
      if (color != null && color.isNotEmpty) query = query.eq('color', color);
      if (minSeats != null) query = query.gte('seats', minSeats);
      if (location != null && location.isNotEmpty) {
        query = query.ilike('location', '%$location%');
      }

      final response = await query.order('created_at', ascending: false);

      final normalized = _normalizeList(List<Map<String, dynamic>>.from(response))
          .where(_isVisibleForRent)
          .toList();

      if (category == null || category.isEmpty) return normalized;
      return normalized
          .where((v) => _matchesCategory(_categoryOf(v), category))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('searchVehicles error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('searchVehicles error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // AVAILABILITY
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getVehicleAvailability(
      String vehicleId) async {
    try {
      final response = await supabase
          .from('vehicle_availability')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('getVehicleAvailability error: ${e.message}');
      rethrow;
    }
  }

  Future<List<DateTime>> getUnavailableDates(String vehicleId) async {
    try {
      final availability = await getVehicleAvailability(vehicleId);
      return availability
          .where((r) => r['is_available'] == false)
          .map((r) => DateTime.parse(r['date'] as String))
          .toList();
    } catch (e) {
      debugPrint('getUnavailableDates error: $e');
      return [];
    }
  }

  Future<void> setAvailability({
    required String vehicleId,
    required DateTime date,
    required bool isAvailable,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    await supabase.from('vehicle_availability').upsert(
      {'vehicle_id': vehicleId, 'date': dateStr, 'is_available': isAvailable},
      onConflict: 'vehicle_id,date',
    );
  }

  Future<void> setAvailabilityRange({
    required String vehicleId,
    required DateTime startDate,
    required DateTime endDate,
    required bool isAvailable,
  }) async {
    final records = <Map<String, dynamic>>[];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      records.add({
        'vehicle_id': vehicleId,
        'date': current.toIso8601String().split('T')[0],
        'is_available': isAvailable,
      });
      current = current.add(const Duration(days: 1));
    }
    await supabase
        .from('vehicle_availability')
        .upsert(records, onConflict: 'vehicle_id,date');
  }

  Future<void> clearAvailability({
    required String vehicleId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    await supabase
        .from('vehicle_availability')
        .delete()
        .eq('vehicle_id', vehicleId)
        .eq('date', dateStr);
  }

  Future<bool> isVehicleAvailable(
    String vehicleId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await supabase
          .from('vehicle_availability')
          .select('date')
          .eq('vehicle_id', vehicleId)
          .eq('is_available', false)
          .gte('date', startDate.toIso8601String().split('T')[0])
          .lte('date', endDate.toIso8601String().split('T')[0]);
      return response.isEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // VEHICLE CRUD
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> createVehicle({
    required String ownerId,
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
    required double pricePerDay,
    required double pricePerHour,
    String? vehicleName,
    String? category,
    String? vehicleType,
    String? description,
    String? color,
    String? location,
    double? latitude,
    double? longitude,
    int? seats,
    bool? isPosted,
  }) async {
    final response = await supabase
        .from('vehicles')
        .insert({
          'brand': brand,
          'model': model,
          'year': year,
          'plate_number': plateNumber,
          'owner_id': ownerId,
          'price_per_day': pricePerDay,
          'price_per_hour': pricePerHour,
          'vehicle_name': vehicleName,
          'category': category,
          'vehicle_type': vehicleType,
          'description': description,
          'color': color,
          'location': location,
          'latitude': latitude,
          'seats': seats,
          'is_posted': isPosted ?? false,
          'status': 'active',
          'is_available': true,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select(_vehicleSelect)
        .single();

    return _normalizeVehicleRecord(Map<String, dynamic>.from(response));
  }

  Future<Map<String, dynamic>> updateVehicle(
    String vehicleId, {
    String? brand,
    String? model,
    int? year,
    String? plateNumber,
    double? pricePerDay,
    double? pricePerHour,
    String? vehicleName,
    String? category,
    String? vehicleType,
    String? description,
    String? color,
    String? location,
    double? latitude,
    double? longitude,
    int? seats,
    bool? isPosted,
    bool? isAvailable,
  }) async {
    final updates = <String, dynamic>{
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (year != null) 'year': year,
      if (plateNumber != null) 'plate_number': plateNumber,
      if (pricePerDay != null) 'price_per_day': pricePerDay,
      if (pricePerHour != null) 'price_per_hour': pricePerHour,
      if (vehicleName != null) 'vehicle_name': vehicleName,
      if (category != null) 'category': category,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (description != null) 'description': description,
      if (color != null) 'color': color,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (seats != null) 'seats': seats,
      if (isPosted != null) 'is_posted': isPosted,
      if (isAvailable != null) 'is_available': isAvailable,
    };

    if (updates.isEmpty) throw ArgumentError('No fields to update');

    final response = await supabase
        .from('vehicles')
        .update(updates)
        .eq('id', vehicleId)
        .select(_vehicleSelect)
        .single();

    return _normalizeVehicleRecord(Map<String, dynamic>.from(response));
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await supabase
        .from('vehicles')
        .update({'status': 'inactive', 'is_available': false})
        .eq('id', vehicleId);
  }

  Future<void> updateVehicleStatus(String vehicleId, String status) async {
    await supabase
        .from('vehicles')
        .update({'status': status, 'is_available': status == 'active'})
        .eq('id', vehicleId);
  }

  // ---------------------------------------------------------------------------
  // DOCUMENTS
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> uploadVehicleDocument({
    required String vehicleId,
    required String documentType,
    required String fileUrl,
    String? expiryDate,
  }) async {
    final response = await supabase.from('vehicle_documents').insert({
      'vehicle_id': vehicleId,
      'document_type': documentType,
      'file_url': fileUrl,
      'expiry_date': expiryDate,
      'upload_date': DateTime.now().toIso8601String(),
      'status': 'pending',
    }).select();
    return response.first;
  }

  Future<List<Map<String, dynamic>>> getVehicleDocuments(
      String vehicleId) async {
    try {
      final response = await supabase
          .from('vehicle_documents')
          .select('*')
          .eq('vehicle_id', vehicleId)
          .order('upload_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> renewDocument({
    required String documentId,
    required String newFileUrl,
    required DateTime newExpiryDate,
  }) async {
    final oldDoc = await supabase
        .from('vehicle_documents')
        .select()
        .eq('id', documentId)
        .maybeSingle();

    if (oldDoc == null) throw Exception('Document not found: $documentId');

    return await supabase
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
  }

  Future<List<Map<String, dynamic>>> getDocumentsPendingRenewal({
    required String vehicleId,
    int daysThreshold = 7,
  }) async {
    try {
      final threshold = DateTime.now().add(Duration(days: daysThreshold));
      final docs = await supabase
          .from('vehicle_documents')
          .select()
          .eq('vehicle_id', vehicleId);

      return List<Map<String, dynamic>>.from(
        docs.where((doc) {
          final expiry = doc['expiry_date'] as String?;
          if (expiry == null) return false;
          return DateTime.parse(expiry).isBefore(threshold);
        }),
      );
    } catch (_) {
      return [];
    }
  }

  String getErrorMessage(dynamic error) =>
      error is PostgrestException ? error.message : error.toString();
}