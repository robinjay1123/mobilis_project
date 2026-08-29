import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import 'leaflet_map.dart';

class TripLocationMapDialog extends StatefulWidget {
  final String? bookingId;
  final String? pickupLocation;
  final String? dropoffLocation;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final String? vehicleName;
  final String? plateNumber;

  const TripLocationMapDialog({
    super.key,
    this.bookingId,
    this.pickupLocation,
    this.dropoffLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.vehicleName,
    this.plateNumber,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> booking,
    String? vehicleName,
    String? plateNumber,
  }) {
    final pickupLat = (booking['pickup_latitude'] ??
            booking['pickupLatitude'] as num?)
        ?.toDouble();
    final pickupLng = (booking['pickup_longitude'] ??
            booking['pickupLongitude'] as num?)
        ?.toDouble();
    final dropoffLat = (booking['dropoff_latitude'] ??
            booking['dropoffLatitude'] as num?)
        ?.toDouble();
    final dropoffLng = (booking['dropoff_longitude'] ??
            booking['dropoffLongitude'] as num?)
        ?.toDouble();

    final pickup = booking['pickup_location']?.toString() ??
        booking['pickupLocation']?.toString() ??
        'Pickup Location';
    final dropoff = booking['dropoff_location']?.toString() ??
        booking['dropoffLocation']?.toString() ??
        booking['destination']?.toString() ??
        'Drop-off Location';

    final vName = vehicleName ??
        booking['vehicle_name']?.toString() ??
        booking['carName']?.toString() ??
        booking['vehicles']?['vehicle_name']?.toString() ??
        booking['vehicles']?['brand']?.toString();

    final plate = plateNumber ??
        booking['plate_number']?.toString() ??
        booking['plateNumber']?.toString() ??
        booking['vehicles']?['plate_number']?.toString();

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => TripLocationMapDialog(
        bookingId: booking['id']?.toString(),
        pickupLocation: pickup,
        dropoffLocation: dropoff,
        pickupLatitude: pickupLat,
        pickupLongitude: pickupLng,
        dropoffLatitude: dropoffLat,
        dropoffLongitude: dropoffLng,
        vehicleName: vName,
        plateNumber: plate,
      ),
    );
  }

  @override
  State<TripLocationMapDialog> createState() => _TripLocationMapDialogState();
}

class _TripLocationMapDialogState extends State<TripLocationMapDialog> {
  final MapController _mapController = MapController();
  MobilisMapStyle _mapStyle = MobilisMapStyle.street;

  // Default fallback center (Pangasinan / Central Luzon)
  static const double defaultLat = 16.0433;
  static const double defaultLng = 120.3333;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final markers = <MobilisMapMarker>[];

    // Pickup Marker
    if (widget.pickupLatitude != null &&
        widget.pickupLongitude != null &&
        widget.pickupLatitude != 0.0 &&
        widget.pickupLongitude != 0.0) {
      markers.add(
        MobilisMapMarker(
          latitude: widget.pickupLatitude!,
          longitude: widget.pickupLongitude!,
          color: Colors.green,
          size: 40,
          label: 'Pickup',
          tooltip: widget.pickupLocation ?? 'Pickup Point',
          customChild: Container(
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.trip_origin_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }

    // Dropoff Marker
    if (widget.dropoffLatitude != null &&
        widget.dropoffLongitude != null &&
        widget.dropoffLatitude != 0.0 &&
        widget.dropoffLongitude != 0.0) {
      markers.add(
        MobilisMapMarker(
          latitude: widget.dropoffLatitude!,
          longitude: widget.dropoffLongitude!,
          color: Colors.redAccent,
          size: 40,
          label: 'Drop-off',
          tooltip: widget.dropoffLocation ?? 'Drop-off Location',
          customChild: Container(
            decoration: BoxDecoration(
              color: Colors.redAccent.shade700,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      );
    }

    // Fallback marker if coordinates were not explicitly set but location string exists
    if (markers.isEmpty) {
      markers.add(
        MobilisMapMarker(
          latitude: defaultLat,
          longitude: defaultLng,
          color: AppColors.primary,
          size: 40,
          label: 'Location',
          tooltip: widget.dropoffLocation ?? widget.pickupLocation ?? 'Trip Location',
          customChild: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_pin,
              color: Colors.black,
              size: 24,
            ),
          ),
        ),
      );
    }

    final centerLat = markers.isNotEmpty ? markers.first.latitude : defaultLat;
    final centerLng = markers.isNotEmpty ? markers.first.longitude : defaultLng;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 640,
          maxHeight: 720,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.map_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trip Location Map',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (widget.vehicleName != null &&
                              widget.vehicleName!.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              '${widget.vehicleName}${widget.plateNumber != null && widget.plateNumber!.isNotEmpty ? ' (${widget.plateNumber})' : ''}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Style Switcher
                    PopupMenuButton<MobilisMapStyle>(
                      initialValue: _mapStyle,
                      tooltip: 'Change Map View',
                      icon: Icon(
                        Icons.layers_rounded,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 20,
                      ),
                      onSelected: (style) => setState(() => _mapStyle = style),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: MobilisMapStyle.street,
                          child: Text('Street View'),
                        ),
                        const PopupMenuItem(
                          value: MobilisMapStyle.satellite,
                          child: Text('Satellite View'),
                        ),
                        const PopupMenuItem(
                          value: MobilisMapStyle.terrain,
                          child: Text('Terrain View'),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Map Area
              Expanded(
                child: Stack(
                  children: [
                    MobilisLeafletMap(
                      markers: markers,
                      fallbackLatitude: centerLat,
                      fallbackLongitude: centerLng,
                      initialZoom: 13.0,
                      interactive: true,
                      mapController: _mapController,
                      mapStyle: _mapStyle,
                    ),

                    // Floating Controls (Zoom in, Zoom out, Fit/Center)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Column(
                        children: [
                          _buildMapToolButton(
                            icon: Icons.add,
                            tooltip: 'Zoom In',
                            onTap: () {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(
                                _mapController.camera.center,
                                (currentZoom + 1).clamp(3, 19),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildMapToolButton(
                            icon: Icons.remove,
                            tooltip: 'Zoom Out',
                            onTap: () {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(
                                _mapController.camera.center,
                                (currentZoom - 1).clamp(3, 19),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildMapToolButton(
                            icon: Icons.center_focus_strong_rounded,
                            tooltip: 'Fit Locations',
                            onTap: () => _fitMarkers(markers),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Location Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pickup Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.trip_origin_rounded,
                            color: Colors.green,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pickup Point',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                (widget.pickupLocation != null &&
                                        widget.pickupLocation!.trim().isNotEmpty)
                                    ? widget.pickupLocation!.trim()
                                    : 'PSDC Hub / Designated Pickup Point',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Dropoff Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Drop-off Destination',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.redAccent.shade700,
                                ),
                              ),
                              Text(
                                (widget.dropoffLocation != null &&
                                        widget.dropoffLocation!.trim().isNotEmpty)
                                    ? widget.dropoffLocation!.trim()
                                    : 'Declared Destination',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  void _fitMarkers(List<MobilisMapMarker> markers) {
    if (markers.isEmpty) return;
    if (markers.length == 1) {
      _mapController.move(
        LatLng(markers.first.latitude, markers.first.longitude),
        14.0,
      );
      return;
    }

    final points = markers.map((m) => LatLng(m.latitude, m.longitude)).toList();
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }
}
