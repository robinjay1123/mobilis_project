import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class VehicleService {
  static final VehicleService _instance = VehicleService._internal();
  static const String _vehicleImagesBucket = 'vehicle_images';

  // Single clean select string — no extra whitespace or newlines
  // NOTE: vehicle_images fetched separately, not joined here
  static const String _vehicleSelect =
      'id,brand,model,year,plate_number,price_per_day,price_per_hour,'
      'category,vehicle_type,vehicle_name,description,color,fuel_type,'
      'transmission,location,'
      'latitude,longitude,seats,is_available,is_posted,status,owner_id,'
      'rating';
  static const List<String> _bookingBlockingStatuses = [
    'confirmed',
    'active',
    'ongoing',
  ];

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
            rawImages.whereType<Map<String, dynamic>>(),
          )
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
    merged['rating_count'] = (merged['rating_count'] as num?)?.toInt() ?? 0;

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

    merged['transmission'] = _cleanText(merged['transmission']) ?? 'Manual';
    merged['fuel_type'] = _cleanText(merged['fuel_type']) ?? 'Gasoline';

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

  String? _cleanText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  // ---------------------------------------------------------------------------
  // Visibility filter
  // ---------------------------------------------------------------------------
  bool _isVisibleForRent(Map<String, dynamic> v) {
    if (v['is_posted'] != true) return false;
    if (v['is_available'] == false) return false;
    final status = (v['status'] ?? '').toString().toLowerCase();
    return status != 'inactive' && status != 'archived' && status != 'deleted';
  }

  // ---------------------------------------------------------------------------
  // Category matching
  // ---------------------------------------------------------------------------
  bool _matchesCategory(String vehicleCategory, String requested) {
    final a = vehicleCategory.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
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
  // Fetch and group vehicle images by vehicle_id
  // ---------------------------------------------------------------------------
  Future<Map<String, List<Map<String, dynamic>>>> _fetchAndGroupImages(
    List<String> vehicleIds,
  ) async {
    if (vehicleIds.isEmpty) return {};

    try {
      final imagesResponse = await supabase
          .from('vehicle_images')
          .select('vehicle_id,image_url,display_order')
          .inFilter('vehicle_id', vehicleIds);

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final image in imagesResponse) {
        final vehicleId = image['vehicle_id'] as String?;
        if (vehicleId != null) {
          grouped
              .putIfAbsent(vehicleId, () => [])
              .add(Map<String, dynamic>.from(image));
        }
      }

      // Sort each list by display_order
      for (final list in grouped.values) {
        list.sort((a, b) {
          final aOrder = (a['display_order'] as num?)?.toInt() ?? 9999;
          final bOrder = (b['display_order'] as num?)?.toInt() ?? 9999;
          return aOrder.compareTo(bOrder);
        });
      }

      return grouped;
    } catch (e) {
      debugPrint('Error fetching vehicle images: $e');
      return {};
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchAndGroupPartnerImages(
    List<String> partnerVehicleIds,
  ) async {
    if (partnerVehicleIds.isEmpty) return {};

    try {
      final imagesResponse = await supabase
          .from('vehicle_images')
          .select('partner_vehicle_id,image_url,display_order')
          .inFilter('partner_vehicle_id', partnerVehicleIds);

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final image in imagesResponse) {
        final partnerVehicleId = image['partner_vehicle_id']?.toString();
        if (partnerVehicleId == null || partnerVehicleId.isEmpty) continue;
        grouped.putIfAbsent(partnerVehicleId, () => []).add({
          'image_url': image['image_url'],
          'display_order': image['display_order'],
        });
      }

      for (final list in grouped.values) {
        list.sort((a, b) {
          final aOrder = (a['display_order'] as num?)?.toInt() ?? 9999;
          final bOrder = (b['display_order'] as num?)?.toInt() ?? 9999;
          return aOrder.compareTo(bOrder);
        });
      }

      return grouped;
    } catch (e) {
      debugPrint('Error fetching partner vehicle images: $e');
      return {};
    }
  }

  Map<String, dynamic> _normalizePartnerVehicleRecord(
    Map<String, dynamic> partnerVehicle,
  ) {
    final partner = partnerVehicle['partners'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(partnerVehicle['partners'])
        : <String, dynamic>{};
    final user = partner['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(partner['users'])
        : <String, dynamic>{};

    final partnerName =
        _cleanText(partner['business_name']) ??
        _cleanText(user['full_name']) ??
        _cleanText(user['email']) ??
        'Mobilis Partner';

    final normalized = _normalizeVehicleRecord({
      ...partnerVehicle,
      'id': partnerVehicle['id'],
      'partner_vehicle_id': partnerVehicle['id'],
      'source': 'partner',
      'is_partner_vehicle': true,
      'partner_name': partnerName,
      'owner_name': partnerName,
      'owner': {
        'role': 'partner',
        'full_name': partnerName,
        if (user['email'] != null) 'email': user['email'],
      },
      'vehicle_name':
          _cleanText(partnerVehicle['vehicle_name']) ??
          '${_cleanText(partnerVehicle['brand']) ?? ''} ${_cleanText(partnerVehicle['model']) ?? ''}'
              .trim(),
      'category':
          _cleanText(partnerVehicle['category']) ??
          _cleanText(partnerVehicle['vehicle_type']) ??
          'Partner Vehicle',
      'vehicle_type':
          _cleanText(partnerVehicle['vehicle_type']) ??
          _cleanText(partnerVehicle['category']) ??
          'Partner Vehicle',
      'is_posted': partnerVehicle['is_posted'] ?? true,
      'is_available': partnerVehicle['is_available'] ?? true,
      'status': partnerVehicle['status'] ?? 'available',
    });

    return normalized;
  }

  Future<List<Map<String, dynamic>>> _getAvailablePartnerVehicles() async {
    try {
      List response;
      try {
        response =
            await supabase
                    .from('partner_vehicles')
                    .select(
                      '*, partners:partner_id(id,user_id,business_name,users:user_id(full_name,email))',
                    )
                    .order('created_at', ascending: false)
                as List;
      } catch (e) {
        debugPrint('Partner relation select failed, using fallback: $e');
        response =
            await supabase
                    .from('partner_vehicles')
                    .select('*')
                    .order('created_at', ascending: false)
                as List;
      }

      final partnerVehicles = response
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .where((vehicle) {
            final status = (vehicle['status'] ?? '').toString().toLowerCase();
            return status != 'rejected' &&
                status != 'declined' &&
                status != 'archived' &&
                status != 'deleted';
          })
          .toList();

      final partnerVehicleIds = partnerVehicles
          .map((v) => v['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final imagesByPartnerVehicleId = await _fetchAndGroupPartnerImages(
        partnerVehicleIds,
      );

      for (final vehicle in partnerVehicles) {
        final id = vehicle['id']?.toString();
        vehicle['vehicle_images'] = id == null
            ? <Map<String, dynamic>>[]
            : imagesByPartnerVehicleId[id] ?? <Map<String, dynamic>>[];
      }

      return partnerVehicles.map(_normalizePartnerVehicleRecord).toList();
    } catch (e) {
      debugPrint('getAvailablePartnerVehicles error: $e');
      return [];
    }
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

      final vehicles = List<Map<String, dynamic>>.from(response);

      // Fetch images separately
      final vehicleIds = vehicles
          .map((v) => v['id']?.toString() ?? '')
          .toList();
      final imagesByVehicleId = await _fetchAndGroupImages(vehicleIds);

      // Attach images to each vehicle
      for (final vehicle in vehicles) {
        final id = vehicle['id']?.toString();
        if (id != null) {
          vehicle['vehicle_images'] = imagesByVehicleId[id] ?? [];
        }
      }

      return _normalizeList(vehicles);
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

      final vehicle = Map<String, dynamic>.from(response);

      // Fetch images for this vehicle separately
      try {
        final imagesResponse = await supabase
            .from('vehicle_images')
            .select('image_url,display_order')
            .eq('vehicle_id', vehicleId)
            .order('display_order', ascending: true);
        vehicle['vehicle_images'] = imagesResponse;
      } catch (e) {
        debugPrint('Error fetching images for vehicle $vehicleId: $e');
        vehicle['vehicle_images'] = [];
      }

      return _normalizeVehicleRecord(vehicle);
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
    DateTime? availableFrom,
    DateTime? availableTo,
    String? category,
  }) async {
    debugPrint('getAvailableVehicles: category=$category');

    try {
      final response = await supabase
          .from('vehicles')
          .select(_vehicleSelect)
          .eq('is_posted', true)
          .eq('is_available', true)
          .order('created_at', ascending: false);

      debugPrint('Raw rows returned: ${response.length}');

      final vehicles = List<Map<String, dynamic>>.from(response);

      // Fetch images separately
      final vehicleIds = vehicles
          .map((v) => v['id']?.toString() ?? '')
          .toList();
      final imagesByVehicleId = await _fetchAndGroupImages(vehicleIds);

      // Attach images to each vehicle
      for (final vehicle in vehicles) {
        final id = vehicle['id']?.toString();
        if (id != null) {
          vehicle['vehicle_images'] = imagesByVehicleId[id] ?? [];
        }
      }

      final normalized = _normalizeList(
        vehicles,
      ).where(_isVisibleForRent).toList();
      final partnerVehicles = await _getAvailablePartnerVehicles();
      final allVehicles = [...normalized, ...partnerVehicles];

      final categoryFiltered = category == null || category.isEmpty
          ? allVehicles
          : allVehicles
                .where((v) => _matchesCategory(_categoryOf(v), category))
                .toList();
      return _filterVehiclesAvailableForRange(
        categoryFiltered,
        availableFrom ?? date,
        availableTo ?? date,
      );
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
      var query = supabase
          .from('vehicles')
          .select(_vehicleSelect)
          .eq('is_posted', true)
          .eq('is_available', true);

      if (brand != null && brand.isNotEmpty)
        query = query.ilike('brand', '%$brand%');
      if (model != null && model.isNotEmpty)
        query = query.ilike('model', '%$model%');
      if (minPrice != null) query = query.gte('price_per_day', minPrice);
      if (maxPrice != null) query = query.lte('price_per_day', maxPrice);
      if (color != null && color.isNotEmpty) query = query.eq('color', color);
      if (fuelType != null && fuelType.isNotEmpty) {
        query = query.eq('fuel_type', fuelType);
      }
      if (minSeats != null) query = query.gte('seats', minSeats);
      if (location != null && location.isNotEmpty) {
        query = query.ilike('location', '%$location%');
      }

      final response = await query.order('created_at', ascending: false);

      final vehicles = List<Map<String, dynamic>>.from(response);

      // Fetch images separately
      final vehicleIds = vehicles
          .map((v) => v['id']?.toString() ?? '')
          .toList();
      final imagesByVehicleId = await _fetchAndGroupImages(vehicleIds);

      // Attach images to each vehicle
      for (final vehicle in vehicles) {
        final id = vehicle['id']?.toString();
        if (id != null) {
          vehicle['vehicle_images'] = imagesByVehicleId[id] ?? [];
        }
      }

      final normalized = _normalizeList(
        vehicles,
      ).where(_isVisibleForRent).toList();

      final categoryFiltered = category == null || category.isEmpty
          ? normalized
          : normalized
                .where((v) => _matchesCategory(_categoryOf(v), category))
                .toList();

      return _filterVehiclesAvailableForRange(
        categoryFiltered,
        availableFrom,
        availableTo,
      );
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
    String vehicleId,
  ) async {
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
      final unavailableDates = availability
          .where((r) => r['is_available'] == false)
          .map((r) => DateTime.parse(r['date'] as String))
          .toList();

      final bookedDates = await getBookedDates(vehicleId);
      final byDay = <String, DateTime>{};
      for (final date in [...unavailableDates, ...bookedDates]) {
        byDay[_dateKey(date)] = DateTime(date.year, date.month, date.day);
      }
      return byDay.values.toList()..sort();
    } catch (e) {
      debugPrint('getUnavailableDates error: $e');
      return [];
    }
  }

  Future<List<DateTime>> getBookedDates(String vehicleId) async {
    try {
      final response = await supabase
          .from('bookings')
          .select('start_at,end_at,start_date,end_date')
          .eq('vehicle_id', vehicleId)
          .inFilter('status', _bookingBlockingStatuses);

      final dates = <String, DateTime>{};
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final start = DateTime.tryParse(
          row['start_at']?.toString() ?? row['start_date']?.toString() ?? '',
        )?.toLocal();
        final end = DateTime.tryParse(
          row['end_at']?.toString() ?? row['end_date']?.toString() ?? '',
        )?.toLocal();
        if (start == null || end == null) continue;

        var current = DateTime(start.year, start.month, start.day);
        final last = DateTime(end.year, end.month, end.day);
        while (!current.isAfter(last)) {
          dates[_dateKey(current)] = current;
          current = current.add(const Duration(days: 1));
        }
      }
      return dates.values.toList()..sort();
    } catch (e) {
      debugPrint('getBookedDates error: $e');
      return [];
    }
  }

  Future<Set<DateTime>> getFullyUnavailableDatesForVehicles(
    List<String> vehicleIds, {
    int daysAhead = 365,
  }) async {
    final ids = vehicleIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};

    final today = DateTime.now();
    final firstDay = DateTime(today.year, today.month, today.day);
    final lastDay = firstDay.add(Duration(days: daysAhead));
    final unavailableByDay = <String, Set<String>>{};

    void markUnavailable(String vehicleId, DateTime date) {
      unavailableByDay
          .putIfAbsent(_dateKey(date), () => <String>{})
          .add(vehicleId);
    }

    try {
      final availabilityRows = await supabase
          .from('vehicle_availability')
          .select('vehicle_id,date')
          .inFilter('vehicle_id', ids)
          .eq('is_available', false)
          .gte('date', firstDay.toIso8601String().split('T')[0])
          .lte('date', lastDay.toIso8601String().split('T')[0]);

      for (final row in List<Map<String, dynamic>>.from(availabilityRows)) {
        final vehicleId = row['vehicle_id']?.toString();
        final date = DateTime.tryParse(row['date']?.toString() ?? '');
        if (vehicleId != null && date != null) {
          markUnavailable(vehicleId, DateTime(date.year, date.month, date.day));
        }
      }

      final bookingRows = await supabase
          .from('bookings')
          .select('vehicle_id,start_at,end_at,start_date,end_date')
          .inFilter('vehicle_id', ids)
          .inFilter('status', _bookingBlockingStatuses)
          .lt(
            'start_at',
            lastDay.add(const Duration(days: 1)).toUtc().toIso8601String(),
          )
          .gt('end_at', firstDay.toUtc().toIso8601String());

      for (final row in List<Map<String, dynamic>>.from(bookingRows)) {
        final vehicleId = row['vehicle_id']?.toString();
        final start = DateTime.tryParse(
          row['start_at']?.toString() ?? row['start_date']?.toString() ?? '',
        )?.toLocal();
        final end = DateTime.tryParse(
          row['end_at']?.toString() ?? row['end_date']?.toString() ?? '',
        )?.toLocal();
        if (vehicleId == null || start == null || end == null) continue;

        var current = DateTime(start.year, start.month, start.day);
        final last = DateTime(end.year, end.month, end.day);
        while (!current.isAfter(last) && !current.isAfter(lastDay)) {
          if (!current.isBefore(firstDay)) {
            markUnavailable(vehicleId, current);
          }
          current = current.add(const Duration(days: 1));
        }
      }

      return unavailableByDay.entries
          .where((entry) => entry.value.length >= ids.length)
          .map((entry) => DateTime.parse(entry.key))
          .toSet();
    } catch (e) {
      debugPrint('getFullyUnavailableDatesForVehicles error: $e');
      return {};
    }
  }

  Future<void> setAvailability({
    required String vehicleId,
    required DateTime date,
    required bool isAvailable,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    await supabase.from('vehicle_availability').upsert({
      'vehicle_id': vehicleId,
      'date': dateStr,
      'is_available': isAvailable,
    }, onConflict: 'vehicle_id,date');
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
      final startDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endDay = DateTime(endDate.year, endDate.month, endDate.day);
      final response = await supabase
          .from('vehicle_availability')
          .select('date')
          .eq('vehicle_id', vehicleId)
          .eq('is_available', false)
          .gte('date', _dateKey(startDay))
          .lte('date', _dateKey(endDay));
      if (response.isNotEmpty) return false;

      final rangeEndExclusive = endDay.add(const Duration(days: 1));
      final overlapping = await supabase
          .from('bookings')
          .select('id')
          .eq('vehicle_id', vehicleId)
          .inFilter('status', _bookingBlockingStatuses)
          .lt('start_at', rangeEndExclusive.toUtc().toIso8601String())
          .gt('end_at', startDay.toUtc().toIso8601String())
          .limit(1);
      return overlapping.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _filterVehiclesAvailableForRange(
    List<Map<String, dynamic>> vehicles,
    DateTime? availableFrom,
    DateTime? availableTo,
  ) async {
    if (availableFrom == null && availableTo == null) return vehicles;
    if (vehicles.isEmpty) return vehicles;

    final startDay = availableFrom ?? availableTo!;
    final endDay = availableTo ?? availableFrom!;
    final rangeStart = DateTime(startDay.year, startDay.month, startDay.day);
    final rangeEndExclusive = DateTime(
      endDay.year,
      endDay.month,
      endDay.day,
    ).add(const Duration(days: 1));

    final vehicleIds = vehicles
        .map((v) => v['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (vehicleIds.isEmpty) return vehicles;

    try {
      final overlapping = await supabase
          .from('bookings')
          .select('vehicle_id')
          .inFilter('vehicle_id', vehicleIds)
          .inFilter('status', _bookingBlockingStatuses)
          .lt('start_at', rangeEndExclusive.toUtc().toIso8601String())
          .gt('end_at', rangeStart.toUtc().toIso8601String());

      final bookedVehicleIds = List<Map<String, dynamic>>.from(
        overlapping,
      ).map((row) => row['vehicle_id']?.toString()).whereType<String>().toSet();

      return vehicles
          .where(
            (vehicle) => !bookedVehicleIds.contains(vehicle['id']?.toString()),
          )
          .toList();
    } catch (e) {
      debugPrint('Date availability filter skipped: $e');
      return vehicles;
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
    String? fuelType,
    String? transmission,
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
          'fuel_type': fuelType,
          'transmission': transmission ?? 'Manual',
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
    String? fuelType,
    String? transmission,
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
      if (fuelType != null) 'fuel_type': fuelType,
      if (transmission != null) 'transmission': transmission,
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
    String vehicleId,
  ) async {
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
