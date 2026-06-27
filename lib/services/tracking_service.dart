import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();

  factory TrackingService() => _instance;

  TrackingService._internal();

  final SupabaseClient supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionSubscription;
  String? _activeBookingId;

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
  }

  Future<List<Map<String, dynamic>>> getActiveTrackingLocations() async {
    try {
      final response = await supabase
          .from('tracking_locations')
          .select('''
            *,
            bookings:booking_id (
              id,
              status,
              pickup_location,
              dropoff_location,
              vehicles:vehicle_id (id, brand, model, plate_number),
              renter:renter_id (id, full_name, email),
              drivers:driver_id (id, user_id, users:user_id (id, full_name, email))
            )
          ''')
          .order('recorded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).where((location) {
        final booking = location['bookings'] as Map<String, dynamic>?;
        final status = booking?['status']?.toString().toLowerCase();
        return status == 'active' ||
            status == 'approved' ||
            status == 'confirmed';
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
              vehicles:vehicle_id (id, brand, model, plate_number, owner_id, operator_id),
              renter:renter_id (id, full_name, email, phone),
              drivers:driver_id (id, user_id, users:user_id (id, full_name, email))
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
      if (!{'active', 'approved', 'confirmed'}.contains(status)) return null;

      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) return null;

      final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
      final driver = booking?['drivers'] as Map<String, dynamic>?;
      final allowedUserIds = {
        booking?['renter_id']?.toString(),
        booking?['operator_id']?.toString(),
        vehicle?['owner_id']?.toString(),
        vehicle?['operator_id']?.toString(),
        driver?['user_id']?.toString(),
      }..removeWhere((id) => id == null || id.isEmpty);

      if (!allowedUserIds.contains(currentUserId)) return null;
      return location;
    } catch (e) {
      debugPrint('Error loading tracking location for booking $bookingId: $e');
      return null;
    }
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
}
