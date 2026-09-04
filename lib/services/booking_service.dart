import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'chat_service.dart';
import 'notification_service.dart';
import 'user_restriction_service.dart';
import 'vehicle_service.dart';
import 'booking_inspection_service.dart';
import 'trip_rating_service.dart';
import 'loyalty_service.dart';
import 'vehicle_turnaround_service.dart';
import 'transaction_logger.dart';
import '../utils/pricing_policy.dart';
import '../utils/philippine_geocoding.dart';
import '../utils/booking_status.dart';
import '../utils/currency_formatter.dart';

class BookingService {
  static final BookingService _instance = BookingService._internal();

  factory BookingService() {
    return _instance;
  }

  BookingService._internal();

  SupabaseClient get supabase => Supabase.instance.client;
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

  /// Safely updates a booking row in Supabase.
  /// If Supabase returns PGRST204 (column missing in schema cache), it automatically
  /// strips the unrecognized column(s) and retries the update so database calls never crash.
  static Future<void> safeUpdateBooking(
    String bookingId,
    Map<String, dynamic> updateData,
  ) async {
    final payload = Map<String, dynamic>.from(updateData);
    final supabase = Supabase.instance.client;

    for (int attempt = 0; attempt < 20; attempt++) {
      if (payload.isEmpty) return;
      try {
        await supabase.from('bookings').update(payload).eq('id', bookingId);
        return; // Success!
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST204' ||
            e.message.contains('Could not find the') ||
            e.message.contains('column of \'bookings\' in the schema cache') ||
            e.message.toLowerCase().contains('column')) {
          final match =
              RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message) ??
              RegExp(r"'([^']+)' column of 'bookings'").firstMatch(e.message) ??
              RegExp(r"column '([^']+)'").firstMatch(e.message) ??
              RegExp(r'column "([^"]+)"').firstMatch(e.message);
          if (match != null && match.groupCount >= 1) {
            final missingCol = match.group(1)!;
            debugPrint(
              '⚠️ Column "$missingCol" does not exist in bookings schema cache. Stripping and retrying...',
            );
            payload.remove(missingCol);
            continue; // Retry without the missing column
          }
        }
        rethrow;
      } catch (e) {
        debugPrint('Unexpected error in safeUpdateBooking: $e');
        rethrow;
      }
    }
  }

  static (DateTime, DateTime)? _bookingInterval(Map<String, dynamic> row) {
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
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final inclusiveEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(const Duration(days: 1));
    return (
      start,
      inclusiveEnd.isAfter(start)
          ? inclusiveEnd
          : start.add(const Duration(days: 1)),
    );
  }

  /// App-side fallback for projects where the scheduled database job is not
  /// available. The database function is idempotent and only touches overdue
  /// pending bookings.
  Future<int> processExpiredPendingBookings() async {
    try {
      final response = await supabase.rpc('process_expired_pending_bookings');
      if (response is int) return response;
      return int.tryParse(response?.toString() ?? '') ?? 0;
    } on PostgrestException catch (error) {
      final functionIsMissing =
          error.code == '42883' ||
          error.message.toLowerCase().contains(
            'process_expired_pending_bookings',
          );
      if (!functionIsMissing) {
        debugPrint('Could not process expired bookings: ${error.message}');
      }
      return 0;
    } catch (error) {
      debugPrint('Could not process expired bookings: $error');
      return 0;
    }
  }

  // Get bookings for a partner (via standard vehicles, partner_vehicles, or partner_id)
  Future<List<Map<String, dynamic>>> getPartnerBookings(String userId) async {
    try {
      debugPrint('Fetching bookings for partner/owner: $userId');

      // 1. Get all partner profile IDs for this user
      final partnerIds = <String>{userId};
      try {
        final partners = await supabase
            .from('partners')
            .select('id, user_id')
            .or('user_id.eq.$userId,id.eq.$userId');
        for (final p in List<Map<String, dynamic>>.from(partners)) {
          final id = p['id']?.toString().trim();
          final uId = p['user_id']?.toString().trim();
          if (id != null && id.isNotEmpty) partnerIds.add(id);
          if (uId != null && uId.isNotEmpty) partnerIds.add(uId);
        }
      } catch (e) {
        debugPrint('Error fetching partner IDs: $e');
      }

      final allVehicleIds = <String>{};
      final vehiclePlates = <String>{};

      // 2. Get partner_vehicles IDs and plate numbers
      try {
        final pVehicles = await supabase
            .from('partner_vehicles')
            .select('id, plate_number, vehicle_id')
            .inFilter('partner_id', partnerIds.toList());
        for (final pv in List<Map<String, dynamic>>.from(pVehicles)) {
          final id = pv['id']?.toString().trim();
          final vid = pv['vehicle_id']?.toString().trim();
          final plate = pv['plate_number']?.toString().trim().toUpperCase();
          if (id != null && id.isNotEmpty) allVehicleIds.add(id);
          if (vid != null && vid.isNotEmpty) allVehicleIds.add(vid);
          if (plate != null && plate.isNotEmpty) vehiclePlates.add(plate);
        }
      } catch (e) {
        debugPrint('Error fetching partner_vehicles for partner: $e');
      }

      // Also check partner_vehicles where user_id is the user
      try {
        final pVehiclesByUser = await supabase
            .from('partner_vehicles')
            .select('id, plate_number, vehicle_id')
            .eq('user_id', userId);
        for (final pv in List<Map<String, dynamic>>.from(pVehiclesByUser)) {
          final id = pv['id']?.toString().trim();
          final vid = pv['vehicle_id']?.toString().trim();
          final plate = pv['plate_number']?.toString().trim().toUpperCase();
          if (id != null && id.isNotEmpty) allVehicleIds.add(id);
          if (vid != null && vid.isNotEmpty) allVehicleIds.add(vid);
          if (plate != null && plate.isNotEmpty) vehiclePlates.add(plate);
        }
      } catch (_) {}

      // 3. Get partner_vehicle_applications IDs, created_vehicle_ids, and plates
      try {
        final pApps = await supabase
            .from('partner_vehicle_applications')
            .select('id, partner_vehicle_id, created_vehicle_id, plate_number')
            .inFilter('partner_id', partnerIds.toList());
        for (final app in List<Map<String, dynamic>>.from(pApps)) {
          final appId = app['id']?.toString().trim();
          final pvId = app['partner_vehicle_id']?.toString().trim();
          final cvId = app['created_vehicle_id']?.toString().trim();
          final plate = app['plate_number']?.toString().trim().toUpperCase();
          if (appId != null && appId.isNotEmpty) allVehicleIds.add(appId);
          if (pvId != null && pvId.isNotEmpty) allVehicleIds.add(pvId);
          if (cvId != null && cvId.isNotEmpty) allVehicleIds.add(cvId);
          if (plate != null && plate.isNotEmpty) vehiclePlates.add(plate);
        }
      } catch (e) {
        debugPrint('Error fetching partner_vehicle_applications: $e');
      }

      // 4. Get standard vehicles owned by this partner/user
      try {
        final vehicles = await supabase
            .from('vehicles')
            .select('id, plate_number')
            .inFilter('owner_id', partnerIds.toList());
        for (final v in List<Map<String, dynamic>>.from(vehicles)) {
          final id = v['id']?.toString().trim();
          final plate = v['plate_number']?.toString().trim().toUpperCase();
          if (id != null && id.isNotEmpty) allVehicleIds.add(id);
          if (plate != null && plate.isNotEmpty) vehiclePlates.add(plate);
        }
      } catch (e) {
        debugPrint('Error fetching standard vehicles by owner_id: $e');
      }

      try {
        final vehiclesByOp = await supabase
            .from('vehicles')
            .select('id, plate_number')
            .eq('operator_id', userId);
        for (final v in List<Map<String, dynamic>>.from(vehiclesByOp)) {
          final id = v['id']?.toString().trim();
          final plate = v['plate_number']?.toString().trim().toUpperCase();
          if (id != null && id.isNotEmpty) allVehicleIds.add(id);
          if (plate != null && plate.isNotEmpty) vehiclePlates.add(plate);
        }
      } catch (_) {}

      // If plate numbers found, also match any vehicles sharing those plate numbers
      if (vehiclePlates.isNotEmpty) {
        try {
          final vehiclesByPlate = await supabase
              .from('vehicles')
              .select('id')
              .inFilter('plate_number', vehiclePlates.toList());
          for (final v in List<Map<String, dynamic>>.from(vehiclesByPlate)) {
            final id = v['id']?.toString().trim();
            if (id != null && id.isNotEmpty) allVehicleIds.add(id);
          }
        } catch (_) {}
      }

      final bookingList = <Map<String, dynamic>>[];
      final seenBookingIds = <String>{};

      void addRows(List<dynamic> rows) {
        for (final r in rows) {
          if (r is Map) {
            final rowMap = Map<String, dynamic>.from(r);
            final id = rowMap['id']?.toString().trim();
            if (id != null && id.isNotEmpty && !seenBookingIds.contains(id)) {
              seenBookingIds.add(id);
              bookingList.add(rowMap);
            }
          }
        }
      }

      // Query bookings with isolated try-catches so one failure does not drop others
      if (allVehicleIds.isNotEmpty) {
        final vehicleList = allVehicleIds.toList();
        try {
          final res = await supabase
              .from('bookings')
              .select('*')
              .inFilter('vehicle_id', vehicleList)
              .order('created_at', ascending: false)
              .limit(300);
          addRows(res);
        } catch (e) {
          debugPrint('Error querying bookings by vehicle_id: $e');
        }

        try {
          final res = await supabase
              .from('bookings')
              .select('*')
              .inFilter('partner_vehicle_id', vehicleList)
              .order('created_at', ascending: false)
              .limit(300);
          addRows(res);
        } catch (_) {}
      }

      if (partnerIds.isNotEmpty) {
        final pList = partnerIds.toList();
        try {
          final res = await supabase
              .from('bookings')
              .select('*')
              .inFilter('partner_id', pList)
              .order('created_at', ascending: false)
              .limit(300);
          addRows(res);
        } catch (_) {}

        try {
          final res = await supabase
              .from('bookings')
              .select('*')
              .inFilter('owner_id', pList)
              .order('created_at', ascending: false)
              .limit(300);
          addRows(res);
        } catch (_) {}
      }

      // Sort all fetched bookings by created_at descending
      bookingList.sort((a, b) {
        final aDate = a['created_at']?.toString() ?? '';
        final bDate = b['created_at']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

      debugPrint(
        'Fetched ${bookingList.length} total partner bookings for partner $userId (allVehicleIds: ${allVehicleIds.length})',
      );
      return await hydrateBookingVehicles(bookingList);
    } catch (e) {
      debugPrint('Error fetching partner bookings: $e');
      return [];
    }
  }

  // Get bookings for a partner by status
  Future<List<Map<String, dynamic>>> getPartnerBookingsByStatus(
    String userId,
    String status,
  ) async {
    try {
      final all = await getPartnerBookings(userId);
      final normalizedStatus = status.trim().toLowerCase();
      return all.where((b) {
        final s = b['status']?.toString().trim().toLowerCase() ?? '';
        final group = bookingStatusGroup(s).name.toLowerCase();
        return s == normalizedStatus || group == normalizedStatus;
      }).toList();
    } catch (e) {
      debugPrint('Database error fetching bookings by status: $e');
      return [];
    }
  }

  static Map<String, dynamic> _normalizePartnerVehicle(
    Map<String, dynamic> pv,
  ) {
    final partner = pv['partners'] is Map
        ? Map<String, dynamic>.from(pv['partners'] as Map)
        : <String, dynamic>{};
    final partnerUser = partner['users'] is Map
        ? Map<String, dynamic>.from(partner['users'] as Map)
        : <String, dynamic>{};
    final partnerName =
        partner['business_name']?.toString().trim().isNotEmpty == true
            ? partner['business_name'].toString().trim()
            : partnerUser['full_name']?.toString().trim().isNotEmpty == true
                ? partnerUser['full_name'].toString().trim()
                : pv['owner_name']?.toString().trim().isNotEmpty == true
                    ? pv['owner_name'].toString().trim()
                    : 'Mobilis Partner';

    final brand = pv['brand']?.toString().trim() ?? '';
    final model = pv['model']?.toString().trim() ?? '';
    final combo = [brand, model].where((part) => part.isNotEmpty).join(' ');
    final rawVName = pv['vehicle_name']?.toString().trim() ?? '';
    final vName = combo.isNotEmpty
        ? combo
        : (rawVName.isNotEmpty &&
                rawVName.toLowerCase() != 'partner vehicle' &&
                rawVName.toLowerCase() != 'unknown vehicle'
            ? rawVName
            : (pv['plate_number']?.toString().isNotEmpty == true
                ? 'Vehicle (${pv['plate_number']})'
                : 'Partner Vehicle'));

    final directImage = pv['image_url']?.toString().trim() ?? '';
    final rawImages = pv['vehicle_images'];
    final images = rawImages is List
        ? List<Map<String, dynamic>>.from(rawImages.whereType<Map>())
        : <Map<String, dynamic>>[];

    return {
      ...pv,
      'id': pv['id'],
      'brand': brand,
      'model': model,
      'year': pv['year'],
      'plate_number': pv['plate_number'],
      'vehicle_name': vName,
      'price_per_day': pv['price_per_day'],
      'price_per_hour': pv['price_per_hour'],
      'transmission': pv['transmission'],
      'vehicle_type':
          pv['vehicle_type'] ?? pv['category'] ?? 'Partner Vehicle',
      'category': pv['category'] ?? pv['vehicle_type'] ?? 'Partner Vehicle',
      'seats': pv['seats'],
      'location': pv['location'],
      'latitude': pv['latitude'],
      'longitude': pv['longitude'],
      'is_partner_vehicle': true,
      'owner_role': 'partner',
      'owner_name': partnerName,
      'owner': {
        'id': partnerUser['id'] ?? partner['user_id'],
        'full_name': partnerName,
        'role': 'partner',
        'email': partnerUser['email'],
        'phone': partner['business_phone'] ?? partnerUser['phone'],
      },
      'partner': partner,
      'image_url': directImage.isNotEmpty
          ? directImage
          : (images.isNotEmpty
              ? images.first['image_url']?.toString().trim()
              : null),
      'vehicle_images': images,
    };
  }

  /// Hydrate any missing vehicle, partner vehicle, renter, driver, job assignments, and ratings across booking rows
  Future<List<Map<String, dynamic>>> hydrateBookingVehicles(
    List<Map<String, dynamic>> rawBookings,
  ) async {
    if (rawBookings.isEmpty) return rawBookings;

    final bookings =
        rawBookings.map((b) => Map<String, dynamic>.from(b)).toList();
    final missingVehicleIds = <String>{};
    final missingRenterIds = <String>{};
    final missingDriverIds = <String>{};
    final allBookingIds = <String>{};

    for (final booking in bookings) {
      final bId = booking['id']?.toString().trim() ?? '';
      if (bId.isNotEmpty) allBookingIds.add(bId);

      final vehicle = booking['vehicles'];
      final brand = vehicle is Map ? vehicle['brand']?.toString().trim() ?? '' : '';
      final model = vehicle is Map ? vehicle['model']?.toString().trim() ?? '' : '';
      final vName = vehicle is Map ? vehicle['vehicle_name']?.toString().trim() ?? '' : '';
      final hasValidVehicle = vehicle is Map<String, dynamic> &&
          (brand.isNotEmpty ||
              model.isNotEmpty ||
              (vName.isNotEmpty &&
                  vName.toLowerCase() != 'partner vehicle' &&
                  vName.toLowerCase() != 'unknown vehicle'));

      if (!hasValidVehicle) {
        final partnerVehicle = booking['partner_vehicles'];
        if (partnerVehicle is Map<String, dynamic> &&
            (partnerVehicle['brand']?.toString().trim().isNotEmpty == true ||
                partnerVehicle['vehicle_name']?.toString().trim().isNotEmpty ==
                    true)) {
          booking['vehicles'] = _normalizePartnerVehicle(partnerVehicle);
          booking['is_partner_vehicle'] = true;
        } else {
          final id = booking['partner_vehicle_id']?.toString().trim() ??
              booking['vehicle_id']?.toString().trim();
          if (id != null && id.isNotEmpty) {
            missingVehicleIds.add(id);
          }
        }
      }

      // Check missing renter
      final hasRenter = (booking['users'] is Map && (booking['users'] as Map).isNotEmpty) ||
          (booking['renter'] is Map && (booking['renter'] as Map).isNotEmpty);
      if (!hasRenter) {
        final rId = booking['renter_id']?.toString().trim();
        if (rId != null && rId.isNotEmpty) {
          missingRenterIds.add(rId);
        }
      }

      // Check missing driver
      final hasDriver = booking['driver'] is Map && (booking['driver'] as Map).isNotEmpty;
      if (!hasDriver) {
        final dId = booking['driver_id']?.toString().trim();
        if (dId != null && dId.isNotEmpty) {
          missingDriverIds.add(dId);
        }
      }
    }

    // 1. Hydrate vehicles from partner_vehicles and vehicles
    if (missingVehicleIds.isNotEmpty) {
      final partnerMap = <String, Map<String, dynamic>>{};
      final missingList = missingVehicleIds.toList();
      try {
        List pvRows = [];
        try {
          pvRows = await supabase
              .from('partner_vehicles')
              .select('''
                *,
                partners:partner_id (
                  id,
                  business_name,
                  business_phone,
                  business_address,
                  users:user_id (
                    id,
                    full_name,
                    email,
                    phone
                  )
                )
              ''')
              .inFilter('id', missingList);
        } catch (e) {
          pvRows = await supabase
              .from('partner_vehicles')
              .select('*')
              .inFilter('id', missingList);
        }

        try {
          final pvRowsByVid = await supabase
              .from('partner_vehicles')
              .select('*')
              .inFilter('vehicle_id', missingList);
          pvRows.addAll(pvRowsByVid);
        } catch (_) {}

        for (final row in List<Map<String, dynamic>>.from(pvRows)) {
          final id = row['id']?.toString();
          final vid = row['vehicle_id']?.toString();
          final normalized = _normalizePartnerVehicle(row);
          if (id != null && id.isNotEmpty) {
            partnerMap[id] = normalized;
          }
          if (vid != null && vid.isNotEmpty) {
            partnerMap[vid] = normalized;
          }
        }
      } catch (e) {
        debugPrint('Error fetching missing partner_vehicles for bookings: $e');
      }

      if (partnerMap.isNotEmpty) {
        try {
          final pImages = await supabase
              .from('vehicle_images')
              .select('partner_vehicle_id, image_url, display_order')
              .inFilter('partner_vehicle_id', partnerMap.keys.toList())
              .order('display_order', ascending: true);

          for (final img in List<Map<String, dynamic>>.from(pImages)) {
            final vId = img['partner_vehicle_id']?.toString();
            if (vId != null && partnerMap.containsKey(vId)) {
              final pv = partnerMap[vId]!;
              final currentImgs = List<Map<String, dynamic>>.from(
                pv['vehicle_images'] as List? ?? [],
              );
              currentImgs.add(img);
              pv['vehicle_images'] = currentImgs;
              if (pv['image_url'] == null ||
                  pv['image_url'].toString().isEmpty) {
                pv['image_url'] = img['image_url'];
              }
            }
          }
        } catch (imgErr) {
          debugPrint('Error fetching vehicle_images for partner cars: $imgErr');
        }
      }

      final remainingIds = missingVehicleIds
          .where((id) => !partnerMap.containsKey(id))
          .toList();
      final standardMap = <String, Map<String, dynamic>>{};
      if (remainingIds.isNotEmpty) {
        try {
          final vRows = await supabase
              .from('vehicles')
              .select(
                '*, vehicle_images(image_url, display_order), owner:owner_id(id, full_name, role, email, phone)',
              )
              .inFilter('id', remainingIds);
          for (final row in List<Map<String, dynamic>>.from(vRows)) {
            final id = row['id']?.toString();
            if (id != null && id.isNotEmpty) {
              standardMap[id] = Map<String, dynamic>.from(row);
            }
          }
        } catch (e) {
          debugPrint('Error fetching missing standard vehicles: $e');
        }
      }

      for (final booking in bookings) {
        final vehicle = booking['vehicles'];
        final brand = vehicle is Map ? vehicle['brand']?.toString().trim() ?? '' : '';
        final model = vehicle is Map ? vehicle['model']?.toString().trim() ?? '' : '';
        final vName = vehicle is Map ? vehicle['vehicle_name']?.toString().trim() ?? '' : '';
        final hasValidVehicle = vehicle is Map<String, dynamic> &&
            (brand.isNotEmpty ||
                model.isNotEmpty ||
                (vName.isNotEmpty &&
                    vName.toLowerCase() != 'partner vehicle' &&
                    vName.toLowerCase() != 'unknown vehicle' &&
                    vName.toLowerCase() != 'vehicle'));

        if (!hasValidVehicle) {
          final pvid = booking['partner_vehicle_id']?.toString().trim();
          final vid = booking['vehicle_id']?.toString().trim();
          final id = (pvid != null && pvid.isNotEmpty) ? pvid : vid;
          if (id != null && id.isNotEmpty) {
            if (partnerMap.containsKey(id)) {
              booking['vehicles'] = partnerMap[id];
              booking['is_partner_vehicle'] = true;
            } else if (vid != null && partnerMap.containsKey(vid)) {
              booking['vehicles'] = partnerMap[vid];
              booking['is_partner_vehicle'] = true;
            } else if (standardMap.containsKey(id)) {
              booking['vehicles'] = standardMap[id];
            } else if (vid != null && standardMap.containsKey(vid)) {
              booking['vehicles'] = standardMap[vid];
            }
          }
        }
      }
    }

    // 2. Hydrate missing renters
    if (missingRenterIds.isNotEmpty) {
      final renterMap = <String, Map<String, dynamic>>{};
      try {
        final rRows = await supabase
            .from('users')
            .select('id, full_name, email, phone, role, avatar_url, profile_picture_url, location, latitude, longitude, id_verified, verification_status')
            .inFilter('id', missingRenterIds.toList());
        for (final r in List<Map<String, dynamic>>.from(rRows)) {
          final id = r['id']?.toString();
          if (id != null && id.isNotEmpty) {
            renterMap[id] = Map<String, dynamic>.from(r);
          }
        }
      } catch (e) {
        debugPrint('Error hydrating renters for bookings: $e');
      }

      for (final booking in bookings) {
        final rId = booking['renter_id']?.toString().trim();
        if (rId != null && renterMap.containsKey(rId)) {
          booking['users'] ??= renterMap[rId];
          booking['renter'] ??= renterMap[rId];
        }
      }
    }

    // 3. Hydrate missing drivers
    if (missingDriverIds.isNotEmpty) {
      final driverMap = <String, Map<String, dynamic>>{};
      try {
        final dRows = await supabase
            .from('users')
            .select('id, full_name, email, phone, avatar_url, profile_picture_url')
            .inFilter('id', missingDriverIds.toList());
        for (final d in List<Map<String, dynamic>>.from(dRows)) {
          final id = d['id']?.toString();
          if (id != null && id.isNotEmpty) {
            final userObj = Map<String, dynamic>.from(d);
            driverMap[id] = {
              'id': id,
              'user_id': id,
              'users': userObj,
              'user': userObj,
              'full_name': userObj['full_name'],
              'email': userObj['email'],
              'phone': userObj['phone'],
            };
          }
        }
      } catch (e) {
        debugPrint('Error hydrating drivers for bookings: $e');
      }

      for (final booking in bookings) {
        final dId = booking['driver_id']?.toString().trim();
        if (dId != null && driverMap.containsKey(dId)) {
          booking['driver'] ??= driverMap[dId];
          booking['drivers'] ??= driverMap[dId];
        }
      }
    }

    // 4. Normalize vehicle image and vehicle_name
    for (final booking in bookings) {
      final v = booking['vehicles'];
      if (v is Map<String, dynamic>) {
        final vMap = Map<String, dynamic>.from(v);
        if (vMap['image_url'] == null ||
            vMap['image_url'].toString().trim().isEmpty) {
          final images = vMap['vehicle_images'] as List?;
          if (images != null && images.isNotEmpty) {
            final firstImg = images.first;
            if (firstImg is Map) {
              vMap['image_url'] = firstImg['image_url'];
            }
          }
        }
        if (vMap['vehicle_name'] == null ||
            vMap['vehicle_name'].toString().trim().isEmpty) {
          final b = vMap['brand']?.toString().trim() ?? '';
          final m = vMap['model']?.toString().trim() ?? '';
          final combo = '$b $m'.trim();
          if (combo.isNotEmpty) {
            vMap['vehicle_name'] = combo;
          }
        }
        booking['vehicles'] = vMap;
        if (booking['vehicle_name'] == null ||
            booking['vehicle_name'].toString().trim().isEmpty) {
          booking['vehicle_name'] = vMap['vehicle_name'];
        }
      }
    }

    return bookings;
  }

  // Get bookings for a renter
  // Note: bookings use renter_id which references users.id
  Future<List<Map<String, dynamic>>> getRenterBookings(String userId) async {
    try {
      debugPrint('Fetching bookings for renter: $userId');

      List<Map<String, dynamic>> rawBookings = [];
      try {
        final response = await supabase
            .from('bookings')
            .select('*')
            .eq('renter_id', userId)
            .order('created_at', ascending: false)
            .limit(100);
        rawBookings = List<Map<String, dynamic>>.from(response);
      } catch (e) {
        debugPrint('Database error fetching renter bookings: $e');
      }

      debugPrint('Fetched ${rawBookings.length} bookings for renter $userId');
      return await hydrateBookingVehicles(rawBookings);
    } catch (e) {
      debugPrint('Unexpected error fetching renter bookings: $e');
      return [];
    }
  }

  // Get booking by ID
  Future<Map<String, dynamic>?> getBookingById(String bookingId) async {
    try {
      debugPrint('Fetching booking: $bookingId');

      final response = await supabase
          .from('bookings')
          .select('*')
          .eq('id', bookingId)
          .maybeSingle();

      debugPrint('Booking fetched: ${response != null}');
      if (response == null) return null;

      final booking = Map<String, dynamic>.from(response);
      final hydrated = await hydrateBookingVehicles([booking]);
      return hydrated.isNotEmpty ? hydrated.first : booking;
    } catch (e) {
      debugPrint('Database error fetching booking: $e');
      return null;
    }
  }

  // Create a new booking
  Future<Map<String, dynamic>> createBooking({
    required String renterId,
    required String vehicleId,
    required DateTime startAt,
    required DateTime endAt,
    required double totalPrice,
    double? rentalSubtotal,
    double? discountAmount,
    String? appliedVoucher,
    double? deliveryDistanceKm,
    double? deliveryRatePerKm,
    double? deliveryFee,
    bool withDriver = false,
    double? driverFee,
    String? pickupLocation,
    String? dropoffLocation,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    DateTime? rentalTermsAcceptedAt,
    String? rentalTermsSnapshot,
    double? securityDeposit,
    double? reservationFeeAmount,
    String? reservationPaymentReference,
    String? reservationPaymentProofUrl,
    String? reservationPaymentMethod,
    String? reservationPaymentType,
    String? reservationPaymentSenderPhone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelationship,
    String? renterSignatureText,
    String? renterSignatureUrl,
    String? renterValidIdUrl,
    String? renterSelfieUrl,
    String? coTravelerName,
    String? coTravelerPhone,
    String? coTravelerLicense,
    String? coTravelerSignatureText,
    String? coTravelerSignatureUrl,
    String? coTravelerValidIdUrl,
    String? coTravelerSelfieUrl,
  }) async {
    try {
      debugPrint('Creating booking for renter: $renterId, vehicle: $vehicleId');

      if (renterSelfieUrl == null || renterSelfieUrl.trim().isEmpty) {
        throw Exception('A clear renter selfie is required before booking');
      }

      if (renterSignatureUrl == null || renterSignatureUrl.trim().isEmpty) {
        throw Exception('A drawn digital signature is required before booking');
      }

      if (renterValidIdUrl == null || renterValidIdUrl.trim().isEmpty) {
        throw Exception('A valid ID photo is required before booking');
      }

      final coTravelerFields = [
        coTravelerName?.trim() ?? '',
        coTravelerPhone?.trim() ?? '',
        coTravelerLicense?.trim() ?? '',
      ];
      if (coTravelerFields.any((value) => value.isEmpty)) {
        throw Exception(
          'Co-traveler name, phone number, and license number are required',
        );
      }

      if (coTravelerSignatureUrl == null ||
          coTravelerSignatureUrl.trim().isEmpty ||
          coTravelerValidIdUrl == null ||
          coTravelerValidIdUrl.trim().isEmpty ||
          coTravelerSelfieUrl == null ||
          coTravelerSelfieUrl.trim().isEmpty) {
        throw Exception(
          'Co-traveler signature, valid ID, and selfie are required',
        );
      }

      final cleanDestination = dropoffLocation?.trim() ?? '';
      if (cleanDestination.isEmpty) {
        throw Exception('Please select a trip destination before booking');
      }

      // Fetch vehicle record (checking both standard vehicles and partner_vehicles tables)
      Map<String, dynamic>? vehicleState;
      String? plateNumber;
      String? partnerId;
      String? ownerId;
      bool isPartnerVehicle = false;

      try {
        vehicleState = await supabase
            .from('vehicles')
            .select('*')
            .eq('id', vehicleId)
            .maybeSingle();
        if (vehicleState != null) {
          plateNumber = vehicleState['plate_number']?.toString();
          ownerId = vehicleState['owner_id']?.toString();
          final rawPartnerId = vehicleState['partner_id']?.toString();
          if (rawPartnerId != null && rawPartnerId.isNotEmpty) {
            partnerId = rawPartnerId;
          }
          if (vehicleState['owner_role']?.toString().toLowerCase() == 'partner') {
            isPartnerVehicle = true;
          }
        }
      } catch (e) {
        debugPrint('Could not query vehicles table: $e');
      }

      // Check partner_vehicles table if not found in vehicles table or to enrich partner vehicle state
      if (vehicleState == null) {
        try {
          final partnerState = await supabase
              .from('partner_vehicles')
              .select('*')
              .eq('id', vehicleId)
              .maybeSingle();

          if (partnerState != null) {
            vehicleState = Map<String, dynamic>.from(partnerState);
            vehicleState['owner_role'] = 'partner';
            isPartnerVehicle = true;
            partnerId = partnerState['partner_id']?.toString() ?? partnerId;
            ownerId ??= partnerId;
            plateNumber ??= partnerState['plate_number']?.toString();
          }
        } catch (e) {
          debugPrint('Could not query partner_vehicles table: $e');
        }
      }

      if (isPartnerVehicle || (plateNumber != null && plateNumber.isNotEmpty)) {
        try {
          final pvByPlate = await supabase
              .from('partner_vehicles')
              .select('id,partner_id,vehicle_id')
              .or('id.eq.$vehicleId${plateNumber != null && plateNumber.isNotEmpty ? ',plate_number.eq.$plateNumber' : ''}')
              .maybeSingle();
          if (pvByPlate != null) {
            isPartnerVehicle = true;
            partnerId ??= pvByPlate['partner_id']?.toString();
            ownerId ??= partnerId;
          }
        } catch (_) {}
      }

      final (
        restriction,
        overlappingBookings,
      ) = await (
        UserRestrictionService().getUserRestriction(renterId),
        supabase
            .from('bookings')
            .select('id,start_at,end_at,start_date,end_date,status')
            .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId'),
      ).wait;

      if (restriction.isBlocked || restriction.isAccountRestricted) {
        throw Exception(
          'This renter account is restricted and cannot book vehicles right now',
        );
      }

      if (vehicleState == null) {
        throw Exception('This vehicle is currently unavailable for booking');
      }

      final vehicleStatus =
          vehicleState['status']?.toString().trim().toLowerCase() ?? '';
      final appStatus =
          vehicleState['application_status']?.toString().trim().toLowerCase() ?? '';

      final bool vehicleCanBeBooked;
      if (isPartnerVehicle) {
        const blockedStatuses = {
          'inactive',
          'archived',
          'deleted',
          'rejected',
          'disabled',
          'sold',
        };
        final isBlocked = blockedStatuses.contains(vehicleStatus) ||
            blockedStatuses.contains(appStatus);
        final isAvailableNotFalse = vehicleState['is_available'] != false;
        final isApprovedOrPosted = vehicleState['is_posted'] == true ||
            vehicleStatus == 'available' ||
            vehicleStatus == 'approved' ||
            vehicleStatus == 'active' ||
            appStatus == 'approved';
        vehicleCanBeBooked =
            !isBlocked && isAvailableNotFalse && isApprovedOrPosted;
      } else {
        const blockedStatuses = {
          'inactive',
          'archived',
          'deleted',
          'rejected',
          'disabled',
          'sold',
        };
        final isBlocked = blockedStatuses.contains(vehicleStatus);
        final isAvailableNotFalse = vehicleState['is_available'] != false;
        final isPostedNotFalse = vehicleState['is_posted'] != false;
        vehicleCanBeBooked =
            !isBlocked && isAvailableNotFalse && isPostedNotFalse;
      }

      if (!vehicleCanBeBooked) {
        throw Exception('This vehicle is currently unavailable for booking');
      }

      if (isPartnerVehicle) {
        final approvedAndListed = await VehicleService().isVehicleBookable(
          vehicleId,
        );
        if (!approvedAndListed) {
          throw Exception(
            'This partner vehicle is not approved for rental anymore',
          );
        }
      }

      for (final b in List<Map<String, dynamic>>.from(overlappingBookings)) {
        final status = b['status']?.toString();
        if (!_isBlockingStatus(status)) continue;
        final interval = _bookingInterval(b);
        if (interval == null) continue;
        final (existingStart, existingEnd) = interval;
        if (startAt.isBefore(existingEnd) && endAt.isAfter(existingStart)) {
          throw Exception(
            'Selected dates or hours overlap with an existing or pending booking.',
          );
        }
      }

      double? effectiveDriverFee = driverFee;
      if (withDriver && (effectiveDriverFee == null || effectiveDriverFee <= 0)) {
        final minutes = endAt.difference(startAt).inMinutes;
        final days = minutes <= 0 ? 1 : (minutes / Duration.minutesPerDay).ceil();
        effectiveDriverFee = (days <= 0 ? 1 : days) * PricingPolicy.driverDailyRate;
      }

      final bookingPayload = <String, dynamic>{
        'renter_id': renterId,
        'vehicle_id': vehicleId,
        if (isPartnerVehicle) 'partner_vehicle_id': vehicleId,
        if (isPartnerVehicle && partnerId != null && partnerId.isNotEmpty)
          'partner_id': partnerId,
        if (ownerId != null && ownerId.isNotEmpty) 'owner_id': ownerId,
        'start_at': startAt.toIso8601String(),
        'end_at': endAt.toIso8601String(),
        // Keep legacy fields for existing screens/queries (date-only intent).
        'start_date': DateTime(
          startAt.toLocal().year,
          startAt.toLocal().month,
          startAt.toLocal().day,
        ).toIso8601String(),
        'end_date': DateTime(
          endAt.toLocal().year,
          endAt.toLocal().month,
          endAt.toLocal().day,
        ).toIso8601String(),
        'total_price': totalPrice,
        'rental_subtotal': rentalSubtotal ?? totalPrice,
        if (discountAmount != null && discountAmount > 0)
          'discount_amount': discountAmount,
        if (appliedVoucher != null && appliedVoucher.isNotEmpty)
          'applied_voucher': appliedVoucher,
        if (deliveryDistanceKm != null)
          'delivery_distance_km': deliveryDistanceKm,
        if (deliveryRatePerKm != null)
          'delivery_rate_per_km': deliveryRatePerKm,
        'delivery_fee': deliveryFee ?? 0,
        'with_driver': withDriver,
        if (effectiveDriverFee != null && effectiveDriverFee > 0)
          'driver_fee': effectiveDriverFee,
        'pickup_location': pickupLocation,
        'dropoff_location': cleanDestination,
        if (pickupLatitude != null) 'pickup_latitude': pickupLatitude,
        if (pickupLongitude != null) 'pickup_longitude': pickupLongitude,
        if (dropoffLatitude != null) 'dropoff_latitude': dropoffLatitude,
        if (dropoffLongitude != null) 'dropoff_longitude': dropoffLongitude,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      if (securityDeposit != null) {
        bookingPayload['security_deposit'] = securityDeposit;
      }

      if (reservationFeeAmount != null) {
        bookingPayload['reservation_fee_amount'] = reservationFeeAmount;
      }

      final cleanPaymentType = reservationPaymentType?.trim().toLowerCase();
      if (cleanPaymentType != null && cleanPaymentType.isNotEmpty) {
        bookingPayload['reservation_payment_type'] = cleanPaymentType;
        bookingPayload['reservation_payment_covers_total'] =
            cleanPaymentType == 'full_payment';
      }

      if (reservationPaymentReference != null &&
          reservationPaymentReference.trim().isNotEmpty) {
        bookingPayload['reservation_payment_reference'] =
            reservationPaymentReference.trim();
        bookingPayload['reservation_payment_status'] = 'pending_review';
        bookingPayload['reservation_payment_submitted_at'] = DateTime.now()
            .toIso8601String();
      }

      if (reservationPaymentProofUrl != null &&
          reservationPaymentProofUrl.trim().isNotEmpty) {
        bookingPayload['reservation_payment_proof_url'] =
            reservationPaymentProofUrl.trim();
      }

      if (reservationPaymentMethod != null &&
          reservationPaymentMethod.trim().isNotEmpty) {
        bookingPayload['reservation_payment_method'] = reservationPaymentMethod
            .trim();
      }

      if (reservationPaymentSenderPhone != null &&
          reservationPaymentSenderPhone.trim().isNotEmpty) {
        final cleanSenderPhone = reservationPaymentSenderPhone.trim();
        bookingPayload['reservation_payment_sender_phone'] = cleanSenderPhone;
      }

      if (rentalTermsAcceptedAt != null) {
        bookingPayload['rental_terms_accepted_at'] = rentalTermsAcceptedAt
            .toIso8601String();
      }

      if (rentalTermsSnapshot != null) {
        bookingPayload['rental_terms_snapshot'] = rentalTermsSnapshot;
      }

      if (emergencyContactName != null &&
          emergencyContactName.trim().isNotEmpty) {
        bookingPayload['emergency_contact_name'] = emergencyContactName.trim();
      }

      if (emergencyContactPhone != null &&
          emergencyContactPhone.trim().isNotEmpty) {
        bookingPayload['emergency_contact_phone'] = emergencyContactPhone
            .trim();
      }

      if (emergencyContactRelationship != null &&
          emergencyContactRelationship.trim().isNotEmpty) {
        bookingPayload['emergency_contact_relationship'] =
            emergencyContactRelationship.trim();
      }

      if (renterSignatureText != null &&
          renterSignatureText.trim().isNotEmpty) {
        bookingPayload['renter_signature_text'] = renterSignatureText.trim();
      }

      bookingPayload['renter_signature_url'] = renterSignatureUrl.trim();

      bookingPayload['renter_valid_id_url'] = renterValidIdUrl.trim();

      bookingPayload['renter_selfie_url'] = renterSelfieUrl.trim();

      if (coTravelerName != null && coTravelerName.trim().isNotEmpty) {
        bookingPayload['co_traveler_name'] = coTravelerName.trim();
      }

      if (coTravelerPhone != null && coTravelerPhone.trim().isNotEmpty) {
        bookingPayload['co_traveler_phone'] = coTravelerPhone.trim();
      }

      if (coTravelerLicense != null && coTravelerLicense.trim().isNotEmpty) {
        bookingPayload['co_traveler_license'] = coTravelerLicense.trim();
      }

      if (coTravelerSignatureText != null &&
          coTravelerSignatureText.trim().isNotEmpty) {
        bookingPayload['co_traveler_signature_text'] = coTravelerSignatureText
            .trim();
      }

      bookingPayload['co_traveler_signature_url'] = coTravelerSignatureUrl
          .trim();
      bookingPayload['co_traveler_valid_id_url'] = coTravelerValidIdUrl.trim();
      bookingPayload['co_traveler_selfie_url'] = coTravelerSelfieUrl.trim();

      Map<String, dynamic> response;
      var currentPayload = Map<String, dynamic>.from(bookingPayload);
      int retryCount = 0;

      while (true) {
        try {
          response = await supabase
              .from('bookings')
              .insert(currentPayload)
              .select()
              .single();
          break;
        } on PostgrestException catch (e) {
          final msg = e.message.toLowerCase();
          final details = (e.details?.toString() ?? '').toLowerCase();
          final isFkError = e.code == '23503' ||
              msg.contains('foreign key') ||
              details.contains('foreign key') ||
              msg.contains('fk_') ||
              (msg.contains('vehicle_id') && msg.contains('violates')) ||
              (msg.contains('partner_vehicle_id') && msg.contains('violates')) ||
              (msg.contains('owner_id') && msg.contains('violates')) ||
              (msg.contains('partner_id') && msg.contains('violates'));

          if (isFkError) {
            retryCount++;
            if (retryCount > 8) rethrow;

            if (isPartnerVehicle &&
                currentPayload.containsKey('vehicle_id') &&
                currentPayload.containsKey('partner_vehicle_id')) {
              debugPrint(
                'Foreign key constraint on vehicle_id for partner vehicle ($e). Removing vehicle_id and retrying with partner_vehicle_id...',
              );
              currentPayload.remove('vehicle_id');
              continue;
            }

            if (currentPayload.containsKey('owner_id') &&
                (msg.contains('owner_id') || details.contains('owner_id') || !isPartnerVehicle)) {
              debugPrint(
                'Foreign key constraint on owner_id ($e). Removing owner_id and retrying...',
              );
              currentPayload.remove('owner_id');
              continue;
            }

            if (currentPayload.containsKey('partner_id') &&
                (msg.contains('partner_id') || details.contains('partner_id') || !isPartnerVehicle)) {
              debugPrint(
                'Foreign key constraint on partner_id ($e). Removing partner_id and retrying...',
              );
              currentPayload.remove('partner_id');
              continue;
            }
          }

          if (e.code == 'PGRST204' ||
              msg.contains('column') ||
              msg.contains('schema cache')) {
            retryCount++;
            if (retryCount > 8) {
              rethrow;
            }

            debugPrint(
              'Schema column mismatch when inserting booking ($e). Dynamically stripping missing column and retrying...',
            );

            // Extract the missing column name from the error message
            final match = RegExp(r"'(?:public\.)?(?:bookings\.)?([a-zA-Z0-9_]+)'\s*column|column\s*'(?:public\.)?(?:bookings\.)?([a-zA-Z0-9_]+)'|find the '([a-zA-Z0-9_]+)' column", caseSensitive: false).firstMatch(e.message);
            final missingCol = match?.group(1) ?? match?.group(2) ?? match?.group(3);

            if (missingCol != null && currentPayload.containsKey(missingCol)) {
              final val = currentPayload.remove(missingCol);
              debugPrint('Stripped missing column: $missingCol (value: $val)');
              if (val != null && val.toString().isNotEmpty) {
                final note = '[$missingCol: $val]';
                final existingNotes = currentPayload['operator_notes']?.toString() ?? '';
                currentPayload['operator_notes'] = existingNotes.isNotEmpty
                    ? '$existingNotes | $note'
                    : note;
              }
            } else {
              // Fallback stripping of newer optional columns
              final optionalCols = [
                'reservation_payment_sender_phone',
                'reservation_payment_type',
                'reservation_payment_covers_total',
                'reservation_payment_reference',
                'reservation_payment_proof_url',
                'reservation_payment_method',
                'reservation_payment_status',
                'reservation_payment_submitted_at',
                'applied_voucher',
                'discount_amount',
                'rental_terms_snapshot',
                'refund_phone',
              ];
              bool removedAny = false;
              for (final col in optionalCols) {
                if (currentPayload.containsKey(col)) {
                  currentPayload.remove(col);
                  removedAny = true;
                  break;
                }
              }
              if (!removedAny) {
                rethrow;
              }
            }
          } else if (e.message.toLowerCase().contains('unavailable')) {
            throw Exception('Selected dates are unavailable for bookings');
          } else {
            rethrow;
          }
        }
      }

      final bookingId = response['id']?.toString();
      if (bookingId != null && bookingId.isNotEmpty) {
        unawaited(
          Future<void>(() async {
            final createdBooking = await getBookingById(bookingId) ?? response;
            final vehicle = createdBooking['vehicles'] as Map<String, dynamic>?;
            final vehicleTitle = _vehicleTitle(vehicle);
            final renter = createdBooking['users'] as Map<String, dynamic>?;
            final renterName =
                renter?['full_name']?.toString().trim().isNotEmpty == true
                ? renter!['full_name'].toString().trim()
                : 'A renter';
            await NotificationService().notifyOperatorsNewBooking(
              bookingId: bookingId,
              vehicleTitle: vehicleTitle,
              renterName: renterName,
              withDriver: withDriver,
              partnerId: partnerId ?? createdBooking['partner_id']?.toString() ?? vehicle?['partner_id']?.toString(),
              ownerId: ownerId ?? vehicle?['owner_id']?.toString(),
              vehicleId: vehicleId,
            );
          }).timeout(const Duration(seconds: 8)).catchError((e) {
            debugPrint(
              'Booking created but operator notification timed out/failed: $e',
            );
          }),
        );
      }

      debugPrint('Booking created successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating booking: ${e.message}');
      if (e.message.toLowerCase().contains('unavailable')) {
        throw Exception('Selected dates are unavailable for bookings');
      }
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error creating booking: $e');
      rethrow;
    }
  }

  // Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      debugPrint('Updating booking $bookingId status to: $status');
      final normalizedStatus = status.trim().toLowerCase();

      // Get booking details before updating
      final booking = await getBookingById(bookingId);
      if (booking == null) {
        throw Exception('Booking not found: $bookingId');
      }

      if (normalizedStatus == 'cancelled') {
        final currentStatus =
            booking['status']?.toString().trim().toLowerCase() ?? '';
        const cancellableStatuses = {'pending', 'approved', 'confirmed'};
        if (!cancellableStatuses.contains(currentStatus)) {
          throw Exception(
            'Only pending, approved, or confirmed bookings can be cancelled before the trip starts',
          );
        }

        final createdAtStr = booking['created_at']?.toString();
        final createdAt = createdAtStr == null
            ? null
            : DateTime.tryParse(createdAtStr);
        if (createdAt == null) {
          throw Exception('Booking cancellation window could not be verified');
        }

        if (DateTime.now().isAfter(createdAt.add(const Duration(hours: 24)))) {
          throw Exception(
            'Cancellation window has passed. Bookings can only be cancelled within 24 hours after request.',
          );
        }
      }

      await safeUpdateBooking(bookingId, {
        'status': normalizedStatus,
        if (normalizedStatus == 'cancelled')
          'refund_status': 'refund_needed',
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Booking status updated');

      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final vehicleTitle = vehicle != null
          ? '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
          : 'Your rental vehicle';

      // ✅ Send notifications based on status change
      if (normalizedStatus == 'approved') {
        // Notify renter of approval
        final renterId = booking['renter_id']?.toString();
        if (renterId != null && renterId.isNotEmpty) {
          await NotificationService().notifyBookingApproved(
            renterId: renterId,
            bookingId: bookingId,
            vehicleTitle: vehicleTitle,
          );
        }
      } else if (normalizedStatus == 'rejected') {
        // Notify renter of rejection
        if (booking['renter_id'] != null) {
          try {
            await supabase.from('notifications').insert({
              'user_id': booking['renter_id'],
              'title': '❌ Booking Rejected',
              'message': 'Your booking for $vehicleTitle has been rejected.',
              'type': 'booking',
              'data': {'booking_id': bookingId, 'status': normalizedStatus},
              'created_at': DateTime.now().toIso8601String(),
            });
            debugPrint('✅ Rejection notification sent to renter');
          } catch (e) {
            debugPrint('⚠️ Error sending rejection notification: $e');
          }
        }
      } else if (normalizedStatus == 'cancelled') {
        final reservationReference = booking['reservation_payment_reference']
            ?.toString()
            .trim();
        final hasReservationPayment =
            reservationReference != null && reservationReference.isNotEmpty;

        if (hasReservationPayment) {
          try {
            final operators = await supabase
                .from('users')
                .select('id')
                .eq('role', 'operator');

            final notifications = List<Map<String, dynamic>>.from(operators)
                .map(
                  (operator) => {
                    'user_id': operator['id'],
                    'title': 'Refund Needed for Cancelled Booking',
                    'message':
                        '$vehicleTitle was cancelled after reservation payment. Reference: $reservationReference. Please review refund processing.',
                    'type': 'booking_refund',
                    'data': {
                      'booking_id': bookingId,
                      'status': normalizedStatus,
                      'reservation_payment_reference': reservationReference,
                      'refund_status': 'refund_needed',
                    },
                    'created_at': DateTime.now().toIso8601String(),
                  },
                )
                .toList();

            if (notifications.isNotEmpty) {
              await supabase.from('notifications').insert(notifications);
            }
          } catch (e) {
            debugPrint('Error notifying operators for refund: $e');
          }
        }
        // 🔴 Notify operator/owner when renter cancels (within 24 hours)
        if (vehicle?['owner_id'] != null) {
          try {
            final renter = booking['users'] as Map<String, dynamic>?;
            final renterName = renter?['full_name'] ?? 'Renter';

            await supabase.from('notifications').insert({
              'user_id': vehicle?['owner_id'],
              'title': '🔴 Booking Cancelled by Renter',
              'message':
                  '$renterName has cancelled their booking for $vehicleTitle.',
              'type': 'booking',
              'data': {
                'booking_id': bookingId,
                'status': normalizedStatus,
                'cancelled_by': 'renter',
              },
              'created_at': DateTime.now().toIso8601String(),
            });

            debugPrint('✅ Cancellation notification sent to operator');
          } catch (e) {
            debugPrint(
              '⚠️ Error sending cancellation notification to operator: $e',
            );
          }
        }
      }

      const conversationStatuses = {
        'approved',
        'confirmed',
        'active',
        'ongoing',
      };
      const terminalStatuses = {
        'completed',
        'successful',
        'cancelled',
        'canceled',
        'rejected',
      };

      if (conversationStatuses.contains(normalizedStatus)) {
        try {
          final updatedBooking = await getBookingById(bookingId) ?? booking;
          if (isEligibleForBookingChat(updatedBooking)) {
            await _ensureBookingGroupChatAndSummary(
              booking: updatedBooking,
              vehicleTitle: vehicleTitle,
              summaryTitle: 'Booking Confirmed',
            );
          }
        } catch (e) {
          debugPrint('Error creating booking group chat summary: $e');
        }
      } else if (terminalStatuses.contains(normalizedStatus)) {
        try {
          await ChatService().closeConversation(bookingId);
        } catch (e) {
          debugPrint('Error closing booking group chat: $e');
        }
      }
    } on PostgrestException catch (e) {
      debugPrint('Database error updating booking status: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating booking status: $e');
      rethrow;
    }
  }

  Map<String, dynamic> getTripCompletionState(Map<String, dynamic> booking) {
    final vehicleValue = booking['vehicles'] ?? booking['vehicle'];
    final vehicle = vehicleValue is Map<String, dynamic>
        ? Map<String, dynamic>.from(vehicleValue)
        : <String, dynamic>{};
    final owner = vehicle['owner'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(vehicle['owner'])
        : <String, dynamic>{};
    final rawStatus =
        (booking['rawStatus']?.toString() ??
                booking['status']?.toString() ??
                '')
            .toLowerCase();
    final hasDriver =
        booking['with_driver'] == true ||
        booking['withDriver'] == true ||
        (booking['driver_id']?.toString().trim().isNotEmpty == true) ||
        booking['driver'] != null;
    final ownerRole = (vehicle['owner_role'] ?? owner['role'])
        ?.toString()
        .trim()
        .toLowerCase();
    final ownerId = (vehicle['owner_id'] ?? owner['id'])?.toString().trim();
    final operatorId =
        booking['operator_id']?.toString().trim().isNotEmpty == true
        ? booking['operator_id']?.toString().trim()
        : vehicle['operator_id']?.toString().trim();
    final requiresPartner =
        ownerRole == 'partner' ||
        (ownerId != null &&
            ownerId.isNotEmpty &&
            operatorId != null &&
            operatorId.isNotEmpty &&
            ownerId != operatorId);

    final operatorConfirmed = _hasTripConfirmation(
      booking['operator_trip_confirmed_at'],
    );
    final partnerConfirmed = _hasTripConfirmation(
      booking['partner_trip_confirmed_at'],
    );
    final driverConfirmed = _hasTripConfirmation(
      booking['driver_trip_confirmed_at'],
    );
    final renterConfirmed = _hasTripConfirmation(
      booking['renter_trip_confirmed_at'],
    );

    final completionStage =
        booking['completion_stage']?.toString().trim().toLowerCase() ??
        'not_started';
    final finalPaymentStatus =
        booking['final_payment_status']?.toString().trim().toLowerCase() ??
        'pending';
    final firstReviewerRole = requiresPartner ? 'partner' : 'operator';
    final pendingRoles = <String>[
      if (requiresPartner && !partnerConfirmed) 'partner',
      if (!requiresPartner && !operatorConfirmed) 'operator',
      if (hasDriver && !driverConfirmed) 'driver',
      if (!renterConfirmed) 'renter',
    ];

    return {
      'status': rawStatus,
      'completionStage': completionStage,
      'finalPaymentStatus': finalPaymentStatus,
      'isFullyPaid': finalPaymentStatus == 'paid',
      'firstReviewerRole': firstReviewerRole,
      'hasDriver': hasDriver,
      'requiresPartner': requiresPartner,
      'operatorConfirmed': operatorConfirmed,
      'partnerConfirmed': partnerConfirmed,
      'driverConfirmed': driverConfirmed,
      'renterConfirmed': renterConfirmed,
      'pendingRoles': pendingRoles,
      'allNonRenterConfirmed':
          (requiresPartner ? partnerConfirmed : operatorConfirmed) &&
          (!hasDriver || driverConfirmed),
      'renterCanConfirm':
          completionStage == 'renter_rating' && !renterConfirmed,
      'canConfirmPayment': completionStage == 'awaiting_payment',
      'canRate': <String, bool>{
        'operator':
            completionStage == 'operator_rating' ||
            (operatorConfirmed == false &&
                (rawStatus == 'completed' ||
                    rawStatus == 'returned' ||
                    rawStatus == 'ongoing')),
        'partner':
            completionStage == 'partner_rating' ||
            (partnerConfirmed == false &&
                (rawStatus == 'completed' || rawStatus == 'returned')),
        'driver':
            completionStage == 'driver_rating' ||
            (driverConfirmed == false &&
                (rawStatus == 'completed' || rawStatus == 'returned')),
        'renter':
            completionStage == 'renter_rating' ||
            (renterConfirmed == false &&
                (rawStatus == 'completed' ||
                    rawStatus == 'returned' ||
                    rawStatus == 'ongoing')),
      },
    };
  }

  /// Checks if a booking is 100% fully paid (no remaining rental balance).
  bool isBookingFullyPaid(Map<String, dynamic> booking) {
    // 1. Check final_payment_status
    final finalPaymentStatus = (booking['final_payment_status'] ??
            booking['finalPaymentStatus'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (finalPaymentStatus == 'paid' ||
        finalPaymentStatus == 'completed' ||
        finalPaymentStatus == 'waived' ||
        finalPaymentStatus == 'n/a' ||
        finalPaymentStatus == 'none' ||
        finalPaymentStatus == 'not_required' ||
        finalPaymentStatus == 'not_applicable') {
      return true;
    }

    // 2. Check overall payment_status
    final paymentStatus = (booking['payment_status'] ??
            booking['paymentStatus'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (paymentStatus == 'paid' ||
        paymentStatus == 'full_paid' ||
        paymentStatus == 'fully_paid' ||
        paymentStatus == 'paid_in_full' ||
        paymentStatus == 'completed') {
      return true;
    }

    // 3. Check reservation payment type / full upfront payment indicators
    final resType = (booking['reservation_payment_type'] ??
            booking['reservationPaymentType'] ??
            booking['payment_type'] ??
            booking['paymentType'] ??
            booking['payment_option'] ??
            booking['paymentOption'] ??
            booking['payment_mode'] ??
            booking['paymentMode'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final isFullType = resType == 'full' ||
        resType == 'full_payment' ||
        resType == 'full payment' ||
        resType == 'full_upfront' ||
        resType == 'upfront' ||
        resType == '100%' ||
        resType == '100';

    final isCoversTotal = booking['reservation_payment_covers_total'] == true ||
        booking['reservationPaymentCoversTotal'] == true ||
        booking['reservation_payment_covers_total']?.toString().toLowerCase() == 'true' ||
        booking['reservationPaymentCoversTotal']?.toString().toLowerCase() == 'true' ||
        booking['is_full_payment'] == true ||
        booking['is_full_payment']?.toString().toLowerCase() == 'true' ||
        booking['is_full_payment'] == 1 ||
        booking['is_full_payment']?.toString() == '1';

    if (isFullType || isCoversTotal) {
      final resStatus = (booking['reservation_payment_status'] ??
              booking['reservationPaymentStatus'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();
      if (resStatus != 'rejected' && resStatus != 'failed') {
        return true;
      }
    }

    // 4. Check explicit remaining_balance field
    final remainingBalance = (booking['remaining_balance'] as num?)?.toDouble() ??
        (booking['remainingBalance'] as num?)?.toDouble() ??
        (booking['balance'] as num?)?.toDouble();
    if (remainingBalance != null && remainingBalance <= 0.01) {
      return true;
    }

    // 5. Compare paid_amount / reservation_fee_amount vs total_price / total_cost
    final totalPrice = (booking['total_price'] as num?)?.toDouble() ??
        (booking['totalCost'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final paidAmount = (booking['paid_amount'] as num?)?.toDouble() ??
        (booking['paidAmount'] as num?)?.toDouble() ??
        (booking['reservation_fee_amount'] as num?)?.toDouble() ??
        (booking['reservationFeeAmount'] as num?)?.toDouble() ??
        (booking['reservation_fee'] as num?)?.toDouble() ??
        0.0;

    if (totalPrice > 0 && paidAmount >= (totalPrice - 1.0)) {
      return true;
    }

    return false;
  }

  /// Calculates the remaining unpaid balance for a booking.
  double getBookingRemainingBalance(Map<String, dynamic> booking) {
    if (isBookingFullyPaid(booking)) return 0.0;
    final totalPrice = (booking['total_price'] as num?)?.toDouble() ??
        (booking['totalCost'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final paidAmount = (booking['paid_amount'] as num?)?.toDouble() ??
        (booking['paidAmount'] as num?)?.toDouble() ??
        (booking['reservation_fee_amount'] as num?)?.toDouble() ??
        (booking['reservationFeeAmount'] as num?)?.toDouble() ??
        (booking['reservation_fee'] as num?)?.toDouble() ??
        0.0;
    final balance = totalPrice - paidAmount;
    return balance > 0.01 ? balance : 0.0;
  }

  /// Settles remaining balance before releasing vehicle keys and begins the trip.
  Future<void> settleReleasePayment({
    required String bookingId,
    required String actorId,
    required String actorRole,
    required String paymentMethod,
    String? paymentReference,
    String? proofUrl,
    String? operatorName,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    await supabase.from('bookings').update({
      'reservation_payment_covers_total': true,
      'reservation_payment_type': 'full_payment',
      'reservation_payment_status': 'verified',
      'final_payment_status': 'paid',
      'final_payment_method': paymentMethod,
      'final_payment_reference': paymentReference ?? 'DESK-SETTLED',
      if (proofUrl != null && proofUrl.isNotEmpty)
        'final_payment_proof_url': proofUrl,
      'final_payment_confirmed_at': now,
      'final_payment_confirmed_by': actorId,
      'updated_at': now,
    }).eq('id', bookingId);
  }

  /// Verify renter reservation payment proof (Operator action)
  Future<void> verifyRenterReservationPayment(
    String bookingId, {
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final operatorId = supabase.auth.currentUser?.id;

    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    await supabase.from('bookings').update({
      'reservation_payment_status': 'verified',
      'payment_verified': true,
      'payment_verified_at': now,
      if (operatorId != null && operatorId.isNotEmpty) 'payment_verified_by': operatorId,
      if (notes != null && notes.isNotEmpty) 'payment_verification_notes': notes,
      'updated_at': now,
    }).eq('id', bookingId);

    // Notify renter that payment was verified
    final renterId = booking['renter_id']?.toString();
    if (renterId != null && renterId.isNotEmpty) {
      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final vehicleTitle = _vehicleTitle(vehicle);
      unawaited(
        supabase.from('notifications').insert({
          'user_id': renterId,
          'title': '✅ Payment Verified',
          'message': 'Your payment for $vehicleTitle has been verified! Awaiting operator final booking confirmation.',
          'type': 'booking',
          'data': {'booking_id': bookingId, 'status': 'payment_verified'},
          'created_at': now,
        }).catchError((e) => debugPrint('Error notifying renter: $e')),
      );
    }
  }

  /// Settle refund for a cancelled/rejected booking (Operator action)
  Future<void> settleBookingRefund({
    required String bookingId,
    required double amount,
    required String method,
    required String reference,
    String? receiptUrl,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final operatorId = supabase.auth.currentUser?.id;

    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    await supabase.from('bookings').update({
      'refund_status': 'refunded',
      'refund_completed': true,
      'refund_amount': amount,
      'refund_method': method,
      'refund_ref': reference,
      if (receiptUrl != null && receiptUrl.isNotEmpty) 'refund_receipt_url': receiptUrl,
      if (notes != null && notes.isNotEmpty) 'refund_notes': notes,
      if (operatorId != null && operatorId.isNotEmpty) 'refunded_by': operatorId,
      'refunded_at': now,
      'updated_at': now,
    }).eq('id', bookingId);

    // Notify renter that refund is disbursed
    final renterId = booking['renter_id']?.toString();
    if (renterId != null && renterId.isNotEmpty) {
      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final vehicleTitle = _vehicleTitle(vehicle);
      unawaited(
        supabase.from('notifications').insert({
          'user_id': renterId,
          'title': '💸 Refund Disbursed',
          'message': 'Your refund of PHP ${amount.toStringAsFixed(2)} for $vehicleTitle has been disbursed ($method, Ref: $reference).',
          'type': 'booking_refund',
          'data': {
            'booking_id': bookingId,
            'refund_status': 'refunded',
            'refund_ref': reference,
            'amount': amount,
          },
          'created_at': now,
        }).catchError((e) => debugPrint('Error notifying renter of refund: $e')),
      );
    }
  }

  /// Confirms that the final rental balance and late-return charges have been
  /// settled. The responsible operator handles PSDC vehicles, while the
  /// vehicle owner handles partner vehicles.
  Future<Map<String, dynamic>> confirmFinalPayment({
    required String bookingId,
    required String actorId,
    required String actorRole,
  }) async {
    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    final state = getTripCompletionState(booking);
    final finalPaymentStatus = (booking['final_payment_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (finalPaymentStatus == 'paid' || state['isFullyPaid'] == true) {
      return booking;
    }

    final expectedRole = state['firstReviewerRole']?.toString() ?? 'operator';
    final normalizedRole = actorRole.trim().toLowerCase();
    if (normalizedRole != expectedRole &&
        normalizedRole != 'operator' &&
        normalizedRole != 'admin') {
      throw Exception(
        expectedRole == 'partner'
            ? 'Only the vehicle partner can confirm this final payment'
            : 'Only the PSDC operator can confirm this final payment',
      );
    }
    final stage = state['completionStage']?.toString().toLowerCase() ?? '';
    final status = (booking['status'] ?? '').toString().toLowerCase();
    final hasAfterInspection = await _hasAfterInspection(bookingId);

    const validPaymentStages = {
      'awaiting_payment',
      'operator_rating',
      'partner_rating',
      'driver_rating',
      'renter_rating',
      'awaiting_completion',
      'completed',
    };

    if (!validPaymentStages.contains(stage) &&
        !hasAfterInspection &&
        status != 'completed' &&
        status != 'returned') {
      throw Exception('The vehicle return checklist is not ready for payment');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    final updateData = <String, dynamic>{
      'final_payment_status': 'paid',
      'final_payment_confirmed_at': now,
      'final_payment_confirmed_by': actorId,
      'updated_at': now,
    };

    if (hasAfterInspection ||
        booking['returned_at'] != null ||
        status == 'completed') {
      updateData['status'] = 'completed';
      updateData['completed_at'] = now;
    }

    await supabase.from('bookings').update(updateData).eq('id', bookingId);

    try {
      await TripRatingService().syncRatingFlowForBooking(
        bookingId,
        operatorFallbackUserId: actorId,
      );
    } catch (e) {
      debugPrint('Could not sync rating flow after final payment: $e');
    }

    final vehicle = booking['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    String? reviewerId;
    if (expectedRole == 'partner') {
      reviewerId = vehicle['owner_id']?.toString();
    } else {
      reviewerId = booking['operator_id']?.toString().trim();
      if (reviewerId == null || reviewerId.isEmpty) reviewerId = actorId;
    }
    if (reviewerId?.isNotEmpty == true) {
      await NotificationService().createNotification(
        userId: reviewerId!,
        title: 'Rate The Renter',
        message:
            'The final balance is fully paid. Submit the mandatory renter rating to continue completion.',
        type: 'trip_rating_required',
        data: {'booking_id': bookingId, 'reviewer_role': expectedRole},
      );
    }
    return await getBookingById(bookingId) ?? booking;
  }

  Future<bool> _hasAfterInspection(String bookingId) async {
    try {
      final response = await supabase
          .from('booking_vehicle_inspections')
          .select('id')
          .eq('booking_id', bookingId)
          .eq('inspection_type', 'after')
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> confirmSuccessfulTrip({
    required String bookingId,
    required String actorRole,
  }) async {
    final normalizedRole = actorRole.trim().toLowerCase();
    if (_tripConfirmationColumnForRole(normalizedRole) == null) {
      throw Exception('Unsupported trip confirmation role: $actorRole');
    }

    final booking = await getBookingById(bookingId);
    if (booking == null) {
      throw Exception('Booking not found');
    }

    final completionState = getTripCompletionState(booking);
    final canRate = completionState['canRate'] as Map<String, bool>?;
    if (canRate?[normalizedRole] != true) {
      throw Exception(
        'This confirmation is not available yet. Complete payment and the required ratings in order.',
      );
    }
    throw Exception(
      'A mandatory star rating is required. Open the Rate Trip screen to continue.',
    );
  }

  // Get booking counts by status for partner
  Future<Map<String, int>> getPartnerBookingCounts(
    String partnerId, {
    List<Map<String, dynamic>>? existingBookings,
  }) async {
    try {
      debugPrint('Fetching booking counts for partner: $partnerId');

      final bookings = existingBookings ?? await getPartnerBookings(partnerId);

      final counts = {
        'pending': 0,
        'approved': 0,
        'confirmed': 0,
        'active': 0,
        'completed': 0,
        'rejected': 0,
        'cancelled': 0,
        'total': bookings.length,
      };

      for (final booking in bookings) {
        final group = bookingStatusGroup(booking['status']).name;
        if (counts.containsKey(group)) {
          counts[group] = counts[group]! + 1;
        } else {
          final status = booking['status']?.toString().toLowerCase().trim();
          if (status != null && counts.containsKey(status)) {
            counts[status] = counts[status]! + 1;
          }
        }
      }

      debugPrint('Booking counts: $counts');
      return counts;
    } catch (e) {
      debugPrint('Error getting booking counts: $e');
      return {
        'pending': 0,
        'approved': 0,
        'confirmed': 0,
        'active': 0,
        'completed': 0,
        'rejected': 0,
        'cancelled': 0,
        'total': 0,
      };
    }
  }

  // Get recent bookings for partner (limit)
  Future<List<Map<String, dynamic>>> getRecentPartnerBookings(
    String userId, {
    int limit = 5,
  }) async {
    try {
      final all = await getPartnerBookings(userId);
      return all.take(limit).toList();
    } catch (e) {
      debugPrint('Unexpected error fetching recent partner bookings: $e');
      return [];
    }
  }

  /// Fetch all bookings in the system with full vehicle/renter/driver hydration (Admin & Operator)
  Future<List<Map<String, dynamic>>> getAllBookings() async {
    try {
      await processExpiredPendingBookings();
      final response = await supabase
          .from('bookings')
          .select('*')
          .order('created_at', ascending: false);
      return await hydrateBookingVehicles(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('Error fetching all bookings: $e');
      return [];
    }
  }

  // ================== PARTNER BOOKING CONFIRMATION ==================

  /// Partner confirms that they agree to host the renter for the upcoming
  /// booking. Required before the operator can officially approve.
  Future<void> confirmPartnerBooking({
    required String bookingId,
    required String partnerId,
    Map<String, dynamic>? cachedBooking,
  }) async {
    Map<String, dynamic>? booking = cachedBooking;
    if (booking == null) {
      final response = await supabase
          .from('bookings')
          .select(
            'id, status, renter_id, vehicle_id, driver_id, partner_id, vehicles:vehicle_id(id, brand, model, owner_id, partner_id)',
          )
          .eq('id', bookingId)
          .maybeSingle();
      if (response != null) {
        booking = Map<String, dynamic>.from(response);
      }
    }
    if (booking == null) throw Exception('Booking not found');

    final vehicle = booking['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    final ownerId = (vehicle['owner_id'] ??
            booking['partner_id'] ??
            vehicle['partner_id'])
        ?.toString();
    final bookingConfirmedBy = booking['partner_booking_confirmed_by']?.toString();
    final bookingPartnerId = booking['partner_id']?.toString();

    bool isAuthorized = (ownerId == null || ownerId.isEmpty || ownerId == partnerId) ||
        (bookingPartnerId != null && bookingPartnerId == partnerId) ||
        (bookingConfirmedBy != null && bookingConfirmedBy == partnerId);

    if (!isAuthorized) {
      try {
        final vehicleId = booking['vehicle_id']?.toString() ?? vehicle['id']?.toString();
        if (vehicleId != null && vehicleId.isNotEmpty) {
          final pv = await supabase
              .from('partner_vehicles')
              .select('partner_id')
              .or('id.eq.$vehicleId,vehicle_id.eq.$vehicleId')
              .limit(1)
              .maybeSingle();
          if (pv != null && pv['partner_id']?.toString() == partnerId) {
            isAuthorized = true;
          }
        }
      } catch (_) {}
    }

    if (!isAuthorized) {
      throw Exception('Only the vehicle owner can confirm this booking');
    }

    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    if (status.isNotEmpty && status != 'pending') {
      throw Exception(
        'This booking cannot be confirmed in its current state ($status)',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final updatePayload = <String, dynamic>{
      'partner_booking_confirmed_at': now,
      'partner_booking_confirmed_by': partnerId,
      'updated_at': now,
    };

    // If reservation payment was already verified, lock it
    if (booking['reservation_payment_status'] == 'verified') {
      updatePayload['reservation_payment_status'] = 'verified';
      updatePayload['payment_verified'] = true;
    }

    await supabase
        .from('bookings')
        .update(updatePayload)
        .eq('id', bookingId);

    // Notify operators and renter asynchronously in background
    unawaited(
      _notifyOperatorsForBooking(
        booking,
        title: 'Partner Confirmed Booking',
        message:
            'The vehicle partner confirmed availability. You can now approve the booking.',
        action: 'partner_booking_confirmed',
      ).catchError(
        (e) => debugPrint('Error notifying operators on partner confirm: $e'),
      ),
    );

    final renterId = booking['renter_id']?.toString();
    if (renterId != null && renterId.isNotEmpty) {
      final vehicleTitle = _vehicleTitle(vehicle);
      unawaited(
        NotificationService()
            .createNotification(
              userId: renterId,
              title: 'Partner Confirmed Your Booking',
              message:
                  'The vehicle owner confirmed availability for $vehicleTitle. Awaiting final operator confirmation.',
              type: 'booking',
              data: {'booking_id': bookingId, 'event': 'partner_confirmed'},
            )
            .then<void>((_) {})
            .catchError(
              (e) => debugPrint('Error creating confirmation notification: $e'),
            ),
      );
    }
  }

  /// Partner rejects the booking for their vehicle before operator approval.
  Future<void> rejectPartnerBooking({
    required String bookingId,
    required String partnerId,
    required String reason,
    Map<String, dynamic>? cachedBooking,
  }) async {
    Map<String, dynamic>? booking = cachedBooking;
    if (booking == null) {
      final response = await supabase
          .from('bookings')
          .select(
            'id, status, renter_id, vehicle_id, driver_id, partner_id, paid_amount, reservation_fee_amount, total_price, total_amount, reservation_payment_status, final_payment_status, payment_verified, vehicles:vehicle_id(id, brand, model, owner_id, partner_id)',
          )
          .eq('id', bookingId)
          .maybeSingle();
      if (response != null) {
        booking = Map<String, dynamic>.from(response);
      }
    }
    if (booking == null) throw Exception('Booking not found');

    final vehicle = booking['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    final ownerId = (vehicle['owner_id'] ??
            booking['partner_id'] ??
            vehicle['partner_id'])
        ?.toString();
    final bookingConfirmedBy = booking['partner_booking_confirmed_by']?.toString();
    final bookingPartnerId = booking['partner_id']?.toString();

    bool isAuthorized = (ownerId == null || ownerId.isEmpty || ownerId == partnerId) ||
        (bookingPartnerId != null && bookingPartnerId == partnerId) ||
        (bookingConfirmedBy != null && bookingConfirmedBy == partnerId);

    if (!isAuthorized) {
      try {
        final vehicleId = booking['vehicle_id']?.toString() ?? vehicle['id']?.toString();
        if (vehicleId != null && vehicleId.isNotEmpty) {
          final pv = await supabase
              .from('partner_vehicles')
              .select('partner_id')
              .or('id.eq.$vehicleId,vehicle_id.eq.$vehicleId')
              .limit(1)
              .maybeSingle();
          if (pv != null && pv['partner_id']?.toString() == partnerId) {
            isAuthorized = true;
          }
        }
      } catch (_) {}
    }

    if (!isAuthorized) {
      throw Exception('Only the vehicle owner can reject this booking');
    }

    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    if (status.isNotEmpty &&
        !{
          'pending',
          'approved',
          'driver_accepted',
          'payment_submitted',
          'awaiting_payment',
        }.contains(status)) {
      throw Exception(
        'This booking cannot be rejected in its current state ($status)',
      );
    }

    final payState = resolveBookingPaymentState(booking);
    final paidAmount = resolveBookingRefundAmount(booking);
    final isAlreadyPaid = payState == BookingPaymentState.paid ||
        payState == BookingPaymentState.pendingConfirmation ||
        payState == BookingPaymentState.paymentReview ||
        booking['payment_verified'] == true ||
        booking['reservation_payment_status'] == 'verified' ||
        booking['reservation_payment_status'] == 'paid' ||
        booking['final_payment_status'] == 'paid' ||
        (booking['reservation_payment_reference']?.toString().trim().isNotEmpty == true) ||
        (booking['reservation_payment_proof_url']?.toString().trim().isNotEmpty == true) ||
        paidAmount > 0;

    final now = DateTime.now().toUtc().toIso8601String();
    final updatePayload = <String, dynamic>{
      'status': 'rejected',
      'partner_booking_rejected_at': now,
      'partner_booking_rejection_reason': reason,
      'rejection_reason': reason,
      'rejected_at': now,
      'updated_at': now,
    };

    if (isAlreadyPaid && paidAmount > 0) {
      updatePayload['refund_status'] = 'refund_needed';
      updatePayload['refund_amount'] = paidAmount;
    }

    await supabase
        .from('bookings')
        .update(updatePayload)
        .eq('id', bookingId);

    // Cancel driver assignment in parallel if any
    final assignedDriverId = booking['driver_id']?.toString();
    if (assignedDriverId != null && assignedDriverId.isNotEmpty) {
      unawaited(
        supabase
            .from('driver_job_assignments')
            .update({'status': 'cancelled', 'updated_at': now})
            .eq('booking_id', bookingId)
            .inFilter('status', ['pending_offer', 'assigned', 'accepted'])
            .then(
              (_) => supabase
                  .from('users')
                  .update({'is_available': true})
                  .eq('id', assignedDriverId),
            )
            .catchError(
              (e) => debugPrint(
                'Error cancelling driver assignment on reject: $e',
              ),
            ),
      );
    }

    // Notify renter and operators
    final renterId = booking['renter_id']?.toString();
    final vehicleTitle = _vehicleTitle(vehicle);
    if (renterId != null && renterId.isNotEmpty) {
      final refundMsg = (isAlreadyPaid && paidAmount > 0)
          ? ' Your payment of PHP ${paidAmount.toStringAsFixed(2)} has been queued for a refund.'
          : '';
      unawaited(
        NotificationService()
            .createNotification(
              userId: renterId,
              title: isAlreadyPaid ? 'Booking Declined - Refund Processing' : 'Booking Declined',
              message:
                  'Your booking for $vehicleTitle was declined by the vehicle partner. Reason: $reason.$refundMsg',
              type: 'booking',
              data: {'booking_id': bookingId, 'status': 'rejected', 'refund_required': isAlreadyPaid},
            )
            .then<void>((_) {})
            .catchError(
              (e) => debugPrint('Error creating rejection notification: $e'),
            ),
      );
    }

    if (isAlreadyPaid && paidAmount > 0) {
      unawaited(
        _notifyOperatorsForBooking(
          booking,
          title: 'Partner Declined Paid Booking',
          message:
              'Partner declined booking #$bookingId for $vehicleTitle. A refund of PHP ${paidAmount.toStringAsFixed(2)} is required.',
          action: 'refund_needed',
        ).catchError(
          (e) => debugPrint('Error notifying operators on partner decline refund: $e'),
        ),
      );
    }
  }

  // ================== OPERATOR WORKFLOW ==================

  /// Get all pending bookings for operator approval
  Future<List<Map<String, dynamic>>> getPendingBookings() async {
    try {
      await processExpiredPendingBookings();
      debugPrint('Fetching pending bookings');
      final response = await supabase
          .from('bookings')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return await hydrateBookingVehicles(
        List<Map<String, dynamic>>.from(response),
      );
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching pending bookings: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching pending bookings: $e');
      return [];
    }
  }

  /// All bookings managed or monitored by operators (including partner vehicles) — every status.
  Future<List<Map<String, dynamic>>> getOperatorBookings(
    String operatorId,
  ) async {
    try {
      await processExpiredPendingBookings();
      final response = await supabase
          .from('bookings')
          .select('*')
          .order('created_at', ascending: false);
      return await hydrateBookingVehicles(
        List<Map<String, dynamic>>.from(response),
      );
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching operator bookings: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching operator bookings: $e');
      return [];
    }
  }

  /// Approved/ongoing/active bookings for the operator's live dashboard (including partner units).
  Future<List<Map<String, dynamic>>> getOperatorActiveBookings(
    String operatorId,
  ) async {
    try {
      final response = await supabase
          .from('bookings')
          .select('*')
          .inFilter('status', [
            'approved',
            'confirmed',
            'active',
            'ongoing',
            'return_pending_inspection',
            'awaiting_completion',
          ])
          .order('start_at', ascending: true);
      return await hydrateBookingVehicles(
        List<Map<String, dynamic>>.from(response),
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error fetching operator active bookings: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint('Error fetching operator active bookings: $e');
      return [];
    }
  }

  /// Pending bookings that operators monitor (PSDC and partner units).
  Future<List<Map<String, dynamic>>> getOperatorPendingApproval(
    String operatorId,
  ) async {
    try {
      await processExpiredPendingBookings();
      final response = await supabase
          .from('bookings')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return await hydrateBookingVehicles(
        List<Map<String, dynamic>>.from(response),
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error fetching operator pending bookings: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint('Error fetching operator pending bookings: $e');
      return [];
    }
  }

  /// Approve booking (operator action)
  Future<void> approveBooking(String bookingId, String operatorNotes) async {
    try {
      debugPrint('Approving booking: $bookingId');
      final operatorId = supabase.auth.currentUser?.id;
      if (operatorId == null || operatorId.isEmpty) {
        throw Exception('Operator is not authenticated');
      }

      // Keep every approval entry point behind finalizeBooking so a
      // driver-required reservation cannot bypass assignment/acceptance.
      await supabase
          .from('bookings')
          .update({
            'operator_notes': operatorNotes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);
      await finalizeBooking(bookingId: bookingId, operatorId: operatorId);

      debugPrint('Booking approved');
    } on PostgrestException catch (e) {
      debugPrint('Database error approving booking: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error approving booking: $e');
      rethrow;
    }
  }

  /// Reject booking (operator action)
  Future<void> rejectBooking(
    String bookingId,
    String reason, {
    Map<String, dynamic>? cachedBooking,
  }) async {
    try {
      debugPrint('Rejecting booking: $bookingId');

      Map<String, dynamic>? booking = cachedBooking;
      if (booking == null || booking['total_price'] == null || booking['reservation_payment_type'] == null) {
        booking = await getBookingById(bookingId) ?? booking;
      }
      if (booking == null) {
        final response = await supabase
            .from('bookings')
            .select(
              'id, status, renter_id, vehicle_id, driver_id, total_price, total_cost, paid_amount, reservation_fee_amount, reservation_payment_type, reservation_payment_covers_total, reservation_payment_reference, reservation_payment_proof_url, reservation_payment_status, final_payment_status, vehicles:vehicle_id(id, brand, model)',
            )
            .eq('id', bookingId)
            .maybeSingle();
        if (response != null) {
          booking = Map<String, dynamic>.from(response);
        }
      }
      if (booking == null) {
        throw Exception('Booking not found: $bookingId');
      }

      final payState = resolveBookingPaymentState(booking);
      final paidAmount = resolveBookingRefundAmount(booking);
      final refundAmount = paidAmount;
      final hasPaidOrVerified = payState == BookingPaymentState.paid ||
          payState == BookingPaymentState.pendingConfirmation ||
          payState == BookingPaymentState.paymentReview ||
          isBookingFullyPaid(booking) ||
          (booking['reservation_payment_reference']?.toString().trim().isNotEmpty == true) ||
          (booking['final_payment_reference']?.toString().trim().isNotEmpty == true) ||
          (booking['reservation_payment_proof_url']?.toString().trim().isNotEmpty == true) ||
          ((booking['paid_amount'] as num?)?.toDouble() ?? 0) > 0 ||
          ((booking['reservation_fee_amount'] as num?)?.toDouble() ?? 0) > 0 ||
          refundAmount > 0;

      final now = DateTime.now().toIso8601String();
      await supabase
          .from('bookings')
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'rejected_at': now,
            'updated_at': now,
            if (hasPaidOrVerified && refundAmount > 0) ...{
              'refund_status': 'refund_needed',
              'refund_amount': refundAmount,
              'refund_reason': 'Booking rejected by operator: $reason',
            } else ...{
              'refund_status': null,
            },
          })
          .eq('id', bookingId);

      final assignedDriverId = booking['driver_id']?.toString();
      if (assignedDriverId != null && assignedDriverId.isNotEmpty) {
        unawaited(
          supabase
              .from('driver_job_assignments')
              .update({'status': 'cancelled', 'updated_at': now})
              .eq('booking_id', bookingId)
              .inFilter('status', ['pending_offer', 'assigned', 'accepted'])
              .then(
                (_) => supabase
                    .from('users')
                    .update({'is_available': true})
                    .eq('id', assignedDriverId),
              )
              .catchError(
                (e) => debugPrint(
                  'Error cancelling driver assignment on reject: $e',
                ),
              ),
        );
      }

      debugPrint('Booking rejected');

      // ✅ Send notification to renter when booking is rejected (asynchronous)
      final renterId = booking['renter_id']?.toString();
      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final vehicleTitle = vehicle != null
          ? '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
          : 'Your rental vehicle';

      if (renterId != null && renterId.isNotEmpty) {
        final refundMsg = hasPaidOrVerified
            ? ' Reason: $reason. Since your payment was received/verified, a refund of PHP ${paidAmount.toStringAsFixed(2)} has been queued for disbursement.'
            : ' Reason: $reason';

        unawaited(
          supabase
              .from('notifications')
              .insert({
                'user_id': renterId,
                'title': '❌ Booking Rejected',
                'message': 'Your booking for $vehicleTitle has been rejected.$refundMsg',
                'type': 'booking',
                'data': {
                  'booking_id': bookingId,
                  'status': 'rejected',
                  'refund_needed': hasPaidOrVerified,
                  if (hasPaidOrVerified) 'refund_amount': paidAmount,
                },
                'created_at': DateTime.now().toIso8601String(),
              })
              .then((_) => debugPrint('✅ Rejection notification sent to renter'))
              .catchError(
                (e) => debugPrint('⚠️ Error sending rejection notification: $e'),
              ),
        );
      }

      if (hasPaidOrVerified) {
        try {
          final operators = await supabase
              .from('users')
              .select('id')
              .eq('role', 'operator');

          final opNotifications = List<Map<String, dynamic>>.from(operators)
              .map(
                (op) => {
                  'user_id': op['id'],
                  'title': '💸 Refund Required for Rejected Booking',
                  'message':
                      'A refund of PHP ${paidAmount.toStringAsFixed(2)} is required for rejected booking of $vehicleTitle.',
                  'type': 'booking_refund',
                  'data': {
                    'booking_id': bookingId,
                    'status': 'rejected',
                    'refund_status': 'refund_needed',
                    'refund_amount': paidAmount,
                  },
                  'created_at': DateTime.now().toIso8601String(),
                },
              )
              .toList();

          if (opNotifications.isNotEmpty) {
            unawaited(supabase.from('notifications').insert(opNotifications));
          }
        } catch (_) {}
      }
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting booking: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error rejecting booking: $e');
      rethrow;
    }
  }

  /// Checks all active driver job offers (status = pending_offer or assigned)
  /// and automatically declines any that have exceeded the 10-minute response window.
  Future<void> checkAndExpireDriverAssignments() async {
    try {
      final response = await supabase
          .from('driver_job_assignments')
          .select('id, booking_id, driver_id, offered_at, created_at, status')
          .inFilter('status', ['pending_offer', 'assigned']);

      final now = DateTime.now();

      for (final offer in response) {
        final offerId = offer['id']?.toString() ?? '';
        final bookingId = offer['booking_id']?.toString() ?? '';
        final driverId = offer['driver_id']?.toString() ?? '';
        final offeredAtStr = offer['offered_at']?.toString() ?? offer['created_at']?.toString();
        final offeredAt = offeredAtStr != null ? DateTime.tryParse(offeredAtStr)?.toLocal() : null;

        if (offeredAt != null && now.difference(offeredAt).inMinutes >= 10) {
          debugPrint('Driver job offer $offerId for booking $bookingId expired after 10 minutes. Auto-declining.');
          final nowIso = now.toIso8601String();

          // 1. Mark assignment as rejected/expired
          await supabase
              .from('driver_job_assignments')
              .update({
                'status': 'rejected',
                'rejection_reason': 'Auto-declined: 10-minute driver acceptance window expired',
                'replied_at': nowIso,
                'updated_at': nowIso,
              })
              .eq('id', offerId);

          // 2. Reset booking driver allocation so operator/partner can reassign immediately
          if (bookingId.isNotEmpty) {
            await supabase
                .from('bookings')
                .update({
                  'driver_id': null,
                  'driver_assigned_at': null,
                  'status': 'pending',
                  'updated_at': nowIso,
                })
                .eq('id', bookingId);
          }

          // 3. Mark driver available
          if (driverId.isNotEmpty) {
            try {
              await supabase
                  .from('users')
                  .update({'is_available': true})
                  .eq('id', driverId);
            } catch (_) {}
          }

          // 4. Send notifications
          if (bookingId.isNotEmpty) {
            try {
              final shortBookingId = bookingId.length >= 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId;
              await NotificationService().notifyOperatorDriverResponse(
                bookingId: bookingId,
                driverId: driverId,
                driverName: 'Assigned Driver',
                accepted: false,
              );

              if (driverId.isNotEmpty) {
                await NotificationService().createNotification(
                  userId: driverId,
                  title: 'Job Offer Expired (10 min Limit)',
                  message: 'The job offer for booking #$shortBookingId expired because it was not accepted within 10 minutes.',
                  type: 'booking',
                  data: {
                    'booking_id': bookingId,
                    'event': 'driver_offer_expired',
                  },
                );
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking expired driver assignments: $e');
    }
  }

  /// Assign driver to booking (operator action)
  Future<void> assignDriver(
    String bookingId,
    String driverId,
    double tripFee, {
    String? operatorId,
  }) async {
    try {
      debugPrint(
        'Assigning driver $driverId to booking $bookingId with fee: $tripFee',
      );

      final booking = await supabase
          .from('bookings')
          .select('id, with_driver, driver_fee, start_at, end_at, start_date, end_date, status, renter_id, operator_id')
          .eq('id', bookingId)
          .maybeSingle();

      if (booking == null) {
        throw Exception('Booking not found');
      }

      double effectiveTripFee = tripFee;
      if (effectiveTripFee <= 0) {
        final existingFee = (booking['driver_fee'] as num?)?.toDouble() ?? 0.0;
        if (existingFee > 0) {
          effectiveTripFee = existingFee;
        } else {
          final start = DateTime.tryParse((booking['start_at'] ?? booking['start_date'])?.toString() ?? '');
          final end = DateTime.tryParse((booking['end_at'] ?? booking['end_date'])?.toString() ?? '');
          int days = 1;
          if (start != null && end != null && end.isAfter(start)) {
            days = (end.difference(start).inMinutes / Duration.minutesPerDay).ceil();
            if (days <= 0) days = 1;
          }
          effectiveTripFee = days * PricingPolicy.driverDailyRate;
        }
      }

      final driver = await _getDriverAssignmentTarget(driverId);
      if (driver == null) {
        throw Exception('Selected user is not a valid driver');
      }

      final driverUserId = driver['user_id']?.toString();
      if (driverUserId == null || driverUserId.isEmpty) {
        throw Exception('Selected driver is missing profile linkage');
      }

      final currentStatus =
          booking['status']?.toString().trim().toLowerCase() ?? '';

      if (!{
        'pending',
        'pending_approval',
        'awaiting_driver',
        'approved',
        'confirmed',
        'assigned',
        'active',
        'ongoing',
      }.contains(currentStatus)) {
        throw Exception(
          'A driver can only be assigned to pending, approved, confirmed, or active bookings',
        );
      }

      final effectiveOperatorId =
          operatorId ??
          booking['operator_id']?.toString() ??
          supabase.auth.currentUser?.id;

      final now = DateTime.now().toIso8601String();
      await supabase
          .from('driver_job_assignments')
          .update({'status': 'superseded', 'updated_at': now})
          .eq('booking_id', bookingId)
          .inFilter('status', ['pending_offer', 'assigned']);

      final assignment = await supabase
          .from('driver_job_assignments')
          .insert({
            'booking_id': bookingId,
            'driver_id': driverUserId,
            'trip_fee': effectiveTripFee,
            'status': 'pending_offer',
            'offered_at': now,
            'created_at': now,
            'updated_at': now,
          })
          .select('id')
          .single();
      final assignmentId = assignment['id']?.toString();

      try {
        final updateData = <String, dynamic>{
          'driver_id': driverUserId,
          'with_driver': true,
          'driver_fee': effectiveTripFee,
          'status': 'pending',
          'driver_assigned_at': now,
          'updated_at': now,
        };
        if (effectiveOperatorId != null && effectiveOperatorId.isNotEmpty) {
          updateData['operator_id'] = effectiveOperatorId;
        }

        await supabase
            .from('bookings')
            .update(updateData)
            .eq('id', bookingId);
      } catch (_) {
        if (assignmentId != null && assignmentId.isNotEmpty) {
          await supabase
              .from('driver_job_assignments')
              .update({'status': 'cancelled', 'updated_at': now})
              .eq('id', assignmentId);
        }
        rethrow;
      }

      await supabase
          .from('users')
          .update({'is_available': false})
          .eq('id', driverUserId);

      debugPrint('Driver job offer created for booking');

      // ✅ Send notification to renter about driver assignment
      try {
        final driverName = driver['full_name'] ?? 'Driver';
        final renterId = booking['renter_id']?.toString();
        if (renterId != null && renterId.isNotEmpty) {
          await NotificationService().createNotification(
            userId: renterId,
            title: 'Driver Selection in Progress',
            message:
                '$driverName was selected and is reviewing the job offer. Your booking is not finalized yet.',
            type: 'booking',
            data: {
              'booking_id': bookingId,
              'driver_id': driverUserId,
              'event': 'driver_offer_sent',
            },
          );
        }

        debugPrint('✅ Driver assignment notification sent to renter');
      } catch (e) {
        debugPrint('⚠️ Error sending driver assignment notification: $e');
      }

      // ✅ Notify the assigned driver with booking + renter details
      try {
        final bookingDetails = await getBookingById(bookingId);
        final vehicle = bookingDetails?['vehicles'] as Map<String, dynamic>?;
        final vehicleTitle = _vehicleTitle(vehicle);
        final renter = bookingDetails?['users'] as Map<String, dynamic>?;
        final renterName = renter?['full_name']?.toString() ?? 'Renter';
        final renterPhone = renter?['phone']?.toString() ?? '';
        await NotificationService().notifyDriverJobAssigned(
          driverId: driverUserId,
          bookingId: bookingId,
          renterId: booking['renter_id']?.toString(),
          renterName: renterName,
          renterPhone: renterPhone,
          vehicleTitle: vehicleTitle,
          pickupLocation: bookingDetails?['pickup_location']?.toString(),
          dropoffLocation: bookingDetails?['dropoff_location']?.toString(),
          startDate: bookingDetails?['start_date']?.toString(),
          endDate: bookingDetails?['end_date']?.toString(),
          startAt: bookingDetails?['start_at']?.toString(),
          endAt: bookingDetails?['end_at']?.toString(),
          tripFee: effectiveTripFee,
        );
        debugPrint('✅ Driver assignment notification sent to driver');
      } catch (e) {
        debugPrint('⚠️ Error sending driver notification: $e');
      }
    } on PostgrestException catch (e) {
      debugPrint('Database error assigning driver: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error assigning driver: $e');
      rethrow;
    }
  }

  /// Finalize a booking after the selected driver accepts the job offer.
  Future<Map<String, dynamic>> finalizeBooking({
    required String bookingId,
    required String operatorId,
  }) async {
    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    final currentStatus =
        booking['status']?.toString().trim().toLowerCase() ?? '';
    if (!{
      'pending',
      'pending_approval',
      'driver_accepted',
      'pending_driver_confirmation',
      'driver_assigned',
      'awaiting_driver',
      'approved',
      'confirmed',
    }.contains(currentStatus)) {
      throw Exception(
        'This booking cannot be finalized from its current state',
      );
    }

    final withDriver = booking['with_driver'] == true;
    final driverId = booking['driver_id']?.toString().trim() ?? '';
    Map<String, dynamic>? acceptedAssignment;
    if (withDriver) {
      if (driverId.isEmpty) {
        throw Exception('Select a driver before finalizing this booking');
      }

      final assignmentRows = await supabase
          .from('driver_job_assignments')
          .select('id, status, driver_id, replied_at')
          .eq('booking_id', bookingId)
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(1);
      if (assignmentRows.isNotEmpty) {
        acceptedAssignment = Map<String, dynamic>.from(assignmentRows.first);
      }
      final responseStatus = acceptedAssignment?['status']
          ?.toString()
          .trim()
          .toLowerCase();
      if (responseStatus != 'accepted' && responseStatus != 'confirmed') {
        throw Exception('Wait for the selected driver to accept the job first');
      }
    }

    final wasPaymentVerified = booking['reservation_payment_status'] == 'verified' ||
        booking['reservation_payment_status'] == 'paid' ||
        booking['payment_verified'] == true ||
        isBookingFullyPaid(booking);

    final now = DateTime.now().toIso8601String();
    if (currentStatus != 'confirmed') {
      await supabase
          .from('bookings')
          .update({
            'status': 'confirmed',
            'operator_id': operatorId,
            'approved_at': now,
            'updated_at': now,
            if (wasPaymentVerified) ...{
              'reservation_payment_status': 'verified',
              'final_payment_status': 'paid',
              'payment_status': 'paid',
            },
          })
          .eq('id', bookingId);
    } else if (booking['operator_id']?.toString() != operatorId) {
      await supabase
          .from('bookings')
          .update({
            'operator_id': operatorId,
            'updated_at': now,
            if (wasPaymentVerified) ...{
              'reservation_payment_status': 'verified',
              'final_payment_status': 'paid',
              'payment_status': 'paid',
            },
          })
          .eq('id', bookingId);
    }

    if (acceptedAssignment != null) {
      await supabase
          .from('driver_job_assignments')
          .update({'status': 'confirmed', 'updated_at': now})
          .eq('id', acceptedAssignment['id']);
    }

    final finalized = await getBookingById(bookingId);
    if (finalized == null) {
      throw Exception('Booking finalized but could not be reloaded');
    }
    final vehicle = finalized['vehicles'] as Map<String, dynamic>?;
    final vehicleTitle = _vehicleTitle(vehicle);
    if (isEligibleForBookingChat(finalized)) {
      await _ensureBookingGroupChatAndSummary(
        booking: finalized,
        vehicleTitle: vehicleTitle,
        summaryTitle: 'Booking Confirmed',
      );
    }

    final renterId = finalized['renter_id']?.toString();
    if (renterId != null && renterId.isNotEmpty) {
      await NotificationService().notifyBookingFinalized(
        userId: renterId,
        bookingId: bookingId,
        vehicleTitle: vehicleTitle,
        role: 'renter',
      );
    }
    if (driverId.isNotEmpty) {
      await NotificationService().notifyBookingFinalized(
        userId: driverId,
        bookingId: bookingId,
        vehicleTitle: vehicleTitle,
        role: 'driver',
      );
    }
    final ownerId = vehicle?['owner_id']?.toString();
    if (ownerId != null &&
        ownerId.isNotEmpty &&
        ownerId != operatorId &&
        ownerId != renterId) {
      await NotificationService().notifyBookingFinalized(
        userId: ownerId,
        bookingId: bookingId,
        vehicleTitle: vehicleTitle,
        role: 'partner',
      );
    }

    return finalized;
  }

  /// Repairs or creates the booking group chat without duplicating it.
  /// Only approved/active trips starting within 3 days are eligible for an active conversation (unless forced).
  Future<void> ensureBookingConversationForActiveBooking({
    required String bookingId,
    String? operatorId,
    bool force = false,
  }) async {
    var booking = await getBookingById(bookingId);
    if (booking == null) return;

    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    const activeStatuses = {'approved', 'confirmed', 'active', 'ongoing'};
    if (!activeStatuses.contains(status)) return;
    if (!force && !isEligibleForBookingChat(booking)) return;

    final storedOperatorId = booking['operator_id']?.toString().trim() ?? '';
    final resolvedOperatorId = operatorId?.trim() ?? '';
    if (storedOperatorId.isEmpty && resolvedOperatorId.isNotEmpty) {
      await supabase
          .from('bookings')
          .update({
            'operator_id': resolvedOperatorId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);
      booking = await getBookingById(bookingId) ?? booking;
    }

    await _ensureBookingGroupChatAndSummary(
      booking: booking,
      vehicleTitle: _vehicleTitle(booking['vehicles'] as Map<String, dynamic>?),
      summaryTitle: 'Booking Confirmed',
    );
  }

  /// Unassign driver from booking
  Future<void> unassignDriver(String bookingId) async {
    try {
      debugPrint('Unassigning driver from booking: $bookingId');
      final booking = await supabase
          .from('bookings')
          .select('driver_id')
          .eq('id', bookingId)
          .maybeSingle();
      final driverId = booking?['driver_id']?.toString();
      final now = DateTime.now().toIso8601String();
      await supabase
          .from('bookings')
          .update({
            'driver_id': null,
            'driver_assigned_at': null,
            'status': 'pending',
            'updated_at': now,
          })
          .eq('id', bookingId);

      await supabase
          .from('driver_job_assignments')
          .update({'status': 'cancelled', 'updated_at': now})
          .eq('booking_id', bookingId)
          .inFilter('status', ['pending_offer', 'assigned', 'accepted']);
      if (driverId != null && driverId.isNotEmpty) {
        await supabase
            .from('users')
            .update({'is_available': true})
            .eq('id', driverId);
      }

      debugPrint('Driver unassigned from booking');
    } on PostgrestException catch (e) {
      debugPrint('Database error unassigning driver: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error unassigning driver: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableVerifiedDrivers({
    DateTime? bookingDate,
    DateTime? startDate,
    DateTime? endDate,
    String? excludeBookingId,
    List<Map<String, double>> proximityTargets = const [],
    bool prioritizeProximity = false,
    bool prioritizePsdc = false,
  }) async {
    try {
      final effectiveStart = (startDate ?? bookingDate ?? DateTime.now()).toLocal();
      final effectiveEnd = (endDate ?? (startDate != null ? startDate.add(const Duration(days: 1)) : bookingDate?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1)))).toLocal();

      final reqStartDay = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
      final reqEndDay = DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day, 23, 59, 59);

      // 1. Check which drivers already have active / confirmed / ongoing bookings on overlapping dates
      final Set<String> busyDriverIds = {};
      try {
        var bookingsQuery = supabase
            .from('bookings')
            .select('id, driver_id, status, start_at, end_at, start_date, end_date')
            .not('driver_id', 'is', null)
            .not('status', 'in', '(cancelled,rejected,completed,refunded,failed)');

        if (excludeBookingId != null && excludeBookingId.isNotEmpty) {
          bookingsQuery = bookingsQuery.neq('id', excludeBookingId);
        }

        final overlappingBookings = await bookingsQuery;
        for (final b in List<Map<String, dynamic>>.from(overlappingBookings)) {
          final dId = b['driver_id']?.toString()?.trim() ?? '';
          if (dId.isEmpty) continue;

          final bStart = DateTime.tryParse((b['start_at'] ?? b['start_date'])?.toString() ?? '')?.toLocal();
          final bEnd = DateTime.tryParse((b['end_at'] ?? b['end_date'])?.toString() ?? '')?.toLocal();

          if (bStart != null) {
            final bStartDay = DateTime(bStart.year, bStart.month, bStart.day);
            final bEffectiveEnd = bEnd ?? bStart.add(const Duration(days: 1));
            final bEndDay = DateTime(bEffectiveEnd.year, bEffectiveEnd.month, bEffectiveEnd.day, 23, 59, 59);

            final isOverlap = !bEndDay.isBefore(reqStartDay) && !bStartDay.isAfter(reqEndDay);
            if (isOverlap) {
              busyDriverIds.add(dId);
            }
          }
        }
      } catch (err) {
        debugPrint('Driver overlapping bookings check note: $err');
      }

      // 2. Check driver availability schedule (date-based and day-of-week)
      final Set<String> driversWithDateSchedules = {};
      final Map<String, Set<String>> driverAvailableDates = {};
      final Map<String, Set<String>> driverUnavailableDates = {};
      final Map<String, Map<String, bool>> driverDayOfWeekSchedule = {};
      final List<String> datesToCheck = [];
      final List<String> dayNamesToCheck = [];

      try {
        const dayNames = [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday',
        ];
        var cur = DateTime(reqStartDay.year, reqStartDay.month, reqStartDay.day);
        // Only check up to (but NOT including) the end day — the end date is the
        // return/drop-off day and the driver is not required to be scheduled then.
        final endCheck = DateTime(reqEndDay.year, reqEndDay.month, reqEndDay.day);
        while (cur.isBefore(endCheck)) {
          datesToCheck.add(
            '${cur.year.toString().padLeft(4, '0')}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}',
          );
          if (cur.weekday >= 1 && cur.weekday <= 7) {
            dayNamesToCheck.add(dayNames[cur.weekday - 1]);
          }
          cur = cur.add(const Duration(days: 1));
        }
        // If start == end (same-day booking) still add the start date
        if (datesToCheck.isEmpty) {
          datesToCheck.add(
            '${reqStartDay.year.toString().padLeft(4, '0')}-${reqStartDay.month.toString().padLeft(2, '0')}-${reqStartDay.day.toString().padLeft(2, '0')}',
          );
          if (reqStartDay.weekday >= 1 && reqStartDay.weekday <= 7) {
            dayNamesToCheck.add(dayNames[reqStartDay.weekday - 1]);
          }
        }

        final scheduleResponse = await supabase
            .from('driver_availability_schedule')
            .select('driver_id, is_available, date, day_of_week');

        for (final row in List<Map<String, dynamic>>.from(scheduleResponse)) {
          final dId = row['driver_id']?.toString()?.trim();
          if (dId == null || dId.isEmpty) continue;
          final isAvail = row['is_available'] != false;
          final dateVal = row['date']?.toString()?.trim();
          final dayVal = row['day_of_week']?.toString()?.toLowerCase().trim();

          if (dateVal != null && dateVal.isNotEmpty) {
            final normalizedDate = dateVal.split('T')[0];
            driversWithDateSchedules.add(dId);
            if (isAvail) {
              driverAvailableDates
                  .putIfAbsent(dId, () => <String>{})
                  .add(normalizedDate);
            } else {
              driverUnavailableDates
                  .putIfAbsent(dId, () => <String>{})
                  .add(normalizedDate);
            }
          } else if (dayVal != null && dayVal.isNotEmpty) {
            driverDayOfWeekSchedule
                .putIfAbsent(dId, () => <String, bool>{})[dayVal] = isAvail;
          }
        }
      } catch (scheduleErr) {
        debugPrint('Driver availability schedule lookup note: $scheduleErr');
      }

      List<Map<String, dynamic>> rawDriverRows = [];

      // 3. Query verified & approved drivers directly from public.drivers joined with public.users
      try {
        final response = await supabase
            .from('drivers')
            .select(
              'id, user_id, verification_status, driver_tier, rating, total_trips, is_available, users(id, full_name, email, phone, role, is_available, id_verified, verification_status, application_status, avatar_url, profile_picture_url, location, latitude, longitude, is_active)',
            )
            .or('verification_status.eq.approved,verification_status.eq.verified');
        for (final row in List<Map<String, dynamic>>.from(response)) {
          final u = row['users'] as Map<String, dynamic>?;
          final uId = row['user_id']?.toString() ?? u?['id']?.toString();
          if (u != null && uId != null && uId.isNotEmpty && u['is_active'] != false) {
            rawDriverRows.add(row);
          }
        }
      } catch (joinErr) {
        debugPrint('Direct drivers table query note: $joinErr');
      }

      final drivers = rawDriverRows
          .where((driver) {
            final user = driver['users'] as Map<String, dynamic>?;
            if (user == null) return false;

            // Reject suspended / inactive users
            if (user['is_active'] == false) return false;

            // Reject drivers who have master availability explicitly turned off.
            // A null value means "not yet set" which is fine if the schedule allows it.
            final userAvail = user['is_available'];
            final driverAvail = driver['is_available'];
            if (userAvail == false || driverAvail == false) {
              return false;
            }

            final driverUserId = driver['user_id']?.toString() ?? '';
            final driverProfileId = driver['id']?.toString() ?? '';

            // Reject drivers who already have an active / confirmed / ongoing booking on overlapping dates
            if (busyDriverIds.contains(driverUserId) ||
                busyDriverIds.contains(driverProfileId)) {
              return false;
            }

            // Check if driver has calendar date availability configured
            final hasDateSchedule =
                driversWithDateSchedules.contains(driverUserId) ||
                driversWithDateSchedules.contains(driverProfileId);

            if (hasDateSchedule) {
              final availDates = <String>{
                ...?driverAvailableDates[driverUserId],
                ...?driverAvailableDates[driverProfileId],
              };
              final unavailDates = <String>{
                ...?driverUnavailableDates[driverUserId],
                ...?driverUnavailableDates[driverProfileId],
              };

              // If driver has date schedule, every requested date must be explicitly in available dates and not in unavailDates
              if (availDates.isEmpty) return false;
              for (final dStr in datesToCheck) {
                if (unavailDates.contains(dStr) || !availDates.contains(dStr)) {
                  return false;
                }
              }
            } else {
              // If no calendar dates set, check day-of-week schedule if configured
              final daySchedule = <String, bool>{
                ...?driverDayOfWeekSchedule[driverUserId],
                ...?driverDayOfWeekSchedule[driverProfileId],
              };
              if (daySchedule.isEmpty) {
                // Driver has not selected their availability yet; cannot be assigned
                return false;
              }
              for (final dName in dayNamesToCheck) {
                if (daySchedule[dName] != true) {
                  return false;
                }
              }
            }

            final driverVer =
                driver['verification_status']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';
            final userVer =
                user['verification_status']?.toString().trim().toLowerCase() ??
                '';
            final userAppStatus =
                user['application_status']?.toString().trim().toLowerCase() ??
                '';

            // Filter out explicitly rejected drivers
            if (driverVer == 'rejected' || userVer == 'rejected' || userAppStatus == 'rejected') {
              return false;
            }

            // Must be verified and have completed driver/user application
            final isVerifiedOrDone =
                user['id_verified'] == true ||
                _isVerifiedDriverStatus(userVer) ||
                _isVerifiedDriverStatus(driverVer) ||
                userAppStatus == 'approved' ||
                userAppStatus == 'verified' ||
                userAppStatus == 'basic' ||
                userAppStatus == 'completed' ||
                driver['license_verified'] == true;

            if (!isVerifiedOrDone) return false;

            return true;
          })
          .map((driver) {
            final normalized = Map<String, dynamic>.from(driver);
            final user = Map<String, dynamic>.from(driver['users'] as Map<String, dynamic>? ?? {});
            final isPsdc =
                driver['is_psdc_driver'] == true ||
                user['is_psdc_driver'] == true ||
                driver['driver_tier']?.toString().toLowerCase() == 'psdc';
            normalized['is_psdc_driver'] = isPsdc;

            // Resolve driver coordinates from Plus Code, city name, address, or lat/lng
            final rawLocation = user['location'] ?? user['address'] ?? user['city'] ?? driver['address'] ?? driver['location'] ?? '';
            final resolvedPoint = PhilippineGeocoding.resolveLocationSync(
              rawLocation,
              latitudeValue: user['latitude'] ?? driver['latitude'],
              longitudeValue: user['longitude'] ?? driver['longitude'],
            );

            user['latitude'] = resolvedPoint.latitude;
            user['longitude'] = resolvedPoint.longitude;
            normalized['users'] = user;
            normalized['latitude'] = resolvedPoint.latitude;
            normalized['longitude'] = resolvedPoint.longitude;

            if (proximityTargets.isNotEmpty) {
              final distances = proximityTargets.map(
                (target) => _distanceInKilometers(
                  resolvedPoint.latitude,
                  resolvedPoint.longitude,
                  target['latitude']!,
                  target['longitude']!,
                ),
              );
              normalized['distance_km'] = distances.reduce(math.min);
            }
            return normalized;
          })
          .toList();

      drivers.sort((a, b) {
        if (prioritizeProximity) {
          final aDistance = (a['distance_km'] as num?)?.toDouble();
          final bDistance = (b['distance_km'] as num?)?.toDouble();
          if (aDistance != null && bDistance != null) {
            final comparison = aDistance.compareTo(bDistance);
            if (comparison != 0) return comparison;
          } else if (aDistance != null) {
            return -1;
          } else if (bDistance != null) {
            return 1;
          }
        }

        if (prioritizePsdc || (!prioritizeProximity && prioritizePsdc)) {
          final aIsPsdc = a['is_psdc_driver'] == true;
          final bIsPsdc = b['is_psdc_driver'] == true;
          if (aIsPsdc && !bIsPsdc) return -1;
          if (!aIsPsdc && bIsPsdc) return 1;
        }

        final aRating = (a['rating'] as num?)?.toDouble() ?? 0.0;
        final bRating = (b['rating'] as num?)?.toDouble() ?? 0.0;
        if (aRating != bRating) {
          return bRating.compareTo(aRating);
        }

        final aTrips = (a['total_trips'] as num?)?.toInt() ?? 0;
        final bTrips = (b['total_trips'] as num?)?.toInt() ?? 0;
        if (aTrips != bTrips) {
          return bTrips.compareTo(aTrips);
        }

        final aUser = a['users'] as Map<String, dynamic>?;
        final bUser = b['users'] as Map<String, dynamic>?;
        final aName = aUser?['full_name']?.toString() ?? '';
        final bName = bUser?['full_name']?.toString() ?? '';
        return aName.compareTo(bName);
      });

      return drivers;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching available drivers: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching available drivers: $e');
      return [];
    }
  }

  double _distanceInKilometers(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const earthRadiusKm = 6371.0;
    final latitudeDelta = _degreesToRadians(latitudeB - latitudeA);
    final longitudeDelta = _degreesToRadians(longitudeB - longitudeA);
    final a =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(_degreesToRadians(latitudeA)) *
            math.cos(_degreesToRadians(latitudeB)) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  /// Mark a confirmed booking as picked up and active.
  Future<void> markBookingPickedUp(String bookingId) async {
    try {
      debugPrint('Marking booking picked up: $bookingId');

      final booking = await getBookingById(bookingId);
      if (booking == null) {
        throw Exception('Booking not found: $bookingId');
      }

      final status = (booking['status'] as String? ?? '').toLowerCase();
      if (status != 'confirmed' && status != 'approved') {
        throw Exception('Only confirmed bookings can be marked as picked up');
      }

      final currentUserId = supabase.auth.currentUser?.id;
      final assignedDriverId = booking['driver_id']?.toString();
      final withDriver = booking['with_driver'] == true;
      if (!withDriver) {
        throw Exception(
          'Pickup updates are only allowed for with-driver bookings',
        );
      }
      if (currentUserId == null ||
          assignedDriverId == null ||
          assignedDriverId != currentUserId) {
        throw Exception('Only the assigned driver can mark pickup time');
      }

      final inspection = await BookingInspectionService()
          .getCompletedInspection(
            bookingId: bookingId,
            inspectionType: 'before',
          );
      await _postInspectionAuditToBookingChat(
        booking: booking,
        inspection: inspection,
        inspectionType: 'before',
      );

      await supabase
          .from('bookings')
          .update({
            'status': 'active',
            'picked_up_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      try {
        await supabase
            .from('driver_job_assignments')
            .update({
              'status': 'in_progress',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('booking_id', bookingId)
            .eq('driver_id', currentUserId);
      } catch (e) {
        debugPrint('Could not update assignment status to in_progress: $e');
      }

      await _notifyOperatorsForBooking(
        booking,
        title: 'Unit Picked Up',
        message: 'The driver marked the unit as picked up.',
        action: 'picked_up',
      );

      debugPrint('Booking marked as active');
    } on PostgrestException catch (e) {
      debugPrint('Database error marking pickup: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error marking pickup: $e');
      rethrow;
    }
  }

  /// Complete a returned booking and recalculate the total from the actual
  /// return date when it differs from the scheduled end date.
  Future<double> completeBookingReturn({
    required String bookingId,
    required DateTime returnedAt,
  }) async {
    try {
      debugPrint('Completing returned booking: $bookingId');

      final booking = await getBookingById(bookingId);
      if (booking == null) {
        throw Exception('Booking not found: $bookingId');
      }

      final status = (booking['status'] as String? ?? '').toLowerCase();
      if (status != 'active' && status != 'ongoing') {
        throw Exception('Only ongoing bookings can be marked as returned');
      }

      final currentUserId = supabase.auth.currentUser?.id;
      final assignedDriverId = booking['driver_id']?.toString();
      final withDriver = booking['with_driver'] == true;
      if (!withDriver) {
        throw Exception(
          'Return updates are only allowed for with-driver bookings',
        );
      }
      final isDriver = currentUserId != null &&
          assignedDriverId != null &&
          (assignedDriverId == currentUserId ||
              assignedDriverId ==
                  await _getDriverProfileIdForUser(currentUserId) ||
              await _getDriverUserIdForProfile(assignedDriverId) ==
                  currentUserId);
      if (!isDriver) {
        throw Exception('Only the assigned driver can mark return time');
      }

      final lateReturn = _lateReturnValues(booking, returnedAt);
      final lateReturnFee = lateReturn['late_return_fee'] as double;
      final recalculatedTotal = lateReturn['total_price'] as double;

      await supabase
          .from('bookings')
          .update({
            'status': 'return_pending_inspection',
            'returned_at': returnedAt.toIso8601String(),
            'completion_stage': 'awaiting_after_checklist',
            ...lateReturn,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final driverUserId = booking['driver_id']?.toString() ?? currentUserId;
      if (driverUserId.isNotEmpty) {
        await supabase
            .from('users')
            .update({'is_available': true})
            .eq('id', driverUserId);
      }

      try {
        await supabase
            .from('driver_job_assignments')
            .update({
              'status': 'awaiting_completion',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('booking_id', bookingId)
            .inFilter('status', ['assigned', 'accepted', 'ongoing', 'in_progress', 'pending_offer']);
      } catch (e) {
        debugPrint('Could not update assignment return status: $e');
      }

      await _notifyOperatorsForBooking(
        booking,
        title: 'Unit Ready For Return Inspection',
        message:
            'The driver marked the unit as returned. Complete the after-return checklist, evidence, payment, and ratings. Late fee: ${PricingPolicy.peso(lateReturnFee)}. Final total: ${PricingPolicy.peso(recalculatedTotal)}.',
        action: 'returned',
      );

      debugPrint('Booking return is awaiting the after checklist');
      return recalculatedTotal;
    } on PostgrestException catch (e) {
      debugPrint('Database error completing return: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error completing return: $e');
      rethrow;
    }
  }

  /// Starts a booking after the responsible operator or partner completes the
  /// release checklist. This is also used for self-drive bookings that do not
  /// have a driver pickup action.
  Future<void> startBookingAfterInspection({
    required String bookingId,
    required String inspectorId,
  }) async {
    final inspectionService = BookingInspectionService();
    await inspectionService.assertResponsibleInspector(
      bookingId: bookingId,
      inspectorId: inspectorId,
    );
    final inspection = await inspectionService.getCompletedInspection(
      bookingId: bookingId,
      inspectionType: 'before',
    );

    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    if (!BookingInspectionService.isPreInspectionUnlocked(booking)) {
      throw Exception('Pre-trip car inspection is locked until 24 hours before the actual booking start time.');
    }

    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    if (status != 'approved' && status != 'confirmed') {
      if (status == 'active' || status == 'ongoing') return;
      throw Exception('Only approved bookings can begin their trip');
    }

    // Stakeholder Rule: Before giving keys / releasing car, booking must be 100% fully paid!
    if (!isBookingFullyPaid(booking)) {
      final balance = getBookingRemainingBalance(booking);
      throw Exception(
        'Cannot release vehicle keys: Full payment is required before handover. Remaining balance: PHP ${balance.toStringAsFixed(2)}. Please settle payment first.',
      );
    }
    await _postInspectionAuditToBookingChat(
      booking: booking,
      inspection: inspection,
      inspectionType: 'before',
    );

    final now = DateTime.now().toIso8601String();
    await supabase
        .from('bookings')
        .update({'status': 'active', 'picked_up_at': now, 'updated_at': now})
        .eq('id', bookingId);

    final driverId = booking['driver_id']?.toString();
    if (driverId?.isNotEmpty == true) {
      try {
        await supabase
            .from('driver_job_assignments')
            .update({'status': 'in_progress', 'updated_at': now})
            .eq('booking_id', bookingId)
            .eq('driver_id', driverId!);
      } catch (e) {
        debugPrint('Could not start driver assignment: $e');
      }
    }

    final renterId = booking['renter_id']?.toString();
    if (renterId?.isNotEmpty == true) {
      await NotificationService().createNotification(
        userId: renterId!,
        title: 'Trip Started',
        message:
            'The release checklist is complete and your booking is now ongoing.',
        type: 'booking_ongoing',
        data: {'booking_id': bookingId, 'vehicle_id': booking['vehicle_id']},
      );
    }
  }

  /// Records the returned vehicle after the responsible operator or partner
  /// submits the after checklist. If payment is confirmed, booking is completed.
  /// If payment is unpaid, return goes through but booking stays ongoing / awaiting payment.
  Future<void> completeBookingAfterInspection({
    required String bookingId,
    required String inspectorId,
    bool confirmPaymentIfUnpaid = false,
  }) async {
    final inspectionService = BookingInspectionService();
    await inspectionService.assertResponsibleInspector(
      bookingId: bookingId,
      inspectorId: inspectorId,
    );
    final inspection = await inspectionService.getCompletedInspection(
      bookingId: bookingId,
      inspectionType: 'after',
    );

    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');
    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    if (status == 'completed' ||
        status == 'cancelled' ||
        status == 'rejected') {
      return;
    }
    await _postInspectionAuditToBookingChat(
      booking: booking,
      inspection: inspection,
      inspectionType: 'after',
    );

    final returnedAt = DateTime.now();
    final now = returnedAt.toIso8601String();
    final lateReturn = _lateReturnValues(booking, returnedAt);

    final currentPaymentStatus =
        booking['final_payment_status']?.toString().trim().toLowerCase() ??
        'pending';
    final isPaid = currentPaymentStatus == 'paid' || confirmPaymentIfUnpaid;

    if (isPaid) {
      await supabase
          .from('bookings')
          .update({
            'status': 'completed',
            'returned_at': now,
            'completed_at': now,
            'final_payment_status': 'paid',
            'final_payment_confirmed_at': now,
            'final_payment_confirmed_by': inspectorId,
            ...lateReturn,
            'updated_at': now,
          })
          .eq('id', bookingId);

      try {
        await LoyaltyService().awardPointsForCompletedBooking(bookingId);
      } catch (e) {
        debugPrint('Could not award loyalty points: $e');
      }
    } else {
      // Payment has NOT been confirmed yet. Return goes through, but booking stays ongoing!
      await supabase
          .from('bookings')
          .update({
            'status': 'ongoing',
            'returned_at': now,
            'completion_stage': 'awaiting_payment',
            'final_payment_status': 'pending',
            ...lateReturn,
            'updated_at': now,
          })
          .eq('id', bookingId);
    }

    try {
      await supabase
          .from('tracking_locations')
          .delete()
          .eq('booking_id', bookingId);
    } catch (_) {}

    try {
      await TripRatingService().syncRatingFlowForBooking(
        bookingId,
        operatorFallbackUserId: inspectorId,
      );
    } catch (e) {
      debugPrint('Could not sync rating flow: $e');
    }

    final driverId = booking['driver_id']?.toString();
    if (driverId?.isNotEmpty == true) {
      await supabase
          .from('users')
          .update({'is_available': true})
          .eq('id', driverId!);
      try {
        await supabase
            .from('driver_job_assignments')
            .update({
              'status': isPaid ? 'completed' : 'awaiting_completion',
              'updated_at': now,
            })
            .eq('booking_id', bookingId)
            .eq('driver_id', driverId);
      } catch (e) {
        debugPrint('Could not update driver assignment: $e');
      }
    }

    final renterId = booking['renter_id']?.toString();
    if (renterId?.isNotEmpty == true) {
      await NotificationService().createNotification(
        userId: renterId!,
        title: 'Vehicle Return Inspected & Trip Completed',
        message:
            'The return inspection is complete and your trip is marked as completed! Don\'t forget to rate your experience.',
        type: 'trip_completed',
        data: {'booking_id': bookingId, 'vehicle_id': booking['vehicle_id']},
      );
    }

    // Automated vehicle unlisting for turnaround / cleaning & inspection
    try {
      final vehicleId = booking['vehicle_id']?.toString();
      if (vehicleId != null && vehicleId.isNotEmpty) {
        final vehicle = booking['vehicles'] as Map<String, dynamic>?;
        final partnerVehicleId = booking['partner_vehicle_id']?.toString() ??
            vehicle?['partner_vehicle_id']?.toString();
        final vehicleTitle = _vehicleTitle(vehicle);
        final partnerId = vehicle?['owner_id']?.toString();

        await VehicleTurnaroundService().handleVehicleReturn(
          vehicleId: vehicleId,
          partnerVehicleId: partnerVehicleId,
          bookingId: bookingId,
          vehicleTitle: vehicleTitle,
          partnerId: partnerId,
        );
      }
    } catch (turnaroundErr) {
      debugPrint('Could not initiate vehicle turnaround: $turnaroundErr');
    }
  }

  Future<void> _postInspectionAuditToBookingChat({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> inspection,
    required String inspectionType,
  }) async {
    try {
      final bookingId = booking['id']?.toString() ?? '';
      final inspectorId = inspection['inspector_id']?.toString() ?? '';
      if (bookingId.isEmpty || inspectorId.isEmpty) return;

      try {
        await _ensureBookingGroupChatAndSummary(
          booking: booking,
          vehicleTitle: _vehicleTitle(
            booking['vehicles'] as Map<String, dynamic>?,
          ),
          summaryTitle: 'Booking Confirmed',
        );
      } catch (_) {}

      final conversation = await ChatService().getConversationByBookingId(
        bookingId,
      );
      final conversationId = conversation?['id']?.toString() ?? '';
      if (conversationId.isEmpty) {
        debugPrint(
          'The booking conversation could not be prepared for audit message',
        );
        return;
      }

      final inspector = await _getUserById(inspectorId);
      final inspectorName =
          inspector?['full_name']?.toString().trim().isNotEmpty == true
          ? inspector!['full_name'].toString().trim()
          : 'Responsible inspector';
      final inspectorRole = inspector?['role']?.toString().trim().toLowerCase();
      final roleLabel = inspectorRole == 'partner' ? 'Partner' : 'Operator';
      final normalizedType = inspectionType.trim().toLowerCase();
      final isBefore = normalizedType == 'before';
      final evidence = inspection['evidence_urls'] is List
          ? List<dynamic>.from(inspection['evidence_urls'] as List)
                .map((item) => item.toString().trim())
                .where((url) => url.isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      final checklist = inspection['checklist_items'] is Map
          ? Map<String, dynamic>.from(inspection['checklist_items'] as Map)
          : const <String, dynamic>{};
      final checkedSectionLines = <String>[];
      var checkedCount = 0;
      for (final section
          in BookingInspectionService.checklistSections.entries) {
        final confirmedLabels = section.value.entries
            .where((entry) => checklist[entry.key] == true)
            .map((entry) => entry.value)
            .toList(growable: false);
        checkedCount += confirmedLabels.length;
        if (confirmedLabels.isNotEmpty) {
          checkedSectionLines.add('• ${section.key.toUpperCase()}');
          for (final label in confirmedLabels) {
            checkedSectionLines.add('  - $label');
          }
        }
      }

      final evidenceUrl = evidence.isNotEmpty ? evidence.first : null;
      final lowerEvidenceUrl = evidenceUrl?.toLowerCase() ?? '';
      final evidenceType =
          lowerEvidenceUrl.contains('.mp4') ||
              lowerEvidenceUrl.contains('.mov') ||
              lowerEvidenceUrl.contains('.webm')
          ? 'video'
          : 'image';
      final inspectionId =
          inspection['id']?.toString() ??
          '$bookingId-$normalizedType-$inspectorId';
      final title = isBefore
          ? 'Before-Release Checklist Submitted'
          : 'After-Return Checklist Submitted';
      final content = <String>[
        title,
        'Submitted by: $inspectorName ($roleLabel)',
        'Fuel level: ${inspection['fuel_level'] ?? 'Recorded'}',
        'Mileage: ${inspection['mileage'] ?? 'Recorded'} km',
        'Cleanliness: ${inspection['cleanliness'] ?? 'Recorded'}',
        'Checklist: $checkedCount/${BookingInspectionService.requiredChecklistKeys.length} items confirmed',
        'Evidence: ${evidence.length} photo/video file${evidence.length == 1 ? '' : 's'} attached',
        'Released by: ${inspection['released_by'] ?? 'N/A'}',
        'Received by: ${inspection['received_by'] ?? 'N/A'}',
        if (inspection['scratches']?.toString().trim().isNotEmpty == true)
          'Scratches: ${inspection['scratches']}',
        if (inspection['dents']?.toString().trim().isNotEmpty == true)
          'Dents: ${inspection['dents']}',
        if (inspection['damages']?.toString().trim().isNotEmpty == true)
          'Damages: ${inspection['damages']}',
        if (inspection['remarks']?.toString().trim().isNotEmpty == true)
          'Remarks: ${inspection['remarks']}',
        if (checkedSectionLines.isNotEmpty) '',
        if (checkedSectionLines.isNotEmpty) 'CONFIRMED CHECKLIST ITEMS',
        ...checkedSectionLines,
        '',
        isBefore
            ? 'The vehicle release record is now visible to every booking participant.'
            : 'The vehicle return record is now visible to every booking participant. The trip remains pending until full payment and every mandatory participant rating is recorded.',
      ].join('\n');

      await ChatService().sendBookingAuditMessage(
        conversationId: conversationId,
        senderId: inspectorId,
        content: content,
        auditKey: 'vehicle-checklist:$normalizedType:$inspectionId',
        attachmentUrl: evidenceUrl,
        attachmentType: evidenceUrl == null ? null : evidenceType,
        attachmentName: evidenceUrl == null
            ? null
            : '${isBefore ? 'before-release' : 'after-return'}-evidence-1-of-${evidence.length}',
      );
    } catch (e) {
      debugPrint('Error posting inspection audit to chat: $e');
    }
  }

  /// Calculates late return hours and fees for a booking at a given return timestamp.
  Map<String, dynamic> getLateReturnDetails(
    Map<String, dynamic> booking,
    DateTime returnedAt,
  ) {
    return _lateReturnValues(booking, returnedAt);
  }

  Map<String, dynamic> _lateReturnValues(
    Map<String, dynamic> booking,
    DateTime returnedAt,
  ) {
    final scheduledReturn =
        DateTime.tryParse(booking['end_at']?.toString() ?? '') ??
        DateTime.tryParse(booking['end_date']?.toString() ?? '');
    final lateSeconds = scheduledReturn == null
        ? 0
        : returnedAt.difference(scheduledReturn).inSeconds;
    final lateHours = lateSeconds <= 0
        ? 0
        : math.max(1, (lateSeconds / Duration.secondsPerHour).ceil());

    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final seats = (vehicle?['seats'] as num?)?.toInt() ??
        (booking['seats'] as num?)?.toInt() ??
        4;
    final explicitDailyRate =
        (vehicle?['daily_rate'] as num?)?.toDouble() ??
        (vehicle?['price_per_day'] as num?)?.toDouble();
    final days = (booking['days'] as num?)?.toInt() ?? 1;
    final currentTotal =
        _asDouble(booking['total_price']) ??
        _asDouble(booking['total_cost']) ??
        0.0;
    final dailyRate = explicitDailyRate ?? (currentTotal / (days > 0 ? days : 1));

    final lateFee = PricingPolicy.calculateLateReturnFee(
      seats: seats,
      lateHours: lateHours,
      dailyRate: dailyRate,
    );

    final existingLateFee = _asDouble(booking['late_return_fee']) ?? 0.0;
    final totalWithoutPreviousLateFee = math.max(
      0.0,
      currentTotal - existingLateFee,
    );
    final finalTotal = totalWithoutPreviousLateFee + lateFee;
    return {
      'late_return_hours': lateHours,
      'late_return_days': lateHours == 0 ? 0 : (lateHours / 24).ceil(),
      'late_return_fee': lateFee,
      'total_price': finalTotal,
      'total_cost': finalTotal,
    };
  }

  int _inclusiveRentalDays(DateTime startDate, DateTime endDate) {
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final calendarDays = endDay.difference(startDay).inDays + 1;
    return calendarDays < 1 ? 1 : calendarDays;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool _isExplicitlyUnavailable(dynamic value) {
    if (value is bool) return value == false;
    if (value is String) return value.toLowerCase() == 'false';
    return false;
  }

  bool _isVerifiedDriverStatus(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';
    return status == 'verified' ||
        status == 'approved' ||
        status == 'certified' ||
        status == 'active';
  }

  Future<Map<String, dynamic>?> _getDriverAssignmentTarget(
    String driverIdOrUserId,
  ) async {
    final cleanId = driverIdOrUserId.trim();
    if (cleanId.isEmpty) return null;

    // 1. Try finding in drivers table
    try {
      final driver = await supabase
          .from('drivers')
          .select('id, user_id, verification_status')
          .or('id.eq.$cleanId,user_id.eq.$cleanId')
          .maybeSingle();

      if (driver != null) {
        final userId = driver['user_id']?.toString() ?? cleanId;
        final user = await supabase
            .from('users')
            .select('id, full_name, role, is_available')
            .eq('id', userId)
            .maybeSingle();

        return {
          'driver_id': driver['id']?.toString() ?? cleanId,
          'user_id': userId,
          'verification_status': driver['verification_status'] ?? 'verified',
          'full_name': user?['full_name'] ?? 'Driver',
          'is_available': user?['is_available'] != false,
        };
      }
    } catch (e) {
      debugPrint('Driver table lookup note: $e');
    }

    // 2. Fallback: Lookup directly in users table
    try {
      final user = await supabase
          .from('users')
          .select('id, full_name, role, is_available')
          .eq('id', cleanId)
          .maybeSingle();

      if (user != null) {
        return {
          'driver_id': cleanId,
          'user_id': cleanId,
          'verification_status': 'verified',
          'full_name': user['full_name'] ?? 'Driver',
          'is_available': user['is_available'] != false,
        };
      }
    } catch (e) {
      debugPrint('User table driver target lookup note: $e');
    }

    return null;
  }

  Future<String?> _getDriverProfileIdForUser(String userId) async {
    final driver = await supabase
        .from('drivers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return driver?['id']?.toString();
  }

  Future<String?> _getDriverUserIdForProfile(String driverProfileId) async {
    final driver = await supabase
        .from('drivers')
        .select('user_id')
        .eq('id', driverProfileId)
        .maybeSingle();
    return driver?['user_id']?.toString();
  }

  Future<String?> _resolveDriverUserId(String driverIdOrUserId) async {
    final byUserId = await supabase
        .from('drivers')
        .select('user_id')
        .eq('user_id', driverIdOrUserId)
        .maybeSingle();
    final existingUserId = byUserId?['user_id']?.toString();
    if (existingUserId != null && existingUserId.isNotEmpty) {
      return existingUserId;
    }

    return _getDriverUserIdForProfile(driverIdOrUserId);
  }

  bool _hasTripConfirmation(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isNotEmpty;
  }

  String? _tripConfirmationColumnForRole(String role) {
    switch (role) {
      case 'operator':
        return 'operator_trip_confirmed_at';
      case 'partner':
        return 'partner_trip_confirmed_at';
      case 'driver':
        return 'driver_trip_confirmed_at';
      case 'renter':
        return 'renter_trip_confirmed_at';
      default:
        return null;
    }
  }

  Future<void> _notifyOperatorsForBooking(
    Map<String, dynamic> booking, {
    required String title,
    required String message,
    required String action,
  }) async {
    final operatorIds = <String>{};
    final operatorId = booking['operator_id']?.toString();
    if (operatorId != null && operatorId.isNotEmpty) {
      operatorIds.add(operatorId);
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleOperatorId = vehicle?['operator_id']?.toString();
    if (vehicleOperatorId != null && vehicleOperatorId.isNotEmpty) {
      operatorIds.add(vehicleOperatorId);
    }

    if (operatorIds.isEmpty) {
      final operators = await supabase
          .from('users')
          .select('id')
          .eq('role', 'operator')
          .limit(20);
      for (final operator in List<Map<String, dynamic>>.from(operators)) {
        final id = operator['id']?.toString();
        if (id != null && id.isNotEmpty) operatorIds.add(id);
      }
    }

    // Also include partner/owner if this vehicle is owned by a partner
    final partnerIds = <String>{};
    final bPartnerId = booking['partner_id']?.toString();
    if (bPartnerId != null && bPartnerId.isNotEmpty) partnerIds.add(bPartnerId);
    final vPartnerId = vehicle?['partner_id']?.toString();
    if (vPartnerId != null && vPartnerId.isNotEmpty) partnerIds.add(vPartnerId);
    final vOwnerId = vehicle?['owner_id']?.toString();
    if (vOwnerId != null && vOwnerId.isNotEmpty) partnerIds.add(vOwnerId);

    for (final rawId in partnerIds) {
      try {
        final partnerDoc = await supabase
            .from('partners')
            .select('user_id')
            .eq('id', rawId)
            .maybeSingle();
        final uId = partnerDoc?['user_id']?.toString().trim();
        if (uId != null && uId.isNotEmpty) {
          operatorIds.add(uId);
        } else {
          operatorIds.add(rawId);
        }
      } catch (_) {
        operatorIds.add(rawId);
      }
    }

    for (final id in operatorIds) {
      try {
        await NotificationService().createNotification(
          userId: id,
          title: title,
          message: message,
          type: 'booking_driver_update',
          data: {
            'booking_id': booking['id'],
            'vehicle_id': booking['vehicle_id'],
            'driver_id': booking['driver_id'],
            'action': action,
          },
        );
      } catch (e) {
        debugPrint('Could not notify operator/partner $id: $e');
      }
    }
  }

  /// Checks whether a booking is eligible for automatic group chat creation.
  /// Group chats are automatically created 3 days (72 hours) before the scheduled start time,
  /// or immediately if the booking is starting within 3 days or already active/ongoing.
  bool isEligibleForBookingChat(Map<String, dynamic> booking) {
    final status = (booking['rawStatus'] ?? booking['status'])
        ?.toString()
        .trim()
        .toLowerCase() ?? '';
    const validStatuses = {
      'approved',
      'confirmed',
      'active',
      'ongoing',
      'pending_inspection',
      'return_pending_inspection',
      'awaiting_completion',
      'completed',
    };
    if (!validStatuses.contains(status)) {
      return false;
    }

    // Ongoing, active, inspection, or completed trips are always eligible
    if (status == 'active' ||
        status == 'ongoing' ||
        status == 'pending_inspection' ||
        status == 'return_pending_inspection' ||
        status == 'awaiting_completion' ||
        status == 'completed') {
      return true;
    }

    // For approved/confirmed bookings, check if we are within 3 days before start_at / start_date
    final startRaw = booking['start_at'] ?? booking['start_date'];
    if (startRaw == null) {
      return true; // Fallback if no start date specified
    }

    final startDate = DateTime.tryParse(startRaw.toString());
    if (startDate == null) {
      return true; // Fallback if date cannot be parsed
    }

    // Automatically create if now is on or after (start_date - 3 days)
    final autoCreateThreshold = startDate.subtract(const Duration(days: 3));
    return !DateTime.now().isBefore(autoCreateThreshold);
  }

  /// Synchronizes and auto-creates conversations for approved/confirmed bookings that
  /// have reached the 3-day window before start time.
  Future<void> syncUpcomingBookingConversations({String? userId}) async {
    try {
      const activeStatuses = ['approved', 'confirmed', 'active', 'ongoing'];
      var query = supabase
          .from('bookings')
          .select('''
            id, renter_id, operator_id, driver_id, status, start_at, start_date, end_at, end_date,
            total_price, total_cost, with_driver, conversation_created,
            vehicles!bookings_vehicle_id_fkey(id, brand, model, vehicle_name, plate_number, owner_id, operator_id),
            users!bookings_renter_id_fkey(id, full_name, email, phone)
          ''')
          .inFilter('status', activeStatuses);

      if (userId != null && userId.isNotEmpty) {
        query = query.or('renter_id.eq.$userId,driver_id.eq.$userId,operator_id.eq.$userId');
      }

      final rows = await query.order('updated_at', ascending: false).limit(30);
      final bookings = List<Map<String, dynamic>>.from(rows);

      for (final booking in bookings) {
        if (booking['conversation_created'] == true) continue;
        if (!isEligibleForBookingChat(booking)) continue;

        final vehicle = booking['vehicles'] as Map<String, dynamic>?;
        final vehicleTitle = _vehicleTitle(vehicle);
        await _ensureBookingGroupChatAndSummary(
          booking: booking,
          vehicleTitle: vehicleTitle,
          summaryTitle: 'Booking Confirmed',
        );
      }
    } catch (e) {
      debugPrint('Error syncing upcoming booking conversations: $e');
    }
  }

  Future<void> _ensureBookingGroupChatAndSummary({
    required Map<String, dynamic> booking,
    required String vehicleTitle,
    String summaryTitle = 'Booking Details',
  }) async {
    final bookingId = booking['id']?.toString();
    final renterId = booking['renter_id']?.toString();
    if (bookingId == null ||
        bookingId.isEmpty ||
        renterId == null ||
        renterId.isEmpty) {
      return;
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final ownerId = vehicle?['owner_id']?.toString();
    final operatorId =
        booking['operator_id']?.toString() ??
        vehicle?['operator_id']?.toString() ??
        await _getDefaultOperatorId();
    final driverId = booking['driver_id']?.toString();
    final driverUserId = driverId == null || driverId.isEmpty
        ? null
        : await _resolveDriverUserId(driverId);
    final currentUserId = supabase.auth.currentUser?.id;
    final participantIds = <String>{renterId};
    if (ownerId != null && ownerId.isNotEmpty) {
      participantIds.add(ownerId);
    } else {
      // For company vehicles, add all active operators so all operators can see and reply to chat
      final allOperatorIds = await _getAllOperatorIds();
      participantIds.addAll(allOperatorIds);
    }
    if (operatorId != null && operatorId.isNotEmpty) {
      participantIds.add(operatorId);
    }
    if (currentUserId != null && currentUserId.isNotEmpty) {
      participantIds.add(currentUserId);
    }
    if (driverUserId != null && driverUserId.isNotEmpty) {
      participantIds.add(driverUserId);
    }

    final conversation = await ChatService().createGroupConversation(
      bookingId: bookingId,
      participantIds: participantIds.toList(),
    );

    final hasSummary = await _conversationHasBookingSummary(
      conversation['id'] as String,
    );
    if (hasSummary) {
      await supabase
          .from('bookings')
          .update({'conversation_created': true})
          .eq('id', bookingId);
      return;
    }

    final startLabel = _formatBookingDateTime(
      booking['start_at']?.toString() ?? booking['start_date']?.toString(),
    );
    final endLabel = _formatBookingDateTime(
      booking['end_at']?.toString() ?? booking['end_date']?.toString(),
    );
    final total =
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final withDriver = booking['with_driver'] == true ? 'Yes' : 'No';
    final renter = booking['users'] as Map<String, dynamic>?;
    final renterLabel = _partyLabel(
      renter,
      fallbackName: 'Renter',
      fallbackId: renterId,
    );
    final partner = ownerId == null || ownerId.isEmpty
        ? null
        : await _getUserById(ownerId);
    final partnerLabel = _partyLabel(
      partner,
      fallbackName: 'Partner/Owner',
      fallbackId: ownerId ?? 'N/A',
    );
    final operator = operatorId == null || operatorId.isEmpty
        ? null
        : await _getUserById(operatorId);
    final operatorLabel = operator == null
        ? 'Not assigned yet'
        : _partyLabel(
            operator,
            fallbackName: 'Operator',
            fallbackId: operatorId ?? 'N/A',
          );
    final driver = driverUserId == null || driverUserId.isEmpty
        ? null
        : await _getUserById(driverUserId);
    final driverLabel = booking['with_driver'] == true
        ? (driver == null
              ? 'Requested, waiting for operator assignment'
              : _partyLabel(
                  driver,
                  fallbackName: 'Driver',
                  fallbackId: driverUserId ?? 'N/A',
                ))
        : 'Not requested';
    final plateNumber = vehicle?['plate_number']?.toString();
    final summaryLines = <String>[
      summaryTitle,
      'Vehicle: $vehicleTitle',
      if (plateNumber != null && plateNumber.isNotEmpty)
        'Plate Number: $plateNumber',
      'Booking ID: $bookingId',
      'Status: ${booking['status'] ?? 'pending'}',
      'Schedule: $startLabel -> $endLabel',
      'Total: PHP ${formatAmount(total, decimalDigits: 0)}',
      'With Driver: $withDriver',
      'Renter: $renterLabel',
      'Partner/Owner: $partnerLabel',
      'Operator: $operatorLabel',
      'Driver: $driverLabel',
      'Pickup: ${booking['pickup_location'] ?? 'N/A'}',
      'Drop-off: ${booking['dropoff_location'] ?? 'N/A'}',
      '',
      'Use this conversation for booking coordination and keep updates inside the app.',
    ];
    final summaryMessage = summaryLines.join('\n');

    final senderId = currentUserId ?? renterId;
    await ChatService().sendMessage(
      conversationId: conversation['id'] as String,
      senderId: senderId,
      content: summaryMessage,
      isAutoGenerated: true,
    );

    await supabase
        .from('bookings')
        .update({'conversation_created': true})
        .eq('id', bookingId);
  }

  Future<bool> _conversationHasBookingSummary(String conversationId) async {
    try {
      final existingMessages = await supabase
          .from('messages')
          .select('id, content, message, is_auto_generated')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(30);
      return List<Map<String, dynamic>>.from(existingMessages).any((message) {
        if (message['is_auto_generated'] == true) return true;
        final content =
            (message['content'] ?? message['message'])
                ?.toString()
                .toLowerCase()
                .trim() ??
            '';
        return content.startsWith('booking request created') ||
            content.startsWith('booking details') ||
            content.startsWith('booking confirmed') ||
            content.startsWith('booking approved') ||
            content.startsWith('📋') ||
            content.contains('booking id:') ||
            content.contains('booking confirmed');
      });
    } catch (e) {
      debugPrint('Could not check existing booking summary: $e');
      return false;
    }
  }

  String _vehicleTitle(Map<String, dynamic>? vehicle) {
    if (vehicle == null) return 'Your rental vehicle';
    final vehicleName = vehicle['vehicle_name']?.toString().trim() ?? '';
    if (vehicleName.isNotEmpty) return vehicleName;
    final brand = vehicle['brand']?.toString().trim() ?? '';
    final model = vehicle['model']?.toString().trim() ?? '';
    final title = [brand, model].where((part) => part.isNotEmpty).join(' ');
    return title.isEmpty ? 'Your rental vehicle' : title;
  }

  Future<Map<String, dynamic>?> _getUserById(String userId) async {
    try {
      return await supabase
          .from('users')
          .select('id, full_name, email, phone, role')
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Could not fetch user $userId for booking chat: $e');
      return null;
    }
  }

  Future<String?> _getDefaultOperatorId() async {
    try {
      final operator = await supabase
          .from('users')
          .select('id')
          .eq('role', 'operator')
          .limit(1)
          .maybeSingle();
      return operator?['id']?.toString();
    } catch (e) {
      debugPrint('Could not fetch default operator for booking chat: $e');
      return null;
    }
  }

  Future<List<String>> _getAllOperatorIds() async {
    try {
      final operators = await supabase
          .from('users')
          .select('id')
          .eq('role', 'operator')
          .limit(20);
      return List<Map<String, dynamic>>.from(operators)
          .map((op) => op['id']?.toString().trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Could not fetch all operators: $e');
      return [];
    }
  }

  String _partyLabel(
    Map<String, dynamic>? user, {
    required String fallbackName,
    required String fallbackId,
  }) {
    final name = user?['full_name']?.toString().trim();
    final email = user?['email']?.toString().trim();
    final phone = user?['phone']?.toString().trim();
    final role = user?['role']?.toString().trim();
    final parts = <String>[
      if (name != null && name.isNotEmpty) name else fallbackName,
      if (role != null && role.isNotEmpty) 'Role: $role',
      if (email != null && email.isNotEmpty) email,
      if (phone != null && phone.isNotEmpty) phone,
      'ID: ${user?['id'] ?? fallbackId}',
    ];
    return parts.join(' | ');
  }

  Future<void> _sendBookingGroupMessage({
    required String bookingId,
    required String senderId,
    required String content,
  }) async {
    final conversation = await supabase
        .from('conversations')
        .select('id')
        .eq('booking_id', bookingId)
        .maybeSingle();
    if (conversation == null) return;
    await ChatService().sendMessage(
      conversationId: conversation['id'] as String,
      senderId: senderId,
      content: content,
    );
  }

  String _formatBookingDateTime(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    final local = parsed.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour12:$minute $suffix';
  }

  // ================== SEARCH & FILTER ==================

  /// Search bookings by multiple criteria
  Future<List<Map<String, dynamic>>> searchBookings({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? renterId,
    String? driverId,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      debugPrint('Searching bookings with filters');

      var query = supabase
          .from('bookings')
          .select(
            'id, renter_id, vehicle_id, start_at, end_at, start_date, end_date, status, total_price, pickup_location, dropoff_location, created_at, vehicles(brand, model, year, plate_number), users:users!bookings_renter_id_fkey(full_name, email)',
          );

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      if (startDate != null) {
        query = query.gte('start_date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('end_date', endDate.toIso8601String());
      }

      if (location != null && location.isNotEmpty) {
        query = query.or(
          'pickup_location.ilike.%$location%,dropoff_location.ilike.%$location%',
        );
      }

      if (renterId != null && renterId.isNotEmpty) {
        query = query.eq('renter_id', renterId);
      }

      if (driverId != null && driverId.isNotEmpty) {
        query = query.eq('driver_id', driverId);
      }

      if (minPrice != null) {
        query = query.gte('total_price', minPrice);
      }

      if (maxPrice != null) {
        query = query.lte('total_price', maxPrice);
      }

      final response = await query.order('created_at', ascending: false);

      debugPrint('Found ${response.length} matching bookings');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error searching bookings: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error searching bookings: $e');
      return [];
    }
  }

  /// Get booking statistics by date range
  Future<Map<String, dynamic>> getBookingStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('Fetching booking stats');

      var totalQuery = supabase
          .from('bookings')
          .select('id, total_price, status');

      if (startDate != null) {
        totalQuery = totalQuery.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        totalQuery = totalQuery.lte('created_at', endDate.toIso8601String());
      }

      final allBookings = List<Map<String, dynamic>>.from(await totalQuery);

      // Calculate stats
      int completed = 0;
      int cancelled = 0;
      int active = 0;
      double totalRevenue = 0;

      for (var booking in allBookings) {
        final status = booking['status'] as String?;
        final price = (booking['total_price'] as num?)?.toDouble() ?? 0;

        if (status == 'completed') {
          completed++;
          totalRevenue += price;
        } else if (status == 'cancelled') {
          cancelled++;
        } else if (status == 'active') {
          active++;
        }
      }

      return {
        'total_bookings': allBookings.length,
        'completed': completed,
        'cancelled': cancelled,
        'active': active,
        'total_revenue': totalRevenue,
        'average_booking_value': allBookings.isNotEmpty
            ? totalRevenue / allBookings.length
            : 0,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching stats: ${e.message}');
      return {};
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      return {};
    }
  }

  /// Checks if a booking can be extended and determines the maximum allowed extension date
  /// before any subsequent booking or reservation starts.
  Future<({
    bool canExtend,
    DateTime? maxAllowedExtensionDate,
    DateTime? nextBookingStart,
    String? blockingReason,
  })> getTripExtensionAvailability({
    required String bookingId,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) {
        return (
          canExtend: false,
          maxAllowedExtensionDate: null,
          nextBookingStart: null,
          blockingReason: 'Booking not found',
        );
      }

      final rentalType = (booking['rental_type'] ?? booking['rentalType'] ?? '').toString().toLowerCase().trim();
      final isExplicitSelfDrive = rentalType == 'self_drive' || rentalType == 'self drive' || rentalType == 'selfdrive';
      final withDriver = !isExplicitSelfDrive && (booking['with_driver'] == true ||
          booking['with_driver'] == 1 ||
          booking['with_driver']?.toString().toLowerCase() == 'true' ||
          booking['withDriver'] == true);

      if (withDriver) {
        return (
          canExtend: false,
          maxAllowedExtensionDate: null,
          nextBookingStart: null,
          blockingReason:
              'Trip extensions are only applicable for Self Drive rentals. Bookings with a driver cannot be extended.',
        );
      }

      final vehicleId = booking['vehicle_id']?.toString() ?? booking['partner_vehicle_id']?.toString() ?? '';
      final endRaw =
          booking['end_at']?.toString() ?? booking['end_date']?.toString();
      final currentEndAt = endRaw != null
          ? DateTime.tryParse(endRaw)?.toLocal()
          : null;

      if (vehicleId.isEmpty || currentEndAt == null) {
        return (
          canExtend: false,
          maxAllowedExtensionDate: null,
          nextBookingStart: null,
          blockingReason: 'Invalid booking date details',
        );
      }

      final currentEndDay = DateTime(
        currentEndAt.year,
        currentEndAt.month,
        currentEndAt.day,
      );
      final initialFirstDate = currentEndDay.add(const Duration(days: 1));

      // Fetch all bookings for this vehicle excluding the current booking
      final response = await supabase
          .from('bookings')
          .select('id,start_at,end_at,start_date,end_date,status')
          .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
          .neq('id', bookingId);

      final futureIntervals = <(DateTime, DateTime)>[];
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final status = row['status']?.toString();
        if (!_isBlockingStatus(status)) continue;
        final interval = _bookingInterval(row);
        if (interval == null) continue;
        final (start, end) = interval;
        // If this booking ends after our current end time or starts on/after our end day, it impacts future extension
        if (end.isAfter(currentEndAt) || !start.isBefore(currentEndDay)) {
          futureIntervals.add((start, end));
        }
      }

      // Sort by start date ascending to find the earliest conflicting upcoming booking
      futureIntervals.sort((a, b) => a.$1.compareTo(b.$1));

      DateTime maxLastDate = initialFirstDate.add(const Duration(days: 30));
      if (futureIntervals.isNotEmpty) {
        final earliestNextBooking = futureIntervals.first;
        final nextStart = earliestNextBooking.$1;
        final nextStartDay = DateTime(nextStart.year, nextStart.month, nextStart.day);

        // If the next booking starts on or before the first possible extension day, extension is impossible
        if (nextStart.isBefore(currentEndAt) || nextStartDay.isBefore(initialFirstDate) || nextStartDay == initialFirstDate) {
          final formattedDate = '${nextStart.month}/${nextStart.day}/${nextStart.year}';
          return (
            canExtend: false,
            maxAllowedExtensionDate: null,
            nextBookingStart: nextStart,
            blockingReason: 'This vehicle is already reserved for another customer starting $formattedDate. Trip extension is not available.',
          );
        }

        // The maximum allowed extension date is strictly the day before the next booking starts
        final contiguousMax = nextStartDay.subtract(const Duration(days: 1));
        if (contiguousMax.isBefore(initialFirstDate)) {
          final formattedDate = '${nextStart.month}/${nextStart.day}/${nextStart.year}';
          return (
            canExtend: false,
            maxAllowedExtensionDate: null,
            nextBookingStart: nextStart,
            blockingReason: 'This vehicle is already reserved for another customer starting $formattedDate. Trip extension is not available.',
          );
        }

        if (contiguousMax.isBefore(maxLastDate)) {
          maxLastDate = contiguousMax;
        }
      }

      return (
        canExtend: true,
        maxAllowedExtensionDate: maxLastDate,
        nextBookingStart: futureIntervals.isNotEmpty ? futureIntervals.first.$1 : null,
        blockingReason: null,
      );
    } catch (e) {
      debugPrint('Error checking trip extension availability: $e');
      return (
        canExtend: false,
        maxAllowedExtensionDate: null,
        nextBookingStart: null,
        blockingReason: 'Error checking availability: $e',
      );
    }
  }

  /// Renter requests a trip extension for an active booking.
  Future<void> requestTripExtension({
    required String bookingId,
    required DateTime newEndAt,
    required double additionalPrice,
    required int extensionDays,
    String? newDestination,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final rentalType = (booking['rental_type'] ?? booking['rentalType'] ?? '').toString().toLowerCase().trim();
      final isExplicitSelfDrive = rentalType == 'self_drive' || rentalType == 'self drive' || rentalType == 'selfdrive';
      final withDriver = !isExplicitSelfDrive && (booking['with_driver'] == true ||
          booking['with_driver'] == 1 ||
          booking['with_driver']?.toString().toLowerCase() == 'true' ||
          booking['withDriver'] == true);

      if (withDriver) {
        throw Exception(
          'Trip extensions are only applicable for Self Drive rentals. Bookings with a driver cannot be extended.',
        );
      }

      if (booking['safety_freeze'] == true) {
        throw Exception(
          'This trip is currently under a Safety Freeze and cannot be extended. Please contact support.',
        );
      }

      final renterId = booking['renter_id']?.toString() ?? '';
      if (renterId.isNotEmpty) {
        final restriction = await UserRestrictionService().getUserRestriction(
          renterId,
        );
        if (restriction.isBlocked || restriction.isAccountRestricted) {
          throw Exception(
            'Your account is under safety review and cannot request trip extensions. Please return the vehicle by the scheduled time.',
          );
        }
      }

      final currentEndRaw =
          booking['end_at']?.toString() ?? booking['end_date']?.toString();
      final currentEndAt = currentEndRaw != null
          ? DateTime.tryParse(currentEndRaw)?.toLocal()
          : null;
      if (currentEndAt != null && !newEndAt.isAfter(currentEndAt)) {
        throw Exception(
          'Extended return date must be after your current return date.',
        );
      }

      final vehicleId = booking['vehicle_id']?.toString() ?? booking['partner_vehicle_id']?.toString() ?? '';
      final overlappingBookings = await supabase
          .from('bookings')
          .select('id,start_at,end_at,start_date,end_date,status')
          .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
          .neq('id', bookingId);

      final extensionStart = currentEndAt ?? DateTime.now();
      for (final b in List<Map<String, dynamic>>.from(overlappingBookings)) {
        final status = b['status']?.toString();
        if (!_isBlockingStatus(status)) continue;
        final interval = _bookingInterval(b);
        if (interval == null) continue;
        final (existingStart, existingEnd) = interval;
        if (extensionStart.isBefore(existingEnd) && newEndAt.isAfter(existingStart)) {
          final startFormatted = '${existingStart.month}/${existingStart.day}/${existingStart.year}';
          final endFormatted = '${existingEnd.month}/${existingEnd.day}/${existingEnd.year}';
          throw Exception(
            'This vehicle has already been reserved by another customer for $startFormatted - $endFormatted. Extension is not available for these dates.',
          );
        }
      }

      final principalPrice =
          (booking['principal_total_price'] as num?)?.toDouble() ??
          (booking['total_price'] as num?)?.toDouble() ??
          0.0;

      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final isPartnerVehicle = _isPartnerBookingVehicle(vehicle);

      await safeUpdateBooking(bookingId, {
        'extension_requested_end_at': newEndAt.toIso8601String(),
        if (newDestination != null && newDestination.trim().isNotEmpty)
          'extension_requested_destination': newDestination.trim(),
        'extension_additional_price': additionalPrice,
        'extension_days': extensionDays,
        'extension_status': 'pending',
        'extension_payment_status': 'unpaid',
        'extension_requested_at': DateTime.now().toIso8601String(),
        'principal_total_price': principalPrice,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Create or locate conversation for this booking
      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      final renterName =
          booking['renter']?['full_name']?.toString() ??
          booking['users']?['full_name']?.toString() ??
          'Renter';
      final vehicleTitle = _vehicleTitle(vehicle);
      final formattedDate = '${newEndAt.month}/${newEndAt.day}/${newEndAt.year}';
      final destMsg = newDestination != null && newDestination.trim().isNotEmpty
          ? ' to "$newDestination"'
          : '';
      final msg =
          'Trip Extension Requested: $renterName requested extending trip until $formattedDate$destMsg (+PHP ${additionalPrice.toStringAsFixed(2)}). Awaiting ${isPartnerVehicle ? "Partner" : "Operator"} review.';

      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: renterId,
            content: msg,
          );
        }
      }

      // Send push notification to operators & partner
      unawaited(
        NotificationService().notifyOperatorsNewBooking(
          bookingId: bookingId,
          vehicleTitle: vehicleTitle,
          renterName: renterName,
          withDriver: false,
          partnerId: booking['partner_id']?.toString() ?? vehicle['partner_id']?.toString(),
          ownerId: vehicle['owner_id']?.toString(),
          vehicleId: (booking['vehicle_id'] ?? booking['partner_id'] ?? vehicle['id'])?.toString(),
        ).catchError((_) => 0),
      );
    } catch (e) {
      debugPrint('Error requesting trip extension: $e');
      rethrow;
    }
  }

  /// Instant Trip Extension with immediate online payment:
  /// Validates availability, commits new end return date, totals, and records the online payment proof in one immediate transaction.
  Future<void> submitInstantTripExtensionWithPayment({
    required String bookingId,
    required DateTime newEndAt,
    required double additionalPrice,
    required int extensionDays,
    required String paymentMethod,
    required String paymentReference,
    String? proofUrl,
    String? newDestination,
    String? renterId,
  }) async {
    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    final rentalType = (booking['rental_type'] ?? booking['rentalType'] ?? '').toString().toLowerCase().trim();
    final isExplicitSelfDrive = rentalType == 'self_drive' || rentalType == 'self drive' || rentalType == 'selfdrive';
    final withDriver = !isExplicitSelfDrive && (booking['with_driver'] == true ||
        booking['with_driver'] == 1 ||
        booking['with_driver']?.toString().toLowerCase() == 'true' ||
        booking['withDriver'] == true);

    if (withDriver) {
      throw Exception(
        'Trip extensions are only applicable for Self Drive rentals. Bookings with a driver cannot be extended.',
      );
    }

    if (booking['safety_freeze'] == true) {
      throw Exception(
        'This trip is currently under a Safety Freeze and cannot be extended. Please contact support.',
      );
    }

    final effectiveRenterId = renterId ??
        booking['renter_id']?.toString() ??
        supabase.auth.currentUser?.id ??
        '';
    if (effectiveRenterId.isNotEmpty) {
      final restriction =
          await UserRestrictionService().getUserRestriction(effectiveRenterId);
      if (restriction.isBlocked || restriction.isAccountRestricted) {
        throw Exception(
          'Your account is under safety review and cannot request trip extensions. Please return the vehicle by the scheduled time.',
        );
      }
    }

    final currentEndRaw =
        booking['end_at']?.toString() ?? booking['end_date']?.toString();
    final currentEndAt = currentEndRaw != null
        ? DateTime.tryParse(currentEndRaw)?.toLocal()
        : null;
    if (currentEndAt != null && !newEndAt.isAfter(currentEndAt)) {
      throw Exception(
        'Extended return date must be after your current return date.',
      );
    }

    final vehicleId = (booking['vehicle_id'] ?? booking['partner_vehicle_id'])?.toString().trim() ?? '';
    if (vehicleId.isNotEmpty) {
      try {
        final List<dynamic> overlappingBookings = await supabase
            .from('bookings')
            .select('id,start_at,end_at,start_date,end_date,status')
            .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
            .neq('id', bookingId);

        final extensionStart = currentEndAt ?? DateTime.now();
        for (final b in List<Map<String, dynamic>>.from(overlappingBookings)) {
          final status = b['status']?.toString();
          if (!_isBlockingStatus(status)) continue;
          final interval = _bookingInterval(b);
          if (interval == null) continue;
          final (existingStart, existingEnd) = interval;
          if (extensionStart.isBefore(existingEnd) &&
              newEndAt.isAfter(existingStart)) {
            final startFormatted =
                '${existingStart.month}/${existingStart.day}/${existingStart.year}';
            final endFormatted =
                '${existingEnd.month}/${existingEnd.day}/${existingEnd.year}';
            throw Exception(
              'This vehicle has already been reserved by another customer for $startFormatted - $endFormatted. Extension is not available for these dates.',
            );
          }
        }
      } catch (e) {
        if (e.toString().contains('reserved by another customer')) {
          rethrow;
        }
        debugPrint('Non-critical exception during extension overlap check: $e');
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();

    // ⚠️ CRITICAL FIX: Do NOT immediately commit end_at, end_date, total_price, days, or dropoff_location!
    // The extension must be reviewed and explicitly approved/finalized by the Partner/Operator.
    // Trip schedule remains untouched until the Partner/Operator approves.
    await safeUpdateBooking(bookingId, {
      'extension_requested_end_at': newEndAt.toIso8601String(),
      if (newDestination != null && newDestination.trim().isNotEmpty)
        'extension_requested_destination': newDestination.trim(),
      'extension_additional_price': additionalPrice,
      'extension_days': extensionDays,
      'extension_status': 'payment_completed',
      'extension_payment_status': 'pending_review',
      'extension_payment_method': paymentMethod.trim(),
      'extension_payment_reference': paymentReference.trim(),
      if (proofUrl != null && proofUrl.isNotEmpty)
        'extension_payment_proof_url': proofUrl.trim(),
      'extension_payment_submitted_at': now,
      'extension_requested_at': now,
      'updated_at': now,
    });

    // Send conversation message & push notifications
    final conversation =
        await ChatService().getConversationBookingContext(bookingId);
    final renterName = booking['renter']?['full_name']?.toString() ??
        booking['users']?['full_name']?.toString() ??
        'Renter';
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final vehicleTitle = _vehicleTitle(vehicle);
    final formattedDate = '${newEndAt.month}/${newEndAt.day}/${newEndAt.year}';
    final destMsg = newDestination != null && newDestination.trim().isNotEmpty
        ? ' to "$newDestination"'
        : '';
    final msg =
        'Trip Extension Requested with Payment: $renterName requested extension until $formattedDate$destMsg (+PHP ${additionalPrice.toStringAsFixed(2)}) via $paymentMethod (Ref: $paymentReference). Awaiting Partner/Operator review and confirmation.';

    if (conversation != null) {
      final conversationId = conversation['id']?.toString();
      if (conversationId != null) {
        await ChatService().sendMessage(
          conversationId: conversationId,
          senderId: effectiveRenterId,
          content: msg,
        );
      }
    }

    unawaited(
      NotificationService()
          .notifyOperatorsNewBooking(
            bookingId: bookingId,
            vehicleTitle: vehicleTitle,
            renterName: renterName,
            withDriver: false,
            partnerId: booking['partner_id']?.toString() ?? vehicle['partner_id']?.toString(),
            ownerId: vehicle['owner_id']?.toString(),
            vehicleId: (booking['vehicle_id'] ?? booking['partner_id'] ?? vehicle['id'])?.toString(),
          )
          .catchError((_) => 0),
    );
  }

  bool _isPartnerBookingVehicle(Map<String, dynamic> vehicle) {
    final ownerRole = vehicle['owner_role']?.toString().toLowerCase().trim();
    if (ownerRole == 'partner') return true;
    final owner = vehicle['owner'] as Map<String, dynamic>?;
    final role = owner?['role']?.toString().toLowerCase().trim();
    if (role == 'partner') return true;
    final partnerId = vehicle['partner_id']?.toString().trim();
    if (partnerId != null && partnerId.isNotEmpty) return true;
    final ownerId = vehicle['owner_id']?.toString().trim();
    return ownerId != null &&
        ownerId.isNotEmpty &&
        ownerRole != 'operator' &&
        ownerRole != 'admin';
  }

  /// Accept an extension request (Partner for partner vehicle, Operator for operator vehicle).
  Future<void> acceptTripExtension({
    required String bookingId,
    String? reviewerId,
    String? operatorId,
    String? reviewerRole,
  }) async {
    final effectiveReviewerId = reviewerId ?? operatorId ?? '';
    final effectiveRole = reviewerRole ?? (operatorId != null ? 'operator' : 'partner');

    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final isPartnerVehicle = _isPartnerBookingVehicle(vehicle);

      if (isPartnerVehicle && effectiveRole == 'operator') {
        throw Exception(
          'Operator cannot accept extension for a Partner-owned vehicle. Only the Partner can accept.',
        );
      }

      final addPrice =
          (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;

      await supabase
          .from('bookings')
          .update({
            'extension_status': 'payment_pending',
            'extension_payment_status': 'unpaid',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: effectiveReviewerId,
            content:
                'Trip Extension Accepted: Your extension request was accepted! Please pay the extension fee of PHP ${addPrice.toStringAsFixed(2)} in the app to proceed.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error accepting trip extension: $e');
      rethrow;
    }
  }

  /// Backward compatible alias for accepting trip extensions
  Future<void> approveTripExtension({
    required String bookingId,
    String? operatorId,
    String? reviewerId,
    String reviewerRole = 'operator',
  }) async {
    return acceptTripExtension(
      bookingId: bookingId,
      reviewerId: reviewerId ?? operatorId,
      reviewerRole: reviewerRole,
    );
  }

  /// Submit payment for an extension request (by Renter).
  Future<void> submitExtensionPayment({
    required String bookingId,
    String? renterId,
    String? method,
    String? reference,
    String? paymentMethod,
    String? paymentReference,
    String? proofUrl,
  }) async {
    final effectiveMethod = method ?? paymentMethod ?? 'E-Wallet';
    final effectiveReference = reference ?? paymentReference ?? 'N/A';
    final effectiveRenterId = renterId ?? supabase.auth.currentUser?.id ?? '';
    final effectiveProofUrl = proofUrl ?? '';

    try {
      await supabase
          .from('bookings')
          .update({
            'extension_payment_method': effectiveMethod.trim(),
            'extension_payment_reference': effectiveReference.trim(),
            'extension_payment_proof_url': effectiveProofUrl.trim(),
            'extension_payment_submitted_at': DateTime.now().toIso8601String(),
            'extension_payment_status': 'pending_review',
            'extension_status': 'payment_completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: effectiveRenterId,
            content:
                'Extension Payment Submitted: Renter submitted extension fee payment ($effectiveMethod - Ref: $effectiveReference). Awaiting verification.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error submitting extension payment: $e');
      rethrow;
    }
  }

  /// Verify extension payment (Operator for operator vehicle, Partner for partner vehicle).
  Future<void> verifyExtensionPayment({
    required String bookingId,
    required String verifierId,
    String? verifierRole,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final isPartnerVehicle = _isPartnerBookingVehicle(vehicle);

      if (isPartnerVehicle && verifierRole == 'operator') {
        throw Exception(
          'Operator cannot verify payment for a Partner-owned vehicle. Only the Partner can verify.',
        );
      }

      await supabase
          .from('bookings')
          .update({
            'extension_payment_status': 'verified',
            'extension_payment_verified_at': DateTime.now().toIso8601String(),
            'extension_payment_verified_by': verifierId,
            'extension_status': 'pending_final_confirmation',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: verifierId,
            content:
                'Extension Payment Verified: Payment confirmed! Ready for final trip extension confirmation.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error verifying extension payment: $e');
      rethrow;
    }
  }

  /// Finalize trip extension (commits new dates, destination, and fee to booking).
  Future<void> finalizeTripExtension({
    required String bookingId,
    required String finalizerId,
    String? finalizerRole,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final isPartnerVehicle = _isPartnerBookingVehicle(vehicle);

      if (isPartnerVehicle && finalizerRole == 'operator') {
        throw Exception(
          'Operator cannot finalize extension for a Partner-owned vehicle. Only the Partner can finalize.',
        );
      }

      final newEndAtRaw = booking['extension_requested_end_at']?.toString();
      if (newEndAtRaw == null) {
        throw Exception('No requested extension return date found on this booking.');
      }
      final newEndAt = DateTime.parse(newEndAtRaw);
      final addPrice =
          (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;
      final currentTotal =
          (booking['total_price'] as num?)?.toDouble() ??
          (booking['totalCost'] as num?)?.toDouble() ??
          0.0;
      final newTotal = currentTotal + addPrice;
      final requestedDest =
          booking['extension_requested_destination']?.toString();

      final currentDays = (booking['days'] as num?)?.toInt() ?? 1;
      final extDays = (booking['extension_days'] as num?)?.toInt() ?? 1;
      final totalDays = currentDays + extDays;

      await supabase
          .from('bookings')
          .update({
            'end_at': newEndAt.toIso8601String(),
            'end_date': newEndAt.toIso8601String(),
            'total_price': newTotal,
            'totalCost': newTotal,
            'days': totalDays,
            if (requestedDest != null && requestedDest.trim().isNotEmpty)
              'dropoff_location': requestedDest.trim(),
            'extension_status': 'finalized',
            'extension_payment_status': 'paid',
            'extension_finalized_at': DateTime.now().toIso8601String(),
            'extension_finalized_by': finalizerId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: finalizerId,
            content:
                'Trip Extension Finalized: Your trip end date is updated to ${newEndAt.month}/${newEndAt.day}/${newEndAt.year}${requestedDest != null && requestedDest.isNotEmpty ? " (Destination: $requestedDest)" : ""}. New total: PHP ${newTotal.toStringAsFixed(2)}.',
          );
        }
      }

      // In-app notification to renter
      final renterId = booking['renter_id']?.toString();
      if (renterId != null && renterId.isNotEmpty) {
        unawaited(
          supabase.from('notifications').insert({
            'user_id': renterId,
            'title': '🎉 Trip Extension Confirmed',
            'message':
                'Your trip extension until ${newEndAt.month}/${newEndAt.day}/${newEndAt.year} has been approved and confirmed by the vehicle manager.',
            'type': 'extension_approved',
            'data': {
              'booking_id': bookingId,
              'extension_status': 'finalized',
              'new_end_at': newEndAt.toIso8601String(),
            },
            'created_at': DateTime.now().toIso8601String(),
          }).catchError((e) => debugPrint('Error notifying renter of extension approval: $e')),
        );
      }
    } catch (e) {
      debugPrint('Error finalizing trip extension: $e');
      rethrow;
    }
  }

  /// Reject trip extension request.
  /// If the renter has already paid for the extension, payment records are strictly preserved
  /// and a refund process is initiated (extension_refund_status: 'pending_refund').
  Future<void> rejectTripExtension({
    required String bookingId,
    String? reviewerId,
    String? operatorId,
    String? reviewerRole,
    String? reason,
    Map<String, dynamic>? cachedBooking,
  }) async {
    final effectiveReviewerId = reviewerId ?? operatorId ?? '';
    final effectiveRole =
        reviewerRole ?? (operatorId != null ? 'operator' : 'partner');

    try {
      Map<String, dynamic>? booking = cachedBooking;
      if (booking == null) {
        final response = await supabase
            .from('bookings')
            .select(
              '*, vehicles:vehicle_id(id, brand, model, owner_id, partner_id)',
            )
            .eq('id', bookingId)
            .maybeSingle();
        if (response != null) {
          booking = Map<String, dynamic>.from(response);
        }
      }
      if (booking == null) throw Exception('Booking not found');

      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final isPartnerVehicle = _isPartnerBookingVehicle(vehicle);

      if (isPartnerVehicle && effectiveRole == 'operator') {
        throw Exception(
          'Operator cannot reject extension for a Partner-owned vehicle. Only the Partner can reject.',
        );
      }

      final payStatus =
          booking['extension_payment_status']?.toString().toLowerCase().trim() ??
              '';
      final payRef =
          booking['extension_payment_reference']?.toString().trim() ?? '';
      final hasPayment = (payStatus == 'paid' ||
              payStatus == 'verified' ||
              payStatus == 'pending_review') ||
          (payRef.isNotEmpty && payRef != 'N/A');
      final addPrice =
          (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;

      final updates = <String, dynamic>{
        'extension_status': 'rejected',
        'extension_rejection_reason':
            reason ?? 'Extension request declined.',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (hasPayment && addPrice > 0) {
        updates['extension_refund_status'] = 'pending_refund';
        updates['extension_refund_required'] = true;
        updates['extension_refund_amount'] = addPrice;
      }

      await supabase
          .from('bookings')
          .update(updates)
          .eq('id', bookingId);

      final refundNotice = (hasPayment && addPrice > 0)
          ? ' Since you already paid for the extension fee of PHP ${addPrice.toStringAsFixed(2)}, a refund has been initiated and will be returned to you.'
          : '';

      unawaited(
        ChatService()
            .getConversationBookingContext(bookingId)
            .then<void>((conversation) async {
              if (conversation != null) {
                final conversationId = conversation['id']?.toString();
                if (conversationId != null) {
                  await ChatService().sendMessage(
                    conversationId: conversationId,
                    senderId: effectiveReviewerId,
                    content:
                        'Trip Extension Request Declined${reason != null && reason.isNotEmpty ? ": $reason" : ""}.$refundNotice Please return the vehicle according to your scheduled return time.',
                  );
                }
              }
            })
            .catchError(
              (e) => debugPrint('Error sending extension decline chat: $e'),
            ),
      );

      if (hasPayment && addPrice > 0) {
        final renterId = booking['renter_id']?.toString();
        if (renterId != null && renterId.isNotEmpty) {
          unawaited(
            supabase.from('notifications').insert({
              'user_id': renterId,
              'title': '⚠️ Extension Declined • Refund Initiated',
              'message':
                  'Your trip extension request was declined. A refund of PHP ${addPrice.toStringAsFixed(2)} has been initiated for your extension fee.',
              'type': 'extension_refund',
              'data': {
                'booking_id': bookingId,
                'extension_refund_status': 'pending_refund',
                'amount': addPrice,
              },
              'created_at': DateTime.now().toIso8601String(),
            }).catchError((e) => debugPrint('Error notifying renter of extension refund: $e')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error rejecting trip extension: $e');
      rethrow;
    }
  }

  /// Settle refund for a declined paid trip extension (Partner or Operator action)
  Future<void> settleExtensionRefund({
    required String bookingId,
    required double amount,
    required String method,
    required String reference,
    String? receiptUrl,
    String? notes,
    String? settlerId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final effectiveSettlerId =
        settlerId ?? supabase.auth.currentUser?.id ?? '';

    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    await supabase.from('bookings').update({
      'extension_refund_status': 'refunded',
      'extension_refund_completed': true,
      'extension_refund_amount': amount,
      'extension_refund_method': method.trim(),
      'extension_refund_ref': reference.trim(),
      if (receiptUrl != null && receiptUrl.trim().isNotEmpty)
        'extension_refund_receipt_url': receiptUrl.trim(),
      if (notes != null && notes.trim().isNotEmpty)
        'extension_refund_notes': notes.trim(),
      if (effectiveSettlerId.isNotEmpty)
        'extension_refunded_by': effectiveSettlerId,
      'extension_refunded_at': now,
      'updated_at': now,
    }).eq('id', bookingId);

    // Notify renter that extension refund is disbursed
    final renterId = booking['renter_id']?.toString();
    if (renterId != null && renterId.isNotEmpty) {
      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final vehicleTitle = _vehicleTitle(vehicle);
      unawaited(
        supabase.from('notifications').insert({
          'user_id': renterId,
          'title': '💸 Extension Fee Refunded',
          'message':
              'Your extension fee refund of PHP ${amount.toStringAsFixed(2)} for $vehicleTitle has been disbursed ($method, Ref: $reference).',
          'type': 'extension_refund',
          'data': {
            'booking_id': bookingId,
            'extension_refund_status': 'refunded',
            'extension_refund_ref': reference,
            'amount': amount,
          },
          'created_at': now,
        }).catchError((e) => debugPrint('Error notifying renter of extension refund: $e')),
      );

      final conversation =
          await ChatService().getConversationBookingContext(bookingId);
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: effectiveSettlerId,
            content:
                'Extension Fee Refund Disbursed: PHP ${amount.toStringAsFixed(2)} was sent via $method (Ref: $reference). Thank you for your patience.',
          );
        }
      }
    }
  }

  /// Cancel trip extension request (by Renter).
  Future<void> cancelTripExtension({
    required String bookingId,
    required String userId,
  }) async {
    try {
      await supabase
          .from('bookings')
          .update({
            'extension_status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);
    } catch (e) {
      debugPrint('Error cancelling trip extension: $e');
      rethrow;
    }
  }

  /// Fetch all extension requests for an operator or partner.
  Future<List<Map<String, dynamic>>> getExtensionRequests({
    String? operatorId,
    String? partnerId,
  }) async {
    try {
      var query = supabase
          .from('bookings')
          .select('''
            *,
            users:renter_id (*),
            vehicles:vehicle_id (
              *,
              owner:owner_id (*)
            )
          ''')
          .neq('extension_status', 'none')
          .order('extension_requested_at', ascending: false);

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching extension requests: $e');
      return [];
    }
  }

  /// Renter initiates vehicle return and submits final payment settlement.
  Future<void> renterInitiateReturn({
    required String bookingId,
    required String renterId,
    String? paymentMethod,
    String? paymentReference,
    String? proofUrl,
    int? lateHours,
    double? lateFee,
    double? settledAmount,
    Map<String, dynamic>? cachedBooking,
  }) async {
    try {
      final now = DateTime.now();
      final updates = <String, dynamic>{
        'status': 'return_pending_inspection',
        'returned_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      if (paymentMethod != null && paymentMethod.isNotEmpty) {
        updates['final_payment_method'] = paymentMethod;
      }
      if (paymentReference != null && paymentReference.isNotEmpty) {
        updates['final_payment_reference'] = paymentReference;
      }
      if (proofUrl != null && proofUrl.isNotEmpty) {
        updates['final_payment_proof_url'] = proofUrl;
      }
      if (lateHours != null && lateHours > 0) {
        updates['late_return_hours'] = lateHours;
        updates['late_return_fee'] = lateFee ?? (lateHours * 300.0);
      }
      if (settledAmount != null && settledAmount > 0) {
        updates['renter_return_payment_submitted'] = true;
        updates['renter_return_payment_amount'] = settledAmount;
      }

      try {
        await supabase.from('bookings').update(updates).eq('id', bookingId);
      } catch (dbError) {
        debugPrint(
          'Full update failed, attempting fallback return update: $dbError',
        );
        final fallbackUpdates = <String, dynamic>{
          'status': 'return_pending_inspection',
          'returned_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        if (lateHours != null && lateHours > 0) {
          fallbackUpdates['late_return_hours'] = lateHours;
          fallbackUpdates['late_return_fee'] = lateFee ?? (lateHours * 300.0);
        }
        await supabase
            .from('bookings')
            .update(fallbackUpdates)
            .eq('id', bookingId);
      }

      // 🚀 Non-blocking async notification dispatch so the return UI pops up immediately!
      unawaited(() async {
        try {
          final booking = cachedBooking ?? await getBookingById(bookingId);
          final vehicle = (booking?['vehicles'] ??
                  booking?['partner_vehicles'] ??
                  booking?['partner_vehicle'] ??
                  booking?['vehicle']) as Map<String, dynamic>?;
          final vehicleTitle = _vehicleTitle(vehicle);
          final renter = (booking?['renter'] ?? booking?['users']) as Map<String, dynamic>?;
          final renterName =
              renter?['full_name']?.toString().trim().isNotEmpty == true
              ? renter!['full_name'].toString().trim()
              : 'Renter';

          await NotificationService().notifyOperatorsVehicleReturned(
            bookingId: bookingId,
            vehicleTitle: vehicleTitle,
            renterName: renterName,
            paymentMethod: paymentMethod,
            settledAmount: settledAmount,
            partnerId: vehicle?['owner_id']?.toString() ??
                booking?['partner_id']?.toString(),
          );
        } catch (notifError) {
          debugPrint(
            'Could not send return notification to operator: $notifError',
          );
        }
      }());
    } catch (e) {
      debugPrint('Error initiating return: $e');
      rethrow;
    }
  }

  /// Operator or Partner confirms vehicle return after inspection.
  Future<void> confirmVehicleReturn({
    required String bookingId,
    required String reviewerId,
    required String reviewerRole,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final now = DateTime.now();
      final endRaw =
          booking['end_at']?.toString() ?? booking['end_date']?.toString();
      final endAt = endRaw != null
          ? DateTime.tryParse(endRaw)?.toLocal()
          : null;
      final returnedAtRaw = booking['returned_at']?.toString();
      final returnedAt =
          (returnedAtRaw != null
              ? DateTime.tryParse(returnedAtRaw)?.toLocal()
              : null) ??
          now;

      double lateReturnFee = 0.0;
      if (endAt != null && returnedAt.isAfter(endAt)) {
        final lateHours = (returnedAt.difference(endAt).inMinutes / 60.0)
            .ceil();
        if (lateHours > 0) {
          lateReturnFee = lateHours * 200.0;
        }
      }

      final currentTotal = (booking['total_price'] as num?)?.toDouble() ?? 0.0;
      final updatedTotal = currentTotal + lateReturnFee;

      final isFullPaymentAtCreation =
          booking['reservation_payment_covers_total'] == true ||
          booking['reservation_payment_type']?.toString().toLowerCase() ==
              'full_payment';
      final extensionFee =
          (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;

      final isFullySettled =
          isFullPaymentAtCreation && lateReturnFee <= 0 && extensionFee <= 0;
      final finalPaymentStatus = isFullySettled ? 'paid' : 'pending';

      final bookingUpdate = <String, dynamic>{
        'status': 'awaiting_completion',
        'return_confirmed_at': now.toIso8601String(),
        'return_confirmed_by': reviewerId,
        'late_return_fee': lateReturnFee,
        'total_price': updatedTotal,
        'final_payment_status': finalPaymentStatus,
        'updated_at': now.toIso8601String(),
      };

      if (!isFullySettled) {
        bookingUpdate['completion_stage'] = 'awaiting_payment';
      }

      await supabase.from('bookings').update(bookingUpdate).eq('id', bookingId);

      await TripRatingService().syncRatingFlowForBooking(bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: reviewerId,
            content:
                'Vehicle Return Confirmed: Return inspection completed by $reviewerRole. ${lateReturnFee > 0 ? "Late fee applied: PHP ${lateReturnFee.toStringAsFixed(2)}." : "No late fees."}',
          );
        }
      }

      // Automated vehicle unlisting for turnaround / cleaning & inspection
      try {
        final vehicleId = booking['vehicle_id']?.toString();
        if (vehicleId != null && vehicleId.isNotEmpty) {
          final vehicle = booking['vehicles'] as Map<String, dynamic>?;
          final partnerVehicleId = booking['partner_vehicle_id']?.toString() ??
              vehicle?['partner_vehicle_id']?.toString();
          final vehicleTitle = _vehicleTitle(vehicle);
          final partnerId = vehicle?['owner_id']?.toString();

          await VehicleTurnaroundService().handleVehicleReturn(
            vehicleId: vehicleId,
            partnerVehicleId: partnerVehicleId,
            bookingId: bookingId,
            vehicleTitle: vehicleTitle,
            partnerId: partnerId,
          );
        }
      } catch (turnaroundErr) {
        debugPrint('Could not initiate vehicle turnaround: $turnaroundErr');
      }
    } catch (e) {
      debugPrint('Error confirming vehicle return: $e');
      rethrow;
    }
  }

  /// Operator or Admin confirms manual refund disbursement for a cancelled booking.
  /// Updates refund status to 'refunded' and sends instant notifications to the renter and owner.
  Future<Map<String, dynamic>> processRefundDisbursement({
    required String bookingId,
    required String refundReference,
    double? refundAmount,
    String? notes,
    String? operatorId,
  }) async {
    try {
      debugPrint('Processing refund disbursement for booking #$bookingId');

      final cleanRef = refundReference.trim();
      if (cleanRef.isEmpty) {
        throw Exception('Refund transaction reference number is required.');
      }

      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final renterId = booking['renter_id']?.toString() ?? '';
      final vehicle = booking['vehicles'] as Map<String, dynamic>? ??
          booking['vehicle'] as Map<String, dynamic>?;
      final vehicleTitle = vehicle != null
          ? '${vehicle['brand'] ?? vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
          : 'your rental vehicle';

      final amount = refundAmount ??
          (booking['reservation_payment_amount'] as num?)?.toDouble() ??
          (booking['reservation_fee'] as num?)?.toDouble() ??
          (booking['total_amount'] as num?)?.toDouble() ??
          (booking['total_price'] as num?)?.toDouble() ??
          0.0;

      final now = DateTime.now();

      await supabase.from('bookings').update({
        'refund_status': 'refunded',
        'refund_reference': cleanRef,
        'refund_amount': amount,
        'refund_notes': notes?.trim(),
        'refund_processed_at': now.toIso8601String(),
        if (operatorId != null && operatorId.isNotEmpty)
          'refund_operator_id': operatorId,
        'updated_at': now.toIso8601String(),
      }).eq('id', bookingId);

      // 1. Notify Renter
      if (renterId.isNotEmpty) {
        final amountFmt =
            amount > 0 ? ' of PHP ${amount.toStringAsFixed(2)}' : '';
        await NotificationService().createNotification(
          userId: renterId,
          title: '💰 Refund Completed',
          message:
              'Your refund$amountFmt for $vehicleTitle has been disbursed to your account. Reference: $cleanRef.',
          type: 'booking_refund',
          data: {
            'booking_id': bookingId,
            'status': 'cancelled',
            'refund_status': 'refunded',
            'refund_reference': cleanRef,
            'refund_amount': amount,
            'event': 'refund_disbursed',
          },
        );
      }

      // 2. Notify Vehicle Owner if applicable
      final ownerId = vehicle?['owner_id']?.toString();
      if (ownerId != null && ownerId.isNotEmpty && ownerId != renterId) {
        await NotificationService().createNotification(
          userId: ownerId,
          title: 'Booking Refund Disbursed',
          message:
              'Refund for cancelled booking #$bookingId ($vehicleTitle) has been completed. Reference: $cleanRef.',
          type: 'booking',
          data: {
            'booking_id': bookingId,
            'refund_status': 'refunded',
            'event': 'owner_refund_recorded',
          },
        );
      }

      return {
        'success': true,
        'refund_status': 'refunded',
        'refund_reference': cleanRef,
        'refund_amount': amount,
      };
    } catch (e) {
      debugPrint('Error processing refund disbursement: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Reschedules an active/pending booking to new dates, retaining 100% of the deposit.
  Future<void> rescheduleBooking({
    required String bookingId,
    required DateTime newStartAt,
    required DateTime newEndAt,
    String? newDropoffLocation,
    double? newDropoffLatitude,
    double? newDropoffLongitude,
    String? reason,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) {
        throw Exception('Booking not found');
      }

      final vehicleId = booking['vehicle_id']?.toString() ?? '';
      final currentRescheduleCount = (booking['reschedule_count'] as num?)?.toInt() ?? 0;
      if (currentRescheduleCount >= 1) {
        throw Exception('This booking has already been rescheduled once. Rescheduling is allowed only one time per booking.');
      }
      final originalStart = booking['original_start_at'] ?? booking['start_at'];
      final originalEnd = booking['original_end_at'] ?? booking['end_at'];

      // Validate that reschedule duration does not exceed original reservation duration
      final origStartDt = DateTime.tryParse(originalStart?.toString() ?? '');
      final origEndDt = DateTime.tryParse(originalEnd?.toString() ?? '');
      if (origStartDt != null && origEndDt != null) {
        final origDurationMinutes = origEndDt.difference(origStartDt).inMinutes;
        final newDurationMinutes = newEndAt.difference(newStartAt).inMinutes;
        if (newDurationMinutes > origDurationMinutes + 60) {
          final origDays = (origDurationMinutes / Duration.minutesPerDay).ceil();
          throw Exception(
            'Rescheduled booking duration cannot exceed your original reservation of $origDays day${origDays > 1 ? 's' : ''}. Extending duration is not allowed during reschedule.',
          );
        }
      }

      // Check vehicle availability on requested dates
      final resolvedVehicleId = vehicleId.isNotEmpty
          ? vehicleId
          : (booking['partner_vehicle_id']?.toString() ?? '');
      if (resolvedVehicleId.isNotEmpty) {
        final conflicts = await supabase
            .from('bookings')
            .select('id, start_at, end_at, status')
            .or('vehicle_id.eq.$resolvedVehicleId,partner_vehicle_id.eq.$resolvedVehicleId')
            .neq('id', bookingId)
            .inFilter('status', ['pending', 'approved', 'ongoing'])
            .lte('start_at', newEndAt.toIso8601String())
            .gte('end_at', newStartAt.toIso8601String());

        if (conflicts.isNotEmpty) {
          throw Exception('The selected vehicle is not available for these new dates. Please pick different dates.');
        }
      }

      // Update booking dates, destination and reschedule tracking
      final updateData = <String, dynamic>{
        'start_at': newStartAt.toIso8601String(),
        'end_at': newEndAt.toIso8601String(),
        'original_start_at': originalStart,
        'original_end_at': originalEnd,
        'rescheduled_at': DateTime.now().toIso8601String(),
        'reschedule_count': currentRescheduleCount + 1,
        'reschedule_reason': reason ?? 'Renter requested date change',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newDropoffLocation != null && newDropoffLocation.trim().isNotEmpty) {
        updateData['dropoff_location'] = newDropoffLocation.trim();
      }
      if (newDropoffLatitude != null) {
        updateData['dropoff_latitude'] = newDropoffLatitude;
      }
      if (newDropoffLongitude != null) {
        updateData['dropoff_longitude'] = newDropoffLongitude;
      }

      await supabase.from('bookings').update(updateData).eq('id', bookingId);

      // Notify operator & partner
      try {
        final vehicleTitle = booking['vehicles'] != null
            ? '${booking['vehicles']['brand'] ?? ''} ${booking['vehicles']['model'] ?? ''}'
            : 'vehicle';
        await NotificationService().createNotification(
          userId: booking['vehicles']?['owner_id'] ?? booking['operator_id'] ?? '',
          title: 'Booking Rescheduled',
          message: 'Booking for $vehicleTitle was rescheduled to new dates.',
          type: 'booking_rescheduled',
          data: {
            'booking_id': bookingId,
            'new_start': newStartAt.toIso8601String(),
            'new_end': newEndAt.toIso8601String(),
            if (newDropoffLocation != null && newDropoffLocation.trim().isNotEmpty)
              'new_dropoff_location': newDropoffLocation.trim(),
          },
        );
      } catch (e) {
        debugPrint('Notification dispatch note: $e');
      }
    } catch (e) {
      debugPrint('Error rescheduling booking: $e');
      rethrow;
    }
  }

  /// Cancels booking under strict non-refundable policy (deposit is retained & forfeited)
  Future<void> cancelBookingWithDepositForfeit({
    required String bookingId,
    required String cancellationReason,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      final depositAmount = (booking?['reservation_fee_amount'] as num?)?.toDouble() ?? 1000.0;
      final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
      final vehicleTitle = _vehicleTitle(vehicle);
      final driverId = booking?['driver_id']?.toString() ?? '';
      final renterId = booking?['renter_id']?.toString() ?? '';
      final partnerId = (vehicle?['owner_id'] ?? booking?['partner_id'])?.toString() ?? '';

      await updateBookingStatus(bookingId, 'cancelled');
      await safeUpdateBooking(bookingId, {
        'cancellation_reason': cancellationReason,
        'notes': cancellationReason.isNotEmpty ? 'Cancellation Reason: $cancellationReason' : null,
        'cancelled_at': DateTime.now().toIso8601String(),
        'deposit_forfeited': true,
        'cancellation_fee_retained': depositAmount,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Release driver assignment and restore availability
      if (driverId.isNotEmpty) {
        try {
          final now = DateTime.now().toUtc().toIso8601String();
          await supabase
              .from('driver_job_assignments')
              .update({'status': 'cancelled', 'updated_at': now})
              .eq('booking_id', bookingId)
              .inFilter('status', ['pending_offer', 'assigned', 'accepted']);
          await supabase
              .from('users')
              .update({'is_available': true})
              .eq('id', driverId);
        } catch (e) {
          debugPrint('Could not update driver availability on cancellation: $e');
        }

        unawaited(
          NotificationService().notifyBookingCancelled(
            userId: driverId,
            bookingId: bookingId,
            vehicleTitle: vehicleTitle,
            role: 'driver',
            reason: cancellationReason,
          ).catchError((e) => debugPrint('Error notifying driver on cancellation: $e')),
        );
      }

      // Notify partner
      if (partnerId.isNotEmpty && partnerId != renterId) {
        String partnerUserId = partnerId;
        try {
          final pDoc = await supabase
              .from('partners')
              .select('user_id')
              .eq('id', partnerId)
              .maybeSingle();
          final uId = pDoc?['user_id']?.toString().trim();
          if (uId != null && uId.isNotEmpty) partnerUserId = uId;
        } catch (_) {}

        unawaited(
          NotificationService().notifyBookingCancelled(
            userId: partnerUserId,
            bookingId: bookingId,
            vehicleTitle: vehicleTitle,
            role: 'partner',
            reason: cancellationReason,
          ).catchError((e) => debugPrint('Error notifying partner on cancellation: $e')),
        );
      }

      try {
        await TransactionLogger.logBookingCancelled(
          bookingId: bookingId,
          reason: cancellationReason,
        );
      } catch (e) {
        debugPrint('Transaction log for cancellation note: $e');
      }
    } catch (e) {
      debugPrint('Error cancelling booking with deposit forfeit: $e');
      rethrow;
    }
  }

  Future<void> refundSecurityDeposit({
    required String bookingId,
    required double refundAmount,
    double deductionAmount = 0.0,
    String? deductionNotes,
    required String refundMethod,
    required String refundReference,
    required String refundReceiptUrl,
    required String operatorId,
  }) async {
    final now = DateTime.now().toUtc();
    final updatePayload = <String, dynamic>{
      'security_deposit_refunded': true,
      'security_deposit_refund_amount': refundAmount,
      'security_deposit_refund_deduction': deductionAmount,
      'security_deposit_refund_notes': deductionNotes,
      'security_deposit_refund_method': refundMethod,
      'security_deposit_refund_ref': refundReference,
      'security_deposit_refund_receipt_url': refundReceiptUrl,
      'security_deposit_refunded_at': now.toIso8601String(),
    };
    if (operatorId.trim().isNotEmpty) {
      updatePayload['security_deposit_refunded_by'] = operatorId.trim();
    }

    await safeUpdateBooking(bookingId, updatePayload);

    // Fetch booking to notify renter
    try {
      final booking = await supabase
          .from('bookings')
          .select('renter_id, vehicles(brand, model)')
          .eq('id', bookingId)
          .maybeSingle();
      final renterId = booking?['renter_id']?.toString();
      if (renterId != null && renterId.isNotEmpty) {
        final vehicleMap = booking?['vehicles'] as Map<String, dynamic>? ?? {};
        final vehicleName =
            '${vehicleMap['brand'] ?? ''} ${vehicleMap['model'] ?? ''}'.trim();
        await NotificationService().createNotification(
          userId: renterId,
          title: 'Security Deposit Refunded',
          message:
              'Your security deposit of PHP ${refundAmount.toStringAsFixed(0)} for $vehicleName has been successfully refunded via $refundMethod.',
          type: 'deposit_refunded',
          data: {
            'booking_id': bookingId,
            'refund_amount': refundAmount,
            'refund_reference': refundReference,
            'receipt_url': refundReceiptUrl,
          },
        );
      }
    } catch (e) {
      debugPrint('Deposit refund notification error: $e');
    }
  }

  Future<void> setSecurityDepositReturnEligibility({
    required String bookingId,
    required bool isEligible,
    String? ineligibilityReason,
  }) async {
    await safeUpdateBooking(bookingId, {
      'security_deposit_return_eligible': isEligible,
      if (ineligibilityReason != null)
        'security_deposit_ineligibility_reason': ineligibilityReason,
    });
  }

  /// Disburse partner net earnings / commission for a completed partner booking.
  Future<void> disbursePartnerCommission({
    required String bookingId,
    required String operatorId,
    required String paymentMethod,
    required String referenceNumber,
    String? receiptUrl,
    required double netAmount,
    required double commissionAmount,
    String? partnerUserId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final updatePayload = <String, dynamic>{
      'partner_payout_disbursed': true,
      'partner_payout_status': 'disbursed',
      'partner_payout_amount': netAmount,
      'partner_payout_commission': commissionAmount,
      'partner_payout_method': paymentMethod,
      'partner_payout_ref': referenceNumber,
      'partner_payout_receipt_url': receiptUrl ?? '',
      'partner_payout_disbursed_at': now,
    };
    if (operatorId.trim().isNotEmpty) {
      updatePayload['partner_payout_disbursed_by'] = operatorId.trim();
    }

    await safeUpdateBooking(bookingId, updatePayload);

    if (partnerUserId != null && partnerUserId.isNotEmpty) {
      try {
        final existingPayout = await supabase
            .from('booking_payouts')
            .select('id')
            .eq('booking_id', bookingId)
            .eq('recipient_role', 'partner')
            .maybeSingle();

        final payoutData = {
          'booking_id': bookingId,
          'recipient_user_id': partnerUserId,
          'recipient_role': 'partner',
          'gross_amount': netAmount + commissionAmount,
          'deductions': commissionAmount,
          'net_amount': netAmount,
          'status': 'released',
          'released_at': now,
          'metadata': {
            'commission_rate': 5,
            'payment_method': paymentMethod,
            'reference_number': referenceNumber,
            'receipt_url': receiptUrl,
          },
          'updated_at': now,
        };

        if (existingPayout != null) {
          await supabase
              .from('booking_payouts')
              .update(payoutData)
              .eq('id', existingPayout['id']);
        } else {
          payoutData['created_at'] = now;
          await supabase.from('booking_payouts').insert(payoutData);
        }
      } catch (e) {
        debugPrint('Could not record partner booking_payouts: $e');
      }

      try {
        await NotificationService().notifyPartnerDisbursementCompleted(
          partnerUserId: partnerUserId,
          bookingId: bookingId,
          amount: netAmount,
          paymentMethod: paymentMethod,
          referenceNumber: referenceNumber,
          receiptUrl: receiptUrl,
        );
      } catch (e) {
        debugPrint('Could not notify partner for payout: $e');
      }
    }
  }

  /// Disburse driver trip fee / commission for a completed driver booking.
  Future<void> disburseDriverCommission({
    required String bookingId,
    required String operatorId,
    required String paymentMethod,
    required String referenceNumber,
    String? receiptUrl,
    required double netAmount,
    required double commissionAmount,
    String? driverUserId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final updatePayload = <String, dynamic>{
      'driver_payout_disbursed': true,
      'driver_payout_status': 'disbursed',
      'driver_payout_amount': netAmount,
      'driver_payout_commission': commissionAmount,
      'driver_payout_method': paymentMethod,
      'driver_payout_ref': referenceNumber,
      'driver_payout_receipt_url': receiptUrl ?? '',
      'driver_payout_disbursed_at': now,
    };
    if (operatorId.trim().isNotEmpty) {
      updatePayload['driver_payout_disbursed_by'] = operatorId.trim();
    }

    await safeUpdateBooking(bookingId, updatePayload);

    // Resolve driver user ID if not explicitly passed
    String? resolvedDriverUserId = driverUserId;
    if (resolvedDriverUserId == null || resolvedDriverUserId.isEmpty) {
      try {
        final b = await supabase
            .from('bookings')
            .select('driver_id, drivers(user_id)')
            .eq('id', bookingId)
            .maybeSingle();
        final driverJoin = b?['drivers'] as Map<String, dynamic>?;
        resolvedDriverUserId = driverJoin?['user_id']?.toString() ??
            b?['driver_id']?.toString();
      } catch (_) {}
    }

    if (resolvedDriverUserId != null && resolvedDriverUserId.isNotEmpty) {
      try {
        final earningPayload = <String, dynamic>{
          'booking_id': bookingId,
          'driver_id': resolvedDriverUserId,
          'trip_fee': netAmount + commissionAmount,
          'commission_percentage': 5,
          'commission_amount': commissionAmount,
          'net_earnings': netAmount,
          'payout_status': 'paid',
          'payout_method': paymentMethod,
          'payout_ref': referenceNumber,
          'payout_receipt_url': receiptUrl ?? '',
          'paid_at': now,
        };
        final existingEarning = await supabase
            .from('driver_earnings')
            .select('id')
            .eq('booking_id', bookingId)
            .maybeSingle();
        if (existingEarning == null) {
          await supabase.from('driver_earnings').insert(earningPayload);
        } else {
          await supabase
              .from('driver_earnings')
              .update(earningPayload)
              .eq('id', existingEarning['id']);
        }
      } catch (e) {
        debugPrint('Could not upsert driver_earnings: $e');
      }

      try {
        final existingPayout = await supabase
            .from('booking_payouts')
            .select('id')
            .eq('booking_id', bookingId)
            .eq('recipient_role', 'driver')
            .maybeSingle();

        final payoutData = {
          'booking_id': bookingId,
          'recipient_user_id': resolvedDriverUserId,
          'recipient_role': 'driver',
          'gross_amount': netAmount + commissionAmount,
          'deductions': commissionAmount,
          'net_amount': netAmount,
          'status': 'released',
          'released_at': now,
          'metadata': {
            'commission_rate': 5,
            'payment_method': paymentMethod,
            'reference_number': referenceNumber,
            'receipt_url': receiptUrl,
          },
          'updated_at': now,
        };

        if (existingPayout != null) {
          await supabase
              .from('booking_payouts')
              .update(payoutData)
              .eq('id', existingPayout['id']);
        } else {
          payoutData['created_at'] = now;
          await supabase.from('booking_payouts').insert(payoutData);
        }
      } catch (e) {
        debugPrint('Could not record driver booking_payouts: $e');
      }

      try {
        await NotificationService().notifyDriverDisbursementCompleted(
          driverUserId: resolvedDriverUserId,
          bookingId: bookingId,
          amount: netAmount,
          paymentMethod: paymentMethod,
          referenceNumber: referenceNumber,
          receiptUrl: receiptUrl,
        );
      } catch (e) {
        debugPrint('Could not notify driver for payout: $e');
      }
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
