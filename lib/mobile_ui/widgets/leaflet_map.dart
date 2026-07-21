import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';

const mobilisOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
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

class MobilisLeafletMap extends StatelessWidget {
  final List<MobilisMapMarker> markers;
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
    if (markers.isEmpty) {
      return LatLng(fallbackLatitude, fallbackLongitude);
    }

    final latitude =
        markers.fold<double>(0, (sum, marker) => sum + marker.latitude) /
        markers.length;
    final longitude =
        markers.fold<double>(0, (sum, marker) => sum + marker.longitude) /
        markers.length;
    return LatLng(latitude, longitude);
  }

  double get _zoom {
    if (initialZoom != null || markers.length < 2) {
      return initialZoom ?? (markers.isEmpty ? 12 : 15);
    }

    var minLatitude = markers.first.latitude;
    var maxLatitude = markers.first.latitude;
    var minLongitude = markers.first.longitude;
    var maxLongitude = markers.first.longitude;
    for (final marker in markers.skip(1)) {
      minLatitude = math.min(minLatitude, marker.latitude);
      maxLatitude = math.max(maxLatitude, marker.latitude);
      minLongitude = math.min(minLongitude, marker.longitude);
      maxLongitude = math.max(maxLongitude, marker.longitude);
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
            urlTemplate: mobilisOsmTileUrl,
            userAgentPackageName: mobilisMapUserAgent,
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
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
        ],
      ),
    );
  }
}
