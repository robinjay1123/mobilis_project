import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import '../../../mobile_ui/theme/app_colors.dart';
import '../../../mobile_ui/widgets/optimized_network_image.dart';
import '../../../services/booking_inspection_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/tracking_service.dart';
import '../../../services/image_optimization_service.dart';

bool _bookingNeedsDriver(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == 'yes' || normalized == '1';
  }
  return false;
}

class OperatorWebScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const OperatorWebScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  State<OperatorWebScreen> createState() => _OperatorWebScreenState();
}

class _OperatorWebScreenState extends State<OperatorWebScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _sidebarExpanded = true;
  String? _focusedTrackingBookingId;

  // Stats
  int _totalUsers = 0;
  int _totalPartners = 0;
  int _totalVehicles = 0;
  int _pendingVerifications = 0;
  int _activeBookings = 0;
  int _totalBookings = 0;

  // Lists
  List<Map<String, dynamic>> _pendingApplications = [];
  List<Map<String, dynamic>> _recentBookings = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _partnerVehicles = [];
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _trackingLocations = [];
  Timer? _trackingRefreshTimer;
  Timer? _bookingFlowRefreshDebounce;
  RealtimeChannel? _bookingFlowChannel;
  Map<String, List<Map<String, dynamic>>> _messages = {};
  final Map<String, List<Map<String, dynamic>>> _conversationParticipants = {};

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  static const String _vehicleImagesBucket = 'vehicle_images';

  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _pricePerHourController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _vehicleTypeController = TextEditingController();
  final TextEditingController _vehicleNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _transmissionController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedConversationId = '';
  String _selectedStatus = 'active';
  List<XFile> _selectedImages = [];
  final Map<String, Future<Uint8List>> _selectedImageBytes = {};
  bool _isSubmittingVehicle = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadConversations();
    _setupBookingFlowListener();
    _trackingRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshTrackingLocations(),
    );
  }

  @override
  void dispose() {
    _trackingRefreshTimer?.cancel();
    _bookingFlowRefreshDebounce?.cancel();
    _bookingFlowChannel?.unsubscribe();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _priceController.dispose();
    _pricePerHourController.dispose();
    _categoryController.dispose();
    _vehicleTypeController.dispose();
    _vehicleNameController.dispose();
    _descriptionController.dispose();
    _colorController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _transmissionController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _setupBookingFlowListener() {
    final channelName =
        'operator-booking-flow-${_supabase.auth.currentUser?.id ?? 'guest'}';
    _bookingFlowChannel = _supabase.realtime.channel(channelName);
    void refreshFlow(PostgresChangePayload payload) {
      if (!mounted) return;
      _bookingFlowRefreshDebounce?.cancel();
      _bookingFlowRefreshDebounce = Timer(
        const Duration(milliseconds: 350),
        () {
          _loadDashboardData();
          _loadConversations();
        },
      );
    }

    _bookingFlowChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: refreshFlow,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_job_assignments',
          callback: refreshFlow,
        )
        .subscribe();
  }

  Future<void> _getCurrentVehicleLocation({
    required void Function(String location, String latitude, String longitude)
    onLocationFound,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services in your settings'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is permanently denied. Please enable it in app settings.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final location = placemarks.isNotEmpty
          ? [
              placemarks.first.street,
              placemarks.first.subLocality,
              placemarks.first.locality,
              placemarks.first.administrativeArea,
              placemarks.first.country,
            ].where((s) => s != null && s.isNotEmpty).toList().join(', ')
          : 'Current Location';

      onLocationFound(
        location,
        position.latitude.toString(),
        position.longitude.toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadStats(),
        _loadNotifications(),
        _loadVehicles(),
        _loadRecentBookings(),
        _loadTrackingLocations(),
      ]);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadNotifications() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      _notifications = [];
      return;
    }

    try {
      _notifications = await NotificationService().getNotifications(
        currentUserId,
      );
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      _notifications = [];
    }
  }

  Future<void> _loadTrackingLocations() async {
    _trackingLocations = await TrackingService().getActiveTrackingLocations();
  }

  Future<void> _refreshTrackingLocations() async {
    final locations = await TrackingService().getActiveTrackingLocations();
    if (!mounted) return;
    setState(() => _trackingLocations = locations);
  }

  Future<void> _confirmOperatorSuccessfulTrip(
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    try {
      await BookingService().confirmSuccessfulTrip(
        bookingId: bookingId,
        actorRole: 'operator',
      );
      await _loadRecentBookings();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operator successful trip confirmation saved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isCompanyOwnedBooking(Map<String, dynamic> booking) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final ownerId = vehicle?['owner_id']?.toString();
    if (currentUserId == null || ownerId == null || ownerId.isEmpty) {
      return false;
    }
    return ownerId == currentUserId;
  }

  bool _canTrackBooking(Map<String, dynamic> booking) {
    final status = (booking['status'] as String? ?? '').toLowerCase();
    return _isCompanyOwnedBooking(booking) &&
        (status == 'active' || status == 'approved' || status == 'confirmed');
  }

  Future<void> _openTrackingForBooking(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty || !_canTrackBooking(booking)) return;

    setState(() {
      _selectedIndex = 3;
      _focusedTrackingBookingId = bookingId;
      _isLoading = true;
    });

    try {
      await _loadTrackingLocations();
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _visibleTrackingLocations() {
    if (_focusedTrackingBookingId == null ||
        _focusedTrackingBookingId!.isEmpty) {
      return _trackingLocations
          .where((location) => _isCompanyOwnedTrackingLocation(location))
          .toList();
    }

    final focused = _trackingLocations.where((location) {
      final booking = location['bookings'] as Map<String, dynamic>?;
      return booking?['id']?.toString() == _focusedTrackingBookingId;
    }).toList();

    if (focused.isNotEmpty) return focused;

    return _trackingLocations
        .where((location) => _isCompanyOwnedTrackingLocation(location))
        .toList();
  }

  bool _isCompanyOwnedTrackingLocation(Map<String, dynamic> location) {
    final booking = location['bookings'] as Map<String, dynamic>?;
    if (booking == null) return false;
    return _isCompanyOwnedBooking(booking);
  }

  Future<void> _loadStats() async {
    try {
      final usersResponse = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'renter');
      _totalUsers = (usersResponse as List).length;

      final partnersResponse = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'partner');
      _totalPartners = (partnersResponse as List).length;

      final vehiclesResponse = await _supabase
          .from('vehicles')
          .select('id')
          .eq('status', 'active');
      _totalVehicles = (vehiclesResponse as List).length;

      final pendingResponse = await _supabase
          .from('vehicle_applications')
          .select('id')
          .eq('status', 'pending');
      _pendingVerifications = (pendingResponse as List).length;

      final activeBookingsResponse = await _supabase
          .from('bookings')
          .select('id')
          .inFilter('status', ['active', 'approved', 'confirmed']);
      _activeBookings = (activeBookingsResponse as List).length;

      final totalBookingsResponse = await _supabase
          .from('bookings')
          .select('id');
      _totalBookings = (totalBookingsResponse as List).length;
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadPendingApplications() async {
    try {
      final response = await _supabase
          .from('vehicle_applications')
          .select('''
              *,
              partners:partner_id (
                user_id,
                users:user_id (full_name, email)
              )
            ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);
      _pendingApplications = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading pending applications: $e');
      _pendingApplications = [];
    }
  }

  Future<void> _loadRecentBookings() async {
    try {
      debugPrint(
        '[Bookings] Loading recent bookings (driver embed via drivers -> users)',
      );
      final response = await _supabase
          .from('bookings')
          .select('''
              id,
              vehicle_id,
              renter_id,
              driver_id,
              status,
              start_at,
              end_at,
              start_date,
              end_date,
              total_price,
              total_cost,
              rental_subtotal,
              delivery_distance_km,
              delivery_rate_per_km,
              delivery_fee,
              late_return_days,
              late_return_fee,
              emergency_contact_name,
              emergency_contact_phone,
              emergency_contact_relationship,
              renter_signature_text,
              renter_signature_url,
              renter_valid_id_url,
              renter_selfie_url,
              co_traveler_name,
              co_traveler_phone,
              co_traveler_license,
              co_traveler_signature_text,
              co_traveler_signature_url,
              co_traveler_valid_id_url,
              co_traveler_selfie_url,
              with_driver,
              pickup_location,
              dropoff_location,
              picked_up_at,
              returned_at,
              completed_at,
              operator_trip_confirmed_at,
              partner_trip_confirmed_at,
              driver_trip_confirmed_at,
              renter_trip_confirmed_at,
              created_at,
              vehicles:vehicle_id (
                id,
                brand,
                model,
                year,
                owner_id,
                owner_role,
                operator_id,
                vehicle_name,
                price_per_day,
                vehicle_images(id, image_url, display_order)
              ),
              renter:users!bookings_renter_id_fkey (
                id,
                full_name,
                email
              ),
              driver:drivers!bookings_driver_id_fkey (
                user_id,
                user:users!drivers_user_id_fkey (
                  id,
                  full_name,
                  email
                )
              ),
              job_assignments:driver_job_assignments!driver_job_assignments_booking_id_fkey (
                id,
                driver_id,
                status,
                offered_at,
                replied_at,
                created_at,
                updated_at
              )
            ''')
          .order('created_at', ascending: false)
          .limit(100);

      _recentBookings = List<Map<String, dynamic>>.from(response).map((
        booking,
      ) {
        final normalizedBooking = Map<String, dynamic>.from(booking);
        final vehicle = booking['vehicles'];
        if (vehicle is Map<String, dynamic>) {
          final normalizedVehicle = Map<String, dynamic>.from(vehicle);
          normalizedVehicle['image_url'] = _primaryVehicleImageUrl(
            normalizedVehicle,
          );
          normalizedBooking['vehicles'] = normalizedVehicle;
        }
        return normalizedBooking;
      }).toList();
    } catch (e, st) {
      debugPrint(
        '[Bookings] Error loading recent bookings (driver embed via drivers -> users): $e',
      );
      debugPrint('[Bookings] Stack trace: $st');
      _recentBookings = [];
    }
  }

  Future<void> _loadVehicles() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      var vehicleQuery = _supabase
          .from('vehicles')
          .select('*, vehicle_images(id, image_url, display_order)');

      if (currentUserId != null) {
        vehicleQuery = vehicleQuery.eq('owner_id', currentUserId);
      }

      final ownVehicles = await vehicleQuery.order(
        'created_at',
        ascending: false,
      );
      debugPrint('vehicles loaded: ${(ownVehicles as List).length}');

      final normalizedOwnVehicles = (ownVehicles as List)
          .whereType<Map<String, dynamic>>()
          .map((vehicle) {
            final merged = Map<String, dynamic>.from(vehicle);
            merged['_source'] = 'company';
            return merged;
          })
          .toList();

      List partnerVehiclesResp = [];
      try {
        partnerVehiclesResp =
            await _supabase
                    .from('partner_vehicles')
                    .select(
                      '*, partners:partner_id(id,user_id,business_name,users:user_id(full_name,email))',
                    )
                    .order('created_at', ascending: false)
                as List;
      } catch (e) {
        debugPrint('Partner relation select failed, using fallback: $e');
        try {
          partnerVehiclesResp =
              await _supabase
                      .from('partner_vehicles')
                      .select('*')
                      .order('created_at', ascending: false)
                  as List;
        } catch (fallbackError) {
          debugPrint('Error loading partner_vehicles: $fallbackError');
          partnerVehiclesResp = [];
        }
      }

      final partnerVehicleIds = partnerVehiclesResp
          .whereType<Map<String, dynamic>>()
          .map((pv) => pv['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final partnerImagesByVehicleId = <String, List<Map<String, dynamic>>>{};
      if (partnerVehicleIds.isNotEmpty) {
        try {
          final partnerImages = await _supabase
              .from('vehicle_images')
              .select('partner_vehicle_id,image_url,display_order')
              .inFilter('partner_vehicle_id', partnerVehicleIds);
          for (final image in List<Map<String, dynamic>>.from(partnerImages)) {
            final partnerVehicleId = image['partner_vehicle_id']?.toString();
            if (partnerVehicleId == null || partnerVehicleId.isEmpty) continue;
            partnerImagesByVehicleId
                .putIfAbsent(partnerVehicleId, () => [])
                .add({
                  'image_url': image['image_url'],
                  'display_order': image['display_order'],
                });
          }
        } catch (e) {
          debugPrint('Error loading partner vehicle images: $e');
        }
      }

      final normalizedPartnerVehicles = partnerVehiclesResp
          .whereType<Map<String, dynamic>>()
          .map((pv) {
            final partner = pv['partners'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(pv['partners'])
                : <String, dynamic>{};
            final partnerUser = partner['users'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(partner['users'])
                : <String, dynamic>{};
            final partnerName =
                partner['business_name']?.toString().trim().isNotEmpty == true
                ? partner['business_name'].toString()
                : partnerUser['full_name']?.toString().trim().isNotEmpty == true
                ? partnerUser['full_name'].toString()
                : 'Mobilis Partner';
            final partnerVehicleId = pv['id']?.toString() ?? '';
            final images = partnerImagesByVehicleId[partnerVehicleId] ?? [];
            final merged = Map<String, dynamic>.from(pv)
              ..['_source'] = 'partner'
              ..['source'] = 'partner'
              ..['_partner_vehicle_id'] = partnerVehicleId
              ..['partner_vehicle_id'] = partnerVehicleId
              ..['is_partner_vehicle'] = true
              ..['partner_name'] = partnerName
              ..['owner_name'] = partnerName
              ..['vehicle_images'] = images
              ..['image_url'] = images.isNotEmpty
                  ? images.first['image_url']
                  : pv['image_url']
              ..['vehicle_name'] =
                  pv['vehicle_name'] ??
                  '${pv['brand'] ?? ''} ${pv['model'] ?? ''}'.trim()
              ..['category'] =
                  pv['category'] ?? pv['vehicle_type'] ?? 'Partner Vehicle'
              ..['vehicle_type'] =
                  pv['vehicle_type'] ?? pv['category'] ?? 'Partner Vehicle'
              ..['is_posted'] = pv['is_posted'] ?? pv['is_available'] ?? false;
            return merged;
          })
          .toList();

      setState(() {
        _vehicles = List<Map<String, dynamic>>.from(normalizedOwnVehicles);
        _partnerVehicles = List<Map<String, dynamic>>.from(
          normalizedPartnerVehicles,
        );
      });
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      _vehicles = [];
      _partnerVehicles = [];
    }
  }

  String _primaryVehicleImageUrl(Map<String, dynamic>? vehicle) {
    if (vehicle == null || vehicle.isEmpty) return '';

    final directImageUrl = vehicle['image_url']?.toString().trim() ?? '';
    if (directImageUrl.isNotEmpty) return directImageUrl;

    final images = vehicle['vehicle_images'];
    if (images is! List) return '';

    for (final image in images) {
      if (image is! Map) continue;
      final imageMap = Map<String, dynamic>.from(image);
      final imageUrl = imageMap['image_url']?.toString().trim() ?? '';
      if (imageUrl.isNotEmpty) return imageUrl;
    }

    return '';
  }

  Future<void> _handleApplicationAction(
    String applicationId,
    String action,
  ) async {
    try {
      await _supabase
          .from('vehicle_applications')
          .update({'status': action})
          .eq('id', applicationId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Application ${action == 'approved' ? 'approved' : 'rejected'}',
          ),
          backgroundColor: action == 'approved' ? Colors.green : Colors.red,
        ),
      );
      _loadDashboardData();
      _loadConversations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/auth-processing',
        (route) => false,
        arguments: {'mode': 'logout'},
      );
    }
  }

  /// ✅ Approve booking with optional driver assignment
  Future<void> _approveBooking(
    Map<String, dynamic> booking, {
    String? driverId,
  }) async {
    try {
      final bookingId = booking['id']?.toString() ?? '';
      if (bookingId.isEmpty) {
        throw Exception('Invalid booking id');
      }

      final operatorId = _supabase.auth.currentUser?.id;
      if (operatorId == null || operatorId.isEmpty) {
        throw Exception('Operator is not authenticated');
      }

      final bookingService = BookingService();

      if (driverId != null) {
        await _supabase
            .from('bookings')
            .update({
              'operator_id': operatorId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', bookingId);
        await bookingService.assignDriver(bookingId, driverId, 0.0);
      } else {
        await bookingService.finalizeBooking(
          bookingId: bookingId,
          operatorId: operatorId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              driverId != null
                  ? 'Driver job offer sent. Waiting for a response.'
                  : 'Booking finalized and conversation created.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadDashboardData();
      _loadConversations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _resolveDriverUserId(dynamic driverId) async {
    final value = driverId?.toString().trim();
    if (value == null || value.isEmpty) return null;

    final byUserId = await _supabase
        .from('drivers')
        .select('user_id')
        .eq('user_id', value)
        .maybeSingle();
    final existingUserId = byUserId?['user_id']?.toString();
    if (existingUserId != null && existingUserId.isNotEmpty) {
      return existingUserId;
    }

    final byProfileId = await _supabase
        .from('drivers')
        .select('user_id')
        .eq('id', value)
        .maybeSingle();
    final profileUserId = byProfileId?['user_id']?.toString();
    return profileUserId == null || profileUserId.isEmpty
        ? null
        : profileUserId;
  }

  Map<String, dynamic>? _latestDriverAssignment(Map<String, dynamic> booking) {
    final rawAssignments = booking['job_assignments'];
    if (rawAssignments is! List || rawAssignments.isEmpty) return null;
    final assignments = rawAssignments
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (assignments.isEmpty) return null;
    assignments.sort((a, b) {
      final aDate = DateTime.tryParse(
        (a['created_at'] ?? a['offered_at'])?.toString() ?? '',
      );
      final bDate = DateTime.tryParse(
        (b['created_at'] ?? b['offered_at'])?.toString() ?? '',
      );
      return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
    });
    return assignments.first;
  }

  Future<void> _createBookingGroupChat(
    Map<String, dynamic> booking,
    String? driverId,
  ) async {
    try {
      final bookingId = booking['id'] as String;
      final operatorId = _supabase.auth.currentUser?.id;
      final vehicle = (booking['vehicles'] as Map<String, dynamic>?) ?? {};
      final ownerId = vehicle['owner_id'] as String?;
      final renterId = booking['renter_id'] as String?;

      if (operatorId == null || renterId == null) {
        return;
      }

      final participantIds = <String>{renterId, operatorId};

      final driverIdForChat =
          driverId?.toString() ?? booking['driver_id']?.toString();
      if (driverIdForChat != null && driverIdForChat.isNotEmpty) {
        final driverUserId = await _resolveDriverUserId(driverIdForChat);
        if (driverUserId != null && driverUserId.isNotEmpty) {
          participantIds.add(driverUserId);
        }
      }

      if (ownerId != null) {
        participantIds.add(ownerId);
      }

      await ChatService().createGroupConversation(
        bookingId: bookingId,
        participantIds: participantIds.toList(),
      );

      await _supabase
          .from('bookings')
          .update({
            'conversation_created': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      debugPrint('Group chat created for booking: $bookingId');
    } catch (e) {
      debugPrint('Error creating group chat: $e');
    }
  }

  /// ❌ Reject booking with reason
  Future<void> _rejectBooking(String bookingId, String reason) async {
    try {
      final bookingService = BookingService();
      await bookingService.rejectBooking(bookingId, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Booking rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 🚗 Assign driver to booking
  Future<void> _assignDriver(String bookingId, String driverId) async {
    try {
      final bookingService = BookingService();
      await bookingService.assignDriver(bookingId, driverId, 0.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Driver assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return month >= 1 && month <= 12 ? months[month - 1] : '';
  }

  String _formatBookingDateTime(DateTime? value) {
    if (value == null) return 'N/A';
    final localValue = value.toLocal();
    final hour12 = localValue.hour % 12 == 0 ? 12 : localValue.hour % 12;
    final minute = localValue.minute.toString().padLeft(2, '0');
    final suffix = localValue.hour >= 12 ? 'PM' : 'AM';
    return '${localValue.day.toString().padLeft(2, '0')} ${_getMonthName(localValue.month)} ${localValue.year}, $hour12:$minute $suffix';
  }

  int _inclusiveRentalDays(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) return 0;

    final localStartDate = startDate.toLocal();
    final localEndDate = endDate.toLocal();
    final startDay = DateTime(
      localStartDate.year,
      localStartDate.month,
      localStartDate.day,
    );
    final endDay = DateTime(
      localEndDate.year,
      localEndDate.month,
      localEndDate.day,
    );
    final calendarDays = endDay.difference(startDay).inDays + 1;

    return calendarDays < 1 ? 1 : calendarDays;
  }

  String _vehicleTitle(Map<String, dynamic> vehicle) {
    final vehicleName = vehicle['vehicle_name']?.toString().trim() ?? '';
    if (vehicleName.isNotEmpty) return vehicleName;

    final brand = vehicle['brand']?.toString().trim() ?? '';
    final model = vehicle['model']?.toString().trim() ?? '';
    final year = vehicle['year']?.toString().trim() ?? '';
    final name = [brand, model].where((part) => part.isNotEmpty).join(' ');

    if (name.isEmpty) return 'Unknown Vehicle';
    return year.isEmpty ? name : '$name ($year)';
  }

  void _showApproveDialog(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedDriverId;
        final withDriver = _bookingNeedsDriver(booking['with_driver']);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(withDriver ? 'Select Driver' : 'Finalize Booking'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    withDriver
                        ? 'Choose a driver. The booking will remain pending until the driver accepts and you finalize it.'
                        : 'Finalize this booking and create its conversation?',
                  ),
                  if (withDriver) ...[
                    const SizedBox(height: 16),
                    const Text('Select Driver:'),
                    const SizedBox(height: 8),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: BookingService().getAvailableVerifiedDrivers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          );
                        }

                        final drivers = snapshot.data ?? [];
                        if (drivers.isEmpty) {
                          return const Text('No available drivers found');
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedDriverId,
                          hint: const Text('Choose a driver'),
                          isExpanded: true,
                          items: drivers.map((driverMap) {
                            final driverId = driverMap['id'].toString();
                            final driverUser =
                                driverMap['users'] as Map<String, dynamic>?;
                            final driverName =
                                driverUser?['full_name'] as String? ??
                                'Unknown';
                            return DropdownMenuItem(
                              value: driverId,
                              child: Text(driverName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedDriverId = value);
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (withDriver && selectedDriverId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select an available driver'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    _approveBooking(booking, driverId: selectedDriverId);
                    Navigator.pop(context);
                  },
                  child: Text(withDriver ? 'Send Job Offer' : 'Finalize'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRejectDialog(String bookingId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _rejectBooking(bookingId, reasonController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1200;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F5F5),
      body: Row(
        children: [
          _buildSidebar(isDark, isCompact),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isDark),
                Expanded(child: _buildContent(isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDark, bool isCompact) {
    final sidebarWidth = _sidebarExpanded ? 260.0 : 70.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 70,
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarExpanded ? 20 : 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    'assets/icon/logo-black.png',
                    fit: BoxFit.contain,
                  ),
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PSDC Operator',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          'Management Portal',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildNavItem(0, Icons.home, 'Home', isDark),
                _buildNavItem(1, Icons.book, 'Bookings', isDark),
                _buildNavItem(2, Icons.message, 'Messages', isDark),
                _buildNavItem(
                  3,
                  Icons.notifications,
                  'Notifications',
                  isDark,
                  badge:
                      _notifications.where((n) => n['is_read'] == false).isEmpty
                      ? null
                      : _notifications
                            .where((n) => n['is_read'] == false)
                            .length,
                ),
                _buildNavItem(4, Icons.directions_car, 'Vehicles', isDark),
                _buildNavItem(
                  6,
                  Icons.location_on,
                  'Live Tracking',
                  isDark,
                  badge: _trackingLocations.isEmpty
                      ? null
                      : _trackingLocations.length,
                ),
                const SizedBox(height: 20),
                if (_sidebarExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'SETTINGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey : Colors.grey.shade500,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                _buildNavItem(5, Icons.settings, 'Settings', isDark),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: _sidebarExpanded
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.center,
                children: [
                  Icon(
                    _sidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    bool isDark, {
    int? badge,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: _sidebarExpanded ? 16 : 0),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: _sidebarExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.grey : Colors.grey.shade600),
                size: 22,
              ),
              if (_sidebarExpanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white : Colors.black),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _getPageTitle(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadDashboardData,
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 20),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _handleLogout();
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.person,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Operator',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 10),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Bookings';
      case 2:
        return 'Messages';
      case 3:
        return 'Notifications';
      case 4:
        return 'Vehicles';
      case 5:
        return 'Settings';
      case 6:
        return 'Live Tracking';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent(isDark);
      case 1:
        return _buildBookingsContent(isDark);
      case 2:
        return _buildMessagesContent(isDark);
      case 3:
        return _buildNotificationsContent(isDark);
      case 4:
        return _buildVehiclesContent(isDark);
      case 5:
        return _buildSettingsContent(isDark);
      case 6:
        return _buildTrackingContent(isDark);
      default:
        return _buildDashboardContent(isDark);
    }
  }

  Widget _buildDashboardContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 2,
            children: [
              _buildStatCard(
                'Total Users',
                _totalUsers.toString(),
                Icons.person,
                Colors.blue,
                isDark,
              ),
              _buildStatCard(
                'Partners',
                _totalPartners.toString(),
                Icons.business,
                Colors.green,
                isDark,
              ),
              _buildStatCard(
                'Active Vehicles',
                _totalVehicles.toString(),
                Icons.directions_car,
                Colors.orange,
                isDark,
              ),
              _buildStatCard(
                'Pending Reviews',
                _pendingVerifications.toString(),
                Icons.pending_actions,
                Colors.red,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildCard(
                  'Recent Bookings',
                  _buildBookingsTable(isDark),
                  isDark,
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, Widget content, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildTrackingContent(bool isDark) {
    final visibleLocations = _visibleTrackingLocations();
    final mapUrl = _buildMapboxStaticUrl(visibleLocations);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'Live Tracking (${visibleLocations.length})',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await _loadTrackingLocations();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 12),
                if (_focusedTrackingBookingId != null) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _focusedTrackingBookingId = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Show all company trips'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      side: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    _focusedTrackingBookingId == null
                        ? 'Tracking comes from the driver app while an assigned company trip is active.'
                        : 'Showing the focused company booking selected from Bookings.',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 360,
                width: double.infinity,
                color: isDark ? AppColors.darkBg : Colors.grey.shade100,
                child: mapUrl == null
                    ? Center(
                        child: Text(
                          visibleLocations.isEmpty
                              ? 'No active company tracking locations yet'
                              : 'Add MAPBOX_ACCESS_TOKEN with --dart-define to show the map',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                      )
                    : OptimizedNetworkImage(
                        imageUrl: mapUrl,
                        fit: BoxFit.cover,
                        isThumbnail: false,
                        errorWidget: Center(
                          child: Text(
                            'Mapbox map failed to load',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (visibleLocations.isEmpty)
              Text(
                _focusedTrackingBookingId == null
                    ? 'Ask the driver to start tracking from the active trip card.'
                    : 'No live tracking has started yet for this booking.',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              )
            else
              ...visibleLocations.map(
                (location) => _buildTrackingRow(location, isDark),
              ),
          ],
        ),
        isDark,
      ),
    );
  }

  Widget _buildTrackingRow(Map<String, dynamic> location, bool isDark) {
    final booking = location['bookings'] as Map<String, dynamic>?;
    final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
    final driver = booking?['drivers'] as Map<String, dynamic>?;
    final driverUser = driver?['users'] as Map<String, dynamic>?;
    final renter = booking?['renter'] as Map<String, dynamic>?;
    final bookingId = booking?['id']?.toString() ?? 'N/A';
    final pickup = booking?['pickup_location']?.toString().trim() ?? '';
    final dropoff = booking?['dropoff_location']?.toString().trim() ?? '';
    final vehicleName = [
      vehicle?['brand'],
      vehicle?['model'],
      vehicle?['plate_number'] == null ? null : '(${vehicle?['plate_number']})',
    ].where((part) => part != null && part.toString().isNotEmpty).join(' ');
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicleName.isEmpty ? 'Tracked booking' : vehicleName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Booking: $bookingId | Driver: ${driverUser?['full_name'] ?? 'N/A'} | Renter: ${renter?['full_name'] ?? 'N/A'}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                if (pickup.isNotEmpty || dropoff.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Pickup: ${pickup.isEmpty ? 'N/A' : pickup} | Destination: ${dropoff.isEmpty ? 'N/A' : dropoff}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Lat/Lng: ${lat?.toStringAsFixed(5) ?? 'N/A'}, ${lng?.toStringAsFixed(5) ?? 'N/A'} | Updated: ${location['recorded_at'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _buildMapboxStaticUrl(List<Map<String, dynamic>> locations) {
    const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    if (token.isEmpty || locations.isEmpty) return null;

    final valid = locations
        .where((location) {
          return location['latitude'] is num && location['longitude'] is num;
        })
        .take(10)
        .toList();
    if (valid.isEmpty) return null;

    final overlays = valid
        .map((location) {
          final lat = (location['latitude'] as num).toDouble();
          final lng = (location['longitude'] as num).toDouble();
          return 'pin-s-car+facc15($lng,$lat)';
        })
        .join(',');

    final firstLat = (valid.first['latitude'] as num).toDouble();
    final firstLng = (valid.first['longitude'] as num).toDouble();
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/$overlays/$firstLng,$firstLat,12/1100x360?access_token=$token';
  }

  Widget _buildBookingsTable(bool isDark) {
    if (_recentBookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No bookings found',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return DataTable(
      columns: [
        DataColumn(
          label: Text(
            'Vehicle',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        DataColumn(
          label: Text(
            'Renter',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        DataColumn(
          label: Text(
            'Status',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
      ],
      rows: _recentBookings.take(8).map((booking) {
        final vehicle = booking['vehicles'] as Map<String, dynamic>?;
        final user = booking['renter'] as Map<String, dynamic>?;
        final status = booking['status'] as String? ?? 'pending';

        return DataRow(
          cells: [
            DataCell(
              Text(
                vehicle != null
                    ? '${vehicle['brand']} ${vehicle['model']}'
                    : 'Unknown',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            DataCell(
              Text(
                user?['full_name'] ?? 'Unknown',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            DataCell(_buildStatusBadge(status)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'approved':
        color = AppColors.primary;
        break;
      case 'active':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPendingList(bool isDark) {
    if (_pendingApplications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                size: 48,
                color: Colors.green.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No pending applications',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _pendingApplications
          .take(5)
          .map((app) => _buildApplicationTile(app, isDark))
          .toList(),
    );
  }

  Widget _buildApplicationTile(Map<String, dynamic> application, bool isDark) {
    final partner = application['partners'] as Map<String, dynamic>?;
    final user = partner?['users'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${application['brand'] ?? ''} ${application['model'] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  user?['full_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _handleApplicationAction(
              application['id'].toString(),
              'approved',
            ),
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Approve',
          ),
          IconButton(
            onPressed: () => _handleApplicationAction(
              application['id'].toString(),
              'rejected',
            ),
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Reject',
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        'Vehicle Applications (${_pendingApplications.length} pending)',
        _pendingApplications.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(60),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.green.withOpacity(0.5),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'All applications reviewed!',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: _pendingApplications
                    .map((app) => _buildApplicationTile(app, isDark))
                    .toList(),
              ),
        isDark,
      ),
    );
  }

  Widget _buildBookingsContent(bool isDark) {
    final pendingBookings = _recentBookings
        .where((b) => (b['status'] as String? ?? 'pending') == 'pending')
        .toList();
    final activeBookings = _recentBookings.where((b) {
      final status = (b['status'] as String? ?? 'pending').toLowerCase();
      return status == 'active' ||
          status == 'approved' ||
          status == 'confirmed';
    }).toList();
    final completedBookings = _recentBookings
        .where((b) => (b['status'] as String? ?? 'pending') == 'completed')
        .toList();
    final cancelledBookings = _recentBookings.where((b) {
      final status = (b['status'] as String? ?? 'pending').toLowerCase();
      return status == 'cancelled' ||
          status == 'canceled' ||
          status == 'rejected';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bookings Management (${_recentBookings.length})',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 30),
          if (_recentBookings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Text(
                  'No bookings yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pending section - always show
                _buildBookingSection(
                  'Pending Bookings',
                  pendingBookings,
                  isDark,
                  Colors.orange,
                  showEmpty: true,
                ),
                const SizedBox(height: 30),
                // Active section - always show
                _buildBookingSection(
                  'Ongoing Bookings',
                  activeBookings,
                  isDark,
                  Colors.green,
                  showEmpty: true,
                ),
                const SizedBox(height: 30),
                // Completed section - always show
                _buildBookingSection(
                  'Completed Bookings',
                  completedBookings,
                  isDark,
                  Colors.blue,
                  showEmpty: true,
                ),
                const SizedBox(height: 30),
                // Cancelled section - always show
                _buildBookingSection(
                  'Cancelled Bookings',
                  cancelledBookings,
                  isDark,
                  Colors.red,
                  showEmpty: true,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBookingSection(
    String title,
    List<Map<String, dynamic>> bookings,
    bool isDark,
    Color statusColor, {
    bool showEmpty = false,
  }) {
    final isEmpty = bookings.isEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$title (${bookings.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isEmpty && showEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No ${title.toLowerCase()} at this time',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else if (!isEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final vehicle = booking['vehicles'] as Map<String, dynamic>?;
                final renter = booking['renter'] as Map<String, dynamic>?;
                final driver = booking['driver'] as Map<String, dynamic>?;
                final driverUser = driver?['user'] as Map<String, dynamic>?;
                final withDriver = _bookingNeedsDriver(booking['with_driver']);
                final latestAssignment = _latestDriverAssignment(booking);
                final assignmentStatus = latestAssignment?['status']
                    ?.toString()
                    .trim()
                    .toLowerCase();
                final waitingForDriver =
                    assignmentStatus == 'pending_offer' ||
                    assignmentStatus == 'assigned';
                final driverAccepted = assignmentStatus == 'accepted';
                final driverDeclined = assignmentStatus == 'rejected';
                final status = booking['status'] as String? ?? 'pending';
                final statusLower = status.toLowerCase();
                final canTrack = _canTrackBooking(booking);
                final completionState = BookingService().getTripCompletionState(
                  booking,
                );
                final operatorConfirmed =
                    completionState['operatorConfirmed'] == true;
                final total =
                    (booking['total_price'] as num?)?.toDouble() ??
                    (booking['total_cost'] as num?)?.toDouble() ??
                    0.0;

                // Parse dates
                final startAtStr =
                    (booking['start_at'] ?? booking['start_date']) as String? ??
                    '';
                final endAtStr =
                    (booking['end_at'] ?? booking['end_date']) as String? ?? '';
                final startDate = DateTime.tryParse(startAtStr);
                final endDate = DateTime.tryParse(endAtStr);
                final pickedUpAt = DateTime.tryParse(
                  booking['picked_up_at']?.toString() ?? '',
                );
                final returnedAt = DateTime.tryParse(
                  booking['returned_at']?.toString() ?? '',
                );
                final days = _inclusiveRentalDays(startDate, endDate);

                final localStartDate = startDate?.toLocal();
                final localEndDate = endDate?.toLocal();
                final dateRange = localStartDate != null && localEndDate != null
                    ? '${localStartDate.day.toString().padLeft(2, '0')} ${_getMonthName(localStartDate.month)} - ${localEndDate.day.toString().padLeft(2, '0')} ${_getMonthName(localEndDate.month)}'
                    : 'N/A';
                final startSchedule = _formatBookingDateTime(startDate);
                final endSchedule = _formatBookingDateTime(endDate);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with vehicle and renter
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vehicle thumbnail
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: isDark
                                  ? Colors.black38
                                  : Colors.grey.shade200,
                            ),
                            child: vehicle?['image_url'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: OptimizedNetworkImage(
                                      imageUrl: vehicle!['image_url'],
                                      fit: BoxFit.cover,
                                      errorWidget: Center(
                                        child: Icon(
                                          Icons.directions_car,
                                          color: isDark
                                              ? Colors.grey[600]
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.directions_car,
                                      color: isDark
                                          ? Colors.grey[600]
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          // Vehicle and renter info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Vehicle name + year
                                Text(
                                  vehicle != null
                                      ? _vehicleTitle(vehicle)
                                      : 'Unknown Vehicle',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Renter name
                                Text(
                                  'Renter: ${renter?['full_name'] ?? 'Unknown'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Driver chip if applicable
                                if (withDriver && driver != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Driver: ${driverUser?['full_name'] ?? 'TBA'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black38 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Schedule',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Start: $startSchedule',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Return: $endSchedule',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Details row: dates, days, total, status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Date range
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dates',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateRange,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          // Days
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Days',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$days',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Total
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '₱${total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (pickedUpAt != null || returnedAt != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (pickedUpAt != null)
                              _buildBookingEventChip(
                                Icons.key,
                                'Picked up: '
                                '${pickedUpAt.day.toString().padLeft(2, '0')} '
                                '${_getMonthName(pickedUpAt.month)}',
                                isDark,
                              ),
                            if (returnedAt != null)
                              _buildBookingEventChip(
                                Icons.assignment_turned_in,
                                'Returned: '
                                '${returnedAt.day.toString().padLeft(2, '0')} '
                                '${_getMonthName(returnedAt.month)}',
                                isDark,
                              ),
                          ],
                        ),
                      ],
                      if (statusLower == 'pending') ...[
                        const SizedBox(height: 12),
                        _buildBookingPaymentDetails(booking, isDark),
                        if (withDriver && assignmentStatus != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: driverAccepted
                                  ? Colors.green.withOpacity(0.12)
                                  : driverDeclined
                                  ? Colors.red.withOpacity(0.12)
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: driverAccepted
                                    ? Colors.green
                                    : driverDeclined
                                    ? Colors.red
                                    : AppColors.primary,
                              ),
                            ),
                            child: Text(
                              driverAccepted
                                  ? 'Driver accepted. Finalize the booking to create the conversation.'
                                  : driverDeclined
                                  ? 'Driver declined. Select another available driver.'
                                  : 'Waiting for the selected driver to accept or decline.',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      // Status and actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildStatusBadge(status),
                          Flexible(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (statusLower == 'pending' &&
                                    (!withDriver || driverAccepted))
                                  ElevatedButton.icon(
                                    onPressed: () => _approveBooking(booking),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Finalize'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if (statusLower == 'pending' &&
                                    withDriver &&
                                    !driverAccepted &&
                                    !waitingForDriver)
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _showApproveDialog(booking),
                                    icon: const Icon(
                                      Icons.person_search,
                                      size: 16,
                                    ),
                                    label: Text(
                                      driverDeclined
                                          ? 'Select Another Driver'
                                          : 'Select Driver',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if (statusLower == 'pending' &&
                                    withDriver &&
                                    waitingForDriver)
                                  OutlinedButton.icon(
                                    onPressed: null,
                                    icon: const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    label: const Text('Waiting for Driver'),
                                  ),
                                if (statusLower == 'pending')
                                  OutlinedButton.icon(
                                    onPressed: () => _showRejectDialog(
                                      booking['id'].toString(),
                                    ),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      foregroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if (canTrack)
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _openTrackingForBooking(booking),
                                    icon: const Icon(Icons.explore_outlined),
                                    label: const Text('Track'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _showBookingSafetyReviewDialog(booking),
                                  icon: const Icon(
                                    Icons.verified_user_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Review Docs'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                                if (statusLower == 'confirmed' ||
                                    statusLower == 'approved' ||
                                    statusLower == 'active')
                                  OutlinedButton.icon(
                                    onPressed: () => _showInspectionDialog(
                                      booking,
                                      inspectionType: 'before',
                                    ),
                                    icon: const Icon(
                                      Icons.fact_check_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Before Check'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(
                                        color: Colors.blue,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if (statusLower == 'active' ||
                                    statusLower == 'completed')
                                  OutlinedButton.icon(
                                    onPressed: () => _showInspectionDialog(
                                      booking,
                                      inspectionType: 'after',
                                    ),
                                    icon: const Icon(
                                      Icons.assignment_turned_in_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('After Check'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: const BorderSide(
                                        color: Colors.green,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if ((statusLower == 'confirmed' ||
                                        statusLower == 'approved' ||
                                        statusLower == 'active') &&
                                    !canTrack)
                                  Text(
                                    _isCompanyOwnedBooking(booking)
                                        ? 'Waiting for live location'
                                        : 'Partner monitors this trip',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                if (canTrack)
                                  Text(
                                    'Driver updates this trip',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                if (statusLower == 'completed' &&
                                    !operatorConfirmed)
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _confirmOperatorSuccessfulTrip(booking),
                                    icon: const Icon(Icons.task_alt, size: 16),
                                    label: const Text('Successful Trip'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if (statusLower == 'completed' &&
                                    operatorConfirmed)
                                  Text(
                                    'Successful trip confirmed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBookingPaymentDetails(
    Map<String, dynamic> booking,
    bool isDark,
  ) {
    final amount = (booking['reservation_fee_amount'] as num?)?.toDouble();
    final type = booking['reservation_payment_type']?.toString() ?? '';
    final coversTotal = booking['reservation_payment_covers_total'] == true;
    final status =
        booking['reservation_payment_status']?.toString().trim().isNotEmpty ==
            true
        ? booking['reservation_payment_status'].toString()
        : 'Not submitted';
    final method =
        booking['reservation_payment_method']?.toString().trim().isNotEmpty ==
            true
        ? booking['reservation_payment_method'].toString()
        : 'PSDC QR payment';
    final reference =
        booking['reservation_payment_reference']?.toString().trim() ?? '';
    final proofUrl =
        booking['reservation_payment_proof_url']?.toString().trim() ?? '';
    final submittedAt = DateTime.tryParse(
      booking['reservation_payment_submitted_at']?.toString() ?? '',
    )?.toLocal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black38 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  coversTotal ? 'FULL PAYMENT' : 'RESERVATION',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _buildPaymentInfoTile(
                'Amount paid',
                amount == null ? 'N/A' : 'PHP ${amount.toStringAsFixed(0)}',
                isDark,
              ),
              _buildPaymentInfoTile(
                'Payment type',
                type.isEmpty ? 'Reservation only' : type.replaceAll('_', ' '),
                isDark,
              ),
              _buildPaymentInfoTile(
                'Status',
                status.replaceAll('_', ' '),
                isDark,
              ),
              _buildPaymentInfoTile(
                'Method',
                method.replaceAll('_', ' '),
                isDark,
              ),
              _buildPaymentInfoTile(
                'Reference',
                reference.isEmpty ? 'Missing' : reference,
                isDark,
              ),
              _buildPaymentInfoTile(
                'Submitted',
                _formatBookingDateTime(submittedAt),
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (proofUrl.isEmpty)
            Text(
              'No receipt proof uploaded.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                fontSize: 12,
              ),
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: OnDemandNetworkImage(
                    imageUrl: proofUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    label: 'Load',
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _showReceiptProofDialog(proofUrl, isDark),
                  icon: const Icon(Icons.open_in_full, size: 16),
                  label: const Text('View receipt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoTile(String label, String value, bool isDark) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[500] : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptProofDialog(String proofUrl, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Payment Receipt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: OptimizedNetworkImage(
                      imageUrl: proofUrl,
                      fit: BoxFit.contain,
                      isThumbnail: false,
                      errorWidget: const Padding(
                        padding: EdgeInsets.all(40),
                        child: Icon(Icons.broken_image_outlined, size: 72),
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

  Future<void> _showBookingSafetyReviewDialog(
    Map<String, dynamic> booking,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final evidence = [
      MapEntry(
        'Signature image',
        booking['renter_signature_url']?.toString() ?? '',
      ),
      MapEntry('Valid ID', booking['renter_valid_id_url']?.toString() ?? ''),
      MapEntry('Selfie', booking['renter_selfie_url']?.toString() ?? ''),
      MapEntry(
        'Co-traveler signature image',
        booking['co_traveler_signature_url']?.toString() ?? '',
      ),
      MapEntry(
        'Co-traveler valid ID',
        booking['co_traveler_valid_id_url']?.toString() ?? '',
      ),
      MapEntry(
        'Co-traveler selfie',
        booking['co_traveler_selfie_url']?.toString() ?? '',
      ),
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: const Text('Renter Safety Review'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewLine(
                  'Digital signature',
                  booking['renter_signature_text']?.toString(),
                ),
                _buildReviewLine(
                  'Emergency contact',
                  [
                        booking['emergency_contact_name']?.toString(),
                        booking['emergency_contact_relationship']?.toString(),
                        booking['emergency_contact_phone']?.toString(),
                      ]
                      .where((part) => part != null && part.trim().isNotEmpty)
                      .join(' - '),
                ),
                _buildReviewLine(
                  'Co-traveler',
                  [
                        booking['co_traveler_name']?.toString(),
                        booking['co_traveler_phone']?.toString(),
                      ]
                      .where((part) => part != null && part.trim().isNotEmpty)
                      .join(' - '),
                ),
                _buildReviewLine(
                  'Co-traveler license',
                  booking['co_traveler_license']?.toString(),
                ),
                _buildReviewLine(
                  'Co-traveler signature',
                  booking['co_traveler_signature_text']?.toString(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Uploaded files',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...evidence.map((item) {
                  final url = item.value.trim();
                  final bucket = _storageBucketFromUrl(url);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: url.isEmpty
                          ? null
                          : () => _openEvidenceUrl(url),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        url.isEmpty
                            ? '${item.key}: missing'
                            : bucket == null
                            ? item.key
                            : '${item.key} ($bucket)',
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEvidenceUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showErrorSnackBar('Invalid uploaded file link');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showErrorSnackBar(
        'Could not open uploaded file. Check that the storage bucket exists and the file was uploaded.',
      );
    }
  }

  String? _storageBucketFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final publicIndex = segments.indexOf('public');
    if (publicIndex >= 0 && publicIndex + 1 < segments.length) {
      return segments[publicIndex + 1];
    }

    final signIndex = segments.indexOf('sign');
    if (signIndex >= 0 && signIndex + 1 < segments.length) {
      return segments[signIndex + 1];
    }

    return null;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Widget _buildReviewLine(String label, String? value) {
    final clean = value?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              clean == null || clean.isEmpty ? 'Not provided' : clean,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInspectionDialog(
    Map<String, dynamic> booking, {
    required String inspectionType,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final bookingId = booking['id']?.toString() ?? '';
    if (currentUserId == null || bookingId.isEmpty) return;

    final fuelController = TextEditingController();
    final mileageController = TextEditingController();
    final cleanlinessController = TextEditingController();
    final scratchesController = TextEditingController();
    final dentsController = TextEditingController();
    final damagesController = TextEditingController();
    final remarksController = TextEditingController();
    final selectedEvidence = <PlatformFile>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          title: Text(
            inspectionType == 'before'
                ? 'Before Rental Checklist'
                : 'After Return Checklist',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInspectionTextField(fuelController, 'Fuel level'),
                  _buildInspectionTextField(
                    mileageController,
                    'Mileage',
                    keyboardType: TextInputType.number,
                  ),
                  _buildInspectionTextField(
                    cleanlinessController,
                    'Cleanliness',
                  ),
                  _buildInspectionTextField(scratchesController, 'Scratches'),
                  _buildInspectionTextField(dentsController, 'Dents'),
                  _buildInspectionTextField(damagesController, 'Damages'),
                  _buildInspectionTextField(
                    remarksController,
                    'Other remarks',
                    maxLines: 3,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.media,
                          allowMultiple: true,
                          withData: true,
                        );
                        if (result == null) return;
                        final usableFiles = result.files
                            .where(
                              (file) =>
                                  file.bytes != null &&
                                  file.size <= 25 * 1024 * 1024,
                            )
                            .take(8)
                            .toList();
                        setDialogState(() {
                          selectedEvidence
                            ..clear()
                            ..addAll(usableFiles);
                        });
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add photos or videos'),
                    ),
                  ),
                  if (selectedEvidence.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedEvidence
                            .map(
                              (file) => InputChip(
                                label: Text(file.name),
                                onDeleted: () => setDialogState(
                                  () => selectedEvidence.remove(file),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save Checklist'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) {
      fuelController.dispose();
      mileageController.dispose();
      cleanlinessController.dispose();
      scratchesController.dispose();
      dentsController.dispose();
      damagesController.dispose();
      remarksController.dispose();
      return;
    }

    try {
      if (selectedEvidence.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading checklist evidence...')),
        );
      }
      final evidenceUrls = <String>[];
      for (final file in selectedEvidence) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        evidenceUrls.add(
          await BookingInspectionService().uploadEvidenceBytes(
            userId: currentUserId,
            bookingId: bookingId,
            bytes: bytes,
            extension: file.extension ?? 'jpg',
          ),
        );
      }
      await BookingInspectionService().saveInspection(
        bookingId: bookingId,
        inspectionType: inspectionType,
        inspectorId: currentUserId,
        fuelLevel: fuelController.text.trim(),
        mileage: double.tryParse(mileageController.text.trim()),
        cleanliness: cleanlinessController.text.trim(),
        scratches: scratchesController.text.trim(),
        dents: dentsController.text.trim(),
        damages: damagesController.text.trim(),
        remarks: remarksController.text.trim(),
        evidenceUrls: evidenceUrls,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle checklist saved'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save checklist: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      fuelController.dispose();
      mileageController.dispose();
      cleanlinessController.dispose();
      scratchesController.dispose();
      dentsController.dispose();
      damagesController.dispose();
      remarksController.dispose();
    }
  }

  Widget _buildInspectionTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildBookingEventChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? Colors.grey[300] : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[300] : Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Notifications (${_notifications.length})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  final currentUserId = _supabase.auth.currentUser?.id;
                  if (currentUserId == null) return;
                  await NotificationService().markAllAsRead(currentUserId);
                  await _loadNotifications();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Mark all read'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_notifications.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
              child: Text(
                'No notifications yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final isRead = notification['is_read'] == true;
                final title = notification['title']?.toString() ?? 'Update';
                final message =
                    notification['message']?.toString() ??
                    notification['body']?.toString() ??
                    '';
                final createdAt = DateTime.tryParse(
                  notification['created_at']?.toString() ?? '',
                );

                return InkWell(
                  onTap: () async {
                    final notificationId = notification['id']?.toString();
                    if (notificationId == null || isRead) return;
                    await NotificationService().markAsRead(notificationId);
                    notification['is_read'] = true;
                    if (mounted) setState(() {});
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRead
                          ? (isDark ? AppColors.darkCard : Colors.white)
                          : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isRead
                            ? (isDark
                                  ? AppColors.borderColor
                                  : Colors.grey.shade200)
                            : AppColors.primary.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: isRead
                              ? (isDark ? Colors.grey : Colors.grey.shade600)
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                              if (createdAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${createdAt.day.toString().padLeft(2, '0')} ${_getMonthName(createdAt.month)} ${createdAt.year}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role) {
      case 'partner':
        color = Colors.blue;
        break;
      case 'operator':
        color = Colors.purple;
        break;
      case 'admin':
        color = Colors.red;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildImageWidget(
    XFile imageFile, {
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return FutureBuilder<Uint8List>(
      future: _selectedImageBytes.putIfAbsent(
        imageFile.path,
        imageFile.readAsBytes,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final image = Image.memory(snapshot.data!, fit: fit);
          return borderRadius != null
              ? ClipRRect(borderRadius: borderRadius, child: image)
              : image;
        } else if (snapshot.hasError) {
          return const Center(child: Icon(Icons.error, color: Colors.red));
        } else {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
      },
    );
  }

  Future<void> _loadConversations() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      debugPrint(
        '[Messages] Loading conversations for operator: $currentUserId',
      );

      final participations = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', currentUserId);

      final conversationIds = List<Map<String, dynamic>>.from(participations)
          .map((row) => row['conversation_id']?.toString())
          .whereType<String>()
          .toList();

      if (conversationIds.isEmpty) {
        _conversations = [];
        if (mounted) setState(() {});
        return;
      }

      final response = await _supabase
          .from('conversations')
          .select('''
              id,
              booking_id,
              user_id,
              other_user_id,
              status,
              created_at,
              bookings!conversations_booking_id_fkey (
                id,
                vehicle_id,
                start_at,
                end_at,
                start_date,
                end_date,
                status,
                vehicles!bookings_vehicle_id_fkey (brand, model, year),
                renter:users!bookings_renter_id_fkey (id, full_name, email)
              ),
              users!conversations_user_id_fkey (id, full_name, email),
              other_users:users!conversations_other_user_id_fkey (id, full_name, email)
            ''')
          .inFilter('id', conversationIds)
          .order('created_at', ascending: false);

      _conversations = List<Map<String, dynamic>>.from(response);
      debugPrint('[Messages] Loaded ${_conversations.length} conversations');

      setState(() {});
    } catch (e) {
      debugPrint('[Messages] Error loading conversations: $e');
    }
  }

  Future<void> _loadConversationMessages(String conversationId) async {
    try {
      debugPrint(
        '[Messages] Loading messages for conversation: $conversationId',
      );

      await _loadConversationParticipants(conversationId);

      final response = await _supabase
          .from('messages')
          .select('''
              id,
              conversation_id,
              sender_id,
              message,
              content,
              is_auto_generated,
              created_at,
              sender:users!messages_sender_id_fkey (id, full_name)
            ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      _messages[conversationId] = List<Map<String, dynamic>>.from(response);
      debugPrint(
        '[Messages] Loaded ${_messages[conversationId]?.length ?? 0} messages',
      );

      setState(() {});
    } catch (e) {
      debugPrint('[Messages] Error loading messages: $e');
    }
  }

  Future<void> _loadConversationParticipants(String conversationId) async {
    try {
      _conversationParticipants[conversationId] = await ChatService()
          .getConversationParticipants(conversationId);
    } catch (e) {
      debugPrint('[Messages] Error loading participants: $e');
      _conversationParticipants[conversationId] = [];
    }
  }

  Future<void> _sendMessage(String conversationId, String content) async {
    if (content.trim().isEmpty) return;

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      debugPrint('[Messages] Sending message to conversation: $conversationId');

      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'message': content,
        'content': content,
        'is_auto_generated': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      _messageController.clear();
      await _loadConversationMessages(conversationId);
      debugPrint('[Messages] Message sent successfully');
    } catch (e) {
      debugPrint('[Messages] Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOperatorParticipantReference(
    List<Map<String, dynamic>> participants,
    bool isDark,
  ) {
    if (participants.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversation profiles',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textSecondary : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: participants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final participant = participants[index];
                final name =
                    participant['display_name']?.toString().trim().isNotEmpty ==
                        true
                    ? participant['display_name'].toString().trim()
                    : 'Unknown User';
                final role =
                    participant['display_role']?.toString().trim().isNotEmpty ==
                        true
                    ? participant['display_role'].toString().trim()
                    : 'Participant';
                final phone =
                    participant['display_phone']
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true
                    ? participant['display_phone'].toString().trim()
                    : '';
                final email = participant['email']?.toString().trim() ?? '';
                final avatar =
                    participant['display_avatar']?.toString().trim() ?? '';
                final detail = phone.isNotEmpty
                    ? phone
                    : email.isNotEmpty
                    ? email
                    : 'No contact saved';

                return Container(
                  width: 230,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderColor
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary.withOpacity(0.18),
                        backgroundImage: avatar.isNotEmpty
                            ? OptimizedNetworkImageProvider(avatar)
                            : null,
                        child: avatar.isEmpty
                            ? Text(
                                _initials(name),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesContent(bool isDark) {
    // Show empty state if no conversations
    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.message_outlined,
                size: 64,
                color: isDark ? Colors.grey[600] : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No conversations yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Conversations will appear when you confirm bookings',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedConversationId.isEmpty) {
      // Show conversation list only
      return Row(
        children: [
          // Conversations list (left sidebar)
          Container(
            width: 320,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _conversations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                final conversationId = conversation['id'] as String? ?? '';

                // Safely extract booking info
                var renterName = 'Unknown Renter';
                var vehicleInfo = 'No vehicle info';
                var status = 'PENDING';

                try {
                  final bookings = conversation['bookings'];
                  if (bookings is Map<String, dynamic>) {
                    final renter = bookings['renter'];
                    if (renter is Map<String, dynamic>) {
                      renterName =
                          renter['full_name'] as String? ?? 'Unknown Renter';
                    }

                    final vehicles = bookings['vehicles'];
                    if (vehicles is Map<String, dynamic>) {
                      final brand = vehicles['brand'] as String? ?? '';
                      final model = vehicles['model'] as String? ?? '';
                      vehicleInfo = '$brand $model'.trim();
                    }

                    status = (bookings['status'] as String? ?? 'PENDING')
                        .toUpperCase();
                  }
                } catch (e) {
                  debugPrint('[Messages] Error extracting booking info: $e');
                }

                return InkWell(
                  onTap: () {
                    setState(() => _selectedConversationId = conversationId);
                    _loadConversationMessages(conversationId);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          renterName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vehicleInfo.isEmpty ? 'No vehicle info' : vehicleInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: status == 'CONFIRMED'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Empty chat area
          Expanded(
            child: Center(
              child: Text(
                'Select a conversation to start messaging',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Show conversation detail with chat
    var renterName = 'Conversation';
    var vehicleInfo = 'Vehicle';
    var status = 'pending';
    var conversationStatus = 'active';

    try {
      final conversation = _conversations.firstWhere(
        (c) => c['id'] == _selectedConversationId,
        orElse: () => {},
      );

      if (conversation.isNotEmpty) {
        conversationStatus =
            conversation['status']?.toString().toLowerCase() ?? 'active';
        final bookings = conversation['bookings'];
        if (bookings is Map<String, dynamic>) {
          final renter = bookings['renter'];
          if (renter is Map<String, dynamic>) {
            renterName = renter['full_name'] as String? ?? 'Unknown';
          }

          final vehicles = bookings['vehicles'];
          if (vehicles is Map<String, dynamic>) {
            final brand = vehicles['brand'] as String? ?? '';
            final model = vehicles['model'] as String? ?? '';
            vehicleInfo = '$brand $model'.trim();
          }

          status = bookings['status'] as String? ?? 'pending';
        }
      }
    } catch (e) {
      debugPrint('[Messages] Error extracting conversation data: $e');
    }

    final conversationMessages = _messages[_selectedConversationId] ?? [];
    final isConversationClosed =
        conversationStatus == 'closed' || status.toLowerCase() == 'completed';

    return Row(
      children: [
        // Conversations list (left sidebar)
        Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () =>
                          setState(() => _selectedConversationId = ''),
                    ),
                    Expanded(
                      child: Text(
                        renterName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conversations.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final isSelected = conv['id'] == _selectedConversationId;

                    var rnt = 'Unknown';
                    try {
                      final bookings = conv['bookings'];
                      if (bookings is Map<String, dynamic>) {
                        final renter = bookings['renter'];
                        if (renter is Map<String, dynamic>) {
                          rnt = renter['full_name'] as String? ?? 'Unknown';
                        }
                      }
                    } catch (e) {
                      debugPrint('[Messages] Error extracting renter name: $e');
                    }

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedConversationId = conv['id']);
                        _loadConversationMessages(conv['id']);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.2)
                              : (isDark ? Colors.black26 : Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: AppColors.primary)
                              : null,
                        ),
                        child: Text(
                          rnt,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Chat area (right side)
        Expanded(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.borderColor
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? Colors.black26 : Colors.grey.shade200,
                      ),
                      child: Icon(
                        Icons.directions_car,
                        color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$renterName - Booking',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            '$vehicleInfo (${status.toUpperCase()})',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildOperatorParticipantReference(
                _conversationParticipants[_selectedConversationId] ?? [],
                isDark,
              ),
              // Messages
              Expanded(
                child: conversationMessages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey[500]
                                : Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: conversationMessages.length,
                        itemBuilder: (context, index) {
                          final message = conversationMessages[index];
                          final currentUserId = _supabase.auth.currentUser?.id;
                          final isOwn = message['sender_id'] == currentUserId;

                          var senderName = 'System';
                          try {
                            final sender = message['sender'];
                            if (sender is Map<String, dynamic>) {
                              senderName =
                                  sender['full_name'] as String? ?? 'System';
                            }
                          } catch (e) {
                            debugPrint(
                              '[Messages] Error extracting sender name: $e',
                            );
                          }

                          return Align(
                            alignment: isOwn
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isOwn
                                    ? AppColors.primary
                                    : (isDark
                                          ? Colors.black26
                                          : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isOwn)
                                    Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  if (!isOwn) const SizedBox(height: 4),
                                  Text(
                                    (message['content'] as String?) ??
                                        (message['message'] as String?) ??
                                        '',
                                    style: TextStyle(
                                      color: isOwn
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white
                                                : Colors.black),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatMessageTime(
                                      message['created_at'] as String?,
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isOwn
                                          ? Colors.white70
                                          : (isDark
                                                ? Colors.grey[500]
                                                : Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.borderColor
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: isConversationClosed
                    ? Text(
                        'This booking is completed. The group chat is closed.',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              maxLines: 1,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey[600]
                                      : Colors.grey.shade400,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.borderColor
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _sendMessage(
                              _selectedConversationId,
                              _messageController.text,
                            ),
                            icon: const Icon(Icons.send, size: 18),
                            label: const Text('Send'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatMessageTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildVehiclesContent(bool isDark) {
    final ownVehicles = _vehicles;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Vehicles (${_vehicles.length})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddVehicleDialog(isDark),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add Vehicle',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Company Vehicles (${ownVehicles.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (ownVehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 60,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No company vehicles added yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 5;
                const spacing = 16.0;
                final cardWidth =
                    (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                    crossAxisCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: ownVehicles
                      .map(
                        (vehicle) => SizedBox(
                          width: cardWidth,
                          child: _buildVehicleCard(vehicle, isDark),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 32),
          Text(
            'Partner Vehicles (${_partnerVehicles.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (_partnerVehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.business_center_outlined,
                      size: 60,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No partner vehicles',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 5;
                const spacing = 16.0;
                final cardWidth =
                    (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                    crossAxisCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _partnerVehicles
                      .map(
                        (vehicle) => SizedBox(
                          width: cardWidth,
                          child: _buildVehicleCard(vehicle, isDark),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle, bool isDark) {
    return _VehicleCard(
      brand: vehicle['brand'] ?? 'Unknown',
      model: vehicle['model'] ?? 'Model',
      vehicleName: vehicle['vehicle_name'] ?? '',
      category: vehicle['category'] ?? '',
      vehicleType: vehicle['vehicle_type'] ?? '',
      description: vehicle['description'] ?? '',
      color: vehicle['color'] ?? '',
      location: vehicle['location'] ?? '',
      latitude: vehicle['latitude'],
      longitude: vehicle['longitude'],
      year: (vehicle['year'] ?? '').toString(),
      pricePerDay: vehicle['price_per_day'] ?? 0,
      pricePerHour: vehicle['price_per_hour'] ?? 0,
      isPosted: vehicle['is_posted'] ?? false,
      images: (vehicle['vehicle_images'] as List?) ?? [],
      isDark: isDark,
      transmission: vehicle['transmission'] ?? '',
      onEdit: () => _showEditVehicleDialog(vehicle, isDark),
      onDelete: () => _deleteVehicle(vehicle['id']),
      onTogglePost: (value) => _togglePostingStatus(vehicle, value),
    );
  }

  InputDecoration _fieldDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  TextStyle _fieldTextStyle(bool isDark) {
    return TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15);
  }

  void _showAddVehicleDialog(bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 1000),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add New Vehicle',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isSubmittingVehicle
                            ? null
                            : () => Navigator.pop(context),
                        child: Icon(
                          Icons.close,
                          color: _isSubmittingVehicle
                              ? Colors.grey
                              : (isDark
                                    ? Colors.grey[400]
                                    : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Main image preview
                        Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey.shade300,
                            ),
                            color: isDark
                                ? Colors.black26
                                : Colors.grey.shade50,
                          ),
                          child: _selectedImages.isNotEmpty
                              ? _buildImageWidget(
                                  _selectedImages.first,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_outlined,
                                        size: 50,
                                        color: isDark
                                            ? Colors.grey[600]
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No images selected',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[600]
                                              : Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        // Thumbnails
                        if (_selectedImages.isNotEmpty)
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedImages.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: index == 0
                                              ? AppColors.primary
                                              : (isDark
                                                    ? Colors.grey[700]!
                                                    : Colors.grey.shade300),
                                          width: index == 0 ? 3 : 1,
                                        ),
                                      ),
                                      child: _buildImageWidget(
                                        _selectedImages[index],
                                        fit: BoxFit.cover,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            _selectedImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Image picker buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final pickedFile = await _imagePicker
                                      .pickImage(source: ImageSource.gallery);
                                  if (pickedFile != null) {
                                    setDialogState(() {
                                      _selectedImages.add(pickedFile);
                                    });
                                  }
                                },
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('Add Image'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (_selectedImages.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setDialogState(() {
                                      _selectedImages.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.clear, size: 18),
                                  label: const Text('Clear All'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _brandController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Brand', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _modelController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Model', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _plateController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Plate Number', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _categoryController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Category', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _vehicleTypeController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Vehicle Type', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _vehicleNameController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Vehicle Name', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _colorController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Color', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _transmissionController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration(
                            'Transmission (Manual/Automatic)',
                            isDark,
                          ),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _descriptionController,
                          cursorColor: AppColors.primary,
                          maxLines: 4,
                          decoration: _fieldDecoration('Description', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _yearController,
                          cursorColor: AppColors.primary,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration('Year', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _priceController,
                          cursorColor: AppColors.primary,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            'Price per Day (PHP)',
                            isDark,
                          ),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pricePerHourController,
                          cursorColor: AppColors.primary,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            'Price per Hour (PHP)',
                            isDark,
                          ),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Location',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _getCurrentVehicleLocation(
                                    onLocationFound:
                                        (location, latitude, longitude) {
                                          setDialogState(() {
                                            _locationController.text = location;
                                            _latitudeController.text = latitude;
                                            _longitudeController.text =
                                                longitude;
                                          });
                                        },
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.my_location,
                                          size: 18,
                                          color: Colors.black,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Use Current Location',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locationController,
                          cursorColor: AppColors.primary,
                          decoration: _fieldDecoration('Location', isDark),
                          style: _fieldTextStyle(isDark),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _latitudeController,
                                readOnly: true,
                                cursorColor: AppColors.primary,
                                keyboardType: TextInputType.number,
                                decoration: _fieldDecoration(
                                  'Latitude',
                                  isDark,
                                ),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _longitudeController,
                                readOnly: true,
                                cursorColor: AppColors.primary,
                                keyboardType: TextInputType.number,
                                decoration: _fieldDecoration(
                                  'Longitude',
                                  isDark,
                                ),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Inactive'),
                            ),
                            DropdownMenuItem(
                              value: 'maintenance',
                              child: Text('Maintenance'),
                            ),
                          ],
                          onChanged: (value) => setDialogState(
                            () => _selectedStatus = value ?? 'active',
                          ),
                          decoration: _fieldDecoration('Status', isDark),
                          dropdownColor: isDark
                              ? AppColors.darkCard
                              : Colors.white,
                          style: _fieldTextStyle(isDark),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Footer actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmittingVehicle
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: _isSubmittingVehicle
                                ? Colors.grey
                                : (isDark
                                      ? Colors.grey[400]
                                      : Colors.grey.shade700),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmittingVehicle
                            ? null
                            : () async {
                                if (_brandController.text.isEmpty ||
                                    _modelController.text.isEmpty ||
                                    _plateController.text.isEmpty ||
                                    _categoryController.text.isEmpty ||
                                    _vehicleTypeController.text.isEmpty ||
                                    _vehicleNameController.text.isEmpty ||
                                    _descriptionController.text.isEmpty ||
                                    _colorController.text.isEmpty ||
                                    _yearController.text.isEmpty ||
                                    _priceController.text.isEmpty ||
                                    _pricePerHourController.text.isEmpty ||
                                    _locationController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please fill all fields'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(
                                  () => _isSubmittingVehicle = true,
                                );

                                try {
                                  final currentUserId =
                                      _supabase.auth.currentUser?.id;
                                  if (currentUserId == null) {
                                    throw 'Operator account is required to add vehicles';
                                  }

                                  final existing = await _supabase
                                      .from('vehicles')
                                      .select('id')
                                      .eq('plate_number', _plateController.text)
                                      .limit(1);

                                  String vehicleId;
                                  if (existing != null &&
                                      (existing as List).isNotEmpty) {
                                    vehicleId = existing[0]['id'];
                                  } else {
                                    final vehicleResponse = await _supabase
                                        .from('vehicles')
                                        .insert({
                                          'brand': _brandController.text,
                                          'model': _modelController.text,
                                          'category': _categoryController.text,
                                          'vehicle_type':
                                              _vehicleTypeController.text,
                                          'vehicle_name':
                                              _vehicleNameController.text,
                                          'description':
                                              _descriptionController.text,
                                          'color': _colorController.text,
                                          'transmission':
                                              _transmissionController
                                                  .text
                                                  .isEmpty
                                              ? 'Manual'
                                              : _transmissionController.text,
                                          'plate_number': _plateController.text,
                                          'year':
                                              int.tryParse(
                                                _yearController.text,
                                              ) ??
                                              0,
                                          'price_per_day':
                                              double.tryParse(
                                                _priceController.text,
                                              ) ??
                                              0.0,
                                          'price_per_hour':
                                              double.tryParse(
                                                _pricePerHourController.text,
                                              ) ??
                                              0.0,
                                          'location': _locationController.text,
                                          'latitude':
                                              double.tryParse(
                                                _latitudeController.text,
                                              ) ??
                                              0.0,
                                          'longitude':
                                              double.tryParse(
                                                _longitudeController.text,
                                              ) ??
                                              0.0,
                                          'status': _selectedStatus,
                                          'is_available': true,
                                          'owner_id': currentUserId,
                                        })
                                        .select()
                                        .single();
                                    vehicleId = vehicleResponse['id'];
                                  }

                                  for (
                                    int i = 0;
                                    i < _selectedImages.length;
                                    i++
                                  ) {
                                    final fileName =
                                        'vehicle_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                                    final filePath =
                                        'vehicles/$currentUserId/$fileName';
                                    try {
                                      final originalImageBytes =
                                          await _selectedImages[i]
                                              .readAsBytes();
                                      final imageBytes =
                                          await ImageOptimizationService.optimizeForUpload(
                                            originalImageBytes,
                                            fileName: fileName,
                                          );
                                      await _supabase.storage
                                          .from(_vehicleImagesBucket)
                                          .uploadBinary(
                                            filePath,
                                            imageBytes,
                                            fileOptions: const FileOptions(
                                              cacheControl: '31536000',
                                              upsert: false,
                                            ),
                                          );
                                      final imageUrl = _supabase.storage
                                          .from(_vehicleImagesBucket)
                                          .getPublicUrl(filePath);
                                      await _supabase
                                          .from('vehicle_images')
                                          .insert({
                                            'vehicle_id': vehicleId,
                                            'image_url': imageUrl,
                                            'display_order': i,
                                          });
                                    } catch (e) {
                                      debugPrint(
                                        'Error uploading image $i: $e',
                                      );
                                    }
                                  }

                                  final imageCount = _selectedImages.length;
                                  _brandController.clear();
                                  _modelController.clear();
                                  _categoryController.clear();
                                  _vehicleTypeController.clear();
                                  _vehicleNameController.clear();
                                  _descriptionController.clear();
                                  _colorController.clear();
                                  _transmissionController.clear();
                                  _yearController.clear();
                                  _plateController.clear();
                                  _priceController.clear();
                                  _pricePerHourController.clear();
                                  _selectedImages = [];
                                  _selectedStatus = 'active';
                                  _locationController.clear();
                                  _latitudeController.clear();
                                  _longitudeController.clear();

                                  if (mounted) Navigator.pop(context);
                                  _loadVehicles();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Vehicle added successfully with $imageCount images!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setDialogState(
                                      () => _isSubmittingVehicle = false,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: _isSubmittingVehicle
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Add Vehicle',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditVehicleDialog(Map<String, dynamic> vehicle, bool isDark) {
    final isPartnerVehicle =
        vehicle['_source'] == 'partner' ||
        vehicle['source'] == 'partner' ||
        vehicle['is_partner_vehicle'] == true;
    final partnerVehicleId =
        vehicle['partner_vehicle_id'] ??
        vehicle['_partner_vehicle_id'] ??
        vehicle['id'];
    final brandController = TextEditingController(text: vehicle['brand'] ?? '');
    final modelController = TextEditingController(text: vehicle['model'] ?? '');
    final categoryController = TextEditingController(
      text: vehicle['category'] ?? '',
    );
    final vehicleTypeController = TextEditingController(
      text: vehicle['vehicle_type'] ?? '',
    );
    final vehicleNameController = TextEditingController(
      text: vehicle['vehicle_name'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: vehicle['description'] ?? '',
    );
    final colorController = TextEditingController(text: vehicle['color'] ?? '');
    final transmissionController = TextEditingController(
      text: vehicle['transmission'] ?? 'Manual',
    );
    final locationController = TextEditingController(
      text: vehicle['location'] ?? '',
    );
    final latitudeController = TextEditingController(
      text: vehicle['latitude'] != null
          ? (vehicle['latitude'] as num?)?.toString() ?? ''
          : '',
    );
    final longitudeController = TextEditingController(
      text: vehicle['longitude'] != null
          ? (vehicle['longitude'] as num?)?.toString() ?? ''
          : '',
    );
    final yearController = TextEditingController(
      text: (vehicle['year'] ?? '').toString(),
    );
    final priceController = TextEditingController(
      text: (vehicle['price_per_day'] ?? '').toString(),
    );
    final pricePerHourController = TextEditingController(
      text: (vehicle['price_per_hour'] ?? '').toString(),
    );
    String selectedStatus = vehicle['status'] ?? 'active';
    final List<Map<String, dynamic>> existingImages =
        List<Map<String, dynamic>>.from(
          (vehicle['vehicle_images'] as List?) ?? [],
        );
    final List<XFile> newImages = [];
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickNewImages() async {
            if (isPartnerVehicle) return;
            try {
              if (kIsWeb) {
                final picked = await _imagePicker.pickMultiImage();
                if (picked.isNotEmpty) {
                  setDialogState(() => newImages.addAll(picked));
                }
              } else {
                final picked = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                );
                if (picked != null) {
                  setDialogState(() => newImages.add(picked));
                }
              }
            } catch (e) {
              debugPrint('Error picking images: $e');
            }
          }

          Future<void> removeExistingImage(int index) async {
            if (isPartnerVehicle) return;
            final id = existingImages[index]['id'];
            try {
              await _supabase.from('vehicle_images').delete().eq('id', id);
              setDialogState(() => existingImages.removeAt(index));
            } catch (e) {
              debugPrint('Error deleting existing image: $e');
            }
          }

          final previewImage = newImages.isNotEmpty
              ? _buildImageWidget(
                  newImages.first,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                )
              : existingImages.isNotEmpty
              ? OptimizedNetworkImage(
                  imageUrl: existingImages.first['image_url'] ?? '',
                  fit: BoxFit.cover,
                  errorWidget: Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 50,
                        color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No images',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey[600]
                              : Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 24,
            ),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 1000),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Vehicle',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: isUpdating
                              ? null
                              : () => Navigator.pop(context),
                          child: Icon(
                            Icons.close,
                            color: isUpdating
                                ? Colors.grey
                                : (isDark
                                      ? Colors.grey[400]
                                      : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Preview
                          Container(
                            width: double.infinity,
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                              color: isDark
                                  ? Colors.black26
                                  : Colors.grey.shade50,
                            ),
                            child: previewImage,
                          ),
                          const SizedBox(height: 12),
                          // Thumbnails
                          if (existingImages.isNotEmpty || newImages.isNotEmpty)
                            SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount:
                                    existingImages.length + newImages.length,
                                itemBuilder: (context, index) {
                                  if (index < existingImages.length) {
                                    final img = existingImages[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 90,
                                            height: 90,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.grey[700]!
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: OptimizedNetworkImage(
                                              imageUrl: img['image_url'] ?? '',
                                              fit: BoxFit.cover,
                                              errorWidget: const Center(
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: -6,
                                            right: -6,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  removeExistingImage(index),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    final newImg =
                                        newImages[index -
                                            existingImages.length];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 90,
                                            height: 90,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.grey[700]!
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: _buildImageWidget(
                                              newImg,
                                              fit: BoxFit.cover,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          Positioned(
                                            top: -6,
                                            right: -6,
                                            child: GestureDetector(
                                              onTap: () => setDialogState(
                                                () => newImages.removeAt(
                                                  index - existingImages.length,
                                                ),
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (isPartnerVehicle)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.35),
                                ),
                              ),
                              child: Text(
                                'Partner vehicles are price-managed by operators. Vehicle details and images stay read-only here.',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isPartnerVehicle
                                      ? null
                                      : pickNewImages,
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Add Image'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              if (newImages.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        setDialogState(() => newImages.clear()),
                                    icon: const Icon(Icons.clear, size: 18),
                                    label: const Text('Clear New'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: brandController,
                            readOnly: isPartnerVehicle,
                            cursorColor: AppColors.primary,
                            decoration: _fieldDecoration('Brand', isDark),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: modelController,
                            readOnly: isPartnerVehicle,
                            cursorColor: AppColors.primary,
                            decoration: _fieldDecoration('Model', isDark),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: categoryController,
                            readOnly: isPartnerVehicle,
                            cursorColor: AppColors.primary,
                            decoration: _fieldDecoration('Category', isDark),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: vehicleTypeController,
                            readOnly: isPartnerVehicle,
                            cursorColor: AppColors.primary,
                            decoration: _fieldDecoration(
                              'Vehicle Type',
                              isDark,
                            ),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: vehicleNameController,
                            readOnly: isPartnerVehicle,
                            cursorColor: AppColors.primary,
                            decoration: _fieldDecoration(
                              'Vehicle Name',
                              isDark,
                            ),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: colorController,
                            readOnly: isPartnerVehicle,
                            cursorColor: AppColors.primary,
                            decoration: _fieldDecoration('Color', isDark),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: transmissionController,
                            readOnly: isPartnerVehicle,
                            cursorColor: AppColors.primary,
                            decoration: _fieldDecoration(
                              'Transmission (Manual/Automatic)',
                              isDark,
                            ),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descriptionController,
                            readOnly: isPartnerVehicle,
                            cursorColor: AppColors.primary,
                            maxLines: 4,
                            decoration: _fieldDecoration('Description', isDark),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: yearController,
                            readOnly: isPartnerVehicle,
                            cursorColor: AppColors.primary,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration('Year', isDark),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: priceController,
                            cursorColor: AppColors.primary,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration(
                              'Price per Day (PHP)',
                              isDark,
                            ),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: pricePerHourController,
                            cursorColor: AppColors.primary,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration(
                              'Price per Hour (PHP)',
                              isDark,
                            ),
                            style: _fieldTextStyle(isDark),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: locationController,
                                  readOnly: isPartnerVehicle,
                                  cursorColor: AppColors.primary,
                                  decoration: _fieldDecoration(
                                    'Location',
                                    isDark,
                                  ),
                                  style: _fieldTextStyle(isDark),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: isPartnerVehicle
                                        ? null
                                        : () => _getCurrentVehicleLocation(
                                            onLocationFound:
                                                (
                                                  location,
                                                  latitude,
                                                  longitude,
                                                ) {
                                                  setDialogState(() {
                                                    locationController.text =
                                                        location;
                                                    latitudeController.text =
                                                        latitude;
                                                    longitudeController.text =
                                                        longitude;
                                                  });
                                                },
                                          ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(
                                        Icons.location_searching,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: latitudeController,
                                  readOnly: true,
                                  cursorColor: AppColors.primary,
                                  keyboardType: TextInputType.number,
                                  decoration: _fieldDecoration(
                                    'Latitude',
                                    isDark,
                                  ),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: longitudeController,
                                  readOnly: true,
                                  cursorColor: AppColors.primary,
                                  keyboardType: TextInputType.number,
                                  decoration: _fieldDecoration(
                                    'Longitude',
                                    isDark,
                                  ),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            items: const [
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('Active'),
                              ),
                              DropdownMenuItem(
                                value: 'inactive',
                                child: Text('Inactive'),
                              ),
                              DropdownMenuItem(
                                value: 'maintenance',
                                child: Text('Maintenance'),
                              ),
                            ],
                            onChanged: isPartnerVehicle
                                ? null
                                : (value) => selectedStatus = value ?? 'active',
                            decoration: _fieldDecoration('Status', isDark),
                            dropdownColor: isDark
                                ? AppColors.darkCard
                                : Colors.white,
                            style: _fieldTextStyle(isDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // Footer actions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isUpdating
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isUpdating
                                  ? Colors.grey
                                  : (isDark
                                        ? Colors.grey[400]
                                        : Colors.grey.shade700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isUpdating
                              ? null
                              : () async {
                                  setDialogState(() => isUpdating = true);
                                  try {
                                    if (isPartnerVehicle) {
                                      await _supabase
                                          .from('partner_vehicles')
                                          .update({
                                            'price_per_day':
                                                double.tryParse(
                                                  priceController.text,
                                                ) ??
                                                0.0,
                                            'price_per_hour':
                                                double.tryParse(
                                                  pricePerHourController.text,
                                                ) ??
                                                0.0,
                                            'updated_at': DateTime.now()
                                                .toIso8601String(),
                                          })
                                          .eq('id', partnerVehicleId);

                                      await _supabase
                                          .from('partner_vehicle_applications')
                                          .update({
                                            'price_per_day':
                                                double.tryParse(
                                                  priceController.text,
                                                ) ??
                                                0.0,
                                            'price_per_hour':
                                                double.tryParse(
                                                  pricePerHourController.text,
                                                ) ??
                                                0.0,
                                          })
                                          .eq(
                                            'partner_vehicle_id',
                                            partnerVehicleId,
                                          );
                                    } else {
                                      await _supabase
                                          .from('vehicles')
                                          .update({
                                            'brand': brandController.text,
                                            'model': modelController.text,
                                            'category': categoryController.text,
                                            'vehicle_type':
                                                vehicleTypeController.text,
                                            'vehicle_name':
                                                vehicleNameController.text,
                                            'description':
                                                descriptionController.text,
                                            'color': colorController.text,
                                            'transmission':
                                                transmissionController
                                                    .text
                                                    .isEmpty
                                                ? 'Manual'
                                                : transmissionController.text,
                                            'year':
                                                int.tryParse(
                                                  yearController.text,
                                                ) ??
                                                0,
                                            'price_per_day':
                                                double.tryParse(
                                                  priceController.text,
                                                ) ??
                                                0.0,
                                            'price_per_hour':
                                                double.tryParse(
                                                  pricePerHourController.text,
                                                ) ??
                                                0.0,
                                            'location': locationController.text,
                                            'latitude':
                                                double.tryParse(
                                                  latitudeController.text,
                                                ) ??
                                                0.0,
                                            'longitude':
                                                double.tryParse(
                                                  longitudeController.text,
                                                ) ??
                                                0.0,
                                            'status': selectedStatus,
                                          })
                                          .eq('id', vehicle['id']);

                                      final List<String> uploadErrors = [];
                                      for (
                                        int i = 0;
                                        i < newImages.length;
                                        i++
                                      ) {
                                        final fileName =
                                            'vehicle_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                                        final ownerId =
                                            vehicle['owner_id'] ??
                                            _supabase.auth.currentUser?.id;
                                        final filePath =
                                            'vehicles/${ownerId ?? 'unknown'}/$fileName';
                                        try {
                                          final originalImageBytes =
                                              await newImages[i].readAsBytes();
                                          final imageBytes =
                                              await ImageOptimizationService.optimizeForUpload(
                                                originalImageBytes,
                                                fileName: fileName,
                                              );
                                          await _supabase.storage
                                              .from(_vehicleImagesBucket)
                                              .uploadBinary(
                                                filePath,
                                                imageBytes,
                                                fileOptions: const FileOptions(
                                                  cacheControl: '31536000',
                                                  upsert: false,
                                                ),
                                              );
                                          final imageUrl = _supabase.storage
                                              .from(_vehicleImagesBucket)
                                              .getPublicUrl(filePath);
                                          await _supabase
                                              .from('vehicle_images')
                                              .insert({
                                                'vehicle_id': vehicle['id'],
                                                'image_url': imageUrl,
                                                'display_order':
                                                    existingImages.length + i,
                                              });
                                        } catch (e) {
                                          debugPrint(
                                            'Error uploading new image: $e',
                                          );
                                          uploadErrors.add(e.toString());
                                        }
                                      }

                                      if (uploadErrors.isNotEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Some images failed: ${uploadErrors.first}',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    }

                                    Navigator.pop(context);
                                    _loadVehicles();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Vehicle updated successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } finally {
                                    setDialogState(() => isUpdating = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: isUpdating
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Update Vehicle',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
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
        },
      ),
    );
  }

  Future<void> _deleteVehicle(dynamic vehicleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: const Text('Are you sure you want to delete this vehicle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final partnerVehicle = _partnerVehicles.any(
          (vehicle) =>
              vehicle['id']?.toString() == vehicleId?.toString() ||
              vehicle['partner_vehicle_id']?.toString() ==
                  vehicleId?.toString(),
        );
        await _supabase
            .from(partnerVehicle ? 'partner_vehicles' : 'vehicles')
            .delete()
            .eq('id', vehicleId);
        _loadVehicles();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _togglePostingStatus(
    Map<String, dynamic> vehicle,
    bool isPosted,
  ) async {
    try {
      final isPartnerVehicle =
          vehicle['_source'] == 'partner' ||
          vehicle['source'] == 'partner' ||
          vehicle['is_partner_vehicle'] == true;
      if (isPartnerVehicle) {
        final partnerVehicleId =
            vehicle['partner_vehicle_id'] ??
            vehicle['_partner_vehicle_id'] ??
            vehicle['id'];
        await _supabase
            .from('partner_vehicles')
            .update({
              'is_available': isPosted,
              'status': isPosted ? 'available' : 'pending',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', partnerVehicleId);
      } else {
        await _supabase
            .from('vehicles')
            .update({'is_posted': isPosted})
            .eq('id', vehicle['id']);
      }

      vehicle['is_posted'] = isPosted;
      vehicle['is_available'] = isPosted;
      _loadVehicles();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPosted
                ? 'Vehicle posted successfully!'
                : 'Vehicle unlisted successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildSettingsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            'Appearance',
            Row(
              children: [
                Text(
                  'Dark Mode',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                const Spacer(),
                Switch(
                  value: isDark,
                  onChanged: widget.onThemeToggle,
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),
          _buildCard(
            'Account',
            Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _handleLogout,
                ),
              ],
            ),
            isDark,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stateful vehicle card extracted to avoid Switch overflow in GridView/Wrap
// ---------------------------------------------------------------------------
class _VehicleCard extends StatefulWidget {
  final String brand;
  final String model;
  final String vehicleName;
  final String category;
  final String vehicleType;
  final String description;
  final String color;
  final String location;
  final dynamic latitude;
  final dynamic longitude;
  final String year;
  final dynamic pricePerDay;
  final dynamic pricePerHour;
  final bool isPosted;
  final List images;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onTogglePost;
  final String transmission;

  const _VehicleCard({
    required this.brand,
    required this.model,
    required this.vehicleName,
    required this.category,
    required this.vehicleType,
    required this.description,
    required this.color,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.year,
    required this.pricePerDay,
    required this.pricePerHour,
    required this.isPosted,
    required this.images,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePost,
    required this.transmission,
  });

  @override
  State<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<_VehicleCard> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final isDark = widget.isDark;
    final title = widget.vehicleName.isNotEmpty
        ? widget.vehicleName
        : '${widget.brand} ${widget.model}'.trim();
    final metadata = <String>[
      if (widget.category.isNotEmpty) widget.category,
      if (widget.vehicleType.isNotEmpty) widget.vehicleType,
      if (widget.transmission.isNotEmpty) widget.transmission,
      if (widget.color.isNotEmpty) widget.color,
      if (widget.location.isNotEmpty) widget.location,
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image gallery ──────────────────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 130,
                  child: images.isNotEmpty
                      ? OptimizedNetworkImage(
                          imageUrl:
                              images[_currentImageIndex]['image_url'] ?? '',
                          fit: BoxFit.cover,
                          errorWidget: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: isDark
                                  ? Colors.grey[600]
                                  : Colors.grey.shade400,
                            ),
                          ),
                        )
                      : Container(
                          color: isDark ? Colors.black26 : Colors.grey.shade100,
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 32,
                              color: isDark
                                  ? Colors.grey[600]
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                ),
              ),
              // Counter badge
              if (images.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // Prev arrow
              if (images.length > 1)
                Positioned(
                  left: 4,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _currentImageIndex =
                          (_currentImageIndex - 1 + images.length) %
                          images.length;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              // Next arrow
              if (images.length > 1)
                Positioned(
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _currentImageIndex =
                          (_currentImageIndex + 1) % images.length;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Title ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: Text(
              widget.year,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
          ),
          if (metadata.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Text(
                metadata.join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey : Colors.grey.shade500,
                ),
              ),
            ),

          Divider(
            height: 1,
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),

          // ── Price section ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'PHP ',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        TextSpan(
                          text: widget.pricePerDay.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(
                          text: '/day',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'PHP ${widget.pricePerHour} /hr',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // ── Posted status + toggle ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isPosted ? 'Posted' : 'Not posted',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isPosted
                        ? AppColors.primary
                        : (isDark ? Colors.grey : Colors.grey.shade500),
                  ),
                ),
                // Compact toggle
                GestureDetector(
                  onTap: () => widget.onTogglePost(!widget.isPosted),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: widget.isPosted
                          ? AppColors.primary
                          : (isDark ? Colors.grey[700] : Colors.grey.shade300),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: widget.isPosted
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),

          // ── Edit / Delete ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 13),
                    label: const Text('Edit', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete, size: 13),
                    label: const Text('Delete', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
