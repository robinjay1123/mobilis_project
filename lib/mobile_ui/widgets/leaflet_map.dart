import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';

const mobilisTerrainTileUrl = 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
const mobilisMapUserAgent = 'com.example.mobilis_by_psdc_app';

class MobilisMapMarker {
  final double latitude;
  final double longitude;
  final IconData icon;
  final Color color;
  final double size;

  const MobilisMapMarker({
    required this.latitude,
    required this.longitude,
    this.icon = Icons.location_pin,
    this.color = AppColors.primary,
    this.size = 44,
  });

  LatLng get point => LatLng(latitude, longitude);
}

class MobilisMapPoint {
  final double latitude;
  final double longitude;

  const MobilisMapPoint({required this.latitude, required this.longitude});

  LatLng get point => LatLng(latitude, longitude);
}

class MobilisLeafletMap extends StatelessWidget {
  final List<MobilisMapMarker> markers;
  final List<MobilisMapPoint> routePoints;
  final Color routeColor;
  final double fallbackLatitude;
  final double fallbackLongitude;
  final double? initialZoom;
  final bool interactive;
  final MapController? mapController;
  final void Function(double latitude, double longitude)? onTap;
  final Color backgroundColor;
  final bool showAttribution;

  const MobilisLeafletMap({
    super.key,
    this.markers = const [],
    this.routePoints = const [],
    this.routeColor = AppColors.primary,
    this.fallbackLatitude = 15.9758,
    this.fallbackLongitude = 120.5719,
    this.initialZoom,
    this.interactive = true,
    this.mapController,
    this.onTap,
    this.backgroundColor = const Color(0xFFE8EEF2),
    this.showAttribution = true,
  });

  LatLng get _center {
    final points = <LatLng>[
      ...markers.map((marker) => marker.point),
      ...routePoints.map((point) => point.point),
    ];
    if (points.isEmpty) {
      return LatLng(fallbackLatitude, fallbackLongitude);
    }

    final latitude =
        points.fold<double>(0, (sum, point) => sum + point.latitude) /
        points.length;
    final longitude =
        points.fold<double>(0, (sum, point) => sum + point.longitude) /
        points.length;
    return LatLng(latitude, longitude);
  }

  double get _zoom {
    final points = <LatLng>[
      ...markers.map((marker) => marker.point),
      ...routePoints.map((point) => point.point),
    ];
    if (initialZoom != null || points.length < 2) {
      return initialZoom ?? (points.isEmpty ? 12 : 15);
    }

    var minLatitude = points.first.latitude;
    var maxLatitude = points.first.latitude;
    var minLongitude = points.first.longitude;
    var maxLongitude = points.first.longitude;
    for (final point in points.skip(1)) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
      minLongitude = math.min(minLongitude, point.longitude);
      maxLongitude = math.max(maxLongitude, point.longitude);
    }
    final span = math.max(
      maxLatitude - minLatitude,
      maxLongitude - minLongitude,
    );
    if (span <= 0.002) return 15;
    if (span <= 0.01) return 13;
    if (span <= 0.05) return 11;
    if (span <= 0.2) return 9;
    if (span <= 1) return 7;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: _zoom,
          minZoom: 5,
          maxZoom: 19,
          interactionOptions: InteractionOptions(
            flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
          ),
          onTap: onTap == null
              ? null
              : (_, point) => onTap!(point.latitude, point.longitude),
        ),
        children: [
          TileLayer(
            urlTemplate: mobilisTerrainTileUrl,
            userAgentPackageName: mobilisMapUserAgent,
            // OpenTopoMap publishes native tiles through zoom 17. Allow
            // flutter_map to scale those tiles for precise close-up pinning.
            maxNativeZoom: 17,
          ),
          if (routePoints.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints.map((point) => point.point).toList(),
                  color: routeColor,
                  strokeWidth: 5,
                  borderColor: Colors.black54,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
          if (markers.isNotEmpty)
            MarkerLayer(
              markers: markers
                  .map(
                    (marker) => Marker(
                      point: marker.point,
                      width: marker.size + 10,
                      height: marker.size + 10,
                      child: Icon(
                        marker.icon,
                        size: marker.size,
                        color: marker.color,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (showAttribution)
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors, SRTM | OpenTopoMap',
                ),
              ],
            ),
        ],
      ),
    );
  }
}
