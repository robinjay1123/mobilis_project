import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';

const mobilisTerrainTileUrl = 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
const mobilisSatelliteTileUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/'
    'World_Imagery/MapServer/tile/{z}/{y}/{x}';
const mobilisStreetTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const mobilisMapUserAgent = 'com.example.mobilis_by_psdc_app';

enum MobilisMapStyle { street, terrain, satellite }

class MobilisMapMarker {
  final double latitude;
  final double longitude;
  final IconData icon;
  final Color color;
  final double size;
  final String? tooltip;
  final String? label;
  final VoidCallback? onTap;

  const MobilisMapMarker({
    required this.latitude,
    required this.longitude,
    this.icon = Icons.location_pin,
    this.color = AppColors.primary,
    this.size = 44,
    this.tooltip,
    this.label,
    this.onTap,
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
  final MobilisMapStyle mapStyle;

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
    this.mapStyle = MobilisMapStyle.street,
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
            urlTemplate: switch (mapStyle) {
              MobilisMapStyle.street => mobilisStreetTileUrl,
              MobilisMapStyle.terrain => mobilisTerrainTileUrl,
              MobilisMapStyle.satellite => mobilisSatelliteTileUrl,
            },
            userAgentPackageName: mobilisMapUserAgent,
            maxNativeZoom: switch (mapStyle) {
              MobilisMapStyle.street || MobilisMapStyle.satellite => 19,
              MobilisMapStyle.terrain => 17,
            },
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
                      width: marker.label != null ? 140 : marker.size + 14,
                      height: marker.label != null
                          ? marker.size + 30
                          : marker.size + 14,
                      child: GestureDetector(
                        onTap: marker.onTap,
                        child: Tooltip(
                          message: marker.tooltip ?? marker.label ?? '',
                          waitDuration: const Duration(milliseconds: 100),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF071D31),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: marker.color,
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (marker.label != null &&
                                  marker.label!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF071D31,
                                    ).withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: marker.color.withValues(alpha: 0.8),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    marker.label!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              Icon(
                                marker.icon,
                                size: marker.size,
                                color: marker.color,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 8),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (showAttribution)
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(switch (mapStyle) {
                  MobilisMapStyle.street => 'OpenStreetMap contributors',
                  MobilisMapStyle.terrain =>
                    'OpenStreetMap contributors, SRTM | OpenTopoMap',
                  MobilisMapStyle.satellite =>
                    'Esri, Maxar, Earthstar Geographics',
                }),
              ],
            ),
        ],
      ),
    );
  }
}
