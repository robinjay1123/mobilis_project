import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../../services/tracking_service.dart';

class TripRouteHistoryScreen extends StatefulWidget {
  final String bookingId;
  final String? vehicleName;
  final String? plateNumber;
  final String? renterName;

  const TripRouteHistoryScreen({
    super.key,
    required this.bookingId,
    this.vehicleName,
    this.plateNumber,
    this.renterName,
  });

  static Future<void> open({
    required BuildContext context,
    required String bookingId,
    String? vehicleName,
    String? plateNumber,
    String? renterName,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TripRouteHistoryScreen(
          bookingId: bookingId,
          vehicleName: vehicleName,
          plateNumber: plateNumber,
          renterName: renterName,
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

  // Video Playback Simulation State
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentPlaybackIndex = 0;
  Timer? _playbackTimer;
  bool _autoFollowCar = true;

  final List<double> _availableSpeeds = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0];

  @override
  void initState() {
    super.initState();
    _loadRouteData();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRouteData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _trackingService
          .evaluateTripDestinationCompliance(widget.bookingId)
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _auditData = data;
          _isLoading = false;
          final pts = (data['routePoints'] as List<dynamic>? ?? []);
          _currentPlaybackIndex = pts.isNotEmpty ? pts.length - 1 : 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading trip route history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    final shortBooking = widget.bookingId.length > 8
        ? widget.bookingId.substring(0, 8)
        : widget.bookingId;

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
                'Booking #$shortBooking',
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
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE5A93C),
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
    String currentTimestamp = '';

    if (points.isNotEmpty && activeIndex < points.length) {
      final curPt = points[activeIndex];
      final lat = (curPt['latitude'] as num?)?.toDouble();
      final lng = (curPt['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        currentCarPos = LatLng(lat, lng);
      }
      currentSpeedKph = (((curPt['speed_mps'] as num?) ?? 0) * 3.6).toDouble();
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

    LatLng initialCenter = const LatLng(14.5995, 120.9842);
    if (currentCarPos != null) {
      initialCenter = currentCarPos;
    } else if (pickupLat != null &&
        pickupLng != null &&
        pickupLat != 0.0 &&
        pickupLng != 0.0) {
      initialCenter = LatLng(pickupLat, pickupLng);
    } else if (fullPolyline.isNotEmpty) {
      initialCenter = fullPolyline.first;
    }

    return Column(
      children: [
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
                                value: '${currentSpeedKph.toStringAsFixed(0)} km/h',
                                icon: Icons.electric_meter_rounded,
                                color: const Color(0xFF8B5CF6),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _statCard(
                                label: 'Trail Logs',
                                value: '${activeIndex + 1} / $pointsCount',
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
                          value: '${currentSpeedKph.toStringAsFixed(0)} km/h',
                          icon: Icons.electric_meter_rounded,
                          color: const Color(0xFF8B5CF6),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          label: 'Trail Logs',
                          value: '${activeIndex + 1} / $pointsCount',
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
                      if (pickupLat != null && pickupLng != null)
                        Marker(
                          point: LatLng(pickupLat, pickupLng),
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_pin,
                            color: Color(0xFF178A5B),
                            size: 40,
                          ),
                        ),
                      if (dropoffLat != null && dropoffLng != null)
                        Marker(
                          point: LatLng(dropoffLat, dropoffLng),
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.flag_rounded,
                            color: Color(0xFFD97706),
                            size: 38,
                          ),
                        ),
                      if (currentCarPos != null)
                        Marker(
                          point: currentCarPos,
                          width: 48,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0077FF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0077FF)
                                      .withValues(alpha: 0.6),
                                  blurRadius: 16,
                                  spreadRadius: 3,
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 2.8),
                            ),
                            child: const Icon(
                              Icons.directions_car_filled,
                              color: Colors.white,
                              size: 24,
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
                      _legendDot(const Color(0xFF178A5B), 'Pickup'),
                      _legendDot(const Color(0xFFD97706), 'Destination'),
                      _legendDot(const Color(0xFFE5A93C), 'Corridor'),
                      _legendDot(const Color(0xFF0077FF), 'Actual Trail'),
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
}
