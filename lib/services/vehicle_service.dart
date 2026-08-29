import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'trip_rating_service.dart';
import 'vehicle_turnaround_service.dart';

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
      'owner_role,owner_name,rating,rating_count,'
      'vehicle_images!vehicle_images_vehicle_id_fkey(image_url,display_order)';
  static const List<String> _bookingBlockingStatuses = [
    'pending',
    'Pending',
    'PENDING',
    'requested',
    'Requested',
    'REQUESTED',
    'reserved',
    'Reserved',
    'RESERVED',
    'approved',
    'Approved',
    'APPROVED',
    'confirmed',
    'Confirmed',
    'CONFIRMED',
    'active',
    'Active',
    'ACTIVE',
    'ongoing',
    'Ongoing',
    'ONGOING',
    'paid',
    'Paid',
    'PAID',
    'unpaid',
    'Unpaid',
    'UNPAID',
    'in_progress',
    'In_Progress',
    'IN_PROGRESS',
  ];

  static const Set<String> _nonBlockingStatuses = {
    'cancelled',
    'canceled',
    'rejected',
    'completed',
    'returned',
    'expired',
  };

  static bool _isBlockingStatus(String? status) {
    if (status == null) return false;
    final normalized = status.toString().trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return !_nonBlockingStatuses.contains(normalized);
  }

  factory VehicleService() => _instance;
  VehicleService._internal();

  SupabaseClient get supabase => Supabase.instance.client;
  Future<String>? _availabilityTableFuture;

  Future<String> _availabilityTable() {
    return _availabilityTableFuture ??= _resolveAvailabilityTable();
  }

  Future<String> _resolveAvailabilityTable() async {
    try {
      await supabase.from('vehicle_availability').select('id').limit(1);
      return 'vehicle_availability';
    } on PostgrestException catch (error) {
      final missingRelation =
          error.code == '42P01' ||
          error.code == 'PGRST205' ||
          error.message.toLowerCase().contains('could not find the table');
      if (!missingRelation) rethrow;
      debugPrint(
        'vehicle_availability is unavailable; using the existing backup table.',
      );
      return 'vehicle_availability_backup';
    }
  }

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
    final rawRating = (merged['rating'] as num?)?.toDouble() ?? 0.0;
    final rawCount = (merged['rating_count'] as num?)?.toInt() ?? 0;
    merged['rating'] = rawRating;
    // Only use the actual stored count — never fabricate a count of 1.
    merged['rating_count'] = rawCount;

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
    if (v['is_available'] != true) return false;
    final status = (v['status'] ?? '').toString().toLowerCase();
    return status != 'inactive' && status != 'archived' && status != 'deleted';
  }

  bool _isPartnerOwned(
    Map<String, dynamic> vehicle, [
    Set<String> knownPartnerOwnerIds = const <String>{},
  ]) {
    final ownerRole = vehicle['owner_role']?.toString().trim().toLowerCase();
    final source = vehicle['source']?.toString().trim().toLowerCase();
    final ownerId = vehicle['owner_id']?.toString().trim();
    return ownerRole == 'partner' ||
        source == 'partner' ||
        vehicle['is_partner_vehicle'] == true ||
        (ownerId != null && knownPartnerOwnerIds.contains(ownerId));
  }

  bool _isApprovedForRenterListing(
    Map<String, dynamic> vehicle,
    Map<String, Set<String>> approvedLinks,
  ) {
    if (!_isVisibleForRent(vehicle)) return false;
    final status = (vehicle['status'] ?? '').toString().toLowerCase();
    const blockedStatuses = {'rejected', 'deleted', 'archived', 'disabled', 'sold'};
    if (blockedStatuses.contains(status)) return false;
    return true;
  }

  Future<Map<String, Set<String>>> _getApprovedPartnerVehicleLinks() async {
    final partnerVehicleIds = <String>{};
    final vehicleIds = <String>{};
    final plateNumbers = <String>{};
    final partnerOwnerIds = <String>{};

    try {
      final response = await supabase
          .from('partner_vehicle_applications')
          .select('partner_id, application_status, status, partner_vehicle_id, created_vehicle_id, plate_number')
          .or('application_status.eq.approved,status.eq.approved');

      for (final raw in List<Map<String, dynamic>>.from(response)) {
        final partnerOwnerId = raw['partner_id']?.toString().trim();
        if (partnerOwnerId != null && partnerOwnerId.isNotEmpty) {
          partnerOwnerIds.add(partnerOwnerId);
        }
        final status = (raw['application_status'] ?? raw['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (status != 'approved') continue;

        final partnerVehicleId = raw['partner_vehicle_id']?.toString().trim();
        final vehicleId = raw['created_vehicle_id']?.toString().trim();
        final plateNumber = raw['plate_number']
            ?.toString()
            .trim()
            .toUpperCase();
        if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
          partnerVehicleIds.add(partnerVehicleId);
        }
        if (vehicleId != null && vehicleId.isNotEmpty) {
          vehicleIds.add(vehicleId);
        }
        if (plateNumber != null && plateNumber.isNotEmpty) {
          plateNumbers.add(plateNumber);
        }
      }
    } catch (e) {
      debugPrint('Application approval lookup unavailable: $e');
    }

    // Renters cannot read other partners' full applications. The linked
    // partner vehicle row is created by the admin approval flow, so it is the
    // safe renter-facing source for resolving approved canonical vehicles.
    try {
      List response;
      try {
        response =
            await supabase
                    .from('partner_vehicles')
                    .select(
                      'id,vehicle_id,partner_id,plate_number,status,'
                      'partners:partner_id(user_id)',
                    )
                as List;
      } catch (_) {
        response =
            await supabase
                    .from('partner_vehicles')
                    .select('id,vehicle_id,partner_id,plate_number,status')
                as List;
      }

      const blockedStatuses = {'pending', 'disabled', 'sold', 'rejected'};
      for (final raw in response.whereType<Map<String, dynamic>>()) {
        final status = (raw['status'] ?? '').toString().trim().toLowerCase();
        if (status.isEmpty || blockedStatuses.contains(status)) continue;

        final partnerVehicleId = raw['id']?.toString().trim();
        final vehicleId = raw['vehicle_id']?.toString().trim();
        final plateNumber = raw['plate_number']
            ?.toString()
            .trim()
            .toUpperCase();
        final partner = raw['partners'];
        final partnerUserId = partner is Map<String, dynamic>
            ? partner['user_id']?.toString().trim()
            : null;

        if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
          partnerVehicleIds.add(partnerVehicleId);
        }
        if (vehicleId != null && vehicleId.isNotEmpty) {
          vehicleIds.add(vehicleId);
        }
        if (plateNumber != null && plateNumber.isNotEmpty) {
          plateNumbers.add(plateNumber);
        }
        if (partnerUserId != null && partnerUserId.isNotEmpty) {
          partnerOwnerIds.add(partnerUserId);
        }
      }
    } catch (e) {
      debugPrint('Approved partner vehicle link lookup failed: $e');
    }

    return {
      'partner_vehicle_ids': partnerVehicleIds,
      'vehicle_ids': vehicleIds,
      'plate_numbers': plateNumbers,
      'partner_owner_ids': partnerOwnerIds,
    };
  }

  bool _hasApprovedPartnerApplication(
    Map<String, dynamic> vehicle,
    Map<String, Set<String>> approvedLinks, {
    required bool legacyPartnerVehicle,
  }) {
    final id = vehicle['id']?.toString().trim() ?? '';
    final plate =
        vehicle['plate_number']?.toString().trim().toUpperCase() ?? '';
    final idKey = legacyPartnerVehicle ? 'partner_vehicle_ids' : 'vehicle_ids';
    return approvedLinks[idKey]!.contains(id) ||
        (plate.isNotEmpty && approvedLinks['plate_numbers']!.contains(plate));
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
      'is_posted': partnerVehicle['is_posted'] != false,
      'is_available': partnerVehicle['is_available'] != false,
      'status': partnerVehicle['status'] ?? 'pending',
    });

    return normalized;
  }

  Future<List<Map<String, dynamic>>> _getAvailablePartnerVehicles(
    Map<String, Set<String>> approvedLinks,
  ) async {
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
            final appStatus =
                (vehicle['application_status'] ?? '').toString().toLowerCase();
            const blockedStatuses = {
              'rejected',
              'deleted',
              'archived',
              'disabled',
              'sold',
              'pending',
            };
            if (blockedStatuses.contains(status) ||
                blockedStatuses.contains(appStatus)) {
              return false;
            }
            final isPosted = vehicle['is_posted'] == true ||
                vehicle['is_available'] == true ||
                status == 'available' ||
                status == 'approved' ||
                status == 'active';
            return isPosted;
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

      return partnerVehicles.map((vehicle) {
        final normalized = _normalizePartnerVehicleRecord(vehicle);
        normalized['id'] = vehicle['id'];
        normalized['partner_vehicle_id'] = vehicle['id'];
        return normalized;
      }).toList();
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
      final partnerProfile = await supabase
          .from('partners')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      final partnerId = partnerProfile?['id']?.toString();

      List response;
      if (partnerId != null && partnerId.isNotEmpty) {
        response = await supabase
            .from('partner_vehicles')
            .select('*, partners:partner_id(id,user_id,business_name,users:user_id(full_name,email))')
            .eq('partner_id', partnerId)
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('partner_vehicles')
            .select('*, partners:partner_id(id,user_id,business_name,users:user_id(full_name,email))')
            .order('created_at', ascending: false);
      }

      final vehicles = List<Map<String, dynamic>>.from(response);
      final partnerVehicleIds = vehicles
          .map((v) => v['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final imagesByPartnerVehicleId = await _fetchAndGroupPartnerImages(
        partnerVehicleIds,
      );

      for (final vehicle in vehicles) {
        final id = vehicle['id']?.toString();
        vehicle['vehicle_images'] = id == null
            ? <Map<String, dynamic>>[]
            : imagesByPartnerVehicleId[id] ?? <Map<String, dynamic>>[];
      }

      return vehicles.map((v) => _normalizePartnerVehicleRecord(v)).toList();
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
      // 1. First check partner_vehicles table to get full partner info if it's a partner vehicle
      final partnerResponse = await supabase
          .from('partner_vehicles')
          .select(
            '*, partners:partner_id(id,user_id,business_name,users:user_id(full_name,email))',
          )
          .eq('id', vehicleId)
          .maybeSingle();

      if (partnerResponse != null) {
        final partnerVehicle = Map<String, dynamic>.from(partnerResponse);
        final images = await _fetchAndGroupPartnerImages([vehicleId]);
        partnerVehicle['vehicle_images'] =
            images[vehicleId] ?? <Map<String, dynamic>>[];
        final normalized = _normalizePartnerVehicleRecord(partnerVehicle);
        try {
          final summary =
              await TripRatingService().getVehicleRatingSummary(vehicleId);
          if ((summary['count'] as num? ?? 0) > 0) {
            normalized['rating'] = summary['average'];
            normalized['rating_count'] = summary['count'];
          }
        } catch (_) {}

        return normalized;
      }

      // 2. Fall back to vehicles table
      final response = await supabase
          .from('vehicles')
          .select(_vehicleSelect)
          .eq('id', vehicleId)
          .maybeSingle();

      if (response != null) {
        final vehicle = Map<String, dynamic>.from(response);
        final normalized = _normalizeVehicleRecord(vehicle);
        if (vehicle['owner_role']?.toString().toLowerCase() == 'partner') {
          normalized['is_partner_vehicle'] = true;
          normalized['source'] = 'partner';
        }
        try {
          final summary =
              await TripRatingService().getVehicleRatingSummary(vehicleId);
          if ((summary['count'] as num? ?? 0) > 0) {
            normalized['rating'] = summary['average'];
            normalized['rating_count'] = summary['count'];
          }
        } catch (_) {}

        return normalized;
      }

      return null;
    } on PostgrestException catch (e) {
      debugPrint('getVehicleById error: ${e.message}');
      rethrow;
    }
  }

  /// Revalidates a renter-facing vehicle against its live listing state.
  /// Partner vehicles additionally require a currently approved application.
  Future<bool> isVehicleBookable(String vehicleId) async {
    if (vehicleId.trim().isEmpty) return false;

    try {
      // 1. Check partner_vehicles table first
      try {
        final partnerResponse = await supabase
            .from('partner_vehicles')
            .select('id,plate_number,is_available,status')
            .eq('id', vehicleId)
            .maybeSingle();

        if (partnerResponse != null) {
          final pv = Map<String, dynamic>.from(partnerResponse);
          final status = (pv['status'] ?? '').toString().toLowerCase();
          const blockedStatuses = {
            'rejected',
            'deleted',
            'archived',
            'disabled',
            'sold',
            'inactive',
          };

          if (blockedStatuses.contains(status)) {
            return false;
          }

          if (pv['is_available'] == false) {
            return false;
          }

          final isApprovedOrActive =
              status == 'available' ||
              status == 'approved' ||
              status == 'active';
          return isApprovedOrActive;
        }
      } catch (e) {
        debugPrint('isVehicleBookable partner_vehicles check fallback: $e');
      }

      // 2. Check vehicles table
      final response = await supabase
          .from('vehicles')
          .select('id,plate_number,owner_role,is_available,is_posted,status')
          .eq('id', vehicleId)
          .maybeSingle();

      if (response != null) {
        final vehicle = Map<String, dynamic>.from(response);
        final ownerRole = vehicle['owner_role']?.toString().toLowerCase();
        final status = (vehicle['status'] ?? '').toString().toLowerCase();

        if (ownerRole == 'partner') {
          const blockedStatuses = {
            'rejected',
            'deleted',
            'archived',
            'disabled',
            'sold',
            'inactive',
          };
          if (blockedStatuses.contains(status)) return false;
          if (vehicle['is_available'] == false) return false;
          return vehicle['is_posted'] == true ||
              status == 'available' ||
              status == 'approved' ||
              status == 'active';
        }

        return _isVisibleForRent(vehicle);
      }

      return false;
    } catch (error) {
      debugPrint('Unable to validate vehicle booking eligibility: $error');
      return false;
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
      try {
        await VehicleTurnaroundService().processExpiredTurnarounds();
      } catch (_) {}

      final approvedLinks = await _getApprovedPartnerVehicleLinks();
      final response = await supabase
          .from('vehicles')
          .select(_vehicleSelect)
          .eq('is_posted', true)
          .eq('is_available', true)
          .order('created_at', ascending: false);

      debugPrint('Raw rows returned: ${response.length}');

      final vehicles = List<Map<String, dynamic>>.from(response);

      final normalized = _normalizeList(vehicles)
          .where(
            (vehicle) => _isApprovedForRenterListing(vehicle, approvedLinks),
          )
          .toList();
      final linkedPartnerVehicles = await _getAvailablePartnerVehicles(
        approvedLinks,
      );
      final allVehicles = <Map<String, dynamic>>[];
      final seenVehicleKeys = <String>{};
      for (final vehicle in [...normalized, ...linkedPartnerVehicles]) {
        final plate = vehicle['plate_number']?.toString().trim().toUpperCase();
        final id = vehicle['id']?.toString().trim() ?? '';
        final idKey = id.isEmpty ? null : 'id:$id';
        final plateKey = plate == null || plate.isEmpty ? null : 'plate:$plate';
        if ((idKey != null && seenVehicleKeys.contains(idKey)) ||
            (plateKey != null && seenVehicleKeys.contains(plateKey))) {
          continue;
        }
        if (idKey != null) seenVehicleKeys.add(idKey);
        if (plateKey != null) seenVehicleKeys.add(plateKey);
        allVehicles.add(vehicle);
      }

      try {
        await TripRatingService().batchHydrateVehicleRatings(allVehicles);
      } catch (ratingErr) {
        debugPrint('Error hydrating vehicle ratings: $ratingErr');
      }

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
    String? transmission,
    String? category,
  }) async {
    try {
      try {
        await VehicleTurnaroundService().processExpiredTurnarounds();
      } catch (_) {}

      final approvedLinks = await _getApprovedPartnerVehicleLinks();
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
      if (transmission != null && transmission.isNotEmpty) {
        query = query.ilike('transmission', '%$transmission%');
      }
      if (minSeats != null) query = query.gte('seats', minSeats);
      if (location != null && location.trim().isNotEmpty) {
        final loc = location.trim();
        query = query.or(
          'location.ilike.%$loc%,'
          'city.ilike.%$loc%,'
          'province.ilike.%$loc%,'
          'address.ilike.%$loc%,'
          'pickup_location.ilike.%$loc%,'
          'brand.ilike.%$loc%,'
          'model.ilike.%$loc%,'
          'vehicle_name.ilike.%$loc%,'
          'description.ilike.%$loc%',
        );
      }

      final response = await query.order('created_at', ascending: false);

      final vehicles = List<Map<String, dynamic>>.from(response);

      final normalized = _normalizeList(vehicles)
          .where(
            (vehicle) => _isApprovedForRenterListing(vehicle, approvedLinks),
          )
          .toList();

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
      final table = await _availabilityTable();
      final response = await supabase
          .from(table)
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
      final explicitlyUnavailableDates = availability
          .where((r) => r['is_available'] == false)
          .map((r) => DateTime.parse(r['date'] as String))
          .toList();
      final byDay = <String, DateTime>{};
      for (final date in explicitlyUnavailableDates) {
        byDay[_dateKey(date)] = DateTime(date.year, date.month, date.day);
      }

      final response = await supabase
          .from('bookings')
          .select('start_at,end_at,start_date,end_date,status')
          .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
          .inFilter('status', _bookingBlockingStatuses);
      final intervalsByDay = <String, List<(DateTime, DateTime)>>{};
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final status = row['status']?.toString();
        if (!_isBlockingStatus(status)) continue;
        final interval = _bookingInterval(row);
        if (interval == null) continue;
        final (start, end) = interval;

        var current = _dateOnly(start);
        final last = _dateOnly(end);
        while (!current.isAfter(last)) {
          byDay[_dateKey(current)] = current;
          current = current.add(const Duration(days: 1));
        }
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
          .select('start_at,end_at,start_date,end_date,status')
          .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
          .inFilter('status', _bookingBlockingStatuses);

      final dates = <String, DateTime>{};
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final status = row['status']?.toString();
        if (!_isBlockingStatus(status)) continue;
        final interval = _bookingInterval(row);
        if (interval == null) continue;
        final (start, endExclusive) = interval;
        final end = endExclusive.subtract(const Duration(microseconds: 1));

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

  Future<List<DateTime>> getAvailableTimeSlots({
    required String vehicleId,
    required DateTime date,
    DateTime? rentalStart,
    bool selectingEnd = false,
    int firstHour = 0,
    int lastHour = 23,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final windowStart = rentalStart ?? day;
    final windowEnd = day.add(const Duration(days: 1));
    if (selectingEnd && rentalStart == null) return [];
    if (selectingEnd && !day.isAfter(_dateOnly(rentalStart!))) {
      if (day.isBefore(_dateOnly(rentalStart))) return [];
    }

    try {
      final table = await _availabilityTable();
      final availabilityRows = await supabase
          .from(table)
          .select('date,is_available')
          .eq('vehicle_id', vehicleId)
          .eq('is_available', false)
          .gte('date', _dateKey(windowStart))
          .lte('date', _dateKey(day));
      final unavailableDays = List<Map<String, dynamic>>.from(
        availabilityRows,
      ).map((row) => row['date']?.toString()).whereType<String>().toSet();

      final bookingRows = await supabase
          .from('bookings')
          .select('start_at,end_at,start_date,end_date,status')
          .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
          .inFilter('status', _bookingBlockingStatuses);
      final bookedIntervals = <(DateTime, DateTime)>[];
      for (final row in List<Map<String, dynamic>>.from(bookingRows)) {
        final status = row['status']?.toString();
        if (!_isBlockingStatus(status)) continue;
        final interval = _bookingInterval(row);
        if (interval == null) continue;
        final (start, end) = interval;
        if (start.isBefore(windowEnd) && end.isAfter(windowStart)) {
          bookedIntervals.add((start, end));
        }
      }

      bool rangeHasUnavailableDay(DateTime start, DateTime end) {
        var current = _dateOnly(start);
        final last = _dateOnly(end);
        while (!current.isAfter(last)) {
          if (unavailableDays.contains(_dateKey(current))) return true;
          current = current.add(const Duration(days: 1));
        }
        return false;
      }

      bool overlapsBooking(DateTime start, DateTime end) {
        return bookedIntervals.any(
          (interval) => start.isBefore(interval.$2) && end.isAfter(interval.$1),
        );
      }

      final now = DateTime.now();
      final slots = <DateTime>[];
      final initialHour = firstHour;
      for (var hour = initialHour; hour <= lastHour; hour++) {
        final candidate = DateTime(day.year, day.month, day.day, hour);
        final intervalStart = selectingEnd ? rentalStart! : candidate;
        final intervalEnd = selectingEnd
            ? candidate
            : candidate.add(const Duration(hours: 1));
        if (!intervalEnd.isAfter(intervalStart)) continue;
        if (!candidate.isAfter(now)) continue;
        if (selectingEnd && !candidate.isAfter(rentalStart!)) continue;
        if (selectingEnd && rentalStart != null) {
          final diffMinutes = candidate.difference(rentalStart!).inMinutes;
          // Minimum 12 hours (720 min) and Maximum 23 hours (1380 min) for hourly mode
          if (diffMinutes < 12 * 60 || diffMinutes > 23 * 60) {
            continue;
          }
        }
        if (rangeHasUnavailableDay(intervalStart, intervalEnd)) continue;
        if (overlapsBooking(intervalStart, intervalEnd)) continue;
        slots.add(candidate);
      }
      return slots;
    } catch (e) {
      debugPrint('getAvailableTimeSlots error: $e');
      rethrow;
    }
  }

  Future<bool> isTimeRangeAvailable({
    required String vehicleId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    if (!endAt.isAfter(startAt)) return false;

    try {
      final table = await _availabilityTable();
      final unavailableRows = await supabase
          .from(table)
          .select('date')
          .eq('vehicle_id', vehicleId)
          .eq('is_available', false)
          .gte('date', _dateKey(startAt))
          .lte('date', _dateKey(endAt));
      if (unavailableRows.isNotEmpty) return false;

      final bookingRows = await supabase
          .from('bookings')
          .select('start_at,end_at,start_date,end_date,status')
          .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
          .inFilter('status', _bookingBlockingStatuses);
      for (final row in List<Map<String, dynamic>>.from(bookingRows)) {
        final status = row['status']?.toString();
        if (!_isBlockingStatus(status)) continue;
        final interval = _bookingInterval(row);
        if (interval == null) continue;
        final (bookedStart, bookedEnd) = interval;
        if (startAt.isBefore(bookedEnd) && endAt.isAfter(bookedStart)) {
          return false;
        }
      }
      return true;
    } catch (error) {
      debugPrint('isTimeRangeAvailable error: $error');
      rethrow;
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
      final table = await _availabilityTable();
      final availabilityRows = await supabase
          .from(table)
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
        final interval = _bookingInterval(row);
        if (vehicleId == null || interval == null) continue;
        final (start, endExclusive) = interval;
        final end = endExclusive.subtract(const Duration(microseconds: 1));

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
    final table = await _availabilityTable();
    final record = {
      'vehicle_id': vehicleId,
      'date': dateStr,
      'is_available': isAvailable,
    };
    if (table == 'vehicle_availability_backup') {
      await supabase
          .from(table)
          .delete()
          .eq('vehicle_id', vehicleId)
          .eq('date', dateStr);
      await supabase.from(table).insert(record);
    } else {
      await supabase.from(table).upsert(record, onConflict: 'vehicle_id,date');
    }
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
    final table = await _availabilityTable();
    if (table == 'vehicle_availability_backup') {
      await supabase
          .from(table)
          .delete()
          .eq('vehicle_id', vehicleId)
          .gte('date', startDate.toIso8601String().split('T')[0])
          .lte('date', endDate.toIso8601String().split('T')[0]);
      await supabase.from(table).insert(records);
    } else {
      await supabase.from(table).upsert(records, onConflict: 'vehicle_id,date');
    }
  }

  Future<void> clearAvailability({
    required String vehicleId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final table = await _availabilityTable();
    await supabase
        .from(table)
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
      final table = await _availabilityTable();
      final startDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endDay = DateTime(endDate.year, endDate.month, endDate.day);
      final response = await supabase
          .from(table)
          .select('date')
          .eq('vehicle_id', vehicleId)
          .eq('is_available', false)
          .gte('date', _dateKey(startDay))
          .lte('date', _dateKey(endDay));
      if (response.isNotEmpty) return false;

      final rangeEndExclusive = endDay.add(const Duration(days: 1));
      final bookingRows = await supabase
          .from('bookings')
          .select('id,start_at,end_at,start_date,end_date')
          .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
          .inFilter('status', _bookingBlockingStatuses);
      for (final row in List<Map<String, dynamic>>.from(bookingRows)) {
        final interval = _bookingInterval(row);
        if (interval == null) continue;
        final (bookedStart, bookedEnd) = interval;
        if (bookedStart.isBefore(rangeEndExclusive) &&
            bookedEnd.isAfter(startDay)) {
          return false;
        }
      }
      return true;
    } catch (error) {
      debugPrint('isVehicleAvailable error: $error');
      rethrow;
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

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  (DateTime, DateTime)? _bookingInterval(Map<String, dynamic> row) {
    final startAt = row['start_at']?.toString().trim() ?? '';
    final endAt = row['end_at']?.toString().trim() ?? '';
    if (startAt.isNotEmpty && endAt.isNotEmpty) {
      final start = DateTime.tryParse(startAt)?.toLocal();
      final end = DateTime.tryParse(endAt)?.toLocal();
      if (start != null && end != null && end.isAfter(start)) {
        return (start, end);
      }
    }

    final startDate = DateTime.tryParse(
      row['start_date']?.toString().trim() ?? '',
    );
    final endDate = DateTime.tryParse(row['end_date']?.toString().trim() ?? '');
    if (startDate == null || endDate == null) return null;
    final start = _dateOnly(startDate);
    final inclusiveEnd = _dateOnly(endDate).add(const Duration(days: 1));
    return (
      start,
      inclusiveEnd.isAfter(start)
          ? inclusiveEnd
          : start.add(const Duration(days: 1)),
    );
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
