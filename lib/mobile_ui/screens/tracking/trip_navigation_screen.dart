import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/gps_tracker_model.dart';
import '../../../services/gps_service.dart';
import '../../../services/tracking_service.dart';
import '../../../utils/philippine_geocoding.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking_return_countdown.dart';
import '../../widgets/leaflet_map.dart';

class TripNavigationScreen extends StatefulWidget {
  final String bookingId;
  final String participantRole;

  const TripNavigationScreen({
    super.key,
    required this.bookingId,
    required this.participantRole,
  });

  @override
  State<TripNavigationScreen> createState() => _TripNavigationScreenState();
}

class _TripNavigationScreenState extends State<TripNavigationScreen> {
  final TrackingService _trackingService = TrackingService();
  final GpsService _gpsService = GpsService();
  final MapController _mapController = MapController();

  Timer? _refreshTimer;
  Map<String, dynamic>? _booking;
  Map<String, dynamic>? _vehicleLocation;
  List<MobilisMapPoint> _route = const [];
  double? _distanceKm;
  double? _estimatedMinutes;
  double? _destinationLatitude;
  double? _destinationLongitude;
  String? _destinationAddress;
  String? _vehicleAddress;
  String? _error;
  bool _loading = true;
  bool _isRefreshing = false;
  bool _sendingEmergency = false;
  bool _isNoteCollapsed = false;
  MobilisMapStyle _mapStyle = MobilisMapStyle.street;
  String? _lastRouteKey;
  DateTime? _lastTrackerUpdate;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Continuous 8-second polling for live vehicle GPS updates
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Resolves the vehicle's position directly from the onboard GPS hardware
  /// or vehicle telemetry (from the car itself, not the driver's phone).
  Future<Map<String, dynamic>?> _resolveVehicleLocation(
    Map<String, dynamic> booking,
  ) async {
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final vehicleId = vehicle['id']?.toString() ??
        booking['vehicle_id']?.toString() ??
        '';

    if (vehicleId.isEmpty) return null;

    // 1. Check GpsService and live provider telemetry (Aika / Traccar hardware tracker)
    try {
      final tracker = await _gpsService.getTrackerForVehicle(vehicleId);
      if (tracker != null) {
        try {
          final livePos = await _gpsService.fetchLatestLocation(tracker: tracker);
          if (livePos != null &&
              (livePos.latitude != 0 || livePos.longitude != 0)) {
            return {
              'latitude': livePos.latitude,
              'longitude': livePos.longitude,
              'speed_kph': livePos.speedKph,
              'recorded_at': livePos.timestamp?.toIso8601String() ??
                  DateTime.now().toIso8601String(),
              'source': 'vehicle_gps_tracker',
              'provider': tracker.provider,
            };
          }
        } catch (_) {}

        if (tracker.latitude != null &&
            tracker.longitude != null &&
            (tracker.latitude != 0 || tracker.longitude != 0)) {
          return {
            'latitude': tracker.latitude,
            'longitude': tracker.longitude,
            'speed_kph': tracker.speedKph,
            'recorded_at': tracker.lastLocationUpdate?.toIso8601String() ??
                DateTime.now().toIso8601String(),
            'source': 'vehicle_gps_tracker',
            'provider': tracker.provider,
          };
        }
      }
    } catch (e) {
      debugPrint('Error resolving tracker for vehicle: $e');
    }

    // 2. Query vehicle_trackers table directly
    try {
      final trackerRows = await Supabase.instance.client
          .from('vehicle_trackers')
          .select(
            'latitude, longitude, speed_kph, last_location_update, address, provider',
          )
          .or('vehicle_id.eq.$vehicleId,partner_vehicle_id.eq.$vehicleId')
          .order('last_location_update', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(trackerRows);
      if (list.isNotEmpty) {
        final lat = _asDouble(list.first['latitude']);
        final lng = _asDouble(list.first['longitude']);
        if (lat != null && lng != null && (lat != 0 || lng != 0)) {
          return {
            'latitude': lat,
            'longitude': lng,
            'speed_kph': _asDouble(list.first['speed_kph']),
            'recorded_at': list.first['last_location_update'],
            'address': list.first['address'],
            'source': 'vehicle_gps_tracker',
            'provider': list.first['provider'] ?? 'gps_tracker',
          };
        }
      }
    } catch (e) {
      debugPrint('Direct vehicle_trackers query error: $e');
    }

    // 3. Query tracking_locations table for vehicle-associated coordinates
    try {
      final locRows = await Supabase.instance.client
          .from('tracking_locations')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('recorded_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(locRows);
      if (list.isNotEmpty) {
        final lat = _asDouble(list.first['latitude']);
        final lng = _asDouble(list.first['longitude']);
        if (lat != null && lng != null && (lat != 0 || lng != 0)) {
          return {
            'latitude': lat,
            'longitude': lng,
            'speed_kph': _asDouble(list.first['speed_mps']) != null
                ? (_asDouble(list.first['speed_mps'])! * 3.6)
                : null,
            'recorded_at': list.first['recorded_at'],
            'source': list.first['source'] ?? 'vehicle_telemetry',
          };
        }
      }
    } catch (e) {
      debugPrint('Direct tracking_locations query error: $e');
    }

    // 4. Fallback to vehicle's registered location / coordinates in vehicles table
    try {
      final rawLocation = vehicle['location'] ??
          vehicle['address'] ??
          vehicle['city'] ??
          '';
      final point = PhilippineGeocoding.resolveLocationSync(
        rawLocation.toString(),
        latitudeValue: vehicle['latitude'],
        longitudeValue: vehicle['longitude'],
      );
      if (PhilippineGeocoding.isValidPhilippines(point)) {
        return {
          'latitude': point.latitude,
          'longitude': point.longitude,
          'source': 'vehicle_registered_location',
        };
      }
    } catch (e) {
      debugPrint('Vehicle registered location fallback error: $e');
    }

    return null;
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    if (silent && mounted) setState(() => _isRefreshing = true);

    final navigation = await _trackingService
        .getParticipantNavigationLocationForBooking(widget.bookingId);

    if (navigation == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isRefreshing = false;
        _error =
            'Navigation is available for assigned active or ongoing bookings.';
      });
      return;
    }

    final booking = Map<String, dynamic>.from(
      navigation['booking'] as Map<String, dynamic>,
    );

    // CRITICAL: Resolve location from the CAR ITSELF (onboard GPS tracker), NOT the driver's phone!
    final vehicleLoc = await _resolveVehicleLocation(booking);
    final location = vehicleLoc ??
        (navigation['location'] is Map
            ? Map<String, dynamic>.from(navigation['location'] as Map)
            : null);

    if (!mounted) return;
    setState(() {
      _booking = booking;
      _vehicleLocation = location;
      _loading = false;
      _isRefreshing = false;
      _lastTrackerUpdate = DateTime.now();
      _error = location == null
          ? 'Connecting to vehicle GPS tracker... Waiting for signal.'
          : null;
    });

    await _updateRoute();
    _reverseGeocodePoints();
  }

  Future<void> _updateRoute() async {
    final booking = _booking;
    final location = _vehicleLocation;
    if (booking == null || location == null) return;

    final currentLat = _asDouble(location['latitude']);
    final currentLng = _asDouble(location['longitude']);
    var destinationLat = _asDouble(booking['dropoff_latitude']);
    var destinationLng = _asDouble(booking['dropoff_longitude']);

    if (destinationLat == null || destinationLng == null) {
      final address = (booking['dropoff_location'] ?? booking['pickup_location'])
          ?.toString()
          .trim() ??
          '';
      if (address.isNotEmpty) {
        try {
          final matches = await locationFromAddress(address);
          if (matches.isNotEmpty) {
            destinationLat = matches.first.latitude;
            destinationLng = matches.first.longitude;
          }
        } catch (_) {
          final fallbackPoint = PhilippineGeocoding.resolveLocationSync(address);
          destinationLat = fallbackPoint.latitude;
          destinationLng = fallbackPoint.longitude;
        }
      }
    }

    if (currentLat == null ||
        currentLng == null ||
        destinationLat == null ||
        destinationLng == null) {
      return;
    }

    final routeKey = [
      currentLat.toStringAsFixed(4),
      currentLng.toStringAsFixed(4),
      destinationLat.toStringAsFixed(4),
      destinationLng.toStringAsFixed(4),
    ].join(':');
    if (_lastRouteKey == routeKey) return;
    _lastRouteKey = routeKey;

    var route = <MobilisMapPoint>[
      MobilisMapPoint(latitude: currentLat, longitude: currentLng),
      MobilisMapPoint(latitude: destinationLat, longitude: destinationLng),
    ];
    var distanceMeters = Geolocator.distanceBetween(
      currentLat,
      currentLng,
      destinationLat,
      destinationLng,
    );
    var durationSeconds = distanceMeters / 11.11;

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$currentLng,$currentLat;$destinationLng,$destinationLat'
        '?overview=full&geometries=geojson&steps=false',
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = payload['routes'] as List<dynamic>? ?? const [];
        if (routes.isNotEmpty) {
          final first = Map<String, dynamic>.from(routes.first as Map);
          final geometry = first['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?;
          if (coordinates != null && coordinates.length >= 2) {
            route = coordinates.map((coordinate) {
              final pair = coordinate as List<dynamic>;
              return MobilisMapPoint(
                latitude: (pair[1] as num).toDouble(),
                longitude: (pair[0] as num).toDouble(),
              );
            }).toList();
          }
          distanceMeters =
              (first['distance'] as num?)?.toDouble() ?? distanceMeters;
          durationSeconds =
              (first['duration'] as num?)?.toDouble() ?? durationSeconds;
        }
      }
    } catch (_) {
      // Straight-line fallback keeps navigation usable during routing outages
    }

    if (!mounted) return;
    setState(() {
      _route = route;
      _distanceKm = distanceMeters / 1000;
      _estimatedMinutes = durationSeconds / 60;
      _destinationLatitude = destinationLat;
      _destinationLongitude = destinationLng;
      _destinationAddress =
          booking['dropoff_location']?.toString() ?? 'Destination point';
    });
  }

  Future<void> _reverseGeocodePoints() async {
    final location = _vehicleLocation;
    if (location == null) return;
    final lat = _asDouble(location['latitude']);
    final lng = _asDouble(location['longitude']);
    if (lat == null || lng == null) return;

    if (location['address'] != null &&
        location['address'].toString().trim().isNotEmpty) {
      if (mounted) {
        setState(() => _vehicleAddress = location['address'].toString());
      }
      return;
    }

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = [p.street, p.subLocality, p.locality, p.administrativeArea]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
        if (parts.isNotEmpty) {
          setState(() => _vehicleAddress = parts.join(', '));
        }
      }
    } catch (_) {}
  }

  void _recenterOnVehicle() {
    final lat = _asDouble(_vehicleLocation?['latitude']);
    final lng = _asDouble(_vehicleLocation?['longitude']);
    if (lat != null && lng != null) {
      _mapController.move(LatLng(lat, lng), 15.5);
    }
  }

  void _recenterOnRoute() {
    if (_route.isEmpty) {
      _recenterOnVehicle();
      return;
    }
    final latLngPoints = _route.map((p) => p.point).toList();
    if (latLngPoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(latLngPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(48, 140, 48, 220),
        ),
      );
    }
  }

  Future<void> _openExternalDirections() async {
    final currentLat = _asDouble(_vehicleLocation?['latitude']);
    final currentLng = _asDouble(_vehicleLocation?['longitude']);
    final destLat = _destinationLatitude;
    final destLng = _destinationLongitude;

    if (destLat == null || destLng == null) return;

    final originParam = currentLat != null && currentLng != null
        ? '&origin=$currentLat,$currentLng'
        : '';
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1$originParam&destination=$destLat,$destLng&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching external navigation: $e');
    }
  }

  double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    final currentLat = _asDouble(_vehicleLocation?['latitude']);
    final currentLng = _asDouble(_vehicleLocation?['longitude']);
    final destinationLat = _destinationLatitude;
    final destinationLng = _destinationLongitude;

    final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
    final vehicleTitle = [vehicle?['brand'], vehicle?['model']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' ');
    final plateNumber = vehicle?['plate_number']?.toString().trim() ?? '';

    final markers = <MobilisMapMarker>[
      if (currentLat != null && currentLng != null)
        MobilisMapMarker(
          latitude: currentLat,
          longitude: currentLng,
          icon: Icons.directions_car_filled_rounded,
          color: AppColors.primary,
          size: 40,
          label: 'Vehicle (Car GPS)',
          tooltip:
              '${vehicleTitle.isEmpty ? "Car" : vehicleTitle} • Live onboard GPS fix',
        ),
      if (destinationLat != null && destinationLng != null)
        MobilisMapMarker(
          latitude: destinationLat,
          longitude: destinationLng,
          icon: Icons.location_pin,
          color: Colors.redAccent,
          size: 42,
          label: 'Destination',
          tooltip: _destinationAddress ?? 'Trip destination',
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : booking == null
              ? _ErrorState(
                  message: _error ?? 'Trip navigation is currently unavailable.',
                  onRetry: _refresh,
                )
              : Stack(
                  children: [
                    // ───────────────────────────────────────────────────────────
                    // 1. FULL-SCREEN MAP
                    // ───────────────────────────────────────────────────────────
                    Positioned.fill(
                      child: MobilisLeafletMap(
                        mapController: _mapController,
                        markers: markers,
                        routePoints: _route,
                        routeColor: AppColors.primary,
                        fallbackLatitude:
                            currentLat ?? destinationLat ?? 15.9758,
                        fallbackLongitude:
                            currentLng ?? destinationLng ?? 120.5719,
                        mapStyle: _mapStyle,
                        interactive: true,
                        showAttribution: false,
                      ),
                    ),

                    // ───────────────────────────────────────────────────────────
                    // 2. FLOATING TOP HEADER BAR
                    // ───────────────────────────────────────────────────────────
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: [
                          // Circular Back Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 1,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Vehicle Info & Live Tracker Chip
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.directions_car_filled_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          vehicleTitle.isEmpty
                                              ? 'Active Vehicle'
                                              : vehicleTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: _isRefreshing
                                                    ? AppColors.primary
                                                    : const Color(0xFF10B981),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _isRefreshing
                                                  ? 'REFRESHING GPS...'
                                                  : 'CAR GPS • LIVE (8s)',
                                              style: TextStyle(
                                                color: _isRefreshing
                                                    ? AppColors.primary
                                                    : const Color(0xFF10B981),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            if (plateNumber.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '• $plateNumber',
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 9.5,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Layer Switcher / Refresh
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white24,
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              tooltip: 'Refresh Vehicle GPS',
                              onPressed: () => _refresh(silent: false),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ───────────────────────────────────────────────────────────
                    // 3. MANDATORY ADVISORY NOTE BANNER (RECOMMENDED PATH ONLY)
                    // ───────────────────────────────────────────────────────────
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 68,
                      left: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131F33).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.alt_route_rounded,
                                    color: Color(0xFFFFB300),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Recommended Path Only',
                                    style: TextStyle(
                                      color: Color(0xFFFFB300),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isNoteCollapsed = !_isNoteCollapsed;
                                    });
                                  },
                                  child: Icon(
                                    _isNoteCollapsed
                                        ? Icons.expand_more_rounded
                                        : Icons.expand_less_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            if (!_isNoteCollapsed) ...[
                              const SizedBox(height: 6),
                              const Text(
                                '• This route is an advisory recommended navigation path. Actual conditions, closures, or roadwork may require alternative detours.\n• Vehicle location is tracked directly from the car itself (onboard GPS hardware), not the driver\'s mobile phone.',
                                style: TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // ───────────────────────────────────────────────────────────
                    // 4. FLOATING MAP ACTION BUTTONS (RECENTER / VIEW ROUTE)
                    // ───────────────────────────────────────────────────────────
                    Positioned(
                      bottom: 232,
                      right: 14,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Recenter on Vehicle Location
                          _FloatingCircleButton(
                            icon: Icons.my_location_rounded,
                            tooltip: 'Center on Vehicle',
                            color: AppColors.primary,
                            onTap: _recenterOnVehicle,
                          ),
                          const SizedBox(height: 10),

                          // Fit Full Route
                          _FloatingCircleButton(
                            icon: Icons.route_rounded,
                            tooltip: 'Fit Entire Route',
                            color: Colors.white,
                            onTap: _recenterOnRoute,
                          ),
                        ],
                      ),
                    ),

                    // ───────────────────────────────────────────────────────────
                    // 5. FLOATING BOTTOM TRIP METRICS & DESTINATION CARD
                    // ───────────────────────────────────────────────────────────
                    Positioned(
                      bottom: MediaQuery.of(context).padding.bottom + 12,
                      left: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black87,
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Metrics Row (Distance, Time, Car Speed)
                            Row(
                              children: [
                                Expanded(
                                  child: _NavMetricBadge(
                                    label: 'RECOMMENDED ROUTE',
                                    value: _distanceKm == null
                                        ? '--'
                                        : '${_distanceKm!.toStringAsFixed(1)} km',
                                    icon: Icons.route_rounded,
                                    accentColor: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _NavMetricBadge(
                                    label: 'ESTIMATED TIME',
                                    value: _estimatedMinutes == null
                                        ? '--'
                                        : '${_estimatedMinutes!.ceil()} min',
                                    icon: Icons.schedule_rounded,
                                    accentColor: const Color(0xFF10B981),
                                  ),
                                ),
                                if (_vehicleLocation?['speed_kph'] != null) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _NavMetricBadge(
                                      label: 'CAR SPEED',
                                      value:
                                          '${(_vehicleLocation!['speed_kph'] as num).toStringAsFixed(0)} km/h',
                                      icon: Icons.speed_rounded,
                                      accentColor: Colors.lightBlueAccent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white12, height: 1),
                            const SizedBox(height: 10),

                            // Destination Address Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.redAccent,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DESTINATION',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _destinationAddress ??
                                            booking['dropoff_location']
                                                ?.toString() ??
                                            'Destination location',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Car Origin Row
                            if (_vehicleAddress != null &&
                                _vehicleAddress!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.directions_car_filled_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'CAR LOCATION (ONBOARD GPS)',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _vehicleAddress!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _openExternalDirections,
                                    icon: const Icon(
                                      Icons.directions_rounded,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                    label: const Text(
                                      'Open in Google Maps',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _FloatingCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _FloatingCircleButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _NavMetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _NavMetricBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_disabled_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Navigation Unavailable',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
