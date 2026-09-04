import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../services/tracking_service.dart';

import '../screens/partner/trip_route_history_screen.dart';
export '../screens/partner/trip_route_history_screen.dart';

class TripRouteHistoryDialog extends StatefulWidget {
  final String bookingId;
  final String? vehicleName;
  final String? plateNumber;
  final String? renterName;

  const TripRouteHistoryDialog({
    super.key,
    required this.bookingId,
    this.vehicleName,
    this.plateNumber,
    this.renterName,
  });

  static Future<void> show({
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
  State<TripRouteHistoryDialog> createState() => _TripRouteHistoryDialogState();
}

class _TripRouteHistoryDialogState extends State<TripRouteHistoryDialog> {
  final TrackingService _trackingService = TrackingService();
  final MapController _mapController = MapController();

  bool _isLoading = true;
  Map<String, dynamic>? _auditData;

  // Video Playback Simulation State
  bool _isPlaying = false;
  double _playbackSpeed = 1.0; // 0.5x, 1x, 2x, 5x, 10x, 20x, 50x
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
          .timeout(const Duration(seconds: 5));
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

    // Calculate dynamic timer interval based on playback speed (base: 600ms per point / speed)
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
      _startPlayback(); // restart timer with current position
    }
  }

  void _setPlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    if (_isPlaying) {
      _startPlayback(); // restart timer with new interval
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 32,
        vertical: isCompact ? 20 : 32,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: size.height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B26) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isDark),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE5A93C),
                        ),
                      )
                    : _buildContent(isDark, isCompact),
              ),
              _buildFooter(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D141E) : const Color(0xFF0F1B2B),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE5A93C).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.play_circle_filled_rounded,
              color: Color(0xFFE5A93C),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Trip Playback & Destination Audit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.vehicleName != null && widget.vehicleName!.isNotEmpty
                      ? '${widget.vehicleName} (${widget.plateNumber ?? ''}) • Booking #${widget.bookingId.substring(0, widget.bookingId.length > 8 ? 8 : widget.bookingId.length)}'
                      : 'Booking #${widget.bookingId.substring(0, widget.bookingId.length > 8 ? 8 : widget.bookingId.length)}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, bool isCompact) {
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

    // All polyline coordinates (Actual Vehicle Trail)
    final List<LatLng> fullPolyline = [];
    for (final p in points) {
      final lat = (p['latitude'] as num?)?.toDouble();
      final lng = (p['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        fullPolyline.add(LatLng(lat, lng));
      }
    }

    // Coordinates up to current playback index
    final List<LatLng> traveledPolyline = [];
    final activeIndex = _currentPlaybackIndex.clamp(0, fullPolyline.isNotEmpty ? fullPolyline.length - 1 : 0);
    if (fullPolyline.isNotEmpty) {
      for (int i = 0; i <= activeIndex && i < fullPolyline.length; i++) {
        traveledPolyline.add(fullPolyline[i]);
      }
    }

    // Planned / Recommended road route from pickup to destination (for reference only)
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
      final recAt = curPt['recorded_at']?.toString() ?? curPt['created_at']?.toString();
      if (recAt != null && recAt.isNotEmpty) {
        try {
          final cleanStr = recAt.trim();
          DateTime dt;
          if (cleanStr.endsWith('Z') ||
              cleanStr.contains('+') ||
              (cleanStr.length > 10 && cleanStr.substring(10).contains('-'))) {
            dt = DateTime.parse(cleanStr).toLocal();
          } else {
            // Timestamp without timezone offset from DB/GPS is in UTC - append Z then convert to local
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
    } else if (pickupLat != null && pickupLng != null && pickupLat != 0.0 && pickupLng != 0.0) {
      initialCenter = LatLng(pickupLat, pickupLng);
    } else if (fullPolyline.isNotEmpty) {
      initialCenter = fullPolyline.first;
    }

    return Column(
      children: [
        // Top Stats & Alert Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? const Color(0xFF16202E) : const Color(0xFFF7FAFC),
          child: Column(
            children: [
              if (!isCompliant)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          'Destination Deviation: Vehicle traveled ${maxDeviationKm.toStringAsFixed(1)} km outside stated dropoff ($dropoffLocation). Recommended Penalty: ₱${NumberFormat('#,##0.00').format(penaltyAmount)}',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFFB71C1C),
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
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF178A5B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
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
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Destination Compliant: Stayed within declared destination corridor ($dropoffLocation). No penalty required.',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF0F5132),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Compact 4-stat bar
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
              ),
            ],
          ),
        ),

        // Interactive Leaflet Map + Video Playback Controls Overlay
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
                  // 1. Planned / Recommended Route to Destination (Reference view only)
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
                  // 2. Background full vehicle trail (translucent remaining trail)
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
                  // 3. Active traveled vehicle GPS trail up to current playback frame (bold neon blue)
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
                      // Animated moving car marker
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
                                  color: const Color(0xFF0077FF).withValues(alpha: 0.6),
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

              // Map legend badge (top left)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _legendDot(const Color(0xFF178A5B), 'Pickup (Start)'),
                      _legendDot(const Color(0xFFD97706), 'Destination'),
                      _legendDot(const Color(0xFFE5A93C), 'Planned Route (Reference)'),
                      _legendDot(const Color(0xFF0077FF), 'Actual Vehicle Trail'),
                    ],
                  ),
                ),
              ),

              // Current Timestamp & Speed HUD overlay (top right)
              if (currentTimestamp.isNotEmpty)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          currentTimestamp,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // VIDEO-LIKE PLAYBACK CONTROLLER DOCK (Bottom center)
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      // Timeline Scrubber Slider + Progress Percent
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
                                overlayColor:
                                    const Color(0xFFE5A93C).withValues(alpha: 0.2),
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
                      const SizedBox(height: 4),
                      // Controls Toolbar: Play/Pause, Rewind, Follow Camera, Speed Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Playback buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Restart / Rewind
                              IconButton(
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
                              // Step Back 5 pts
                              IconButton(
                                onPressed: points.isNotEmpty
                                    ? () => _seekTo(activeIndex - 5)
                                    : null,
                                icon: const Icon(
                                  Icons.fast_rewind_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                tooltip: 'Step Back',
                              ),
                              // Play / Pause Button (Large Hero)
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
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5A93C),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFE5A93C)
                                              .withValues(alpha: 0.45),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.black,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                              // Step Forward 5 pts
                              IconButton(
                                onPressed: points.isNotEmpty
                                    ? () => _seekTo(activeIndex + 5)
                                    : null,
                                icon: const Icon(
                                  Icons.fast_forward_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                tooltip: 'Step Forward',
                              ),
                              // Camera Auto-Follow Toggle
                              IconButton(
                                onPressed: () {
                                  setState(() => _autoFollowCar = !_autoFollowCar);
                                },
                                icon: Icon(
                                  _autoFollowCar
                                      ? Icons.videocam_rounded
                                      : Icons.videocam_off_rounded,
                                  color: _autoFollowCar
                                      ? const Color(0xFFE5A93C)
                                      : Colors.white38,
                                  size: 20,
                                ),
                                tooltip: _autoFollowCar
                                    ? 'Camera Locked on Car'
                                    : 'Manual Pan Mode',
                              ),
                            ],
                          ),

                          // Right: Speed Multiplier Selector
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Speed: ',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              ..._availableSpeeds.map((spd) {
                                final isSelected = _playbackSpeed == spd;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _setPlaybackSpeed(spd),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFE5A93C)
                                            : Colors.white12,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${spd == 0.5 ? '0.5' : spd.toStringAsFixed(0)}x',
                                        style: TextStyle(
                                          fontSize: 10,
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
                        ],
                      ),
                    ],
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
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
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

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D141E) : const Color(0xFFF7FAFC),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Interactive video-style playback with variable speeds & live GPS trail',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A93C),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
