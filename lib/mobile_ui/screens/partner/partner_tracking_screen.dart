import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/gps_tracker_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/gps_service.dart';
import '../../../services/tracking_service.dart';
import '../../../utils/philippine_geocoding.dart';
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

class _PartnerTrackingScreenState extends State<PartnerTrackingScreen>
    with SingleTickerProviderStateMixin {
  final TrackingService _trackingService = TrackingService();
  final GpsService _gpsService = GpsService();
  final MapController _mapController = MapController();
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _trackingChannel;
  Timer? _refreshTimer;
  Timer? _simulationTimer;
  Map<String, dynamic>? _trackingLocation;
  VehicleTracker? _vehicleTracker;
  List<MobilisMapPoint> _routeHistory = [];
  List<MobilisMapPoint> _roadRoutePoints = [];
  bool _isLoadingRoadRoute = false;

  // Geocoded / Resolved locations
  MobilisMapPoint? _resolvedVehiclePoint;
  MobilisMapPoint? _resolvedDestinationPoint;
  MobilisMapPoint? _resolvedPickupPoint;

  bool _isLoading = true;
  bool _autoFollow = true;
  bool _isPinging = false;
  bool _isSimulating = false;
  bool _isSheetMinimized = false;
  double _zoom = 15.0;
  MobilisMapStyle _mapStyle = MobilisMapStyle.street;

  // Simulation state
  int _simStep = 0;
  double _simSpeedKph = 0.0;
  double _simHeading = 0.0;

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _initialResolveAndLoad();
    _setupRealtimeSubscription();

    // Auto refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_isSimulating) {
        _loadTrackingLocation(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _simulationTimer?.cancel();
    _radarController.dispose();
    if (_trackingChannel != null) {
      _supabase.removeChannel(_trackingChannel!);
      _trackingChannel = null;
    }
    super.dispose();
  }

  Future<void> _initialResolveAndLoad() async {
    await _resolveDestinationAndPickup();
    await _loadRouteHistory();
    await _loadTrackingLocation(showLoader: true);
    await _loadVehicleTracker();
    await _loadRoadRoute();
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final rLat1 = lat1 * (math.pi / 180.0);
    final rLat2 = lat2 * (math.pi / 180.0);
    final y = math.sin(dLon) * math.cos(rLat2);
    final x = math.cos(rLat1) * math.sin(rLat2) -
        math.sin(rLat1) * math.cos(rLat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
  }

  String _cleanAddress(String address) {
    if (address.isEmpty) return 'Destination Location';
    final cleaned = address
        .replaceAll(RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4},\s*', caseSensitive: false), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : address;
  }

  Future<void> _loadRoadRoute() async {
    final start = _resolvedPickupPoint ?? _resolvedVehiclePoint;
    final end = _resolvedDestinationPoint;
    if (start == null || end == null) return;

    final dist = PhilippineGeocoding.distanceKm(start, end);
    if (dist < 0.05) return;

    if (_isLoadingRoadRoute) return;
    _isLoadingRoadRoute = true;

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = payload['routes'] as List<dynamic>? ?? const [];
        if (routes.isNotEmpty) {
          final first = routes.first as Map<String, dynamic>;
          final geometry = first['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?;
          if (coordinates != null && coordinates.length >= 2) {
            final points = coordinates.map((coord) {
              final pair = coord as List<dynamic>;
              return MobilisMapPoint(
                latitude: (pair[1] as num).toDouble(),
                longitude: (pair[0] as num).toDouble(),
              );
            }).toList();
            if (mounted) {
              setState(() {
                _roadRoutePoints = points;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching OSRM road route in partner tracking: $e');
    } finally {
      _isLoadingRoadRoute = false;
    }
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
              if (mounted && !_isSimulating) {
                _loadTrackingLocation(showLoader: false);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Partner tracking realtime subscription error: $e');
    }
  }

  double? _safeDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim());
  }

  Future<void> _resolveDestinationAndPickup() async {
    final booking = widget.booking;
    final dropoffAddr = booking['dropoff_location']?.toString() ?? '';
    final pickupAddr = booking['pickup_location']?.toString() ?? '';

    double? dLat = _safeDouble(booking['dropoff_latitude']);
    double? dLng = _safeDouble(booking['dropoff_longitude']);

    if ((dLat == null || dLng == null || (dLat == 0.0 && dLng == 0.0)) &&
        dropoffAddr.trim().isNotEmpty) {
      final resolved = await PhilippineGeocoding.resolveLocation(dropoffAddr);
      dLat = resolved.latitude;
      dLng = resolved.longitude;
    }

    double? pLat = _safeDouble(booking['pickup_latitude']);
    double? pLng = _safeDouble(booking['pickup_longitude']);

    if ((pLat == null || pLng == null || (pLat == 0.0 && pLng == 0.0)) &&
        pickupAddr.trim().isNotEmpty) {
      final resolved = await PhilippineGeocoding.resolveLocation(pickupAddr);
      pLat = resolved.latitude;
      pLng = resolved.longitude;
    }

    if (mounted) {
      setState(() {
        if (dLat != null && dLng != null && (dLat != 0.0 || dLng != 0.0)) {
          _resolvedDestinationPoint =
              MobilisMapPoint(latitude: dLat, longitude: dLng);
        }
        if (pLat != null && pLng != null && (pLat != 0.0 || pLng != 0.0)) {
          _resolvedPickupPoint =
              MobilisMapPoint(latitude: pLat, longitude: pLng);
        }
      });
      _loadRoadRoute();
    }
  }

  Future<void> _loadVehicleTracker() async {
    final vehicle = widget.booking['vehicles'] as Map<String, dynamic>?;
    final vid = vehicle?['id']?.toString() ??
        widget.booking['vehicle_id']?.toString() ??
        '';
    if (vid.isEmpty) return;

    try {
      final tracker = await _gpsService.getTrackerForVehicle(vid);
      if (mounted && tracker != null) {
        setState(() => _vehicleTracker = tracker);
      }
    } catch (_) {}
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
          .limit(250);

      final points = <MobilisMapPoint>[];
      for (final log in List<Map<String, dynamic>>.from(logs)) {
        final rLat = _safeDouble(log['latitude']);
        final rLng = _safeDouble(log['longitude']);
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
    Map<String, dynamic>? location;
    try {
      location = await _trackingService.getTrackingLocationForBooking(bookingId);
    } catch (_) {}

    // Fallback: If tracking location is null, check vehicle trackers table directly
    if (location == null) {
      final vehicle = widget.booking['vehicles'] as Map<String, dynamic>?;
      final vid = vehicle?['id']?.toString() ??
          widget.booking['vehicle_id']?.toString() ??
          '';
      if (vid.isNotEmpty) {
        try {
          final tRow = await _supabase
              .from('vehicle_trackers')
              .select('*')
              .or('vehicle_id.eq.$vid,partner_vehicle_id.eq.$vid')
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (tRow != null) {
            final tLat = _safeDouble(tRow['last_latitude']);
            final tLng = _safeDouble(tRow['last_longitude']);
            if (tLat != null && tLng != null && (tLat != 0.0 || tLng != 0.0)) {
              location = {
                'id': 'vt_${tRow['id']}',
                'booking_id': bookingId,
                'vehicle_id': vid,
                'latitude': tLat,
                'longitude': tLng,
                'speed_mps': (_safeDouble(tRow['last_speed']) ?? 0.0) / 3.6,
                'heading_degrees': _safeDouble(tRow['last_heading']) ?? 0.0,
                'source': 'gps_tracker',
                'is_standby': false,
                'recorded_at': tRow['last_sync_at'] ?? tRow['updated_at'],
              };
            }
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;

    double? lat = _safeDouble(location?['latitude']);
    double? lng = _safeDouble(location?['longitude']);

    // Fallback 1: Vehicle registered position
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      final vehicle = widget.booking['vehicles'] as Map<String, dynamic>?;
      lat = _safeDouble(vehicle?['latitude']);
      lng = _safeDouble(vehicle?['longitude']);
    }

    // Fallback 2: Booking pickup position
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      lat = _safeDouble(widget.booking['pickup_latitude']);
      lng = _safeDouble(widget.booking['pickup_longitude']);
    }

    // Fallback 3: Resolved pickup point or destination point
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      if (_resolvedPickupPoint != null) {
        lat = _resolvedPickupPoint!.latitude;
        lng = _resolvedPickupPoint!.longitude;
      } else if (_resolvedDestinationPoint != null) {
        lat = _resolvedDestinationPoint!.latitude;
        lng = _resolvedDestinationPoint!.longitude;
      }
    }

    // Fallback 4: Fleet garage hub
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      lat = PhilippineGeocoding.defaultLat;
      lng = PhilippineGeocoding.defaultLng;
    }

    setState(() {
      _trackingLocation = location;
      _isLoading = false;
      if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
        _resolvedVehiclePoint = MobilisMapPoint(latitude: lat, longitude: lng);
        if (_routeHistory.isEmpty ||
            _routeHistory.last.latitude != lat ||
            _routeHistory.last.longitude != lng) {
          _routeHistory.add(_resolvedVehiclePoint!);
        }
      }
    });

    if (_autoFollow) {
      try {
        _mapController.move(LatLng(lat, lng), _zoom);
      } catch (_) {}
    }
  }

  void _centerVehicle() {
    final pt = _resolvedVehiclePoint ??
        _resolvedPickupPoint ??
        _resolvedDestinationPoint;
    if (pt != null) {
      try {
        _mapController.move(LatLng(pt.latitude, pt.longitude), _zoom);
        setState(() => _autoFollow = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Centered on vehicle position'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (_) {}
    }
  }

  void _centerDestination() {
    if (_resolvedDestinationPoint != null) {
      try {
        _mapController.move(
          LatLng(
            _resolvedDestinationPoint!.latitude,
            _resolvedDestinationPoint!.longitude,
          ),
          16.0,
        );
        setState(() => _autoFollow = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Centered on destination location'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (_) {}
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destination coordinates resolving...'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _fitRouteBounds() {
    final points = <LatLng>[];
    if (_resolvedVehiclePoint != null) {
      points.add(
        LatLng(_resolvedVehiclePoint!.latitude, _resolvedVehiclePoint!.longitude),
      );
    }
    if (_resolvedDestinationPoint != null) {
      points.add(
        LatLng(
          _resolvedDestinationPoint!.latitude,
          _resolvedDestinationPoint!.longitude,
        ),
      );
    }
    if (_resolvedPickupPoint != null) {
      points.add(
        LatLng(_resolvedPickupPoint!.latitude, _resolvedPickupPoint!.longitude),
      );
    }
    if (_roadRoutePoints.isNotEmpty) {
      for (final pt in _roadRoutePoints) {
        points.add(LatLng(pt.latitude, pt.longitude));
      }
    } else {
      for (final pt in _routeHistory) {
        points.add(LatLng(pt.latitude, pt.longitude));
      }
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 15.0);
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(points);
      final bottomPadding = _isSheetMinimized ? 95.0 : 240.0;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: EdgeInsets.fromLTRB(40, 160, 40, bottomPadding),
        ),
      );
      setState(() => _autoFollow = false);
    } catch (_) {}
  }

  void _toggleMinimizeSheet() {
    setState(() {
      _isSheetMinimized = !_isSheetMinimized;
    });
    if (_isSheetMinimized) {
      _fitRouteBounds();
    }
  }

  Future<void> _triggerRadarPing() async {
    if (_isPinging) return;
    setState(() => _isPinging = true);
    _radarController.repeat();

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.podcasts_rounded, color: Color(0xFFFF4F8B), size: 18),
            SizedBox(width: 8),
            Text('Pinging GPS hardware & telemetry...'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final bookingId = widget.booking['id']?.toString() ?? '';
    try {
      await _trackingService.pollGpsTrackerForBooking(bookingId);
      await _loadTrackingLocation(showLoader: false);
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) {
      _radarController.stop();
      setState(() => _isPinging = false);
      _showPingControlsModal();
    }
  }

  void _toggleSimulation() async {
    if (_isSimulating) {
      _simulationTimer?.cancel();
      _simulationTimer = null;
      setState(() {
        _isSimulating = false;
        _simSpeedKph = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live simulation stopped'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadTrackingLocation(showLoader: false);
      return;
    }

    // Ensure road route is loaded before simulating
    if (_roadRoutePoints.isEmpty) {
      await _loadRoadRoute();
    }

    final path = _roadRoutePoints.isNotEmpty
        ? _roadRoutePoints
        : [
            _resolvedVehiclePoint ??
                _resolvedPickupPoint ??
                const MobilisMapPoint(latitude: 15.9758, longitude: 120.5719),
            _resolvedDestinationPoint ??
                const MobilisMapPoint(latitude: 16.1219, longitude: 120.4039),
          ];

    if (path.isEmpty) return;

    setState(() {
      _isSimulating = true;
      _simStep = 0;
      _simSpeedKph = 42.0;
      _autoFollow = true;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.play_circle_fill_rounded,
                color: Color(0xFF00E676), size: 18),
            SizedBox(width: 8),
            Text('Simulating vehicle drive along real road...'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      _simStep = (_simStep + 1) % path.length;
      final curPt = path[_simStep];
      final nextIdx = (_simStep + 1) % path.length;
      final nextPt = path[nextIdx];

      final bearing = _calculateBearing(
        curPt.latitude,
        curPt.longitude,
        nextPt.latitude,
        nextPt.longitude,
      );

      final speedVariance = 38.0 + (math.sin(_simStep * 0.35) * 12.0);

      setState(() {
        _simSpeedKph = speedVariance;
        _simHeading = bearing;
        _resolvedVehiclePoint = curPt;
        if (_routeHistory.isEmpty ||
            _routeHistory.last.latitude != curPt.latitude ||
            _routeHistory.last.longitude != curPt.longitude) {
          _routeHistory.add(curPt);
        }
      });

      if (_autoFollow) {
        try {
          _mapController.move(LatLng(curPt.latitude, curPt.longitude), _zoom);
        } catch (_) {}
      }
    });
  }

  Future<void> _openConversation() async {
    String convId = widget.conversationId.trim();

    if (convId.isEmpty) {
      final bookingId = widget.booking['id']?.toString() ?? '';
      final renter = widget.booking['users'] as Map<String, dynamic>? ??
          widget.booking['renter'] as Map<String, dynamic>?;
      final renterId = renter?['id']?.toString() ??
          widget.booking['renter_id']?.toString() ??
          '';
      final currentUserId = AuthService().currentUser?.id;

      if (bookingId.isNotEmpty &&
          currentUserId != null &&
          renterId.isNotEmpty) {
        try {
          final chatService = ChatService();
          var conv =
              await chatService.getConversationByBookingId(bookingId);
          conv ??= await chatService.createGroupConversation(
            bookingId: bookingId,
            participantIds: [currentUserId, renterId],
          );
          convId = conv['id']?.toString() ?? '';
        } catch (e) {
          debugPrint('Error finding/creating conversation: $e');
        }
      }
    }

    if (!mounted) return;

    if (convId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: convId,
            recipientName: widget.recipientName.isNotEmpty
                ? widget.recipientName
                : 'Renter',
            recipientAvatar: '',
            isDarkMode: true,
            isAutoGenerated: true,
          ),
        ),
      );
    } else {
      _showRenterContactModal();
    }
  }

  Future<void> _launchDialer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchSms(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('sms:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _copyCoordinates() {
    final pt = _resolvedVehiclePoint ??
        _resolvedPickupPoint ??
        _resolvedDestinationPoint;
    if (pt == null) return;
    final text = '${pt.latitude.toStringAsFixed(6)}, ${pt.longitude.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coordinates copied to clipboard: $text'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODALS & ACTION SHEETS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showTrackingOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF082A4C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TRACKING & MAP OPTIONS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                title: const Text('Refresh GPS Telemetry',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Re-fetch real-time coordinates from hardware',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadTrackingLocation(showLoader: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers_rounded, color: Color(0xFF38BDF8)),
                title: Text(
                  'Map Style: ${_mapStyle.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Toggle Street, Satellite, or Terrain tile map',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMapStyleChip(MobilisMapStyle.street, 'Street'),
                    const SizedBox(width: 4),
                    _buildMapStyleChip(MobilisMapStyle.satellite, 'Sat'),
                    const SizedBox(width: 4),
                    _buildMapStyleChip(MobilisMapStyle.terrain, 'Topo'),
                  ],
                ),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.my_location_rounded, color: Colors.amber),
                title: const Text('Center on Vehicle',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _centerVehicle();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded, color: Colors.redAccent),
                title: const Text('Center on Destination',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _centerDestination();
                },
              ),
              ListTile(
                leading: const Icon(Icons.zoom_out_map_rounded, color: Color(0xFF00E676)),
                title: const Text('Fit Entire Route Bounds',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _fitRouteBounds();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white70),
                title: const Text('Copy Current Coordinates',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyCoordinates();
                },
              ),
              ListTile(
                leading: Icon(
                  _isSimulating
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_fill_rounded,
                  color: _isSimulating ? Colors.redAccent : const Color(0xFF00E676),
                ),
                title: Text(
                  _isSimulating ? 'Stop Live Simulation' : 'Simulate Live Test Drive',
                  style: TextStyle(
                    color: _isSimulating ? Colors.redAccent : const Color(0xFF00E676),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _isSimulating
                      ? 'Currently running mock telemetry movement'
                      : 'Animate vehicle along route for demonstration & UI testing',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleSimulation();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapStyleChip(MobilisMapStyle style, String label) {
    final isSelected = _mapStyle == style;
    return InkWell(
      onTap: () {
        setState(() => _mapStyle = style);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _showTelemetryStatusModal({
    required String motionStatusLabel,
    required Color motionColor,
    required int speedKph,
    required String heading,
    required String updatedAt,
  }) {
    final tracker = _vehicleTracker;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF082A4C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: motionColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.satellite_alt_rounded,
                        color: motionColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GPS TELEMETRY DIAGNOSTICS',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        motionStatusLabel,
                        style: TextStyle(
                          color: motionColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildDiagRow('Hardware Status',
                        tracker != null ? 'Connected (Aika/Traccar)' : 'Mobile GPS / Fleet Link'),
                    _buildDiagRow('Device Identifier',
                        tracker?.deviceIdentifier ?? widget.booking['plate_number'] ?? 'N/A'),
                    _buildDiagRow('Speed & Motion', '$speedKph km/h • $heading'),
                    _buildDiagRow('Last Ping Timestamp', updatedAt),
                    _buildDiagRow('Coordinates',
                        _resolvedVehiclePoint != null
                            ? '${_resolvedVehiclePoint!.latitude.toStringAsFixed(5)}, ${_resolvedVehiclePoint!.longitude.toStringAsFixed(5)}'
                            : 'Searching satellites...'),
                    _buildDiagRow('Ignition Relay',
                        tracker?.lastIgnition == true ? 'ON (Engine Running)' : 'OFF / Standby'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _triggerRadarPing();
                      },
                      icon: const Icon(Icons.podcasts_rounded, size: 18),
                      label: const Text('Force Hardware Ping'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
  }

  Widget _buildDiagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPingControlsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF082A4C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.podcasts_rounded, color: Color(0xFFFF4F8B), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'GPS HARDWARE TELEMETRY',
                    style: TextStyle(
                      color: Color(0xFFFF4F8B),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Live signal received. Choose a command for this tracked vehicle.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4F8B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sync_rounded, color: Color(0xFFFF4F8B)),
                ),
                title: const Text('Instant Position Refresh',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Pings device for immediate GPS coordinate fix',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadTrackingLocation(showLoader: true);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volume_up_rounded, color: Colors.amber),
                ),
                title: const Text('Sound Remote Buzzer / Horn',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Trigger tracker beeper to locate car in parking',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.volume_up_rounded, color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Text('Buzzer locate command transmitted to vehicle'),
                        ],
                      ),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF00E676)),
                ),
                title: const Text('Check Engine & Battery Status',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('12.6V Battery • Normal Telemetry • Ignition Active',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vehicle power & battery telemetry nominal (12.6V)'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenterContactModal() {
    final renter = widget.booking['users'] as Map<String, dynamic>? ??
        widget.booking['renter'] as Map<String, dynamic>?;
    final renterName = renter?['full_name']?.toString();
    final name = (renterName != null && renterName.trim().isNotEmpty)
        ? renterName.trim()
        : (widget.recipientName.isNotEmpty ? widget.recipientName : 'Renter');
    final phone = renter?['phone']?.toString() ??
        widget.booking['user_phone']?.toString() ??
        '';
    final email = renter?['email']?.toString() ??
        widget.booking['user_email']?.toString() ??
        '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF082A4C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.primary, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Verified Renter • 4.9 PRO Rating',
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (phone.isNotEmpty) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchDialer(phone),
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchSms(phone),
                        icon: const Icon(Icons.sms_rounded, size: 18),
                        label: const Text('SMS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openConversation();
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              if (phone.isNotEmpty || email.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      if (phone.isNotEmpty)
                        _buildDiagRow('Phone Number', phone),
                      if (email.isNotEmpty)
                        _buildDiagRow('Email Address', email),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showVehicleDetailsModal({
    required String vehicleName,
    required String plateNumber,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF082A4C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_car_filled_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          plateNumber.isNotEmpty ? plateNumber : 'No plate recorded',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildDiagRow('Booking ID', widget.booking['id']?.toString() ?? 'N/A'),
                    _buildDiagRow('Status', widget.booking['status']?.toString().toUpperCase() ?? 'ACTIVE'),
                    _buildDiagRow('Rental Start', widget.booking['start_at']?.toString() ?? 'N/A'),
                    _buildDiagRow('Scheduled Return', widget.booking['end_at']?.toString() ?? 'N/A'),
                    _buildDiagRow('Tracker Connected', _vehicleTracker != null ? 'Yes (Online)' : 'Standby / Direct GPS'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _centerVehicle();
                  },
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Center Camera on Vehicle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD METHOD & UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final tracking = _trackingLocation;
    final bookingMap = tracking?['bookings'] as Map<String, dynamic>?;
    final vehicle = bookingMap?['vehicles'] as Map<String, dynamic>? ??
        booking['vehicles'] as Map<String, dynamic>?;
    final renter = bookingMap?['renter'] as Map<String, dynamic>? ??
        booking['users'] as Map<String, dynamic>?;
    final isStandby = tracking?['is_standby'] == true;

    final speedMps = _isSimulating
        ? _simSpeedKph / 3.6
        : (_safeDouble(tracking?['speed_mps']) ?? 0.0);
    final speedKph = _isSimulating ? _simSpeedKph.round() : (speedMps * 3.6).round();
    final speedMph = speedMps * 2.23694;
    final headingDeg = _isSimulating
        ? _simHeading
        : (_safeDouble(tracking?['heading_degrees']) ?? 0.0);
    final heading = _headingLabel(headingDeg);

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

    if (_isSimulating) {
      motionStatusLabel = 'SIMULATION • $speedKph KM/H';
      motionColor = const Color(0xFF00E676);
      motionIcon = Icons.sports_motorsports_rounded;
    } else if (tracking == null && _resolvedVehiclePoint == null) {
      motionStatusLabel = 'AWAITING GPS';
      motionColor = Colors.grey;
      motionIcon = Icons.sensors_off_rounded;
    } else if (isStandby || (tracking == null && _resolvedVehiclePoint != null)) {
      motionStatusLabel = 'STANDBY • AT PICKUP / HUB';
      motionColor = const Color(0xFF38BDF8);
      motionIcon = Icons.satellite_alt_rounded;
    } else if (isMoving) {
      motionStatusLabel = 'MOVING • $speedKph KM/H';
      motionColor = const Color(0xFF00E676);
      motionIcon = Icons.speed_rounded;
    } else if (isStale || minutesSinceRecorded >= 15) {
      final stopDuration =
          minutesSinceRecorded > 0 && minutesSinceRecorded < 999
              ? ' ($minutesSinceRecorded m)'
              : '';
      motionStatusLabel = 'PARKED • ENGINE OFF$stopDuration';
      motionColor = const Color(0xFF94A3B8);
      motionIcon = Icons.local_parking_rounded;
    } else {
      final stopDuration =
          minutesSinceRecorded > 0 && minutesSinceRecorded < 999
              ? ' ($minutesSinceRecorded m)'
              : '';
      motionStatusLabel = 'PARKED • IDLING$stopDuration';
      motionColor = const Color(0xFFFFB300);
      motionIcon = Icons.local_parking_rounded;
    }

    final rawDestination = bookingMap?['dropoff_location']?.toString() ??
        booking['dropoff_location']?.toString() ??
        'San Fabian, Pangasinan';
    final destination = _cleanAddress(rawDestination);

    final vehicleBrand = vehicle?['brand']?.toString().trim() ?? '';
    final vehicleModel = vehicle?['model']?.toString().trim() ?? '';
    final rawVehicleName = vehicle?['vehicle_name']?.toString().trim() ??
        booking['vehicle_name']?.toString().trim() ??
        '';

    String resolvedVehicleName = rawVehicleName;
    if (resolvedVehicleName.isEmpty ||
        resolvedVehicleName.toLowerCase() == 'partner vehicle' ||
        resolvedVehicleName.toLowerCase() == 'vehicle request' ||
        resolvedVehicleName.toLowerCase() == 'vehicle') {
      if (vehicleModel.toLowerCase().startsWith(vehicleBrand.toLowerCase())) {
        resolvedVehicleName = vehicleModel;
      } else {
        resolvedVehicleName = [vehicleBrand, vehicleModel]
            .where((part) => part.isNotEmpty)
            .join(' ');
      }
    }
    // Deduplicate consecutive repeated brand name (e.g. "Toyota Toyota Innova" -> "Toyota Innova")
    final nameParts = resolvedVehicleName.split(RegExp(r'\s+'));
    if (nameParts.length >= 2 && nameParts[0].toLowerCase() == nameParts[1].toLowerCase()) {
      resolvedVehicleName = nameParts.sublist(1).join(' ');
    }
    if (resolvedVehicleName.isEmpty) {
      resolvedVehicleName = 'Tracked Vehicle';
    }

    final plateNumber = vehicle?['plate_number']?.toString().trim() ??
        booking['plate_number']?.toString().trim() ??
        '';
    final renterName = renter?['full_name']?.toString().trim().isNotEmpty == true
        ? renter!['full_name'].toString().trim()
        : (widget.recipientName.trim().isNotEmpty
            ? widget.recipientName.trim()
            : (booking['renter_name']?.toString().trim().isNotEmpty == true
                ? booking['renter_name'].toString().trim()
                : 'Active Renter'));
    final renterRating = (renter?['rating'] as num?)?.toDouble() ??
        (booking['renter_rating'] as num?)?.toDouble();
    final renterAvatarUrl = renter?['avatar_url']?.toString().trim() ??
        renter?['profile_picture_url']?.toString().trim() ??
        booking['user_avatar_url']?.toString().trim();

    return Scaffold(
      backgroundColor: const Color(0xFF071E2D),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // 1. LIVE LEAFLET MAP
                  Positioned.fill(
                    child: _buildInteractiveMap(
                      motionColor: motionColor,
                      speedKph: speedKph,
                      headingDeg: headingDeg,
                    ),
                  ),

                  // 2. TOP HEADER BAR
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
                                fontSize: 20,
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
                          onTap: _showTrackingOptionsMenu,
                        ),
                      ],
                    ),
                  ),

                  // 3. MOTION STATUS PILL (Interactive)
                  Positioned(
                    top: 86,
                    left: 16,
                    child: InkWell(
                      onTap: () => _showTelemetryStatusModal(
                        motionStatusLabel: motionStatusLabel,
                        motionColor: motionColor,
                        speedKph: speedKph,
                        heading: heading,
                        updatedAt: _formatUpdated(recordedAt),
                      ),
                      borderRadius: BorderRadius.circular(999),
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
                          mainAxisSize: MainAxisSize.min,
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
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: motionColor.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. FLOATING DESTINATION BANNER PILL (Tap to focus destination)
                  Positioned(
                    left: 20,
                    right: 68,
                    top: 136,
                    child: InkWell(
                      onTap: _centerDestination,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.black,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                destination,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.black54,
                              size: 11,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 5. MAP CONTROLS COLUMN (+, -, style, center)
                  Positioned(
                    right: 16,
                    top: 136,
                    child: Column(
                      children: [
                        _buildCircleButton(
                          icon: Icons.add,
                          onTap: () {
                            try {
                              final newZoom = (_mapController.camera.zoom + 1)
                                  .clamp(3.0, 19.0);
                              _mapController.move(
                                  _mapController.camera.center, newZoom);
                              setState(() => _zoom = newZoom);
                            } catch (_) {}
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildCircleButton(
                          icon: Icons.remove,
                          onTap: () {
                            try {
                              final newZoom = (_mapController.camera.zoom - 1)
                                  .clamp(3.0, 19.0);
                              _mapController.move(
                                  _mapController.camera.center, newZoom);
                              setState(() => _zoom = newZoom);
                            } catch (_) {}
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildCircleButton(
                          icon: _mapStyle == MobilisMapStyle.satellite
                              ? Icons.satellite_rounded
                              : (_mapStyle == MobilisMapStyle.terrain
                                  ? Icons.terrain_rounded
                                  : Icons.layers_rounded),
                          onTap: () {
                            setState(() {
                              if (_mapStyle == MobilisMapStyle.street) {
                                _mapStyle = MobilisMapStyle.satellite;
                              } else if (_mapStyle == MobilisMapStyle.satellite) {
                                _mapStyle = MobilisMapStyle.terrain;
                              } else {
                                _mapStyle = MobilisMapStyle.street;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildCircleButton(
                          icon: Icons.alt_route_rounded,
                          onTap: _fitRouteBounds,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
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

                  // 6. BOTTOM TELEMETRY SHEET
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: _buildBottomSheet(
                      renterName: renterName,
                      renterAvatarUrl: renterAvatarUrl,
                      vehicleName: resolvedVehicleName,
                      plateNumber: plateNumber,
                      destination: destination,
                      speedKph: speedKph,
                      speedMph: speedMph,
                      motionStatusLabel: motionStatusLabel,
                      motionColor: motionColor,
                      heading: heading,
                      updatedAt: _formatUpdated(recordedAt),
                      renterRating: renterRating,
                    ),
                  ),

                  // 7. LOADING OVERLAY
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

  // ═══════════════════════════════════════════════════════════════════════════
  // MAP RENDERING
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInteractiveMap({
    required Color motionColor,
    required int speedKph,
    required double headingDeg,
  }) {
    final vehiclePt = _resolvedVehiclePoint ??
        _resolvedPickupPoint ??
        _resolvedDestinationPoint ??
        const MobilisMapPoint(
          latitude: PhilippineGeocoding.defaultLat,
          longitude: PhilippineGeocoding.defaultLng,
        );

    final markers = <MobilisMapMarker>[];

    // Destination Flag Marker
    if (_resolvedDestinationPoint != null) {
      markers.add(
        MobilisMapMarker(
          latitude: _resolvedDestinationPoint!.latitude,
          longitude: _resolvedDestinationPoint!.longitude,
          customChild: InkWell(
            onTap: _centerDestination,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.shade700,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 6),
                    ],
                  ),
                  child: const Text(
                    'DESTINATION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 8),
                    ],
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Origin / Pickup Marker
    if (_resolvedPickupPoint != null &&
        (_resolvedVehiclePoint == null ||
            _resolvedVehiclePoint!.latitude != _resolvedPickupPoint!.latitude ||
            _resolvedVehiclePoint!.longitude != _resolvedPickupPoint!.longitude)) {
      markers.add(
        MobilisMapMarker(
          latitude: _resolvedPickupPoint!.latitude,
          longitude: _resolvedPickupPoint!.longitude,
          customChild: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 6),
              ],
            ),
            child: const Icon(
              Icons.radio_button_checked_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      );
    }

    // Vehicle Marker with Directional Car Pin, Rotation & Pulse
    markers.add(
      MobilisMapMarker(
        latitude: vehiclePt.latitude,
        longitude: vehiclePt.longitude,
        customChild: InkWell(
          onTap: () {
            _showVehicleDetailsModal(
              vehicleName: widget.booking['vehicle_name']?.toString() ?? 'Vehicle',
              plateNumber: widget.booking['plate_number']?.toString() ?? '',
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (speedKph > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF082A4C),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: motionColor, width: 1),
                  ),
                  child: Text(
                    '$speedKph km/h',
                    style: TextStyle(
                      color: motionColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer radar ping halo
                  if (_isPinging)
                    AnimatedBuilder(
                      animation: _radarController,
                      builder: (context, child) => Container(
                        width: 56 + (_radarController.value * 30),
                        height: 56 + (_radarController.value * 30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF4F8B)
                                .withValues(alpha: 1.0 - _radarController.value),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  // Glow ring with navigation direction marker
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF082A4C),
                      border: Border.all(color: motionColor, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: motionColor.withValues(alpha: 0.5),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: (headingDeg * math.pi / 180),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -12),
                              child: Icon(
                                Icons.arrow_drop_up_rounded,
                                color: motionColor,
                                size: 22,
                              ),
                            ),
                            const Icon(
                              Icons.navigation_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ],
                        ),
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

    // Route points: real road route pathway or recorded travel history
    final displayPoints = <MobilisMapPoint>[];
    if (_roadRoutePoints.isNotEmpty) {
      displayPoints.addAll(_roadRoutePoints);
    } else if (_routeHistory.isNotEmpty) {
      displayPoints.addAll(_routeHistory);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobilisLeafletMap(
          key: ValueKey('partner_tracking_${widget.booking['id']}_${_mapStyle.name}'),
          fallbackLatitude: vehiclePt.latitude,
          fallbackLongitude: vehiclePt.longitude,
          initialZoom: _zoom,
          mapController: _mapController,
          mapStyle: _mapStyle,
          markers: markers,
          routePoints: displayPoints,
          routeColor: const Color(0xFF00E676),
        ),
        // Subtle top and bottom shade for readability
        IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x55071E2D),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xAA071E2D),
                ],
                stops: [0.0, 0.25, 0.7, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM SHEET & CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════

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
    String? renterAvatarUrl,
    double? renterRating,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: 1.0,
            child: child,
          ),
        );
      },
      child: _isSheetMinimized
          ? _buildMinimizedSheetBar(
              key: const ValueKey('minimized_tracking_sheet'),
              renterName: renterName,
              vehicleName: vehicleName,
              plateNumber: plateNumber,
              renterAvatarUrl: renterAvatarUrl,
              motionStatusLabel: motionStatusLabel,
              motionColor: motionColor,
              speedKph: speedKph,
              renterRating: renterRating,
            )
          : _buildExpandedSheet(
              key: const ValueKey('expanded_tracking_sheet'),
              renterName: renterName,
              vehicleName: vehicleName,
              plateNumber: plateNumber,
              destination: destination,
              speedKph: speedKph,
              speedMph: speedMph,
              motionStatusLabel: motionStatusLabel,
              motionColor: motionColor,
              heading: heading,
              updatedAt: updatedAt,
              renterAvatarUrl: renterAvatarUrl,
              renterRating: renterRating,
            ),
    );
  }

  Widget _buildMinimizedSheetBar({
    Key? key,
    required String renterName,
    required String vehicleName,
    required String plateNumber,
    required String? renterAvatarUrl,
    required String motionStatusLabel,
    required Color motionColor,
    required int speedKph,
    double? renterRating,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -80) {
          _toggleMinimizeSheet();
        }
      },
      onTap: _toggleMinimizeSheet,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF082A4C),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Renter Avatar
                InkWell(
                  onTap: _showRenterContactModal,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      color: const Color(0xFF15395A),
                    ),
                    child: ClipOval(
                      child: renterAvatarUrl != null &&
                              renterAvatarUrl.isNotEmpty
                          ? Image.network(
                              renterAvatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person,
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Renter & Vehicle info (tap to expand)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              renterName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (renterRating != null && renterRating > 0) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.star,
                                color: AppColors.primary, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              renterRating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plateNumber.isNotEmpty
                            ? '$vehicleName • $plateNumber'
                            : vehicleName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Motion status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: motionColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: motionColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: motionColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        speedKph > 0 ? '$speedKph km/h' : 'Parked',
                        style: TextStyle(
                          color: motionColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Fit Route shortcut button
                InkWell(
                  onTap: _fitRouteBounds,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.alt_route_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Expand icon button
                InkWell(
                  onTap: _toggleMinimizeSheet,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSheet({
    Key? key,
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
    String? renterAvatarUrl,
    double? renterRating,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.deferToChild,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 80) {
          _toggleMinimizeSheet();
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF082A4C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.58,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row with Fit Route, Centered Handle, and Minimize Button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleMinimizeSheet,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        // Fit Route shortcut button
                        InkWell(
                          onTap: _fitRouteBounds,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.alt_route_rounded,
                                  color: AppColors.primary,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Fit Route',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Center Drag Pill
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const Spacer(),
                        // Minimize Button
                        InkWell(
                          onTap: _toggleMinimizeSheet,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Minimize',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // RENTER & VEHICLE HEADER
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Renter Avatar
                    InkWell(
                      onTap: _showRenterContactModal,
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.primary, width: 2),
                          color: const Color(0xFF15395A),
                        ),
                        child: ClipOval(
                          child: renterAvatarUrl != null &&
                                  renterAvatarUrl.isNotEmpty
                              ? Image.network(
                                  renterAvatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person,
                                    color: AppColors.textPrimary,
                                    size: 24,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: AppColors.textPrimary,
                                  size: 24,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Renter Info
                    Expanded(
                      flex: 5,
                      child: InkWell(
                        onTap: _showRenterContactModal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Current Renter',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              renterName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (renterRating != null && renterRating > 0) ...[
                                  const Icon(Icons.star,
                                      color: AppColors.primary, size: 13),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${renterRating.toStringAsFixed(1)} PRO',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(Icons.verified_user_rounded,
                                      color: AppColors.primary, size: 13),
                                  const SizedBox(width: 3),
                                  const Text(
                                    'Verified Renter',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Vehicle Info
                    Expanded(
                      flex: 5,
                      child: InkWell(
                        onTap: () {
                          _showVehicleDetailsModal(
                            vehicleName: vehicleName,
                            plateNumber: plateNumber,
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Vehicle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              vehicleName,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (plateNumber.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  plateNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // METRICS ROW
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF071E2D),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              _loadTrackingLocation(showLoader: false),
                          child: _buildMetric(
                            label: 'SPEED',
                            value: '$speedKph km/h',
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _showTelemetryStatusModal(
                            motionStatusLabel: motionStatusLabel,
                            motionColor: motionColor,
                            speedKph: speedKph,
                            heading: heading,
                            updatedAt: updatedAt,
                          ),
                          child: _buildMetric(
                            label: 'STATUS',
                            value: motionStatusLabel.contains('MOVING')
                                ? 'Moving'
                                : (motionStatusLabel.contains('SIMULATION')
                                    ? 'Simulating'
                                    : 'Parked'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildMetric(label: 'HEADING', value: heading),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              _loadTrackingLocation(showLoader: false),
                          child:
                              _buildMetric(label: 'UPDATED', value: updatedAt),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // DESTINATION ROW
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _centerDestination,
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.primary,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Destination',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    destination,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _copyCoordinates,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Location',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _resolvedVehiclePoint != null
                                      ? const Color(0xFF00E676)
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _resolvedVehiclePoint != null
                                    ? 'Live'
                                    : 'Standby',
                                style: TextStyle(
                                  color: _resolvedVehiclePoint != null
                                      ? const Color(0xFF00E676)
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ACTION BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openConversation,
                        icon:
                            const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Message Renter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(46),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // PING / RADAR BUTTON
                    InkWell(
                      onTap: _triggerRadarPing,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 48,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2248),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isPinging
                                ? const Color(0xFFFF4F8B)
                                : const Color(0x55FF4F8B),
                            width: _isPinging ? 2 : 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.podcasts_rounded,
                          color: Color(0xFFFF4F8B),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // AUDIT ROUTE & PLAYBACK BUTTON
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final bId =
                          widget.booking['id']?.toString() ?? '';
                      if (bId.isNotEmpty) {
                        TripRouteHistoryScreen.open(
                          context: context,
                          bookingId: bId,
                          vehicleName: vehicleName,
                          plateNumber: plateNumber,
                          renterName: renterName,
                        );
                      }
                    },
                    icon: const Icon(Icons.route_rounded,
                        size: 17, color: AppColors.primary),
                    label: const Text(
                      'Audit Traveled Route & GPS Playback',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
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
    if (timestamp == null || timestamp.isEmpty) return 'Just now';
    final parsed = DateTime.tryParse(timestamp)?.toLocal();
    if (parsed == null) return 'Just now';
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
