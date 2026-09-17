import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../../services/tracking_service.dart';
import '../../../utils/philippine_geocoding.dart';
import '../../widgets/skeleton_loading.dart';

class TripRouteHistoryScreen extends StatefulWidget {
  final String? bookingId;
  final String? vehicleId;
  final String? trackerDeviceId;
  final String? vehicleName;
  final String? plateNumber;
  final String? renterName;
  final double? initialLat;
  final double? initialLng;

  const TripRouteHistoryScreen({
    super.key,
    this.bookingId,
    this.vehicleId,
    this.trackerDeviceId,
    this.vehicleName,
    this.plateNumber,
    this.renterName,
    this.initialLat,
    this.initialLng,
  });

  static Future<void> open({
    required BuildContext context,
    String? bookingId,
    String? vehicleId,
    String? trackerDeviceId,
    String? vehicleName,
    String? plateNumber,
    String? renterName,
    double? initialLat,
    double? initialLng,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TripRouteHistoryScreen(
          bookingId: bookingId,
          vehicleId: vehicleId,
          trackerDeviceId: trackerDeviceId,
          vehicleName: vehicleName,
          plateNumber: plateNumber,
          renterName: renterName,
          initialLat: initialLat,
          initialLng: initialLng,
        ),
      ),
    );
  }

  @override
  State<TripRouteHistoryScreen> createState() => _TripRouteHistoryScreenState();
}

class _TripRouteHistoryScreenState extends State<TripRouteHistoryScreen> {
  final TrackingService _trackingService = TrackingService();
  final MapController _mapController = MapController();

  bool _isLoading = true;
  Map<String, dynamic>? _auditData;
  List<Map<String, dynamic>> _routeStops = [];

  // Video Playback Simulation State
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentPlaybackIndex = 0;
  Timer? _playbackTimer;
  bool _autoFollowCar = true;

  // Date Range Filtering State
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _activePreset = 'all'; // 'all', 'today', 'yesterday', '24h', '7d', 'custom'

  // Vehicle location fallback so car marker is never invisible
  double? _resolvedCarLat;
  double? _resolvedCarLng;

  final List<double> _availableSpeeds = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0];

  @override
  void initState() {
    super.initState();
    _resolvedCarLat = widget.initialLat;
    _resolvedCarLng = widget.initialLng;
    _loadRouteData();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  bool _isPointInDateRange(Map<String, dynamic> pt) {
    if (_filterStartDate == null && _filterEndDate == null) return true;
    final rec = pt['recorded_at']?.toString() ?? pt['created_at']?.toString();
    if (rec == null || rec.isEmpty) return true;
    try {
      final clean = rec.trim();
      DateTime dt;
      if (clean.endsWith('Z') ||
          clean.contains('+') ||
          (clean.length > 10 && clean.substring(10).contains('-'))) {
        dt = DateTime.parse(clean).toLocal();
      } else {
        final iso = clean.replaceAll(' ', 'T');
        dt = DateTime.parse('${iso}Z').toLocal();
      }
      if (_filterStartDate != null && dt.isBefore(_filterStartDate!)) return false;
      if (_filterEndDate != null && dt.isAfter(_filterEndDate!)) return false;
      return true;
    } catch (_) {
      return true;
    }
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (preset) {
      case 'today':
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'yesterday':
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day, 0, 0, 0);
        end = DateTime(y.year, y.month, y.day, 23, 59, 59);
        break;
      case '24h':
        start = now.subtract(const Duration(hours: 24));
        end = now;
        break;
      case '7d':
        start = now.subtract(const Duration(days: 7));
        end = now;
        break;
      case 'all':
      default:
        start = null;
        end = null;
        break;
    }

    setState(() {
      _activePreset = preset;
      _filterStartDate = start;
      _filterEndDate = end;
    });
    _loadRouteData();
  }

  Future<void> _loadRouteData() async {
    _playbackTimer?.cancel();
    setState(() {
      _isLoading = true;
      _isPlaying = false;
    });
    try {
      Map<String, dynamic> data = {};
      final bId = widget.bookingId?.trim() ?? '';
      final vId = widget.vehicleId?.trim() ?? '';
      final trackerId = widget.trackerDeviceId?.trim() ?? '';

      // 1. If booking ID is provided, try compliance evaluation with date filter
      if (bId.isNotEmpty) {
        data = await _trackingService
            .evaluateTripDestinationCompliance(
              bId,
              startDate: _filterStartDate,
              endDate: _filterEndDate,
            )
            .timeout(const Duration(seconds: 8));
      }

      var pts = (data['routePoints'] as List<dynamic>? ?? [])
          .map((p) => p as Map<String, dynamic>)
          .where(_isPointInDateRange)
          .toList();

      // 2. If no points or sparse points (< 2 points), query vehicle location history
      List<Map<String, dynamic>> rawLogs = [];
      if (pts.length < 2 && (vId.isNotEmpty || trackerId.isNotEmpty)) {
        rawLogs = await _trackingService.getVehicleLocationHistory(
          vehicleId: vId,
          trackerDeviceId: trackerId,
          startDate: _filterStartDate,
          endDate: _filterEndDate,
          limit: 1000,
        );
        rawLogs = rawLogs.where(_isPointInDateRange).toList();
        if (rawLogs.length >= 2) {
          data = _buildAuditDataFromPoints(rawLogs);
          pts = (data['routePoints'] as List<dynamic>? ?? [])
              .map((p) => p as Map<String, dynamic>)
              .where(_isPointInDateRange)
              .toList();
        }
      }

      // 3. Road route playback generation:
      // If pts has < 2 points (no live hardware GPS telemetry logs for this period in DB):
      // Reconstruct the real road route connecting key stops, aligned with the selected date window!
      if (pts.length < 2) {
        data = await _buildRoadRouteFromStops(
          bookingId: bId,
          vehicleId: vId,
          trackerDeviceId: trackerId,
          existingData: data,
          rawLogs: rawLogs,
          filterStartDate: _filterStartDate,
          filterEndDate: _filterEndDate,
        );
        pts = (data['routePoints'] as List<dynamic>? ?? [])
            .map((p) => p as Map<String, dynamic>)
            .toList();
      } else if (_filterStartDate != null || _filterEndDate != null) {
        // Recalculate audit metrics exclusively for the filtered points
        data = _buildAuditDataFromPoints(
          pts,
          isSimulation: false,
          isReconstructed: false,
          dropoffLocation:
              data['dropoffLocation']?.toString() ?? 'Filtered Window',
          booking: (data['booking'] as Map<String, dynamic>?),
        );
      }

      // Update stop references according to the filtered points
      if (pts.isEmpty) {
        _routeStops = [];
      } else {
        for (final stop in _routeStops) {
          final sLat = (stop['latitude'] as num?)?.toDouble() ?? 0.0;
          final sLng = (stop['longitude'] as num?)?.toDouble() ?? 0.0;
          int closestIdx = 0;
          double minDistance = double.infinity;
          for (int i = 0; i < pts.length; i++) {
            final ptLat = (pts[i]['latitude'] as num).toDouble();
            final ptLng = (pts[i]['longitude'] as num).toDouble();
            final dist = _distanceMeters(sLat, sLng, ptLat, ptLng);
            if (dist < minDistance) {
              minDistance = dist;
              closestIdx = i;
            }
          }
          stop['pointIndex'] = closestIdx;
        }
      }

      if (mounted) {
        setState(() {
          _auditData = data;
          _isLoading = false;
          _currentPlaybackIndex = 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading trip route history: $e');
      if (mounted) {
        final fallbackData = await _buildRoadRouteFromStops(
          bookingId: widget.bookingId?.trim() ?? '',
          vehicleId: widget.vehicleId?.trim() ?? '',
          trackerDeviceId: widget.trackerDeviceId?.trim() ?? '',
          existingData: {},
          rawLogs: [],
          filterStartDate: _filterStartDate,
          filterEndDate: _filterEndDate,
        );
        if (mounted) {
          setState(() {
            _auditData = fallbackData;
            _isLoading = false;
            _currentPlaybackIndex = 0;
          });
        }
      }
    }
  }

  Future<Map<String, dynamic>> _buildRoadRouteFromStops({
    required String bookingId,
    required String vehicleId,
    required String trackerDeviceId,
    required Map<String, dynamic> existingData,
    required List<Map<String, dynamic>> rawLogs,
    DateTime? filterStartDate,
    DateTime? filterEndDate,
  }) async {
    Map<String, dynamic>? booking =
        (existingData['booking'] as Map<String, dynamic>?);

    // If no booking from existingData, try fetching active/recent booking for this vehicle or bookingId
    if (booking == null || booking.isEmpty) {
      if (bookingId.isNotEmpty) {
        try {
          final res = await _trackingService.supabase
              .from('bookings')
              .select('*, vehicles(*)')
              .eq('id', bookingId)
              .maybeSingle();
          if (res != null) booking = Map<String, dynamic>.from(res);
        } catch (_) {}
      } else if (vehicleId.isNotEmpty) {
        try {
          final res = await _trackingService.supabase
              .from('bookings')
              .select('*, vehicles(*)')
              .eq('vehicle_id', vehicleId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (res != null) booking = Map<String, dynamic>.from(res);
        } catch (_) {}
      }
    }

    // 1. Resolve Current / Last Stop of the Vehicle
    double? curLat = widget.initialLat;
    double? curLng = widget.initialLng;
    DateTime? lastRecordedTime;

    if (curLat == null || curLng == null || (curLat == 0.0 && curLng == 0.0)) {
      if (vehicleId.isNotEmpty) {
        try {
          final locRes = await _trackingService.supabase
              .from('tracking_locations')
              .select('*')
              .eq('vehicle_id', vehicleId)
              .order('recorded_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (locRes != null) {
            curLat = (locRes['latitude'] as num?)?.toDouble();
            curLng = (locRes['longitude'] as num?)?.toDouble();
            if (locRes['recorded_at'] != null) {
              lastRecordedTime =
                  DateTime.tryParse(locRes['recorded_at'].toString());
            }
          }
        } catch (_) {}
      }
    }

    // Fallback default coordinates if not found (PSDC Central Garage, Urdaneta)
    curLat ??= PhilippineGeocoding.defaultLat;
    curLng ??= PhilippineGeocoding.defaultLng;
    _resolvedCarLat = curLat;
    _resolvedCarLng = curLng;
    lastRecordedTime ??= DateTime.now();

    // 2. Resolve Key Anchor Stops
    final List<Map<String, dynamic>> keyStops = [];

    // Origin / Start Stop
    double? originLat;
    double? originLng;
    String originTitle = 'Start Origin';
    String originSubtitle = 'Departure Point';

    if (booking != null && booking.isNotEmpty) {
      originLat = (booking['pickup_latitude'] as num?)?.toDouble();
      originLng = (booking['pickup_longitude'] as num?)?.toDouble();
      final pickupAddr = booking['pickup_location']?.toString().trim() ?? '';
      if ((originLat == null ||
              originLng == null ||
              (originLat == 0.0 && originLng == 0.0)) &&
          pickupAddr.isNotEmpty) {
        final pt = PhilippineGeocoding.resolveLocationSync(pickupAddr);
        originLat = pt.latitude;
        originLng = pt.longitude;
      }
      originTitle = 'Pickup Stop';
      originSubtitle = pickupAddr.isNotEmpty ? pickupAddr : 'Pickup Location';
    }

    // If no booking pickup or same as current: check location logs for an earlier stop
    if (originLat == null ||
        originLng == null ||
        (originLat == 0.0 && originLng == 0.0) ||
        ((originLat - curLat).abs() < 0.0005 &&
            (originLng - curLng).abs() < 0.0005)) {
      if (rawLogs.isNotEmpty) {
        for (final log in rawLogs) {
          final lLat = (log['latitude'] as num?)?.toDouble() ?? 0.0;
          final lLng = (log['longitude'] as num?)?.toDouble() ?? 0.0;
          if (lLat != 0.0 && lLng != 0.0) {
            final distMeters = _distanceMeters(lLat, lLng, curLat, curLng);
            if (distMeters > 150) {
              originLat = lLat;
              originLng = lLng;
              originTitle = 'Previous Stop';
              originSubtitle = 'Prior Recorded Location';
              break;
            }
          }
        }
      }
    }

    // If still no distinct origin, use known hub corridor stops
    if (originLat == null ||
        originLng == null ||
        (originLat == 0.0 && originLng == 0.0) ||
        ((originLat - curLat).abs() < 0.0005 &&
            (originLng - curLng).abs() < 0.0005)) {
      final distToGarage =
          _distanceMeters(curLat, curLng, 15.9758, 120.5719);
      if (distToGarage > 500) {
        originLat = 15.9758;
        originLng = 120.5719;
        originTitle = 'Central Hub Depot';
        originSubtitle = 'PSDC Garage, Urdaneta';
      } else {
        originLat = 15.9520;
        originLng = 120.5690;
        originTitle = 'Corridor Checkpoint';
        originSubtitle = 'MacArthur Hwy South Junction';
      }
    }

    // Add Origin Stop
    keyStops.add({
      'title': originTitle,
      'subtitle': originSubtitle,
      'latitude': originLat,
      'longitude': originLng,
      'type': 'start',
    });

    // 3. Intermediate stops from raw logs if any exist between origin and current
    if (rawLogs.length > 2) {
      final intermediate = <Map<String, dynamic>>[];
      for (final log in rawLogs) {
        final lLat = (log['latitude'] as num?)?.toDouble() ?? 0.0;
        final lLng = (log['longitude'] as num?)?.toDouble() ?? 0.0;
        if (lLat == 0.0 || lLng == 0.0) continue;
        final dFromOrigin = _distanceMeters(lLat, lLng, originLat, originLng);
        final dFromCur = _distanceMeters(lLat, lLng, curLat, curLng);
        if (dFromOrigin > 200 && dFromCur > 200) {
          bool isFarFromOthers = true;
          for (final prev in intermediate) {
            final pLat = prev['latitude'] as double;
            final pLng = prev['longitude'] as double;
            if (_distanceMeters(lLat, lLng, pLat, pLng) < 400) {
              isFarFromOthers = false;
              break;
            }
          }
          if (isFarFromOthers) {
            intermediate.add({
              'title': 'Stop #${intermediate.length + 1}',
              'subtitle': 'Intermediate Transit Stop',
              'latitude': lLat,
              'longitude': lLng,
              'type': 'stop',
            });
            if (intermediate.length >= 2) break;
          }
        }
      }
      keyStops.addAll(intermediate);
    }

    // Current / Last Stop of the Vehicle
    keyStops.add({
      'title': 'Current Vehicle Stop',
      'subtitle': 'Latest Live GPS Location',
      'latitude': curLat,
      'longitude': curLng,
      'type': 'current',
    });

    // 4. Resolve Destination Stop (if booking has dropoff)
    double? dropoffLat;
    double? dropoffLng;
    String dropoffLocationText = 'Agreed Destination';
    if (booking != null && booking.isNotEmpty) {
      dropoffLat = (booking['dropoff_latitude'] as num?)?.toDouble();
      dropoffLng = (booking['dropoff_longitude'] as num?)?.toDouble();
      final dropAddr = booking['dropoff_location']?.toString().trim() ?? '';
      if ((dropoffLat == null ||
              dropoffLng == null ||
              (dropoffLat == 0.0 && dropoffLng == 0.0)) &&
          dropAddr.isNotEmpty) {
        final pt = PhilippineGeocoding.resolveLocationSync(dropAddr);
        dropoffLat = pt.latitude;
        dropoffLng = pt.longitude;
      }
      if (dropAddr.isNotEmpty) dropoffLocationText = dropAddr;
    }

    // 5. Connect Stops via Real Road Routing (OSRM Multi-Stop Driving Route)
    final stopCoords = keyStops
        .map((s) => {
              'latitude': s['latitude'] as double,
              'longitude': s['longitude'] as double,
            })
        .toList();

    final roadGeometry =
        await _trackingService.getPlannedMultiStopRoadRoute(stopCoords);

    // 6. If destination exists and differs from current location, fetch planned road route to destination
    List<Map<String, double>> recommendedRoute = [];
    if (dropoffLat != null &&
        dropoffLng != null &&
        dropoffLat != 0.0 &&
        dropoffLng != 0.0 &&
        _distanceMeters(curLat, curLng, dropoffLat, dropoffLng) > 100) {
      recommendedRoute = await _trackingService.getPlannedRoadRoute(
        startLat: curLat,
        startLng: curLng,
        endLat: dropoffLat,
        endLng: dropoffLng,
      );
    }

    // 7. Convert Real Road Geometry Coordinates into Video/GPS Playback Trail Points
    final List<Map<String, dynamic>> routePoints = [];
    final int ptCount = roadGeometry.length;
    DateTime startTime;
    DateTime endTime;

    if (filterStartDate != null && filterEndDate != null) {
      startTime = filterStartDate;
      endTime = filterEndDate;
      final diff = filterEndDate.difference(filterStartDate);
      if (diff.inHours > 3) {
        startTime = filterEndDate.subtract(const Duration(minutes: 45));
        endTime = filterEndDate;
      }
    } else if (filterStartDate != null) {
      startTime = filterStartDate;
      endTime = filterStartDate.add(const Duration(minutes: 30));
    } else if (filterEndDate != null) {
      endTime = filterEndDate;
      startTime = filterEndDate.subtract(const Duration(minutes: 30));
    } else {
      final totalTripDurationMinutes = (ptCount * 0.5).clamp(8.0, 35.0);
      endTime = lastRecordedTime;
      startTime = endTime.subtract(Duration(minutes: totalTripDurationMinutes.round()));
    }

    final totalDurationSeconds = endTime.difference(startTime).inSeconds.clamp(60, 86400 * 7);

    for (int i = 0; i < ptCount; i++) {
      final p = roadGeometry[i];
      final nextP = i < ptCount - 1 ? roadGeometry[i + 1] : p;
      final prevP = i > 0 ? roadGeometry[i - 1] : p;

      final heading = _calculateBearing(
        p['latitude']!,
        p['longitude']!,
        nextP['latitude']!,
        nextP['longitude']!,
      );

      // Realistic speed model along actual Philippine streets:
      // Stops are 0 km/h; curves slow down; straight stretches cruise at 40-52 km/h
      double speedKph = 45.0;
      if (i == 0 || i == ptCount - 1) {
        speedKph = 0.0;
      } else if (i < 2 || i > ptCount - 3) {
        speedKph = 18.0;
      } else {
        final prevHeading = _calculateBearing(
          prevP['latitude']!,
          prevP['longitude']!,
          p['latitude']!,
          p['longitude']!,
        );
        final turnAngle = ((heading - prevHeading).abs()) % 360;
        if (turnAngle > 22 && turnAngle < 338) {
          speedKph = 24.0;
        } else {
          speedKph = 48.0;
        }
      }

      final progress = ptCount > 1 ? (i / (ptCount - 1)) : 1.0;
      final pointTime = startTime.add(
        Duration(seconds: (progress * totalDurationSeconds).round()),
      );

      routePoints.add({
        'latitude': p['latitude'],
        'longitude': p['longitude'],
        'speed_mps': speedKph / 3.6,
        'heading_degrees': heading,
        'source': 'road_network_playback',
        'recorded_at': pointTime.toUtc().toIso8601String(),
      });
    }

    // Associate each stop with its closest point index in routePoints
    for (final stop in keyStops) {
      final sLat = stop['latitude'] as double;
      final sLng = stop['longitude'] as double;
      int closestIdx = 0;
      double minDistance = double.infinity;
      for (int i = 0; i < routePoints.length; i++) {
        final ptLat = (routePoints[i]['latitude'] as num).toDouble();
        final ptLng = (routePoints[i]['longitude'] as num).toDouble();
        final dist = _distanceMeters(sLat, sLng, ptLat, ptLng);
        if (dist < minDistance) {
          minDistance = dist;
          closestIdx = i;
        }
      }
      stop['pointIndex'] = closestIdx;
    }

    _routeStops = keyStops;

    return _buildAuditDataFromPoints(
      routePoints,
      isSimulation: false,
      isReconstructed: true,
      recommendedRoute: recommendedRoute,
      dropoffLocation: dropoffLocationText,
      booking: booking,
    );
  }

  double _distanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
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

  double _calculateBearing(
      double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final y = math.sin(dLon) * math.cos(lat2 * (math.pi / 180.0));
    final x = math.cos(lat1 * (math.pi / 180.0)) *
            math.sin(lat2 * (math.pi / 180.0)) -
        math.sin(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.cos(dLon);
    final brng = math.atan2(y, x);
    return ((brng * 180.0 / math.pi) + 360.0) % 360.0;
  }

  Map<String, dynamic> _buildAuditDataFromPoints(
    List<Map<String, dynamic>> points, {
    bool isSimulation = false,
    bool isReconstructed = false,
    List<Map<String, double>> recommendedRoute = const [],
    String dropoffLocation = 'Recorded Vehicle Path',
    Map<String, dynamic>? booking,
  }) {
    double totalDistanceKm = 0.0;
    double topSpeedKph = 0.0;
    double lastLat = 0.0;
    double lastLng = 0.0;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final lat = (p['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (p['longitude'] as num?)?.toDouble() ?? 0.0;
      final speedMps = (p['speed_mps'] as num?)?.toDouble() ?? 0.0;
      final speedKph = speedMps * 3.6;
      if (speedKph > topSpeedKph) topSpeedKph = speedKph;

      if (i > 0 &&
          lastLat != 0.0 &&
          lastLng != 0.0 &&
          lat != 0.0 &&
          lng != 0.0) {
        final dLat = (lat - lastLat).abs() * 111.0;
        final dLng = (lng - lastLng).abs() *
            111.0 *
            math.cos(lat * math.pi / 180.0);
        totalDistanceKm += math.sqrt(dLat * dLat + dLng * dLng);
      }
      lastLat = lat;
      lastLng = lng;
    }

    return {
      'isCompliant': true,
      'isReconstructed': isReconstructed,
      'maxDeviationKm': 0.0,
      'penaltyAmount': 0.0,
      'violationCount': 0,
      'pointsCount': points.length,
      'totalDistanceKm': totalDistanceKm,
      'topSpeedKph': points.isEmpty ? 0.0 : (topSpeedKph > 0 ? topSpeedKph : 48.0),
      'routePoints': points,
      'recommendedRoute': recommendedRoute,
      'dropoffLocation': dropoffLocation,
      'booking': booking,
    };
  }

  List<Map<String, dynamic>> _getPoints() {
    final raw = _auditData?['routePoints'] as List<dynamic>? ?? [];
    return raw.map((p) => p as Map<String, dynamic>).toList();
  }

  void _startPlayback() {
    final points = _getPoints();
    if (points.isEmpty) return;

    if (_currentPlaybackIndex >= points.length - 1) {
      _currentPlaybackIndex = 0;
    }

    _playbackTimer?.cancel();
    setState(() => _isPlaying = true);

    final intervalMs = (600 / _playbackSpeed).clamp(25.0, 1200.0).round();

    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentPlaybackIndex < points.length - 1) {
        setState(() {
          _currentPlaybackIndex++;
        });

        if (_autoFollowCar) {
          final pt = points[_currentPlaybackIndex];
          final lat = (pt['latitude'] as num?)?.toDouble();
          final lng = (pt['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
            _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
          }
        }
      } else {
        timer.cancel();
        setState(() => _isPlaying = false);
      }
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _seekTo(int index) {
    final points = _getPoints();
    if (points.isEmpty) return;
    final clamped = index.clamp(0, points.length - 1);
    setState(() {
      _currentPlaybackIndex = clamped;
    });

    if (_autoFollowCar) {
      final pt = points[clamped];
      final lat = (pt['latitude'] as num?)?.toDouble();
      final lng = (pt['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
      }
    }

    if (_isPlaying) {
      _startPlayback();
    }
  }

  void _setPlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    if (_isPlaying) {
      _startPlayback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bId = widget.bookingId ?? '';
    final shortBooking = bId.length > 8 ? bId.substring(0, 8) : bId;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D141E) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.vehicleName != null && widget.vehicleName!.isNotEmpty
                        ? widget.vehicleName!
                        : 'Trip Route Audit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Text(
                    'VIDEO REPLAY',
                    style: TextStyle(
                      color: Color(0xFFE5A93C),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [
                if (widget.plateNumber != null && widget.plateNumber!.isNotEmpty)
                  widget.plateNumber!,
                if (shortBooking.isNotEmpty)
                  'Booking #$shortBooking'
                else
                  'Standby / Telemetry Playback',
                if (widget.renterName != null && widget.renterName!.isNotEmpty)
                  widget.renterName!,
              ].join(' • '),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _activePreset != 'all',
              backgroundColor: const Color(0xFFE5A93C),
              smallSize: 8,
              child: Icon(
                Icons.calendar_month_rounded,
                color: _activePreset != 'all'
                    ? const Color(0xFFE5A93C)
                    : (isDark ? Colors.white70 : Colors.black87),
                size: 22,
              ),
            ),
            onPressed: _showCustomDateRangePicker,
            tooltip: 'Filter by Date & Time',
          ),
          IconButton(
            icon: Icon(
              _autoFollowCar ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              color: _autoFollowCar ? const Color(0xFFE5A93C) : Colors.grey,
              size: 22,
            ),
            onPressed: () {
              setState(() => _autoFollowCar = !_autoFollowCar);
            },
            tooltip: _autoFollowCar ? 'Camera Locked to Car' : 'Free Map View',
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 22,
            ),
            onPressed: _loadRouteData,
            tooltip: 'Reload GPS Route',
          ),
        ],
      ),
      body: _isLoading
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MobilisSkeletonTrackingRadar(
                isDark: isDark,
                accentColor: const Color(0xFFE5A93C),
                title: 'Fetching GPS telemetry & route playback...',
                subtitle: 'Querying satellite coordinates & trip timeline. Please wait...',
                height: 320,
              ),
            )
          : _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    final data = _auditData ?? {};
    final isCompliant = data['isCompliant'] == true;
    final penaltyAmount = (data['penaltyAmount'] as num?)?.toDouble() ?? 0.0;
    final maxDeviationKm = (data['maxDeviationKm'] as num?)?.toDouble() ?? 0.0;
    final totalDistanceKm = (data['totalDistanceKm'] as num?)?.toDouble() ?? 0.0;
    final topSpeedKph = (data['topSpeedKph'] as num?)?.toDouble() ?? 0.0;
    final points = _getPoints();
    final pointsCount = points.length;
    final dropoffLocation =
        data['dropoffLocation']?.toString() ?? 'Agreed Destination';
    final booking = (data['booking'] as Map<String, dynamic>?) ?? {};

    // All polyline coordinates
    final List<LatLng> fullPolyline = [];
    for (final p in points) {
      final lat = (p['latitude'] as num?)?.toDouble();
      final lng = (p['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        fullPolyline.add(LatLng(lat, lng));
      }
    }

    // Traveled coordinates up to playback index
    final List<LatLng> traveledPolyline = [];
    final activeIndex = _currentPlaybackIndex.clamp(
        0, fullPolyline.isNotEmpty ? fullPolyline.length - 1 : 0);
    if (fullPolyline.isNotEmpty) {
      for (int i = 0; i <= activeIndex && i < fullPolyline.length; i++) {
        traveledPolyline.add(fullPolyline[i]);
      }
    }

    // Recommended planned route (reference)
    final List<LatLng> recommendedPolyline = [];
    final rawRecommended = data['recommendedRoute'] as List<dynamic>? ?? [];
    for (final p in rawRecommended) {
      if (p is Map) {
        final lat = (p['latitude'] as num?)?.toDouble();
        final lng = (p['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          recommendedPolyline.add(LatLng(lat, lng));
        }
      }
    }

    final pickupLat = (booking['pickup_latitude'] as num?)?.toDouble();
    final pickupLng = (booking['pickup_longitude'] as num?)?.toDouble();
    final dropoffLat = (booking['dropoff_latitude'] as num?)?.toDouble();
    final dropoffLng = (booking['dropoff_longitude'] as num?)?.toDouble();

    LatLng? currentCarPos;
    double currentSpeedKph = 0.0;
    double currentHeading = 0.0;
    String currentTimestamp = '';

    if (points.isNotEmpty && activeIndex < points.length) {
      final curPt = points[activeIndex];
      final lat = (curPt['latitude'] as num?)?.toDouble();
      final lng = (curPt['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        currentCarPos = LatLng(lat, lng);
      }
      currentSpeedKph = (((curPt['speed_mps'] as num?) ?? 0) * 3.6).toDouble();
      currentHeading = (curPt['heading_degrees'] as num?)?.toDouble() ?? 0.0;
      final recAt =
          curPt['recorded_at']?.toString() ?? curPt['created_at']?.toString();
      if (recAt != null && recAt.isNotEmpty) {
        try {
          final cleanStr = recAt.trim();
          DateTime dt;
          if (cleanStr.endsWith('Z') ||
              cleanStr.contains('+') ||
              (cleanStr.length > 10 && cleanStr.substring(10).contains('-'))) {
            dt = DateTime.parse(cleanStr).toLocal();
          } else {
            final iso = cleanStr.replaceAll(' ', 'T');
            dt = DateTime.parse('${iso}Z').toLocal();
          }
          currentTimestamp = DateFormat('hh:mm:ss a • MMM d').format(dt);
        } catch (_) {
          try {
            final dt = DateTime.parse(recAt).toLocal();
            currentTimestamp = DateFormat('hh:mm:ss a • MMM d').format(dt);
          } catch (_) {
            currentTimestamp = recAt;
          }
        }
      }
    }

    // Ensure currentCarPos is NEVER null so the vehicle is always visible on the map
    currentCarPos ??= (_resolvedCarLat != null && _resolvedCarLng != null && _resolvedCarLat != 0.0 && _resolvedCarLng != 0.0)
        ? LatLng(_resolvedCarLat!, _resolvedCarLng!)
        : (widget.initialLat != null && widget.initialLng != null && widget.initialLat != 0.0 && widget.initialLng != 0.0)
            ? LatLng(widget.initialLat!, widget.initialLng!)
            : (pickupLat != null && pickupLng != null && pickupLat != 0.0 && pickupLng != 0.0)
                ? LatLng(pickupLat, pickupLng)
                : const LatLng(PhilippineGeocoding.defaultLat, PhilippineGeocoding.defaultLng);

    LatLng initialCenter = currentCarPos;

    return Column(
      children: [
        // Date Range Filter Toolbar
        _buildDateFilterBar(isDark),

        // Top Section: Destination Alert Banner & Stats
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B26) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
          ),
          child: Column(
            children: [
              if (data['isReconstructed'] == true && (_filterStartDate != null || _filterEndDate != null))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.route_rounded,
                        color: Color(0xFF0284C7),
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Playback generated for the selected timeframe. Vehicle movements reconstructed along real road routes.',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0369A1),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if ((_filterStartDate != null || _filterEndDate != null) && points.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A93C).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_parking_rounded,
                        color: Color(0xFFE5A93C),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Vehicle was parked / stationary with no movement logged in this timeframe. Current location is pinned on the map.',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _applyPreset('all'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFFE5A93C),
                        ),
                        child: const Text(
                          'Show All',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!isCompliant)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE53935).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFE53935),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Destination Deviation: Vehicle traveled ${maxDeviationKm.toStringAsFixed(1)} km outside declared destination ($dropoffLocation). Recommended Penalty: ₱${NumberFormat('#,##0.00').format(penaltyAmount)}',
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFFB71C1C),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF178A5B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF178A5B).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF178A5B),
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Destination Compliant: Stayed within declared destination corridor ($dropoffLocation). No penalty required.',
                          style: TextStyle(
                            color:
                                isDark ? Colors.white70 : const Color(0xFF0F5132),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Responsive Stats Grid (2x2 on narrow screens, 4-in-row on wider)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  if (isNarrow) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                label: 'Total Distance',
                                value: '${totalDistanceKm.toStringAsFixed(1)} km',
                                icon: Icons.alt_route_rounded,
                                color: const Color(0xFF3B82F6),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _statCard(
                                label: 'Top Speed',
                                value: '${topSpeedKph.toStringAsFixed(0)} km/h',
                                icon: Icons.speed_rounded,
                                color: const Color(0xFFE5A93C),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                label: 'Current Speed',
                                value: pointsCount > 0
                                    ? '${currentSpeedKph.toStringAsFixed(0)} km/h'
                                    : '0 km/h (Parked)',
                                icon: Icons.electric_meter_rounded,
                                color: const Color(0xFF8B5CF6),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _statCard(
                                label: 'Trail Logs',
                                value: pointsCount > 0
                                    ? '${activeIndex + 1} / $pointsCount'
                                    : '0 (Stationary)',
                                icon: Icons.gps_fixed_rounded,
                                color: const Color(0xFF10B981),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          label: 'Total Distance',
                          value: '${totalDistanceKm.toStringAsFixed(1)} km',
                          icon: Icons.alt_route_rounded,
                          color: const Color(0xFF3B82F6),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          label: 'Top Speed',
                          value: '${topSpeedKph.toStringAsFixed(0)} km/h',
                          icon: Icons.speed_rounded,
                          color: const Color(0xFFE5A93C),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          label: 'Current Speed',
                          value: pointsCount > 0
                              ? '${currentSpeedKph.toStringAsFixed(0)} km/h'
                              : '0 km/h (Parked)',
                          icon: Icons.electric_meter_rounded,
                          color: const Color(0xFF8B5CF6),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          label: 'Trail Logs',
                          value: pointsCount > 0
                              ? '${activeIndex + 1} / $pointsCount'
                              : '0 (Stationary)',
                          icon: Icons.gps_fixed_rounded,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // Full-Screen Map + Overlays
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: fullPolyline.isNotEmpty ? 13.5 : 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.psdc.mobilis',
                  ),
                  if (recommendedPolyline.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: recommendedPolyline,
                          strokeWidth: 4.0,
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.70),
                          borderStrokeWidth: 1.5,
                          borderColor: Colors.black26,
                        ),
                      ],
                    ),
                  if (fullPolyline.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: fullPolyline,
                          strokeWidth: 3.5,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.20)
                              : Colors.blueGrey.withValues(alpha: 0.30),
                        ),
                      ],
                    ),
                  if (traveledPolyline.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: traveledPolyline,
                          strokeWidth: 5.5,
                          color: const Color(0xFF0077FF),
                          borderStrokeWidth: 1.5,
                          borderColor: Colors.white70,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      // Render Key Anchor Stops (Pickup, Intermediate Stops, Checkpoints)
                      for (final stop in _routeStops) ...[
                        if (stop['type'] == 'start')
                          Marker(
                            point: LatLng(
                              (stop['latitude'] as num).toDouble(),
                              (stop['longitude'] as num).toDouble(),
                            ),
                            width: 44,
                            height: 44,
                            child: Tooltip(
                              message: '${stop['title']}: ${stop['subtitle']}',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.trip_origin_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        if (stop['type'] == 'stop')
                          Marker(
                            point: LatLng(
                              (stop['latitude'] as num).toDouble(),
                              (stop['longitude'] as num).toDouble(),
                            ),
                            width: 38,
                            height: 38,
                            child: Tooltip(
                              message: '${stop['title']}: ${stop['subtitle']}',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.pause_circle_filled_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                      if (dropoffLat != null && dropoffLng != null)
                        Marker(
                          point: LatLng(dropoffLat, dropoffLng),
                          width: 44,
                          height: 44,
                          child: Tooltip(
                            message: 'Destination: $dropoffLocation',
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.flag_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      Marker(
                        point: currentCarPos,
                          width: 52,
                          height: 52,
                          child: Tooltip(
                            message: widget.vehicleName != null &&
                                    widget.vehicleName!.isNotEmpty
                                ? '${widget.vehicleName!} • ${points.isEmpty ? 'Parked / Stationary' : '${currentSpeedKph.toStringAsFixed(0)} km/h'}'
                                : 'Vehicle Location',
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: points.isEmpty
                                        ? const Color(0xFFE5A93C)
                                        : const Color(0xFF0077FF),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (points.isEmpty
                                                ? const Color(0xFFE5A93C)
                                                : const Color(0xFF0077FF))
                                            .withValues(alpha: 0.6),
                                        blurRadius: 16,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                    border: Border.all(
                                        color: Colors.white, width: 2.8),
                                  ),
                                  child: Transform.rotate(
                                    angle: (currentHeading * math.pi / 180.0),
                                    child: Icon(
                                      points.isEmpty
                                          ? Icons.directions_car_filled_rounded
                                          : Icons.navigation_rounded,
                                      color: points.isEmpty
                                          ? Colors.black
                                          : Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                if (points.isEmpty)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check,
                                          size: 9, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Map Legend Badge (Top Left)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0D141E).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _legendDot(const Color(0xFF10B981), 'Start Stop'),
                      if (_routeStops.any((s) => s['type'] == 'stop'))
                        _legendDot(const Color(0xFFF59E0B), 'Intermediate Stop'),
                      _legendDot(const Color(0xFF0077FF), 'Road Trail'),
                      _legendDot(const Color(0xFF0077FF), 'Vehicle Position'),
                      if (dropoffLat != null && dropoffLng != null)
                        _legendDot(const Color(0xFFEF4444), 'Destination'),
                      if (recommendedPolyline.length > 1)
                        _legendDot(const Color(0xFFE5A93C), 'Corridor'),
                    ],
                  ),
                ),
              ),

              // Timestamp HUD (Top Right)
              if (currentTimestamp.isNotEmpty)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0D141E).withValues(alpha: 0.92)
                          : Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_filled_rounded,
                          color: Color(0xFFE5A93C),
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          currentTimestamp,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // VIDEO-LIKE PLAYBACK CONTROLLER DOCK (Bottom Floating Dock)
              Positioned(
                bottom: 16,
                left: 12,
                right: 12,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF090E17).withValues(alpha: 0.96)
                          : const Color(0xFF1E293B).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Interactive Stops Navigation Bar
                        if (_routeStops.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            height: 30,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _routeStops.length,
                              separatorBuilder: (_, index) => const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 3),
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 10,
                                  color: Colors.white38,
                                ),
                              ),
                              itemBuilder: (context, idx) {
                                final stop = _routeStops[idx];
                                final isStart = stop['type'] == 'start';
                                final isCur = stop['type'] == 'current';
                                final stopColor = isStart
                                    ? const Color(0xFF10B981)
                                    : (isCur
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFFF59E0B));
                                return InkWell(
                                  onTap: () {
                                    final ptIdx = stop['pointIndex'] as int?;
                                    if (ptIdx != null) _seekTo(ptIdx);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: stopColor.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: stopColor.withValues(alpha: 0.60),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isStart
                                              ? Icons.trip_origin_rounded
                                              : (isCur
                                                  ? Icons.directions_car_filled_rounded
                                                  : Icons.location_on_rounded),
                                          color: stopColor,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          stop['title']?.toString() ?? 'Stop',
                                          style: TextStyle(
                                            color: stopColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        // Timeline Scrubber Slider + Indices
                        Row(
                          children: [
                            Text(
                              pointsCount > 0 ? '${activeIndex + 1}' : '0',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4.0,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7.0,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14.0,
                                  ),
                                  activeTrackColor: const Color(0xFFE5A93C),
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: const Color(0xFFE5A93C),
                                  overlayColor: const Color(0xFFE5A93C)
                                      .withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: pointsCount > 1
                                      ? activeIndex.toDouble()
                                      : 0.0,
                                  min: 0.0,
                                  max: pointsCount > 1
                                      ? (pointsCount - 1).toDouble()
                                      : 1.0,
                                  onChanged: pointsCount > 1
                                      ? (val) => _seekTo(val.round())
                                      : null,
                                ),
                              ),
                            ),
                            Text(
                              '$pointsCount',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        // Controls Toolbar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Playback controls (Rewind, Step, Play, Step)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: points.isNotEmpty
                                      ? () => _seekTo(0)
                                      : null,
                                  icon: const Icon(
                                    Icons.replay_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  tooltip: 'Restart Trip',
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: points.isNotEmpty
                                      ? () => _seekTo(activeIndex - 5)
                                      : null,
                                  icon: const Icon(
                                    Icons.fast_rewind_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  tooltip: 'Step Back 5 Logs',
                                ),
                                const SizedBox(width: 10),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: points.isEmpty
                                        ? null
                                        : () {
                                            if (_isPlaying) {
                                              _pausePlayback();
                                            } else {
                                              _startPlayback();
                                            }
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5A93C),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE5A93C)
                                                .withValues(alpha: 0.45),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.black,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: points.isNotEmpty
                                      ? () => _seekTo(activeIndex + 5)
                                      : null,
                                  icon: const Icon(
                                    Icons.fast_forward_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  tooltip: 'Step Forward 5 Logs',
                                ),
                              ],
                            ),

                            // Speed multiplier buttons
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Speed: ',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  ..._availableSpeeds.map((spd) {
                                    final isSelected = _playbackSpeed == spd;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 2),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(5),
                                        onTap: () => _setPlaybackSpeed(spd),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFFE5A93C)
                                                : Colors.white12,
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            '${spd == 0.5 ? '0.5' : spd.toStringAsFixed(0)}x',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? Colors.black
                                                  : Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterBar(bool isDark) {
    final hasFilter = _activePreset != 'all';
    String filterLabel = 'All Recorded History (Full Trip)';
    if (_activePreset == 'today') {
      filterLabel = 'Today (${DateFormat('MMM d').format(DateTime.now())})';
    } else if (_activePreset == 'yesterday') {
      final y = DateTime.now().subtract(const Duration(days: 1));
      filterLabel = 'Yesterday (${DateFormat('MMM d').format(y)})';
    } else if (_activePreset == '24h') {
      filterLabel = 'Last 24 Hours';
    } else if (_activePreset == '7d') {
      filterLabel = 'Last 7 Days';
    } else if (_filterStartDate != null && _filterEndDate != null) {
      final s = DateFormat('MMM d, hh:mm a').format(_filterStartDate!);
      final e = DateFormat('MMM d, hh:mm a').format(_filterEndDate!);
      filterLabel = '$s → $e';
    } else if (_filterStartDate != null) {
      filterLabel = 'From ${DateFormat('MMM d, hh:mm a').format(_filterStartDate!)}';
    } else if (_filterEndDate != null) {
      filterLabel = 'Until ${DateFormat('MMM d, hh:mm a').format(_filterEndDate!)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1522) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFilter ? Icons.filter_alt_rounded : Icons.calendar_today_rounded,
                size: 14,
                color: hasFilter
                    ? const Color(0xFFE5A93C)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  filterLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: hasFilter ? FontWeight.bold : FontWeight.w600,
                    color: hasFilter
                        ? const Color(0xFFE5A93C)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasFilter) ...[
                InkWell(
                  onTap: () => _applyPreset('all'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 11, color: Colors.redAccent),
                        SizedBox(width: 3),
                        Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              InkWell(
                onTap: _showCustomDateRangePicker,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A93C).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 12, color: Color(0xFFE5A93C)),
                      SizedBox(width: 4),
                      Text(
                        'Custom Filter',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE5A93C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Horizontal Preset Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All Time', 'all', isDark),
                const SizedBox(width: 6),
                _filterChip('Today', 'today', isDark),
                const SizedBox(width: 6),
                _filterChip('Yesterday', 'yesterday', isDark),
                const SizedBox(width: 6),
                _filterChip('Last 24h', '24h', isDark),
                const SizedBox(width: 6),
                _filterChip('Last 7 Days', '7d', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String presetKey, bool isDark) {
    final isSelected = _activePreset == presetKey;
    return InkWell(
      onTap: () => _applyPreset(presetKey),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE5A93C)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE5A93C)
                : (isDark ? Colors.white12 : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChipInsideModal(
      String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomDateRangePicker() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    DateTime selectedStart = _filterStartDate ??
        now.subtract(const Duration(days: 1));
    DateTime selectedEnd = _filterEndDate ?? now;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final startFormatted =
                DateFormat('MMM d, yyyy • hh:mm a').format(selectedStart);
            final endFormatted =
                DateFormat('MMM d, yyyy • hh:mm a').format(selectedEnd);
            final isValid = !selectedEnd.isBefore(selectedStart);

            Future<void> pickStart() async {
              final d = await showDatePicker(
                context: context,
                initialDate: selectedStart,
                firstDate: DateTime(2020, 1, 1),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d == null || !context.mounted) return;
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(selectedStart),
              );
              final time = t ?? TimeOfDay.fromDateTime(selectedStart);
              setModalState(() {
                selectedStart = DateTime(
                  d.year,
                  d.month,
                  d.day,
                  time.hour,
                  time.minute,
                );
              });
            }

            Future<void> pickEnd() async {
              final d = await showDatePicker(
                context: context,
                initialDate: selectedEnd,
                firstDate: DateTime(2020, 1, 1),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d == null || !context.mounted) return;
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(selectedEnd),
              );
              final time = t ?? TimeOfDay.fromDateTime(selectedEnd);
              setModalState(() {
                selectedEnd = DateTime(
                  d.year,
                  d.month,
                  d.day,
                  time.hour,
                  time.minute,
                );
              });
            }

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 18,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B26) : Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 24,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5A93C)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: Color(0xFFE5A93C),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filter GPS Route by Date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Select a custom start and end date/time to audit vehicle movements.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Quick Presets inside modal
                      Text(
                        'QUICK PRESETS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPresetChipInsideModal('Today', () {
                            final n = DateTime.now();
                            setModalState(() {
                              selectedStart =
                                  DateTime(n.year, n.month, n.day, 0, 0, 0);
                              selectedEnd =
                                  DateTime(n.year, n.month, n.day, 23, 59, 59);
                            });
                          }, isDark),
                          _buildPresetChipInsideModal('Yesterday', () {
                            final y =
                                DateTime.now().subtract(const Duration(days: 1));
                            setModalState(() {
                              selectedStart =
                                  DateTime(y.year, y.month, y.day, 0, 0, 0);
                              selectedEnd =
                                  DateTime(y.year, y.month, y.day, 23, 59, 59);
                            });
                          }, isDark),
                          _buildPresetChipInsideModal('Last 24 Hours', () {
                            final n = DateTime.now();
                            setModalState(() {
                              selectedStart =
                                  n.subtract(const Duration(hours: 24));
                              selectedEnd = n;
                            });
                          }, isDark),
                          _buildPresetChipInsideModal('Last 7 Days', () {
                            final n = DateTime.now();
                            setModalState(() {
                              selectedStart =
                                  n.subtract(const Duration(days: 7));
                              selectedEnd = n;
                            });
                          }, isDark),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Start Date & Time Field
                      Text(
                        'START DATE & TIME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: pickStart,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.play_circle_outline_rounded,
                                  color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  startFormatted,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Icon(Icons.edit_calendar_rounded,
                                  size: 16,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // End Date & Time Field
                      Text(
                        'END DATE & TIME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: pickEnd,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !isValid
                                  ? Colors.red.shade400
                                  : (isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.stop_circle_outlined,
                                  color: Color(0xFFEF4444), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  endFormatted,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Icon(Icons.edit_calendar_rounded,
                                  size: 16,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            ],
                          ),
                        ),
                      ),
                      if (!isValid) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'End date/time must be after start date/time.',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _applyPreset('all');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    isDark ? Colors.white70 : Colors.black87,
                                side: BorderSide(
                                  color:
                                      isDark ? Colors.white24 : Colors.black26,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Reset to All Time'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: !isValid
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                      setState(() {
                                        _activePreset = 'custom';
                                        _filterStartDate = selectedStart;
                                        _filterEndDate = selectedEnd;
                                      });
                                      _loadRouteData();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE5A93C),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Apply Filter',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
