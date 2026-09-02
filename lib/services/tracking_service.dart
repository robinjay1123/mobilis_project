import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';
import 'gps_service.dart';
import '../models/gps_tracker_model.dart';
import '../utils/philippine_geocoding.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();

  factory TrackingService() => _instance;

  TrackingService._internal();

  final SupabaseClient supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionSubscription;
  String? _activeBookingId;
  final Map<String, DateTime> _stationarySinceByBooking = {};

  static const double overspeedThresholdKph = 100;
  static const double geofenceRadiusMeters = 75000;
  static const Duration unauthorizedStopThreshold = Duration(minutes: 15);

  bool get isTracking => _positionSubscription != null;
  String? get activeBookingId => _activeBookingId;

  Future<void> startBookingTracking({
    required String bookingId,
    required String vehicleId,
    required String trackedUserId,
    String source = 'driver_app',
  }) async {
    await stopTracking();
    await _ensureLocationPermission();

    _activeBookingId = bookingId;
    final initialPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await upsertTrackingLocation(
      bookingId: bookingId,
      vehicleId: vehicleId,
      trackedUserId: trackedUserId,
      position: initialPosition,
      source: source,
    );

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          position,
        ) async {
          try {
            await upsertTrackingLocation(
              bookingId: bookingId,
              vehicleId: vehicleId,
              trackedUserId: trackedUserId,
              position: position,
              source: source,
            );
          } catch (e) {
            debugPrint('Tracking update failed: $e');
          }
        });
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _activeBookingId = null;
  }

  Future<void> upsertTrackingLocation({
    required String bookingId,
    required String vehicleId,
    required String trackedUserId,
    required Position position,
    String source = 'driver_app',
  }) async {
    await supabase.from('tracking_locations').upsert({
      'booking_id': bookingId,
      'vehicle_id': vehicleId,
      'tracked_user_id': trackedUserId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy_meters': position.accuracy,
      'speed_mps': position.speed,
      'heading_degrees': position.heading,
      'source': source,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'booking_id,tracked_user_id');

    try {
      await supabase.from('tracking_location_logs').insert({
        'booking_id': bookingId,
        'vehicle_id': vehicleId,
        'tracked_user_id': trackedUserId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy_meters': position.accuracy,
        'speed_mps': position.speed,
        'heading_degrees': position.heading,
        'source': source,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _evaluateSafetySignals(
        bookingId: bookingId,
        vehicleId: vehicleId,
        position: position,
      );
    } on PostgrestException catch (error) {
      debugPrint(
        'Trip evidence logging is unavailable until its migration is pushed: ${error.message}',
      );
    } catch (error) {
      debugPrint(
        'Trip safety evaluation failed without stopping tracking: $error',
      );
    }
  }

  /// Participant-safe navigation data. This intentionally exposes only the
  /// current renter's or assigned driver's own active booking.
  Future<Map<String, dynamic>?> getParticipantNavigationLocationForBooking(
    String bookingId,
  ) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return null;

    try {
      final bookingResponse = await supabase
          .from('bookings')
          .select('''
            id,
            status,
            renter_id,
            driver_id,
            vehicle_id,
            start_at,
            end_at,
            pickup_location,
            dropoff_location,
            pickup_latitude,
            pickup_longitude,
            dropoff_latitude,
            dropoff_longitude,
            vehicles:vehicle_id (id, brand, model, plate_number)
          ''')
          .eq('id', bookingId)
          .maybeSingle();
      if (bookingResponse == null) return null;

      final booking = Map<String, dynamic>.from(bookingResponse);
      final status = booking['status']?.toString().trim().toLowerCase() ?? '';
      if (!{'active', 'ongoing'}.contains(status)) return null;

      final isRenter = booking['renter_id']?.toString() == currentUserId;
      final driverReference = booking['driver_id']?.toString() ?? '';
      var isAssignedDriver = driverReference == currentUserId;
      if (!isAssignedDriver && driverReference.isNotEmpty) {
        final driver = await supabase
            .from('drivers')
            .select('id,user_id')
            .or('id.eq.$driverReference,user_id.eq.$driverReference')
            .maybeSingle();
        isAssignedDriver = driver?['user_id']?.toString() == currentUserId;
      }
      if (!isRenter && !isAssignedDriver) return null;

      final rows = await supabase
          .from('tracking_locations')
          .select()
          .eq('booking_id', bookingId)
          .order('recorded_at', ascending: false)
          .limit(1);

      return {
        'booking': booking,
        'location': rows.isEmpty ? null : Map<String, dynamic>.from(rows.first),
        'participant_role': isRenter ? 'renter' : 'driver',
      };
    } on PostgrestException catch (error) {
      debugPrint('Unable to load participant navigation: ${error.message}');
      return null;
    }
  }

  Future<String> _resolveAddress(double? lat, double? lng) async {
    if (lat == null || lng == null) return 'Location coordinates unavailable';
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.street,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country,
        ]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
        final joined = parts.join(', ');
        if (joined.trim().isNotEmpty) return joined;
      }
    } catch (e) {
      debugPrint('Geocoding lookup error: $e');
    }
    return 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
  }

  Future<void> reportEmergency({
    required String bookingId,
    double? latitude,
    double? longitude,
  }) async {
    final participant = await getParticipantNavigationLocationForBooking(
      bookingId,
    );
    if (participant == null || participant['participant_role'] != 'renter') {
      throw Exception(
        'Emergency assistance can only be requested by the renter during their ongoing trip.',
      );
    }
    final context = await _loadSafetyBookingContext(bookingId);
    if (context == null) throw Exception('Active booking not found');

    final renter = context['renter'] as Map<String, dynamic>?;
    final vehicle = context['vehicles'] as Map<String, dynamic>?;

    final renterName = renter?['full_name']?.toString().trim() ?? 'Renter';
    final renterPhone = renter?['phone']?.toString().trim() ?? 'N/A';
    final renterEmail = renter?['email']?.toString().trim() ?? '';

    final vehicleBrand = vehicle?['brand']?.toString().trim() ?? '';
    final vehicleModel = vehicle?['model']?.toString().trim() ?? '';
    final rawVehicleName = vehicle?['vehicle_name']?.toString().trim() ?? '';
    final vehicleName = rawVehicleName.isNotEmpty
        ? rawVehicleName
        : '$vehicleBrand $vehicleModel'.trim();
    final plateNumber = vehicle?['plate_number']?.toString().trim() ?? 'N/A';

    final address = await _resolveAddress(latitude, longitude);
    final mapsUrl = (latitude != null && longitude != null)
        ? 'https://maps.google.com/?q=$latitude,$longitude'
        : '';

    final notificationMessage =
        'Renter: $renterName (Mobile: $renterPhone) | Vehicle: $vehicleName [$plateNumber] | Location: $address${mapsUrl.isNotEmpty ? ' | Maps: $mapsUrl' : ''}';

    await _recordSafetyEvent(
      context: context,
      eventType: 'emergency_${DateTime.now().millisecondsSinceEpoch}',
      severity: 'critical',
      title: '🚨 EMERGENCY ALERT: Renter Needs Immediate Help!',
      message: notificationMessage,
      latitude: latitude,
      longitude: longitude,
      details: {
        'generated_by': 'mobilis_tracking_service',
        'renter_id': context['renter_id'],
        'renter_name': renterName,
        'renter_phone': renterPhone,
        'renter_email': renterEmail,
        'vehicle_id': context['vehicle_id'],
        'vehicle_name': vehicleName,
        'plate_number': plateNumber,
        'location_address': address,
        'google_maps_url': mapsUrl,
        'booking_id': bookingId,
      },
      notifyParticipants: true,
    );
  }

  Future<List<Map<String, dynamic>>> getTripLocationEvidence(
    String bookingId,
  ) async {
    final rows = await supabase
        .from('tracking_location_logs')
        .select()
        .eq('booking_id', bookingId)
        .order('recorded_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _evaluateSafetySignals({
    required String bookingId,
    required String vehicleId,
    required Position position,
  }) async {
    final context = await _loadSafetyBookingContext(bookingId);
    if (context == null) return;

    final speedKph = position.speed < 0 ? 0.0 : position.speed * 3.6;
    if (speedKph >= overspeedThresholdKph) {
      await _recordSafetyEvent(
        context: context,
        eventType:
            'overspeed_${DateTime.now().millisecondsSinceEpoch ~/ 300000}',
        severity: 'high',
        title: 'Overspeed alert',
        message: 'Vehicle speed reached ${speedKph.toStringAsFixed(0)} km/h.',
        latitude: position.latitude,
        longitude: position.longitude,
        speedKph: speedKph,
        notifyParticipants: true,
      );
    }

    final pickupLat = _asDouble(context['pickup_latitude']);
    final pickupLng = _asDouble(context['pickup_longitude']);
    final dropoffLat = _asDouble(context['dropoff_latitude']);
    final dropoffLng = _asDouble(context['dropoff_longitude']);
    final pickupDistance = pickupLat == null || pickupLng == null
        ? 0.0
        : Geolocator.distanceBetween(
            pickupLat,
            pickupLng,
            position.latitude,
            position.longitude,
          );
    final destinationDistance = dropoffLat == null || dropoffLng == null
        ? 0.0
        : Geolocator.distanceBetween(
            dropoffLat,
            dropoffLng,
            position.latitude,
            position.longitude,
          );
    final hasBothAnchors =
        pickupLat != null &&
        pickupLng != null &&
        dropoffLat != null &&
        dropoffLng != null;
    final outsideAllowedArea = hasBothAnchors
        ? pickupDistance > geofenceRadiusMeters &&
              destinationDistance > geofenceRadiusMeters
        : (pickupLat != null &&
              pickupLng != null &&
              pickupDistance > geofenceRadiusMeters);
    if (outsideAllowedArea) {
      await _recordSafetyEvent(
        context: context,
        eventType:
            'geofence_${DateTime.now().millisecondsSinceEpoch ~/ 1800000}',
        severity: 'high',
        title: 'Geofence alert',
        message: 'The vehicle moved outside the permitted trip area.',
        latitude: position.latitude,
        longitude: position.longitude,
        speedKph: speedKph,
        notifyParticipants: true,
      );
    }

    if (speedKph <= 1) {
      final stoppedAt = _stationarySinceByBooking.putIfAbsent(
        bookingId,
        DateTime.now,
      );
      if (DateTime.now().difference(stoppedAt) >= unauthorizedStopThreshold) {
        await _recordSafetyEvent(
          context: context,
          eventType:
              'vehicle_parked_${DateTime.now().millisecondsSinceEpoch ~/ 1800000}',
          severity: 'info',
          title: 'Vehicle Parked',
          message: 'The vehicle is stationary (engine off/parked).',
          latitude: position.latitude,
          longitude: position.longitude,
          speedKph: speedKph,
          notifyParticipants: false,
        );
      }
    } else {
      _stationarySinceByBooking.remove(bookingId);
    }

    await _evaluateReturnReminder(context);
  }

  Future<Map<String, dynamic>?> _loadSafetyBookingContext(
    String bookingId,
  ) async {
    final response = await supabase
        .from('bookings')
        .select('''
          id,
          status,
          renter_id,
          driver_id,
          operator_id,
          vehicle_id,
          end_at,
          pickup_latitude,
          pickup_longitude,
          dropoff_latitude,
          dropoff_longitude,
          renter:renter_id (
            id,
            full_name,
            email,
            phone
          ),
          vehicles:vehicle_id (
            id,
            brand,
            model,
            vehicle_name,
            plate_number,
            owner_id
          )
        ''')
        .eq('id', bookingId)
        .maybeSingle();
    if (response == null) return null;
    final context = Map<String, dynamic>.from(response);
    final status = context['status']?.toString().trim().toLowerCase() ?? '';
    return {'active', 'ongoing'}.contains(status) ? context : null;
  }

  Future<void> _evaluateReturnReminder(Map<String, dynamic> context) async {
    final endAt = DateTime.tryParse(context['end_at']?.toString() ?? '');
    if (endAt == null) return;
    final remaining = endAt.toLocal().difference(DateTime.now());
    if (remaining > const Duration(hours: 2)) return;

    late final String bucket;
    late final String message;
    if (remaining.isNegative) {
      bucket = 'overdue_${DateTime.now().millisecondsSinceEpoch ~/ 1800000}';
      message = 'The scheduled return time has passed. Late fees may apply.';
    } else if (remaining <= const Duration(minutes: 30)) {
      bucket = '30_minutes';
      message = 'The vehicle is due for return in 30 minutes.';
    } else if (remaining <= const Duration(hours: 1)) {
      bucket = '1_hour';
      message = 'The vehicle is due for return in 1 hour.';
    } else {
      bucket = '2_hours';
      message = 'The vehicle is due for return in 2 hours.';
    }
    await _recordSafetyEvent(
      context: context,
      eventType: 'return_reminder_$bucket',
      severity: remaining.isNegative ? 'high' : 'info',
      title: remaining.isNegative
          ? 'Vehicle return overdue'
          : 'Return reminder',
      message: message,
      notifyParticipants: true,
    );
  }

  Future<void> _recordSafetyEvent({
    required Map<String, dynamic> context,
    required String eventType,
    required String severity,
    required String title,
    required String message,
    double? latitude,
    double? longitude,
    double? speedKph,
    Map<String, dynamic>? details,
    bool notifyParticipants = false,
  }) async {
    final bookingId = context['id']?.toString() ?? '';
    if (bookingId.isEmpty || await _eventExists(bookingId, eventType)) return;
    await supabase.from('trip_safety_events').insert({
      'booking_id': bookingId,
      'vehicle_id': context['vehicle_id'],
      'event_type': eventType,
      'severity': severity,
      'title': title,
      'message': message,
      'latitude': latitude,
      'longitude': longitude,
      'speed_kph': speedKph,
      'details': details ?? {'generated_by': 'mobilis_tracking_service'},
    });

    final recipients = await _safetyNotificationRecipients(
      context,
      includeParticipants: notifyParticipants,
    );
    for (final userId in recipients) {
      try {
        await NotificationService().createNotification(
          userId: userId,
          title: title,
          message: message,
          type: 'trip_safety',
          data: {
            'booking_id': bookingId,
            'event': eventType,
            'severity': severity,
            if (details != null) ...details,
          },
        );
      } catch (error) {
        debugPrint('Safety notification failed for $userId: $error');
      }
    }
  }

  Future<bool> _eventExists(String bookingId, String eventType) async {
    final rows = await supabase
        .from('trip_safety_events')
        .select('id')
        .eq('booking_id', bookingId)
        .eq('event_type', eventType)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<Set<String>> _safetyNotificationRecipients(
    Map<String, dynamic> context, {
    required bool includeParticipants,
  }) async {
    final recipients = <String>{};
    final vehicle = context['vehicles'] as Map<String, dynamic>?;
    final ownerRole = vehicle?['owner_role']?.toString().toLowerCase();
    final isPartner =
        ownerRole == 'partner' ||
        vehicle?['is_partner_vehicle'] == true ||
        vehicle?['partner_vehicle_id'] != null;
    if (isPartner) {
      final ownerId = vehicle?['owner_id']?.toString() ?? '';
      if (ownerId.isNotEmpty) recipients.add(ownerId);
    } else {
      final operatorId = context['operator_id']?.toString() ?? '';
      if (operatorId.isNotEmpty) {
        recipients.add(operatorId);
      } else {
        final operators = await supabase
            .from('users')
            .select('id')
            .eq('role', 'operator');
        recipients.addAll(
          List<Map<String, dynamic>>.from(operators)
              .map((row) => row['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty),
        );
      }
    }
    final admins = await supabase.from('users').select('id').inFilter('role', [
      'admin',
      'super_admin',
    ]);
    recipients.addAll(
      List<Map<String, dynamic>>.from(
        admins,
      ).map((row) => row['id']?.toString() ?? '').where((id) => id.isNotEmpty),
    );

    if (includeParticipants) {
      final renterId = context['renter_id']?.toString() ?? '';
      if (renterId.isNotEmpty) recipients.add(renterId);
      final driverReference = context['driver_id']?.toString() ?? '';
      if (driverReference.isNotEmpty) {
        final driver = await supabase
            .from('drivers')
            .select('user_id')
            .or('id.eq.$driverReference,user_id.eq.$driverReference')
            .maybeSingle();
        final driverUserId = driver?['user_id']?.toString() ?? '';
        if (driverUserId.isNotEmpty) recipients.add(driverUserId);
      }
    }
    return recipients;
  }

  double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  Future<List<Map<String, dynamic>>> getActiveTrackingLocations() async {
    try {
      final access = await _currentTrackingAccess();
      if (access == null || {'renter', 'driver'}.contains(access.role)) {
        return [];
      }
      final response = await supabase
          .from('tracking_locations')
          .select('''
            *,
            bookings:booking_id (
              id,
              status,
              operator_id,
              pickup_location,
              dropoff_location,
              pickup_latitude,
              pickup_longitude,
              dropoff_latitude,
              dropoff_longitude,
              start_at,
              end_at,
              vehicles:vehicle_id (
                id,
                brand,
                model,
                plate_number,
                vehicle_name,
                image_url,
                vehicle_images,
                owner_id,
                owner:owner_id (id, role)
              ),
              renter:renter_id (id, full_name, email),
              driver:driver_id (
                id,
                user_id,
                users(id, full_name, email)
              )
            )
          ''')
          .order('recorded_at', ascending: false)
          .limit(60);

      const onTripStatuses = {
        'ongoing',
        'active',
        'picked_up',
        'in_progress',
      };

      final candidateList = <Map<String, dynamic>>[];
      final vehiclesWithActiveTracking = <String>{};
      final seenVehicles = <String>{};

      for (final loc in List<Map<String, dynamic>>.from(response)) {
        final booking = loc['bookings'] as Map<String, dynamic>?;
        final status = booking?['status']?.toString().toLowerCase() ?? '';
        final isReturnedOrCompleted = booking?['returned_at'] != null ||
            booking?['completed_at'] != null ||
            booking?['completion_stage'] == 'completed' ||
            booking?['completion_stage'] == 'awaiting_payment' ||
            booking?['completion_stage'] == 'completed_pending_review' ||
            {'completed', 'returned', 'cancelled', 'rejected'}.contains(status);

        final vid = loc['vehicle_id']?.toString() ??
            booking?['vehicles']?['id']?.toString() ??
            '';

        final isTripActive =
            onTripStatuses.contains(status) && !isReturnedOrCompleted;

        if (isTripActive && _canViewTracking(access, booking)) {
          final enriched = Map<String, dynamic>.from(loc);
          enriched['has_active_booking'] = true;
          enriched['is_active_booking'] = true;
          candidateList.add(enriched);

          if (vid.isNotEmpty) {
            seenVehicles.add(vid);
            vehiclesWithActiveTracking.add(vid);
          }
        } else if (vid.isNotEmpty && !seenVehicles.contains(vid)) {
          // Booking is approved/pending/finished: vehicle is currently Idle
          final enriched = Map<String, dynamic>.from(loc);
          enriched['has_active_booking'] = false;
          enriched['is_active_booking'] = false;
          enriched['bookings'] = null;
          enriched['status'] = 'Available (Idle)';
          enriched['vehicle'] = booking?['vehicles'] ?? loc['vehicle'];
          candidateList.add(enriched);
          seenVehicles.add(vid);
        }
      }

      // 2. Fetch all connected trackers for idle / available vehicles
      try {
        final trackerRows = await supabase
            .from('vehicle_trackers')
            .select('*')
            .neq('connection_status', 'disconnected');

        final trackers = List<Map<String, dynamic>>.from(trackerRows);

        // Fetch vehicle details for all tracked vehicles across vehicles, partner_vehicles, and partner_vehicle_applications
        final vehicleIds = <String>{};
        for (final t in trackers) {
          final vid = t['vehicle_id']?.toString();
          final pvid = t['partner_vehicle_id']?.toString();
          final vaid = t['vehicle_application_id']?.toString();
          if (vid != null && vid.isNotEmpty) vehicleIds.add(vid);
          if (pvid != null && pvid.isNotEmpty) vehicleIds.add(pvid);
          if (vaid != null && vaid.isNotEmpty) vehicleIds.add(vaid);
        }

        final filteredIds = vehicleIds
            .where((id) => !vehiclesWithActiveTracking.contains(id))
            .toList();

        final vehiclesMap = <String, Map<String, dynamic>>{};
        if (filteredIds.isNotEmpty) {
          try {
            final vehRows = await supabase
                .from('vehicles')
                .select('id, brand, model, vehicle_name, plate_number, owner_id, status, latitude, longitude, image_url, vehicle_images')
                .inFilter('id', filteredIds);
            for (final v in List<Map<String, dynamic>>.from(vehRows)) {
              final brand = v['brand']?.toString().trim() ?? '';
              final model = v['model']?.toString().trim() ?? '';
              final combo = [brand, model].where((s) => s.isNotEmpty).join(' ');
              v['vehicle_name'] = v['vehicle_name'] ?? (combo.isNotEmpty ? combo : 'Vehicle');
              vehiclesMap[v['id'].toString()] = v;
            }
          } catch (e) {
            debugPrint('Error fetching vehicles for trackers: $e');
          }

          try {
            final pVehRows = await supabase
                .from('partner_vehicles')
                .select('id, brand, model, plate_number, vehicle_name, partner_id, status, latitude, longitude, image_url, vehicle_images')
                .inFilter('id', filteredIds);
            for (final pv in List<Map<String, dynamic>>.from(pVehRows)) {
              final brand = pv['brand']?.toString().trim() ?? '';
              final model = pv['model']?.toString().trim() ?? '';
              final synthesized = [brand, model].where((s) => s.isNotEmpty).join(' ');
              pv['vehicle_name'] = synthesized.isNotEmpty ? synthesized : 'Partner Vehicle';
              vehiclesMap[pv['id'].toString()] = pv;
            }
          } catch (_) {}

          try {
            final pAppRows = await supabase
                .from('partner_vehicle_applications')
                .select('id, brand, model, plate_number, vehicle_name, partner_id, partner_vehicle_id, status, latitude, longitude, photo_url, vehicle_images')
                .inFilter('id', filteredIds);
            for (final pva in List<Map<String, dynamic>>.from(pAppRows)) {
              final brand = pva['brand']?.toString().trim() ?? '';
              final model = pva['model']?.toString().trim() ?? '';
              final synthesized = [brand, model].where((s) => s.isNotEmpty).join(' ');
              pva['vehicle_name'] = pva['vehicle_name'] ?? (synthesized.isNotEmpty ? synthesized : 'Partner Vehicle');
              vehiclesMap[pva['id'].toString()] = pva;
              if (pva['partner_vehicle_id'] != null) {
                vehiclesMap[pva['partner_vehicle_id'].toString()] = pva;
              }
            }
          } catch (_) {}
        }

        // Add idle tracked vehicles to the result list
        for (final t in trackers) {
          final vid = (t['vehicle_id'] ?? t['partner_vehicle_id'] ?? t['vehicle_application_id'])?.toString() ?? '';
          if (vid.isNotEmpty && vehiclesWithActiveTracking.contains(vid)) {
            continue; // Already included as active booking
          }

          var veh = vehiclesMap[vid] ??
              (t['vehicle_id'] != null ? vehiclesMap[t['vehicle_id']?.toString()] : null) ??
              (t['partner_vehicle_id'] != null ? vehiclesMap[t['partner_vehicle_id']?.toString()] : null) ??
              (t['vehicle_application_id'] != null ? vehiclesMap[t['vehicle_application_id']?.toString()] : null);

          final deviceId = t['device_identifier']?.toString() ?? '';
          final bool isUnassigned = veh == null;
          if (veh == null) {
            veh = {
              'id': vid.isNotEmpty ? vid : 'tracker_${t['id']}',
              'brand': 'GPS Tracker',
              'model': deviceId.isNotEmpty ? deviceId : 'Device',
              'vehicle_name': deviceId.isNotEmpty ? 'GPS Tracker $deviceId' : 'GPS Tracker (Standby)',
              'plate_number': deviceId,
              'is_unassigned_tracker': true,
            };
          } else {
            veh = Map<String, dynamic>.from(veh);
            if ((veh['vehicle_name'] == null || veh['vehicle_name'].toString().trim().isEmpty) &&
                (veh['brand'] != null || veh['model'] != null)) {
              final b = veh['brand']?.toString().trim() ?? '';
              final m = veh['model']?.toString().trim() ?? '';
              final combo = [b, m].where((s) => s.isNotEmpty).join(' ');
              if (combo.isNotEmpty) veh['vehicle_name'] = combo;
            }
            if ((veh['plate_number'] == null || veh['plate_number'].toString().trim().isEmpty) &&
                deviceId.isNotEmpty) {
              veh['plate_number'] = deviceId;
            }
          }

          var lat = (t['last_latitude'] as num?)?.toDouble();
          var lng = (t['last_longitude'] as num?)?.toDouble();

          // Fallback to vehicle registered coordinates if tracker position is not yet synced
          if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
            lat = _asDouble(veh['latitude']);
            lng = _asDouble(veh['longitude']);
          }

          if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
            continue;
          }

          final lastSpeed = (t['last_speed'] as num?)?.toDouble() ?? 0.0;

          candidateList.add({
            'id': 'idle_tracker_${t['id']}',
            'vehicle_id': vid.isNotEmpty ? vid : 'tracker_${t['id']}',
            'latitude': lat,
            'longitude': lng,
            'speed_mps': lastSpeed / 3.6,
            'heading_degrees': 0.0,
            'source': 'gps_tracker',
            'recorded_at':
                t['last_sync_at'] ?? t['last_location_at'] ?? DateTime.now().toUtc().toIso8601String(),
            'updated_at':
                t['last_sync_at'] ?? DateTime.now().toUtc().toIso8601String(),
            'has_active_booking': false,
            'is_active_booking': false,
            'bookings': null,
            'vehicle': veh,
            'tracker': t,
            'status': 'Available (Idle)',
          });
        }
      } catch (e) {
        debugPrint('Error fetching idle vehicle trackers: $e');
      }

      // 3. Strict deduplication by vehicle plate number & vehicle ID
      final dedupedMap = <String, Map<String, dynamic>>{};
      for (final loc in candidateList) {
        final veh = (loc['vehicle'] ?? loc['bookings']?['vehicles']) as Map?;
        final rawPlate = veh?['plate_number']?.toString() ??
            loc['tracker']?['device_identifier']?.toString() ??
            '';
        final plate = rawPlate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        final vid = loc['vehicle_id']?.toString() ?? veh?['id']?.toString() ?? '';
        final dedupKey = plate.isNotEmpty
            ? 'plate_$plate'
            : (vid.isNotEmpty ? 'vid_$vid' : 'id_${loc['id']}');

        if (!dedupedMap.containsKey(dedupKey)) {
          dedupedMap[dedupKey] = loc;
          continue;
        }

        final existing = dedupedMap[dedupKey]!;
        final existingIsActive = existing['has_active_booking'] == true;
        final newIsActive = loc['has_active_booking'] == true;

        if (newIsActive && !existingIsActive) {
          dedupedMap[dedupKey] = loc; // Active trip replaces idle
        } else if (newIsActive == existingIsActive) {
          final existingDate = DateTime.tryParse(
            existing['recorded_at']?.toString() ?? existing['updated_at']?.toString() ?? '',
          );
          final newDate = DateTime.tryParse(
            loc['recorded_at']?.toString() ?? loc['updated_at']?.toString() ?? '',
          );
          if (newDate != null && (existingDate == null || newDate.isAfter(existingDate))) {
            dedupedMap[dedupKey] = loc; // More recent ping replaces older ping
          }
        }
      }

      return dedupedMap.values.toList();
    } catch (e) {
      debugPrint('Error loading tracking locations: $e');
      return [];
    }
  }

  /// 🔒 Partner-isolated live tracking: strictly fetches positions ONLY for vehicles
  /// owned by [partnerId] (excluding PSDC fleet and other partners).
  Future<List<Map<String, dynamic>>> getPartnerActiveTrackingLocations(String partnerId) async {
    try {
      if (partnerId.trim().isEmpty) return [];

      final partnerVehicleIds = <String>{};
      final vehiclesMap = <String, Map<String, dynamic>>{};

      // 1. Discover all vehicle IDs belonging to this partner
      try {
        final pv = await supabase
            .from('partner_vehicles')
            .select('id, brand, model, plate_number, partner_id, status, latitude, longitude')
            .eq('partner_id', partnerId);
        for (final row in List<Map<String, dynamic>>.from(pv)) {
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            partnerVehicleIds.add(id);
            final brand = row['brand']?.toString().trim() ?? '';
            final model = row['model']?.toString().trim() ?? '';
            final synthesized = [brand, model].where((s) => s.isNotEmpty).join(' ');
            row['vehicle_name'] = synthesized.isNotEmpty ? synthesized : 'Partner Vehicle';
            vehiclesMap[id] = row;
          }
        }
      } catch (_) {}

      try {
        final v = await supabase
            .from('vehicles')
            .select('id, brand, model, plate_number, owner_id, status, latitude, longitude')
            .or('owner_id.eq.$partnerId,partner_id.eq.$partnerId');
        for (final row in List<Map<String, dynamic>>.from(v)) {
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            partnerVehicleIds.add(id);
            final brand = row['brand']?.toString().trim() ?? '';
            final model = row['model']?.toString().trim() ?? '';
            final synthesized = [brand, model].where((s) => s.isNotEmpty).join(' ');
            row['vehicle_name'] = synthesized.isNotEmpty ? synthesized : 'Partner Vehicle';
            vehiclesMap[id] = row;
          }
        }
      } catch (_) {}

      try {
        final pva = await supabase
            .from('partner_vehicle_applications')
            .select('id, brand, model, plate_number, partner_id, partner_vehicle_id, status, latitude, longitude')
            .eq('partner_id', partnerId);
        for (final row in List<Map<String, dynamic>>.from(pva)) {
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            partnerVehicleIds.add(id);
            final brand = row['brand']?.toString().trim() ?? '';
            final model = row['model']?.toString().trim() ?? '';
            final synthesized = [brand, model].where((s) => s.isNotEmpty).join(' ');
            row['vehicle_name'] = synthesized.isNotEmpty ? synthesized : 'Partner Vehicle';
            vehiclesMap[id] = row;
          }
          final pvid = row['partner_vehicle_id']?.toString() ?? '';
          if (pvid.isNotEmpty) {
            partnerVehicleIds.add(pvid);
            vehiclesMap[pvid] = row;
          }
        }
      } catch (_) {}

      if (partnerVehicleIds.isEmpty) {
        return [];
      }

      final candidateList = <Map<String, dynamic>>[];
      final vehiclesWithLiveLoc = <String>{};

      // 2. Fetch tracking_locations filtered to partner vehicles
      try {
        final response = await supabase
            .from('tracking_locations')
            .select('''
              *,
              bookings:booking_id (
                id,
                status,
                partner_id,
                pickup_location,
                dropoff_location,
                pickup_latitude,
                pickup_longitude,
                dropoff_latitude,
                dropoff_longitude,
                start_at,
                end_at,
                vehicles:vehicle_id (
                  id,
                  brand,
                  model,
                  plate_number,
                  owner_id,
                  owner:owner_id (id, role)
                ),
                renter:renter_id (id, full_name, email),
                driver:driver_id (
                  id,
                  user_id,
                  users(id, full_name, email)
                )
              )
            ''')
            .inFilter('vehicle_id', partnerVehicleIds.toList())
            .order('recorded_at', ascending: false)
            .limit(40);

        const onTripStatuses = {
          'ongoing',
          'active',
          'picked_up',
          'in_progress',
        };

        for (final loc in List<Map<String, dynamic>>.from(response)) {
          final vid = loc['vehicle_id']?.toString() ?? '';
          if (!partnerVehicleIds.contains(vid)) continue;

          final booking = loc['bookings'] as Map<String, dynamic>?;
          final status = booking?['status']?.toString().toLowerCase() ?? '';
          final isReturnedOrCompleted = booking?['returned_at'] != null ||
              booking?['completed_at'] != null ||
              {'completed', 'returned', 'cancelled', 'rejected'}.contains(status);

          final isTripActive = onTripStatuses.contains(status) && !isReturnedOrCompleted;

          final enriched = Map<String, dynamic>.from(loc);
          enriched['has_active_booking'] = isTripActive;
          enriched['is_active_booking'] = isTripActive;
          enriched['vehicle'] = booking?['vehicles'] ?? vehiclesMap[vid];

          if (!isTripActive) {
            enriched['bookings'] = null;
            enriched['status'] = 'Available (Idle)';
          }

          candidateList.add(enriched);
          if (vid.isNotEmpty) vehiclesWithLiveLoc.add(vid);
        }
      } catch (e) {
        debugPrint('Error loading partner tracking_locations: $e');
      }

      // 3. Check connected GPS trackers for partner's idle vehicles
      try {
        final trackerRows = await supabase
            .from('vehicle_trackers')
            .select('*')
            .neq('connection_status', 'disconnected');

        for (final t in List<Map<String, dynamic>>.from(trackerRows)) {
          final vid = (t['vehicle_id'] ?? t['partner_vehicle_id'] ?? t['vehicle_application_id'])?.toString() ?? '';
          if (!partnerVehicleIds.contains(vid) || vehiclesWithLiveLoc.contains(vid)) {
            continue;
          }

          final veh = vehiclesMap[vid] ?? {
            'id': vid,
            'brand': 'GPS Tracker',
            'model': t['device_identifier']?.toString() ?? 'Partner Vehicle',
            'plate_number': t['device_identifier']?.toString() ?? '',
          };

          var lat = (t['last_latitude'] as num?)?.toDouble() ?? _asDouble(veh['latitude']);
          var lng = (t['last_longitude'] as num?)?.toDouble() ?? _asDouble(veh['longitude']);

          if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
            continue;
          }

          final lastSpeed = (t['last_speed'] as num?)?.toDouble() ?? 0.0;

          candidateList.add({
            'id': 'partner_tracker_${t['id']}',
            'vehicle_id': vid,
            'latitude': lat,
            'longitude': lng,
            'speed_mps': lastSpeed / 3.6,
            'heading_degrees': 0.0,
            'source': 'gps_tracker',
            'recorded_at': t['last_sync_at'] ?? t['last_location_at'] ?? DateTime.now().toUtc().toIso8601String(),
            'updated_at': t['last_sync_at'] ?? DateTime.now().toUtc().toIso8601String(),
            'has_active_booking': false,
            'is_active_booking': false,
            'bookings': null,
            'vehicle': veh,
            'tracker': t,
            'status': 'Available (Idle)',
          });

          vehiclesWithLiveLoc.add(vid);
        }
      } catch (e) {
        debugPrint('Error fetching partner idle vehicle trackers: $e');
      }

      // 4. Fallback for partner vehicles with registered coordinates but no tracking pings yet
      for (final vid in partnerVehicleIds) {
        if (!vehiclesWithLiveLoc.contains(vid)) {
          final veh = vehiclesMap[vid];
          if (veh != null) {
            final lat = _asDouble(veh['latitude']);
            final lng = _asDouble(veh['longitude']);
            if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
              candidateList.add({
                'id': 'partner_idle_$vid',
                'vehicle_id': vid,
                'latitude': lat,
                'longitude': lng,
                'speed_mps': 0.0,
                'heading_degrees': 0.0,
                'source': 'registered_location',
                'recorded_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
                'has_active_booking': false,
                'is_active_booking': false,
                'bookings': null,
                'vehicle': veh,
                'status': 'Available (Idle)',
              });
            }
          }
        }
      }

      // Deduplicate by plate/id
      final dedupedMap = <String, Map<String, dynamic>>{};
      for (final loc in candidateList) {
        final veh = (loc['vehicle'] ?? loc['bookings']?['vehicles']) as Map?;
        final rawPlate = veh?['plate_number']?.toString() ??
            loc['tracker']?['device_identifier']?.toString() ??
            '';
        final plate = rawPlate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        final vid = loc['vehicle_id']?.toString() ?? veh?['id']?.toString() ?? '';
        final dedupKey = plate.isNotEmpty
            ? 'plate_$plate'
            : (vid.isNotEmpty ? 'vid_$vid' : 'id_${loc['id']}');

        if (!dedupedMap.containsKey(dedupKey)) {
          dedupedMap[dedupKey] = loc;
          continue;
        }

        final existing = dedupedMap[dedupKey]!;
        final existingIsActive = existing['has_active_booking'] == true;
        final newIsActive = loc['has_active_booking'] == true;

        if (newIsActive && !existingIsActive) {
          dedupedMap[dedupKey] = loc;
        } else if (newIsActive == existingIsActive) {
          final existingDate = DateTime.tryParse(existing['recorded_at']?.toString() ?? '');
          final newDate = DateTime.tryParse(loc['recorded_at']?.toString() ?? '');
          if (newDate != null && (existingDate == null || newDate.isAfter(existingDate))) {
            dedupedMap[dedupKey] = loc;
          }
        }
      }

      return dedupedMap.values.toList();
    } catch (e) {
      debugPrint('Error loading partner tracking locations: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTrackingLocationForBooking(
    String bookingId,
  ) async {
    try {
      final access = await _currentTrackingAccess();
      if (access == null || {'renter', 'driver'}.contains(access.role)) {
        return null;
      }

      // Try polling the GPS tracker if assigned to this booking
      await pollGpsTrackerForBooking(bookingId);

      final response = await supabase
          .from('tracking_locations')
          .select('''
            *,
            bookings:booking_id (
              id,
              status,
              renter_id,
              operator_id,
              pickup_location,
              dropoff_location,
              pickup_latitude,
              pickup_longitude,
              dropoff_latitude,
              dropoff_longitude,
              start_at,
              end_at,
              vehicles:vehicle_id (
                id,
                brand,
                model,
                plate_number,
                owner_id,
                owner:owner_id (id, role)
              ),
              renter:renter_id (id, full_name, email, phone),
              driver:driver_id (
                id,
                user_id,
                users(id, full_name, email)
              )
            )
          ''')
          .eq('booking_id', bookingId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      final location = Map<String, dynamic>.from(response);
      final booking = location['bookings'] as Map<String, dynamic>?;
      final status = booking?['status']?.toString().toLowerCase() ?? '';
      const activeStatuses = {
        'active',
        'ongoing',
        'picked_up',
        'in_progress',
        'confirmed',
        'approved',
        'assigned',
        'return_pending_inspection',
      };
      if (!activeStatuses.contains(status)) return null;
      if (!_canViewTracking(access, booking)) return null;
      return location;
    } catch (e) {
      debugPrint('Error loading tracking location for booking $bookingId: $e');
      return null;
    }
  }

  Future<_TrackingAccess?> _currentTrackingAccess() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return null;
    final user = await supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final role = user?['role']?.toString().trim().toLowerCase() ?? '';
    if (role.isEmpty) return null;
    return _TrackingAccess(userId: userId, role: role);
  }

  bool _canViewTracking(_TrackingAccess access, Map<String, dynamic>? booking) {
    if (booking == null) return false;
    if (access.role == 'admin' ||
        access.role == 'super_admin' ||
        access.role == 'operator') {
      return true;
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    if (vehicle == null) return false;
    final owner = vehicle['owner'] as Map<String, dynamic>?;
    final ownerRole = owner?['role']?.toString().trim().toLowerCase();
    final ownerId = vehicle['owner_id']?.toString();
    final partnerVehicle =
        ownerRole == 'partner' ||
        vehicle['is_partner_vehicle'] == true ||
        vehicle['partner_vehicle_id'] != null;

    if (access.role == 'partner') {
      final bookingPartnerId = booking['partner_id']?.toString() ??
          booking['partner_user_id']?.toString() ??
          booking['partnerId']?.toString();
      if (bookingPartnerId != null && bookingPartnerId.isNotEmpty && bookingPartnerId == access.userId) {
        return true;
      }
      final ownerUserId = owner?['id']?.toString() ?? ownerId;
      return partnerVehicle && (ownerId == access.userId || ownerUserId == access.userId);
    }
    return false;
  }

  Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }
  }

  /// Polls all connected GPS hardware trackers (both active bookings and idle vehicles)
  /// and updates both vehicle_trackers table and tracking_locations.
  Future<void> pollGpsTrackersForActiveBookings() async {
    try {
      final gpsService = GpsService();

      // 1. Fetch all connected trackers from database
      final trackerRows = await supabase
          .from('vehicle_trackers')
          .select('*')
          .neq('connection_status', 'disconnected');

      final activeTrackers = List<Map<String, dynamic>>.from(trackerRows);
      if (activeTrackers.isEmpty) return;

      // 2. Fetch active bookings to associate if on a trip
      final activeBookingsRows = await supabase
          .from('bookings')
          .select('''
            id,
            status,
            vehicle_id,
            renter_id,
            driver_id
          ''')
          .inFilter('status', [
            'ongoing',
            'active',
            'picked_up',
            'in_progress',
          ]);
      final activeBookings = List<Map<String, dynamic>>.from(activeBookingsRows);
      final bookingByVehicleId = <String, Map<String, dynamic>>{};
      for (final b in activeBookings) {
        final vid = b['vehicle_id']?.toString() ?? '';
        if (vid.isNotEmpty) {
          bookingByVehicleId[vid] = b;
        }
      }

      for (final tMap in activeTrackers) {
        try {
          final tracker = VehicleTracker.fromJson(tMap);
          if (tracker.deviceIdentifier.trim().isEmpty) continue;

          final position = await gpsService.fetchLatestLocation(
            tracker: tracker,
          );
          if (position == null ||
              (position.latitude == 0.0 && position.longitude == 0.0)) {
            continue;
          }

          final targetVid = tracker.vehicleId ??
              tracker.partnerVehicleId ??
              tracker.vehicleApplicationId ??
              '';
          if (targetVid.isEmpty) continue;

          final booking = bookingByVehicleId[targetVid];
          if (booking != null) {
            final bookingId = booking['id']?.toString() ?? '';
            final trackedUserId = booking['driver_id']?.toString() ??
                booking['renter_id']?.toString() ??
                '';

            await supabase.from('tracking_locations').upsert(
              {
                'booking_id': bookingId,
                'vehicle_id': targetVid,
                'tracked_user_id':
                    trackedUserId.isEmpty ? targetVid : trackedUserId,
                'latitude': position.latitude,
                'longitude': position.longitude,
                'accuracy_meters': 10.0,
                'speed_mps': position.speedKph / 3.6,
                'heading_degrees': 0.0,
                'source': 'gps_tracker',
                'recorded_at': position.gpsTime?.toUtc().toIso8601String() ??
                    DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
              onConflict: 'booking_id,tracked_user_id',
            );

            // Append GPS movement trail log for historical route playback and auditing
            try {
              await supabase.from('tracking_location_logs').insert({
                'booking_id': bookingId,
                'vehicle_id': targetVid,
                'tracked_user_id':
                    trackedUserId.isEmpty ? targetVid : trackedUserId,
                'latitude': position.latitude,
                'longitude': position.longitude,
                'accuracy_meters': 10.0,
                'speed_mps': position.speedKph / 3.6,
                'heading_degrees': 0.0,
                'source': 'gps_tracker',
                'recorded_at': position.gpsTime?.toUtc().toIso8601String() ??
                    DateTime.now().toUtc().toIso8601String(),
              });

              final posObj = Position(
                latitude: position.latitude,
                longitude: position.longitude,
                timestamp: position.gpsTime ?? DateTime.now(),
                accuracy: 10.0,
                altitude: 0.0,
                altitudeAccuracy: 0.0,
                heading: 0.0,
                headingAccuracy: 0.0,
                speed: position.speedKph / 3.6,
                speedAccuracy: 0.0,
              );
              await _evaluateSafetySignals(
                bookingId: bookingId,
                vehicleId: targetVid,
                position: posObj,
              );
            } catch (logErr) {
              debugPrint('GPS movement trail logging note: $logErr');
            }
          } else {
            // Vehicle is currently IDLE (no active on-trip booking)
            try {
              await supabase.from('vehicle_trackers').update({
                'last_latitude': position.latitude,
                'last_longitude': position.longitude,
                'last_speed': position.speedKph,
                'last_location_at': position.gpsTime?.toUtc().toIso8601String() ??
                    DateTime.now().toUtc().toIso8601String(),
                'last_sync_at': DateTime.now().toUtc().toIso8601String(),
                'connection_status': 'connected',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('id', tracker.id);

              if (tracker.vehicleId != null && tracker.vehicleId!.isNotEmpty) {
                await supabase.from('vehicles').update({
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                }).eq('id', tracker.vehicleId!);
              }
              if (tracker.partnerVehicleId != null &&
                  tracker.partnerVehicleId!.isNotEmpty) {
                await supabase.from('partner_vehicles').update({
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', tracker.partnerVehicleId!);
              }
            } catch (idleErr) {
              debugPrint('Error updating idle tracker position: $idleErr');
            }
          }
        } catch (e) {
          debugPrint('Error polling tracker: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in pollGpsTrackersForActiveBookings: $e');
    }
  }

  /// Polls the GPS hardware tracker for a specific booking and upserts the
  /// location into [tracking_locations] and [tracking_location_logs].
  Future<void> pollGpsTrackerForBooking(String bookingId) async {
    if (bookingId.isEmpty) return;
    try {
      final booking = await supabase
          .from('bookings')
          .select('id, vehicle_id, renter_id, driver_id')
          .eq('id', bookingId)
          .maybeSingle();
      if (booking == null) return;

      final vehicleId = booking['vehicle_id']?.toString() ?? '';
      if (vehicleId.isEmpty) return;

      final gpsService = GpsService();
      final tracker = await gpsService.getTrackerForVehicle(vehicleId);
      if (tracker == null ||
          tracker.connectionStatus == GpsConnectionStatus.disconnected ||
          tracker.deviceIdentifier.trim().isEmpty) {
        return;
      }

      final position = await gpsService.fetchLatestLocation(tracker: tracker);
      if (position == null ||
          (position.latitude == 0.0 && position.longitude == 0.0)) {
        return;
      }

      final trackedUserId = booking['driver_id']?.toString() ??
          booking['renter_id']?.toString() ??
          '';

      await supabase.from('tracking_locations').upsert(
        {
          'booking_id': bookingId,
          'vehicle_id': vehicleId,
          'tracked_user_id': trackedUserId.isEmpty ? vehicleId : trackedUserId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy_meters': 10.0,
          'speed_mps': position.speedKph / 3.6,
          'heading_degrees': 0.0,
          'source': 'gps_tracker',
          'recorded_at': position.gpsTime?.toUtc().toIso8601String() ??
              DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'booking_id,tracked_user_id',
      );

      // Append GPS movement trail log
      try {
        await supabase.from('tracking_location_logs').insert({
          'booking_id': bookingId,
          'vehicle_id': vehicleId,
          'tracked_user_id':
              trackedUserId.isEmpty ? vehicleId : trackedUserId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy_meters': 10.0,
          'speed_mps': position.speedKph / 3.6,
          'heading_degrees': 0.0,
          'source': 'gps_tracker',
          'recorded_at': position.gpsTime?.toUtc().toIso8601String() ??
              DateTime.now().toUtc().toIso8601String(),
        });

        final posObj = Position(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: position.gpsTime ?? DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: position.speedKph / 3.6,
          speedAccuracy: 0.0,
        );
        await _evaluateSafetySignals(
          bookingId: bookingId,
          vehicleId: vehicleId,
          position: posObj,
        );
      } catch (logErr) {
        debugPrint('GPS movement trail logging note: $logErr');
      }
    } catch (e) {
      debugPrint('Error polling GPS tracker for booking $bookingId: $e');
    }
  }

  /// Fetches complete chronological GPS route trail for a booking
  Future<List<Map<String, dynamic>>> getTripRouteHistory(String bookingId) async {
    if (bookingId.isEmpty) return [];
    try {
      final rows = await supabase
          .from('tracking_location_logs')
          .select('*')
          .eq('booking_id', bookingId)
          .order('recorded_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching trip route history for booking $bookingId: $e');
      return [];
    }
  }

  /// Pure math geodesic distance in meters (fast, works synchronously on all platforms/web)
  double _distanceBetweenMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Fetches the planned road route from pickup to destination via OSRM (non-blocking fallback)
  Future<List<Map<String, double>>> getPlannedRoadRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final fallback = [
      {'latitude': startLat, 'longitude': startLng},
      {'latitude': endLat, 'longitude': endLng},
    ];
    final samePoint = (startLat - endLat).abs() < 0.0001 &&
        (startLng - endLng).abs() < 0.0001;
    if (samePoint) {
      return [
        {'latitude': startLat, 'longitude': startLng}
      ];
    }
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$startLng,$startLat;$endLng,$endLat'
        '?overview=full&geometries=geojson&steps=false',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = payload['routes'] as List<dynamic>? ?? const [];
        if (routes.isNotEmpty) {
          final first = Map<String, dynamic>.from(routes.first as Map);
          final geometry = first['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?;
          if (coordinates != null && coordinates.length >= 2) {
            return coordinates.map((coordinate) {
              final pair = coordinate as List<dynamic>;
              return {
                'latitude': (pair[1] as num).toDouble(),
                'longitude': (pair[0] as num).toDouble(),
              };
            }).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM planned route fetch: $e');
    }
    return fallback;
  }

  /// Evaluates whether the vehicle went outside the agreed destination and computes penalties
  Future<Map<String, dynamic>> evaluateTripDestinationCompliance(
    String bookingId,
  ) async {
    if (bookingId.isEmpty) {
      return {
        'isCompliant': true,
        'maxDeviationKm': 0.0,
        'penaltyAmount': 0.0,
        'violationCount': 0,
        'pointsCount': 0,
        'totalDistanceKm': 0.0,
        'topSpeedKph': 0.0,
        'safetyEvents': <Map<String, dynamic>>[],
        'routePoints': <Map<String, dynamic>>[],
        'recommendedRoute': <Map<String, double>>[],
      };
    }

    try {
      final bookingResponse = await supabase
          .from('bookings')
          .select('*, vehicles(id, brand, model, plate_number)')
          .eq('id', bookingId)
          .maybeSingle();

      final booking = bookingResponse != null
          ? Map<String, dynamic>.from(bookingResponse)
          : <String, dynamic>{};

      // Resolve pickup coordinates (fallback to synchronous geocoding if null or 0)
      double? pickupLat = _asDouble(booking['pickup_latitude']);
      double? pickupLng = _asDouble(booking['pickup_longitude']);
      if ((pickupLat == null || pickupLng == null || (pickupLat == 0.0 && pickupLng == 0.0)) &&
          booking['pickup_location'] != null &&
          booking['pickup_location'].toString().trim().isNotEmpty) {
        try {
          final resolved = PhilippineGeocoding.resolveLocationSync(booking['pickup_location']);
          pickupLat = resolved.latitude;
          pickupLng = resolved.longitude;
        } catch (_) {}
      }

      // Resolve dropoff coordinates (fallback to synchronous geocoding if null or 0)
      double? dropoffLat = _asDouble(booking['dropoff_latitude']);
      double? dropoffLng = _asDouble(booking['dropoff_longitude']);
      if ((dropoffLat == null || dropoffLng == null || (dropoffLat == 0.0 && dropoffLng == 0.0)) &&
          booking['dropoff_location'] != null &&
          booking['dropoff_location'].toString().trim().isNotEmpty) {
        try {
          final resolved = PhilippineGeocoding.resolveLocationSync(booking['dropoff_location']);
          dropoffLat = resolved.latitude;
          dropoffLng = resolved.longitude;
        } catch (_) {}
      }
      dropoffLat ??= pickupLat;
      dropoffLng ??= pickupLng;

      // 1. Actual vehicle GPS trail from tracking_location_logs
      final rawPoints = await getTripRouteHistory(bookingId);
      final List<Map<String, dynamic>> points = [];

      // ✅ Use actual recorded vehicle GPS points from tracking_location_logs
      if (rawPoints.isNotEmpty) {
        points.addAll(rawPoints);
      } else if (pickupLat != null && pickupLng != null && pickupLat != 0.0 && pickupLng != 0.0) {
        // Fallback to single pickup origin point only if no GPS logs have been recorded yet
        final tripStartIso = booking['start_at']?.toString() ??
            booking['start_date']?.toString() ??
            DateTime.now().toUtc().toIso8601String();
        points.add({
          'booking_id': bookingId,
          'latitude': pickupLat,
          'longitude': pickupLng,
          'speed_mps': 0.0,
          'heading_degrees': 0.0,
          'source': 'pickup_origin',
          'recorded_at': tripStartIso,
        });
      }

      // 2. Fetch the planned / recommended road route from pickup to destination for destination reference
      List<Map<String, double>> recommendedRoute = [];
      if (pickupLat != null && pickupLng != null && dropoffLat != null && dropoffLng != null &&
          pickupLat != 0.0 && pickupLng != 0.0 && dropoffLat != 0.0 && dropoffLng != 0.0) {
        recommendedRoute = await getPlannedRoadRoute(
          startLat: pickupLat,
          startLng: pickupLng,
          endLat: dropoffLat,
          endLng: dropoffLng,
        );
      }

      double totalDistanceMeters = 0.0;
      double topSpeedMps = 0.0;
      double maxDeviationFromDestinationMeters = 0.0;
      int violationPoints = 0;

      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final lat = _asDouble(p['latitude']) ?? 0.0;
        final lng = _asDouble(p['longitude']) ?? 0.0;
        final speed = _asDouble(p['speed_mps']) ?? 0.0;
        if (speed > topSpeedMps) topSpeedMps = speed;

        if (i > 0) {
          final prevLat = _asDouble(points[i - 1]['latitude']) ?? 0.0;
          final prevLng = _asDouble(points[i - 1]['longitude']) ?? 0.0;
          if (lat != 0.0 && lng != 0.0 && prevLat != 0.0 && prevLng != 0.0) {
            totalDistanceMeters += _distanceBetweenMeters(
              prevLat,
              prevLng,
              lat,
              lng,
            );
          }
        }

        if (dropoffLat != null && dropoffLng != null && lat != 0.0 && lng != 0.0) {
          final distFromDest = _distanceBetweenMeters(
            dropoffLat,
            dropoffLng,
            lat,
            lng,
          );
          if (distFromDest > maxDeviationFromDestinationMeters) {
            maxDeviationFromDestinationMeters = distFromDest;
          }
          // If car is > 30km away from destination and > 30km from pickup
          if (distFromDest > 30000) {
            final distFromPickup = (pickupLat != null && pickupLng != null)
                ? _distanceBetweenMeters(pickupLat, pickupLng, lat, lng)
                : distFromDest;
            if (distFromPickup > 30000) {
              violationPoints++;
            }
          }
        }
      }

      // Fetch any safety events for this booking
      List<Map<String, dynamic>> safetyEvents = [];
      try {
        final eventRows = await supabase
            .from('trip_safety_events')
            .select('*')
            .eq('booking_id', bookingId)
            .order('created_at', ascending: false);
        safetyEvents = List<Map<String, dynamic>>.from(eventRows);
      } catch (_) {}

      final hasDestinationViolationEvent = safetyEvents.any(
        (e) =>
            e['event_type']?.toString().contains('geofence') == true ||
            e['event_type']?.toString().contains('destination') == true,
      );

      final isCompliant = violationPoints == 0 && !hasDestinationViolationEvent;
      final maxDeviationKm = maxDeviationFromDestinationMeters / 1000.0;

      // Recommended destination penalty calculation:
      // Base penalty ₱1,000 for destination violation + ₱50 per km beyond 25km deviation
      double recommendedPenalty = 0.0;
      if (!isCompliant) {
        final excessKm = (maxDeviationKm - 25.0).clamp(0.0, 500.0);
        recommendedPenalty = 1000.0 + (excessKm * 50.0);
      }

      return {
        'isCompliant': isCompliant,
        'maxDeviationKm': maxDeviationKm,
        'penaltyAmount': recommendedPenalty,
        'violationCount': violationPoints,
        'pointsCount': points.length,
        'totalDistanceKm': totalDistanceMeters / 1000.0,
        'topSpeedKph': topSpeedMps * 3.6,
        'booking': booking,
        'safetyEvents': safetyEvents,
        'routePoints': points,
        'recommendedRoute': recommendedRoute,
        'dropoffLocation':
            booking['dropoff_location']?.toString() ?? 'Stated Destination',
        'pickupLocation':
            booking['pickup_location']?.toString() ?? 'Origin Pickup',
      };
    } catch (e) {
      debugPrint('Error evaluating destination compliance: $e');
      return {
        'isCompliant': true,
        'maxDeviationKm': 0.0,
        'penaltyAmount': 0.0,
        'violationCount': 0,
        'pointsCount': 0,
        'totalDistanceKm': 0.0,
        'topSpeedKph': 0.0,
        'safetyEvents': <Map<String, dynamic>>[],
        'routePoints': <Map<String, dynamic>>[],
        'recommendedRoute': <Map<String, double>>[],
      };
    }
  }
}

class _TrackingAccess {
  final String userId;
  final String role;

  const _TrackingAccess({required this.userId, required this.role});
}
