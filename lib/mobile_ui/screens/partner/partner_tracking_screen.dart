import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/tracking_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/leaflet_map.dart';
import '../../widgets/trip_route_history_dialog.dart';
import '../home/chat_detail_screen.dart';

class PartnerTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String conversationId;
  final String recipientName;

  const PartnerTrackingScreen({
    super.key,
    required this.booking,
    required this.conversationId,
    required this.recipientName,
  });

  @override
  State<PartnerTrackingScreen> createState() => _PartnerTrackingScreenState();
}

class _PartnerTrackingScreenState extends State<PartnerTrackingScreen> {
  final TrackingService _trackingService = TrackingService();
  final MapController _mapController = MapController();
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _trackingChannel;
  Timer? _refreshTimer;
  Map<String, dynamic>? _trackingLocation;
  List<MobilisMapPoint> _routeHistory = [];
  bool _isLoading = true;
  bool _autoFollow = true;
  double _zoom = 15;

  @override
  void initState() {
    super.initState();
    _loadRouteHistory();
    _loadTrackingLocation();
    _setupRealtimeSubscription();
    // Responsive 20s backup poll while partner is viewing live screen (Realtime channel pushes instant updates)
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        _loadTrackingLocation(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (_trackingChannel != null) {
      _supabase.removeChannel(_trackingChannel!);
      _trackingChannel = null;
    }
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    try {
      _trackingChannel = _supabase
          .channel('partner_live_tracking_$bookingId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tracking_locations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'booking_id',
              value: bookingId,
            ),
            callback: (payload) {
              if (mounted) {
                _loadTrackingLocation(showLoader: false);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Partner tracking realtime subscription error: $e');
    }
  }

  Future<void> _loadRouteHistory() async {
    final bookingId = widget.booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;
    try {
      final logs = await _supabase
          .from('tracking_location_logs')
          .select('latitude, longitude, recorded_at')
          .eq('booking_id', bookingId)
          .order('recorded_at', ascending: true)
          .limit(200);

      final points = <MobilisMapPoint>[];
      for (final log in List<Map<String, dynamic>>.from(logs)) {
        final rLat = (log['latitude'] as num?)?.toDouble();
        final rLng = (log['longitude'] as num?)?.toDouble();
        if (rLat != null && rLng != null && (rLat != 0.0 || rLng != 0.0)) {
          points.add(MobilisMapPoint(latitude: rLat, longitude: rLng));
        }
      }
      if (mounted && points.isNotEmpty) {
        setState(() => _routeHistory = points);
      }
    } catch (_) {}
  }

  Future<void> _loadTrackingLocation({bool showLoader = true}) async {
    if (showLoader && mounted && _trackingLocation == null) {
      setState(() => _isLoading = true);
    }

    final bookingId = widget.booking['id']?.toString() ?? '';
    final location = await _trackingService.getTrackingLocationForBooking(
      bookingId,
    );

    if (!mounted) return;

    var lat = (location?['latitude'] as num?)?.toDouble();
    var lng = (location?['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      lat = (widget.booking['pickup_latitude'] as num?)?.toDouble();
      lng = (widget.booking['pickup_longitude'] as num?)?.toDouble();
    }

    setState(() {
      _trackingLocation = location;
      _isLoading = false;
      if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
        if (_routeHistory.isEmpty ||
            _routeHistory.last.latitude != lat ||
            _routeHistory.last.longitude != lng) {
          _routeHistory.add(MobilisMapPoint(latitude: lat, longitude: lng));
        }
      }
    });

    if (lat != null && lng != null && (lat != 0.0 || lng != 0.0) && _autoFollow) {
      try {
        _mapController.move(LatLng(lat, lng), _zoom);
      } catch (_) {}
    }
  }

  void _centerVehicle() {
    final lat = (_trackingLocation?['latitude'] as num?)?.toDouble() ??
        (widget.booking['pickup_latitude'] as num?)?.toDouble();
    final lng = (_trackingLocation?['longitude'] as num?)?.toDouble() ??
        (widget.booking['pickup_longitude'] as num?)?.toDouble();
    if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
      try {
        _mapController.move(LatLng(lat, lng), _zoom);
        setState(() => _autoFollow = true);
      } catch (_) {}
    }
  }

  Future<void> _openConversation() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          conversationId: widget.conversationId,
          recipientName: widget.recipientName,
          recipientAvatar: '',
          isDarkMode: true,
          isAutoGenerated: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final tracking = _trackingLocation;
    final bookingMap = tracking?['bookings'] as Map<String, dynamic>?;
    final vehicle =
        bookingMap?['vehicles'] as Map<String, dynamic>? ??
        booking['vehicles'] as Map<String, dynamic>?;
    final renter =
        bookingMap?['renter'] as Map<String, dynamic>? ??
        booking['users'] as Map<String, dynamic>?;
    final isStandby = tracking?['is_standby'] == true;
    final lat = (tracking?['latitude'] as num?)?.toDouble() ??
        (bookingMap?['pickup_latitude'] ?? booking['pickup_latitude'] as num?)?.toDouble();
    final lng = (tracking?['longitude'] as num?)?.toDouble() ??
        (bookingMap?['pickup_longitude'] ?? booking['pickup_longitude'] as num?)?.toDouble();
    final speedMps = (tracking?['speed_mps'] as num?)?.toDouble() ?? 0;
    final speedKph = (speedMps * 3.6).round();
    final speedMph = speedMps * 2.23694;
    final heading = (tracking?['heading_degrees'] as num?)?.toDouble() ?? 0;
    final recordedAt = tracking?['recorded_at']?.toString();
    DateTime? recordedAtDt;
    if (recordedAt != null && recordedAt.isNotEmpty) {
      recordedAtDt = DateTime.tryParse(recordedAt)?.toUtc();
    }
    final now = DateTime.now().toUtc();
    final minutesSinceRecorded = recordedAtDt != null
        ? now.difference(recordedAtDt).inMinutes
        : 999;
    final isStale = minutesSinceRecorded >= 15;
    final isMoving = speedKph >= 3;

    final String motionStatusLabel;
    final Color motionColor;
    final IconData motionIcon;

    if (tracking == null && (lat == null || lng == null)) {
      motionStatusLabel = 'AWAITING GPS';
      motionColor = Colors.grey;
      motionIcon = Icons.sensors_off_rounded;
    } else if (isStandby || (tracking == null && lat != null)) {
      motionStatusLabel = 'STANDBY • AT PICKUP / HUB';
      motionColor = const Color(0xFF38BDF8);
      motionIcon = Icons.satellite_alt_rounded;
    } else if (isMoving) {
      motionStatusLabel = 'MOVING • $speedKph KM/H';
      motionColor = const Color(0xFF00E676);
      motionIcon = Icons.speed_rounded;
    } else if (isStale || minutesSinceRecorded >= 15) {
      final stopDuration = minutesSinceRecorded > 0 ? ' ($minutesSinceRecorded m)' : '';
      motionStatusLabel = 'PARKED • ENGINE OFF$stopDuration';
      motionColor = const Color(0xFF94A3B8);
      motionIcon = Icons.local_parking_rounded;
    } else {
      final stopDuration = minutesSinceRecorded > 0 ? ' ($minutesSinceRecorded m)' : '';
      motionStatusLabel = 'PARKED • IDLING$stopDuration';
      motionColor = const Color(0xFFFFB300);
      motionIcon = Icons.local_parking_rounded;
    }

    final destination =
        bookingMap?['dropoff_location']?.toString() ??
        booking['dropoff_location']?.toString() ??
        'Destination unavailable';
    final dropoffLat = (bookingMap?['dropoff_latitude'] ?? booking['dropoff_latitude'] as num?)?.toDouble();
    final dropoffLng = (bookingMap?['dropoff_longitude'] ?? booking['dropoff_longitude'] as num?)?.toDouble();

    final vehicleName =
        [vehicle?['vehicle_name'], vehicle?['brand'], vehicle?['model']]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .join(' ');
    final plateNumber = vehicle?['plate_number']?.toString().trim() ?? '';
    final renterName =
        renter?['full_name']?.toString().trim().isNotEmpty == true
        ? renter!['full_name'].toString().trim()
        : widget.recipientName;

    return Scaffold(
      backgroundColor: const Color(0xFF071E2D),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildMapBackdrop(
                      lat: lat,
                      lng: lng,
                      destination: destination,
                      dropoffLat: dropoffLat,
                      dropoffLng: dropoffLng,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        _buildCircleButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Column(
                          children: const [
                            Text(
                              'LIVE TRACKING',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Powered by Mobilis',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _buildCircleButton(
                          icon: Icons.more_vert,
                          onTap: () => _loadTrackingLocation(showLoader: false),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 96,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF082A4C),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: motionColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: motionColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            motionIcon,
                            size: 14,
                            color: motionColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            motionStatusLabel,
                            style: TextStyle(
                              color: motionColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 160,
                    child: Column(
                      children: [
                        _buildCircleButton(
                          icon: Icons.add,
                          onTap: () {
                            setState(() {
                              _zoom = (_zoom + 1).clamp(6.0, 18.0);
                            });
                            if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
                              try {
                                _mapController.move(LatLng(lat, lng), _zoom);
                              } catch (_) {}
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildCircleButton(
                          icon: Icons.remove,
                          onTap: () {
                            setState(() {
                              _zoom = (_zoom - 1).clamp(6.0, 18.0);
                            });
                            if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
                              try {
                                _mapController.move(LatLng(lat, lng), _zoom);
                              } catch (_) {}
                            }
                          },
                        ),
                        const SizedBox(height: 28),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: IconButton(
                            onPressed: _centerVehicle,
                            icon: const Icon(
                              Icons.my_location,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: _buildBottomSheet(
                      renterName: renterName,
                      vehicleName: vehicleName.isEmpty
                          ? 'Tracked Vehicle'
                          : vehicleName,
                      plateNumber: plateNumber,
                      destination: destination,
                      speedKph: speedKph,
                      speedMph: speedMph,
                      motionStatusLabel: motionStatusLabel,
                      motionColor: motionColor,
                      heading: _headingLabel(heading),
                      updatedAt: _formatUpdated(recordedAt),
                    ),
                  ),
                  if (_isLoading)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x44000000),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBackdrop({
    required double? lat,
    required double? lng,
    required String destination,
    required double? dropoffLat,
    required double? dropoffLng,
  }) {
    if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
      final markers = <MobilisMapMarker>[
        MobilisMapMarker(
          latitude: lat,
          longitude: lng,
          icon: Icons.directions_car_filled_rounded,
          color: AppColors.primary,
          size: 48,
          customChild: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF082A4C),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
        ),
      ];

      if (dropoffLat != null && dropoffLng != null && (dropoffLat != 0.0 || dropoffLng != 0.0)) {
        markers.add(
          MobilisMapMarker(
            latitude: dropoffLat,
            longitude: dropoffLng,
            icon: Icons.flag_rounded,
            color: Colors.redAccent,
            size: 42,
            customChild: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
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
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          MobilisLeafletMap(
            key: ValueKey('partner_tracking_${widget.booking['id']}'),
            fallbackLatitude: lat,
            fallbackLongitude: lng,
            initialZoom: _zoom,
            mapController: _mapController,
            markers: markers,
            routePoints: _routeHistory,
            routeColor: const Color(0xFF00E676),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22000000), Color(0xAA071E2D)],
              ),
            ),
          ),
        ],
      );
    }

    return _buildMapFallback(destination);
  }

  Widget _buildMapFallback(String destination) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB6E4F3), Color(0xFF6AB5D7), Color(0xFF0F3B57)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car_filled,
                color: AppColors.primaryDark,
                size: 34,
              ),
            ),
          ),
          Positioned(
            left: 36,
            right: 36,
            top: 150,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Colors.black,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      destination,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet({
    required String renterName,
    required String vehicleName,
    required String plateNumber,
    required String destination,
    required int speedKph,
    required double speedMph,
    required String motionStatusLabel,
    required Color motionColor,
    required String heading,
    required String updatedAt,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF082A4C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  color: const Color(0xFF15395A),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Renter',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      renterName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.star, color: AppColors.primary, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '4.9 PRO',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Vehicle',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vehicleName,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (plateNumber.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      plateNumber,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardBorderOf(context)),
              boxShadow: AppColors.cardShadowOf(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    label: 'SPEED',
                    value: '$speedKph km/h',
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    label: 'STATUS',
                    value: motionStatusLabel.contains('MOVING')
                        ? 'Moving'
                        : (motionStatusLabel.contains('ENGINE OFF')
                            ? 'Parked (Off)'
                            : 'Parked'),
                  ),
                ),
                Expanded(
                  child: _buildMetric(label: 'HEADING', value: heading),
                ),
                Expanded(
                  child: _buildMetric(label: 'UPDATED', value: updatedAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Destination',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            destination,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Location',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _trackingLocation == null ? 'Unavailable' : 'Live',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.conversationId.trim().isEmpty
                      ? null
                      : _openConversation,
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: const Text('Message Renter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2248),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x55FF4F8B)),
                ),
                child: const Icon(
                  Icons.podcasts_rounded,
                  color: Color(0xFFFF4F8B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final bId = widget.booking['id']?.toString() ?? '';
                if (bId.isNotEmpty) {
                  TripRouteHistoryDialog.show(
                    context: context,
                    bookingId: bId,
                    vehicleName: vehicleName,
                    plateNumber: plateNumber,
                    renterName: renterName,
                  );
                }
              },
              icon: const Icon(Icons.route_rounded, size: 18, color: AppColors.primary),
              label: const Text(
                'Audit Traveled Route & GPS Playback',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC0A2D4A),
        borderRadius: BorderRadius.circular(22),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  String _headingLabel(double headingDegrees) {
    if (headingDegrees.isNaN) return 'Unknown';
    const directions = [
      'North',
      'NE',
      'East',
      'SE',
      'South',
      'SW',
      'West',
      'NW',
    ];
    final index = (((headingDegrees % 360) / 45).round()) % directions.length;
    return directions[index];
  }

  String _formatUpdated(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'N/A';
    final parsed = DateTime.tryParse(timestamp)?.toLocal();
    if (parsed == null) return 'N/A';
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    const spacing = 42.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
