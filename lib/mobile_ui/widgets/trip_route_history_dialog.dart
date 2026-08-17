import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../mobile_ui/theme/app_colors.dart';
import '../../services/tracking_service.dart';

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
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => TripRouteHistoryDialog(
        bookingId: bookingId,
        vehicleName: vehicleName,
        plateNumber: plateNumber,
        renterName: renterName,
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

  @override
  void initState() {
    super.initState();
    _loadRouteData();
  }

  Future<void> _loadRouteData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _trackingService.evaluateTripDestinationCompliance(
        widget.bookingId,
      );
      if (mounted) {
        setState(() {
          _auditData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trip route history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        horizontal: isCompact ? 16 : 32,
        vertical: isCompact ? 24 : 32,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 950,
          maxHeight: size.height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B26) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 28,
                offset: Offset(0, 14),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
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
              color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Color(0xFFE5A93C),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip Route History & Destination Audit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
    final pointsCount = (data['pointsCount'] as num?)?.toInt() ?? 0;
    final dropoffLocation = data['dropoffLocation']?.toString() ?? 'Agreed Destination';
    final pickupLocation = data['pickupLocation']?.toString() ?? 'Pickup Origin';
    final booking = (data['booking'] as Map<String, dynamic>?) ?? {};

    final routePoints = (data['routePoints'] as List<dynamic>? ?? [])
        .map((p) => p as Map<String, dynamic>)
        .toList();

    final List<LatLng> polylineCoordinates = [];
    for (final p in routePoints) {
      final lat = (p['latitude'] as num?)?.toDouble();
      final lng = (p['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        polylineCoordinates.add(LatLng(lat, lng));
      }
    }

    final pickupLat = (booking['pickup_latitude'] as num?)?.toDouble();
    final pickupLng = (booking['pickup_longitude'] as num?)?.toDouble();
    final dropoffLat = (booking['dropoff_latitude'] as num?)?.toDouble();
    final dropoffLng = (booking['dropoff_longitude'] as num?)?.toDouble();

    LatLng initialCenter = const LatLng(14.5995, 120.9842); // Manila default
    if (polylineCoordinates.isNotEmpty) {
      initialCenter = polylineCoordinates.first;
    } else if (pickupLat != null && pickupLng != null) {
      initialCenter = LatLng(pickupLat, pickupLng);
    }

    return Column(
      children: [
        // Top Stats & Alert Banner
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? const Color(0xFF16202E) : const Color(0xFFF7FAFC),
          child: Column(
            children: [
              if (!isCompliant)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE53935).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFE53935),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Destination Violation / Route Deviation Detected',
                              style: TextStyle(
                                color: Color(0xFFE53935),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vehicle operated ${maxDeviationKm.toStringAsFixed(1)} km outside the agreed destination ($dropoffLocation). Recommended Destination Penalty: ₱${NumberFormat('#,##0.00').format(penaltyAmount)}',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF178A5B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
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
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Destination Compliant: The vehicle stayed within the agreed destination corridor ($dropoffLocation). No destination penalty required.',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF0F5132),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      label: 'Distance Traveled',
                      value: '${totalDistanceKm.toStringAsFixed(1)} km',
                      icon: Icons.alt_route_rounded,
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      label: 'Top Speed',
                      value: '${topSpeedKph.toStringAsFixed(0)} km/h',
                      icon: Icons.speed_rounded,
                      color: const Color(0xFFE5A93C),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      label: 'GPS Trail Points',
                      value: '$pointsCount logs',
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

        // Interactive Map
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: polylineCoordinates.isNotEmpty ? 13.5 : 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.psdc.mobilis',
                  ),
                  if (polylineCoordinates.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: polylineCoordinates,
                          strokeWidth: 5.0,
                          color: const Color(0xFF0077FF),
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
                      if (polylineCoordinates.isNotEmpty)
                        Marker(
                          point: polylineCoordinates.last,
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0077FF),
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(
                              Icons.directions_car_filled,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              // Map overlay legend
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0D141E).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _legendDot(const Color(0xFF178A5B), 'Pickup Origin'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFFD97706), 'Agreed Destination'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFF0077FF), 'Traveled GPS Trail'),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 10,
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
                    fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
            'GPS Tracked Live Coordinates recorded automatically',
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
