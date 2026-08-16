import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';
import 'gps_service.dart';

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
              'unauthorized_stop_${DateTime.now().millisecondsSinceEpoch ~/ 1800000}',
          severity: 'warning',
          title: 'Extended stop detected',
          message: 'The vehicle has remained stopped for at least 15 minutes.',
          latitude: position.latitude,
          longitude: position.longitude,
          speedKph: speedKph,
          notifyParticipants: true,
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
              vehicles:vehicle_id (
                id,
                brand,
                model,
                plate_number,
                owner_id,
                owner:owner_id (id, role)
              ),
              renter:renter_id (id, full_name, email),
              drivers:drivers!bookings_driver_id_fkey (
                id,
                user_id,
                users:users!drivers_user_id_fkey (id, full_name, email)
              )
            )
          ''')
          .order('recorded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).where((location) {
        final booking = location['bookings'] as Map<String, dynamic>?;
        final status = booking?['status']?.toString().toLowerCase();
        return (status == 'active' || status == 'ongoing') &&
            _canViewTracking(access, booking);
      }).toList();
    } catch (e) {
      debugPrint('Error loading tracking locations: $e');
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
              vehicles:vehicle_id (
                id,
                brand,
                model,
                plate_number,
                owner_id,
                owner:owner_id (id, role)
              ),
              renter:renter_id (id, full_name, email, phone),
              drivers:drivers!bookings_driver_id_fkey (
                id,
                user_id,
                users:users!drivers_user_id_fkey (id, full_name, email)
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
      if (!{'active', 'ongoing'}.contains(status)) return null;
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
    if (access.role == 'admin' || access.role == 'super_admin') return true;

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
      return partnerVehicle && ownerId == access.userId;
    }
    if (access.role == 'operator') {
      return !partnerVehicle;
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

  /// Polls all connected GPS hardware trackers linked to active bookings
  /// and upserts their latest position into [tracking_locations] so the
  /// admin Live Tracking page can display real-time IMEI GPS tracker data.
  Future<void> pollGpsTrackersForActiveBookings() async {
    try {
      // 1. Find all active/ongoing bookings that have a connected GPS tracker
      final bookings = await supabase
          .from('bookings')
          .select('''
            id,
            status,
            vehicle_id,
            renter_id,
            driver_id
          ''')
          .inFilter('status', ['active', 'ongoing']);

      final activeBookings = List<Map<String, dynamic>>.from(bookings);
      if (activeBookings.isEmpty) return;

      final gpsService = GpsService();

      for (final booking in activeBookings) {
        final vehicleId = booking['vehicle_id']?.toString() ?? '';
        if (vehicleId.isEmpty) continue;

        try {
          // 2. Check if this vehicle has a connected GPS tracker
          final tracker = await gpsService.getTrackerForVehicle(vehicleId);
          if (tracker == null || !tracker.isConnected) continue;

          // 3. Poll the GPS tracker for its latest position
          final position = await gpsService.fetchLatestLocation(
            tracker: tracker,
          );
          if (position == null ||
              (position.latitude == 0.0 && position.longitude == 0.0)) {
            continue;
          }

          // 4. Upsert into tracking_locations so the Live Tracking map shows it
          final bookingId = booking['id']?.toString() ?? '';
          final trackedUserId = booking['driver_id']?.toString() ??
              booking['renter_id']?.toString() ??
              '';

          await supabase.from('tracking_locations').upsert(
            {
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
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'booking_id,tracked_user_id',
          );
        } catch (e) {
          debugPrint(
            'GPS tracker poll failed for vehicle $vehicleId: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('Error polling GPS trackers for active bookings: $e');
    }
  }

  /// Polls the GPS hardware tracker for a specific booking and upserts the
  /// location into [tracking_locations].
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
      if (tracker == null || !tracker.isConnected) return;

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
    } catch (e) {
      debugPrint('Error polling GPS tracker for booking $bookingId: $e');
    }
  }
}

class _TrackingAccess {
  final String userId;
  final String role;

  const _TrackingAccess({required this.userId, required this.role});
}
