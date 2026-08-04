import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/gps_tracker_model.dart';
import '../../../services/gps_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/leaflet_map.dart';

class VehicleTrackingMapScreen extends StatefulWidget {
  final String vehicleTitle;
  final String plateNumber;
  final VehicleTracker tracker;

  const VehicleTrackingMapScreen({
    super.key,
    required this.vehicleTitle,
    required this.plateNumber,
    required this.tracker,
  });

  @override
  State<VehicleTrackingMapScreen> createState() =>
      _VehicleTrackingMapScreenState();
}

class _VehicleTrackingMapScreenState extends State<VehicleTrackingMapScreen> {
  final GpsService _gpsService = GpsService();
  final MapController _mapController = MapController();

  Timer? _pollingTimer;
  GpsPositionData? _currentPosition;
  bool _isLoading = true;
  bool _isFetching = false;
  bool _autoFollow = true;
  final double _currentZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _fetchPosition(showLoader: true);
    // Safe polling every 8 seconds while screen is open
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        _fetchPosition(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    super.dispose();
  }

  Future<void> _fetchPosition({bool showLoader = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final pos = await _gpsService.fetchLatestLocation(
        tracker: widget.tracker,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = pos;
        _isLoading = false;
      });

      if (pos != null && _autoFollow) {
        try {
          final targetLat = pos.latitude == 0 ? 15.928312 : pos.latitude;
          final targetLng = pos.longitude == 0 ? 120.348901 : pos.longitude;
          _mapController.move(LatLng(targetLat, targetLng), _currentZoom);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Tracking fetch error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      _isFetching = false;
    }
  }

  void _centerVehicle() {
    final lat = _currentPosition?.latitude ?? widget.tracker.lastLatitude ?? 15.928312;
    final lng = _currentPosition?.longitude ?? widget.tracker.lastLongitude ?? 120.348901;
    try {
      _mapController.move(LatLng(lat, lng), _currentZoom);
    } catch (_) {}
  }

  String _getTimeAgoString(DateTime? dt) {
    if (dt == null) return 'No timestamp';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds} seconds ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    return '${diff.inHours} hours ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lat = _currentPosition?.latitude ?? widget.tracker.lastLatitude ?? 15.928312;
    final lng = _currentPosition?.longitude ?? widget.tracker.lastLongitude ?? 120.348901;
    final speed = _currentPosition?.speedKph ?? widget.tracker.lastSpeed ?? 0.0;
    final ignition = _currentPosition?.ignitionOn ?? widget.tracker.lastIgnition ?? false;
    final lastTime = _currentPosition?.receivedAt ?? widget.tracker.lastSyncAt;

    final isStale = lastTime != null && DateTime.now().difference(lastTime).inMinutes >= 3;
    final isOnline = _currentPosition?.isOnline == true && !isStale;

    final statusText = isOnline
        ? 'GPS Online'
        : (isStale ? 'Location Stale' : 'GPS Offline');
    final statusColor = isOnline
        ? Colors.green
        : (isStale ? Colors.orange : Colors.redAccent);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.vehicleTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.plateNumber.isNotEmpty ? widget.plateNumber : 'Live Tracking',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _fetchPosition(showLoader: true),
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Leaflet Map
          MobilisLeafletMap(
            mapController: _mapController,
            fallbackLatitude: lat,
            fallbackLongitude: lng,
            initialZoom: _currentZoom,
            interactive: true,
            markers: [
              MobilisMapMarker(
                latitude: lat,
                longitude: lng,
                icon: Icons.directions_car_filled_rounded,
                color: statusColor,
                size: 48,
              ),
            ],
          ),

          // Status Badge Pill Top Left
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Map Control Buttons Right Side
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter_gps',
                  onPressed: _centerVehicle,
                  backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  tooltip: 'Center Vehicle',
                  child: const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'auto_follow_toggle',
                  onPressed: () {
                    setState(() => _autoFollow = !_autoFollow);
                  },
                  backgroundColor: _autoFollow
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBgSecondary : Colors.white),
                  foregroundColor: _autoFollow
                      ? Colors.black
                      : (isDark ? Colors.white : Colors.black),
                  tooltip: _autoFollow ? 'Auto-follow ON' : 'Auto-follow OFF',
                  child: Icon(_autoFollow ? Icons.near_me_rounded : Icons.near_me_disabled_rounded),
                ),
              ],
            ),
          ),

          // Bottom Position & Sensor Info Card
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkBgSecondary : Colors.white).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Speed
                      Column(
                        children: [
                          const Icon(Icons.speed_rounded, color: AppColors.primary, size: 26),
                          const SizedBox(height: 4),
                          Text(
                            '${speed.toStringAsFixed(0)} km/h',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const Text(
                            'Speed',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                      Container(height: 40, width: 1, color: Colors.grey.withValues(alpha: 0.3)),

                      // Ignition
                      Column(
                        children: [
                          Icon(
                            Icons.key_rounded,
                            color: ignition ? Colors.green : Colors.grey,
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ignition ? 'ON' : 'OFF',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: ignition ? Colors.green : Colors.grey,
                            ),
                          ),
                          const Text(
                            'Ignition',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Last updated: ${_getTimeAgoString(lastTime)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
