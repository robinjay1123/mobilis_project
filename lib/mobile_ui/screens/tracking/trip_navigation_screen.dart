import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/tracking_service.dart';
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
  Timer? _refreshTimer;
  Map<String, dynamic>? _booking;
  Map<String, dynamic>? _location;
  List<MobilisMapPoint> _route = const [];
  double? _distanceKm;
  double? _estimatedMinutes;
  double? _destinationLatitude;
  double? _destinationLongitude;
  String? _error;
  bool _loading = true;
  bool _sendingEmergency = false;
  String? _lastRouteKey;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final navigation = await _trackingService
        .getParticipantNavigationLocationForBooking(widget.bookingId);
    if (navigation == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Navigation is available only to the renter or assigned driver during an ongoing trip.';
      });
      return;
    }

    final booking = Map<String, dynamic>.from(
      navigation['booking'] as Map<String, dynamic>,
    );
    final participantRole = navigation['participant_role']?.toString() ?? '';
    final hasAssignedDriver =
        booking['driver_id']?.toString().trim().isNotEmpty == true;
    if (participantRole == 'driver' ||
        (participantRole == 'renter' && !hasAssignedDriver)) {
      await _ensureParticipantTracking(
        booking,
        participantRole: participantRole,
      );
      final refreshed = await _trackingService
          .getParticipantNavigationLocationForBooking(widget.bookingId);
      if (refreshed != null) {
        navigation['location'] = refreshed['location'];
      }
    }

    final location = navigation['location'] is Map
        ? Map<String, dynamic>.from(navigation['location'] as Map)
        : null;
    if (!mounted) return;
    setState(() {
      _booking = booking;
      _location = location;
      _loading = false;
      _error = location == null
          ? 'Waiting for the assigned driver to share the vehicle location.'
          : null;
    });
    await _updateRoute();
  }

  Future<void> _ensureParticipantTracking(
    Map<String, dynamic> booking, {
    required String participantRole,
  }) async {
    if (_trackingService.activeBookingId == widget.bookingId) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final vehicleId = booking['vehicle_id']?.toString() ?? '';
    if (userId == null || vehicleId.isEmpty) return;
    try {
      await _trackingService.startBookingTracking(
        bookingId: widget.bookingId,
        vehicleId: vehicleId,
        trackedUserId: userId,
        source: participantRole == 'driver'
            ? 'driver_navigation'
            : 'renter_self_drive_navigation',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to start location sharing: $error');
      }
    }
  }

  Future<void> _updateRoute() async {
    final booking = _booking;
    final location = _location;
    if (booking == null || location == null) return;
    final currentLat = _asDouble(location['latitude']);
    final currentLng = _asDouble(location['longitude']);
    var destinationLat = _asDouble(booking['dropoff_latitude']);
    var destinationLng = _asDouble(booking['dropoff_longitude']);
    if (destinationLat == null || destinationLng == null) {
      final address = booking['dropoff_location']?.toString().trim() ?? '';
      if (address.isNotEmpty) {
        try {
          final matches = await locationFromAddress(address);
          if (matches.isNotEmpty) {
            destinationLat = matches.first.latitude;
            destinationLng = matches.first.longitude;
          }
        } catch (_) {
          // The address remains visible even if a legacy booking has no pin.
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
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
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
      // Straight-line fallback keeps navigation usable during routing outages.
    }
    if (!mounted) return;
    setState(() {
      _route = route;
      _distanceKm = distanceMeters / 1000;
      _estimatedMinutes = durationSeconds / 60;
      _destinationLatitude = destinationLat;
      _destinationLongitude = destinationLng;
    });
  }

  Future<void> _requestEmergencyHelp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request emergency assistance?'),
        content: const Text(
          'This alerts Mobilis support, the responsible vehicle owner, and the admin with your latest trip location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send Emergency Alert'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _sendingEmergency = true);
    try {
      await _trackingService.reportEmergency(
        bookingId: widget.bookingId,
        latitude: _asDouble(_location?['latitude']),
        longitude: _asDouble(_location?['longitude']),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency alert sent to Mobilis support.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to send alert: $error')));
    } finally {
      if (mounted) setState(() => _sendingEmergency = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    final currentLat = _asDouble(_location?['latitude']);
    final currentLng = _asDouble(_location?['longitude']);
    final destinationLat =
        _destinationLatitude ?? _asDouble(booking?['dropoff_latitude']);
    final destinationLng =
        _destinationLongitude ?? _asDouble(booking?['dropoff_longitude']);
    final markers = <MobilisMapMarker>[
      if (currentLat != null && currentLng != null)
        MobilisMapMarker(
          latitude: currentLat,
          longitude: currentLng,
          icon: Icons.directions_car_rounded,
          color: AppColors.primary,
        ),
      if (destinationLat != null && destinationLng != null)
        MobilisMapMarker(
          latitude: destinationLat,
          longitude: destinationLng,
          icon: Icons.flag_rounded,
          color: Colors.redAccent,
        ),
    ];
    final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
    final vehicleTitle = [vehicle?['brand'], vehicle?['model']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' ');

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        title: const Text(
          'Trip Navigation',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : booking == null
          ? _ErrorState(message: _error ?? 'Trip navigation is unavailable.')
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    vehicleTitle.isEmpty ? 'Active vehicle' : vehicleTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking['dropoff_location']?.toString() ?? 'Destination',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 390,
                      child: markers.isEmpty
                          ? _ErrorState(
                              message: _error ?? 'Waiting for vehicle GPS.',
                            )
                          : MobilisLeafletMap(
                              markers: markers,
                              routePoints: _route,
                              showAttribution: true,
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Distance',
                          value: _distanceKm == null
                              ? '--'
                              : '${_distanceKm!.toStringAsFixed(1)} km',
                          icon: Icons.route_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Estimated time',
                          value: _estimatedMinutes == null
                              ? '--'
                              : '${_estimatedMinutes!.ceil()} min',
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  BookingReturnCountdown(booking: booking),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.warning),
                    ),
                  ],
                  if (widget.participantRole.toLowerCase() == 'renter') ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _sendingEmergency
                            ? null
                            : _requestEmergencyHelp,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        icon: _sendingEmergency
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sos_rounded),
                        label: const Text('Emergency Assistance'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.darkBgSecondary,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.borderColor),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_searching_rounded,
            color: AppColors.primary,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}
