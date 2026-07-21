import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import '../../../mobile_ui/theme/app_colors.dart';
import '../../../mobile_ui/screens/profile/settings_screen.dart';
import '../../../mobile_ui/screens/profile/trip_rating_flow_screen.dart';
import '../../theme/web_portal_theme.dart';
import '../../../utils/booking_status.dart';
import '../../../utils/notification_target.dart';
import '../../../utils/notification_visual.dart';
import '../../../mobile_ui/widgets/optimized_network_image.dart';
import '../../../mobile_ui/widgets/leaflet_map.dart';
import '../../../mobile_ui/widgets/relative_time_text.dart';
import '../../../mobile_ui/widgets/booking_return_countdown.dart';
import '../../../mobile_ui/widgets/vehicle_inspection_checklist_fields.dart';
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
  static const Color _operatorNavy = Color(0xFF032A46);
  static const Color _operatorNavyDeep = Color(0xFF021F35);
  static const Color _operatorGold = Color(0xFFFFD740);
  static const Color _operatorPage = Color(0xFFF5F7F9);
  static const Color _operatorInk = Color(0xFF08233D);

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _sidebarExpanded = true;
  String? _focusedTrackingBookingId;
  String _bookingFilter = 'all';
  String _bookingSearchQuery = '';
  String _bookingDateFilter = 'all';
  String _bookingVehicleTypeFilter = 'all';
  String _vehicleView = 'company';
  String _vehicleSearchQuery = '';
  int _dashboardQueuePage = 0;
  static const int _dashboardQueuePageSize = 10;
  int _bookingPage = 0;
  static const int _bookingPageSize = 10;

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
  List<Map<String, dynamic>> _operatorRevenueBookings = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _partnerVehicles = [];
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationLoadError;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _trackingLocations = [];
  Timer? _trackingRefreshTimer;
  Timer? _bookingFlowRefreshDebounce;
  Timer? _conversationFlowRefreshDebounce;
  RealtimeChannel? _bookingFlowChannel;
  RealtimeChannel? _conversationMessagesChannel;
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
  final TextEditingController _seatsController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  final ScrollController _dashboardQueueScrollController = ScrollController();
  final TextEditingController _bookingSearchController =
      TextEditingController();
  final TextEditingController _vehicleSearchController =
      TextEditingController();
  String _selectedConversationId = '';
  String _selectedStatus = 'active';
  List<XFile> _selectedImages = [];
  final Map<String, Future<Uint8List>> _selectedImageBytes = {};
  bool _isSubmittingVehicle = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadConversations();
    });
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
    _conversationFlowRefreshDebounce?.cancel();
    _bookingFlowChannel?.unsubscribe();
    _conversationMessagesChannel?.unsubscribe();
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
    _seatsController.dispose();
    _messageController.dispose();
    _messageScrollController.dispose();
    _dashboardQueueScrollController.dispose();
    _bookingSearchController.dispose();
    _vehicleSearchController.dispose();
    super.dispose();
  }

  void _setupBookingFlowListener() {
    final channelName =
        'operator-booking-flow-${_supabase.auth.currentUser?.id ?? 'guest'}';
    _bookingFlowChannel = _supabase.realtime.channel(channelName);

    void refreshDashboard(PostgresChangePayload payload) {
      if (!mounted) return;
      _bookingFlowRefreshDebounce?.cancel();
      _bookingFlowRefreshDebounce = Timer(
        const Duration(milliseconds: 350),
        () {
          _loadDashboardData(showLoading: false);
        },
      );
    }

    void refreshConversations(PostgresChangePayload payload) {
      if (!mounted) return;
      _conversationFlowRefreshDebounce?.cancel();
      _conversationFlowRefreshDebounce = Timer(
        const Duration(milliseconds: 300),
        () => _loadConversations(),
      );
    }

    _bookingFlowChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_job_assignments',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicles',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicle_images',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicle_applications',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'partner_vehicles',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'partner_vehicle_applications',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tracking_locations',
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _supabase.auth.currentUser?.id ?? '',
          ),
          callback: refreshDashboard,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: refreshConversations,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_participants',
          callback: refreshConversations,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: refreshConversations,
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

  Future<void> _loadDashboardData({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadStats(),
        _loadNotifications(),
        _loadVehicles(),
        _loadRecentBookings(),
        _loadOperatorRevenueBookings(),
        _loadTrackingLocations(),
      ]);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (showLoading) _isLoading = false;
        });
      }
    }
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

  Future<void> _openOperatorRenterRating(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    try {
      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TripRatingFlowScreen(
            bookingId: bookingId,
            reviewerRole: 'operator',
            title: 'Rate Renter',
            subtitle:
                'Your renter rating is required before this trip can continue to final completion.',
          ),
        ),
      );
      if (submitted != true) return;
      await _loadRecentBookings();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Renter rating saved. Waiting for the remaining required ratings.',
          ),
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

  Future<void> _confirmOperatorFinalPayment(
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    final actorId = _supabase.auth.currentUser?.id;
    if (bookingId.isEmpty || actorId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Full Payment'),
        content: const Text(
          'Confirm that the full rental balance and any late-return fee have been paid. This action unlocks the mandatory renter rating.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await BookingService().confirmFinalPayment(
        bookingId: bookingId,
        actorId: actorId,
        actorRole: 'operator',
      );
      await _loadRecentBookings();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full payment confirmed. Please rate the renter next.'),
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

  bool _isPartnerOwnedBooking(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final owner = vehicle?['owner'] as Map<String, dynamic>?;
    return owner?['role']?.toString().trim().toLowerCase() == 'partner' ||
        vehicle?['is_partner_vehicle'] == true ||
        vehicle?['partner_vehicle_id'] != null;
  }

  bool _canTrackBooking(Map<String, dynamic> booking) {
    return _isCompanyOwnedBooking(booking) &&
        bookingStatusGroup(booking['status']) == BookingStatusGroup.ongoing;
  }

  Future<void> _openBookingConversation(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    try {
      Map<String, dynamic>? conversation;
      for (final item in _conversations) {
        if (item['booking_id']?.toString() == bookingId) {
          conversation = item;
          break;
        }
      }

      if (conversation == null) {
        final operatorId = _supabase.auth.currentUser?.id;
        await BookingService().ensureBookingConversationForActiveBooking(
          bookingId: bookingId,
          operatorId: operatorId,
        );
        await _loadConversations();

        for (final item in _conversations) {
          if (item['booking_id']?.toString() == bookingId) {
            conversation = item;
            break;
          }
        }
      }

      // Realtime/list refreshes can arrive a little later than the insert.
      // Fetch the newly-created row directly so the Message action works now.
      if (conversation == null) {
        final rows = await _supabase
            .from('conversations')
            .select(
              'id, booking_id, user_id, other_user_id, status, created_at, updated_at',
            )
            .eq('booking_id', bookingId)
            .eq('status', 'active')
            .order('created_at', ascending: true)
            .limit(1);
        final directRows = List<Map<String, dynamic>>.from(rows);
        if (directRows.isNotEmpty) {
          conversation = {...directRows.first, 'bookings': booking};
          _conversations.removeWhere(
            (item) => item['booking_id']?.toString() == bookingId,
          );
          _conversations.insert(0, conversation);
        }
      }

      if (!mounted) return;
      final conversationId = conversation?['id']?.toString() ?? '';
      if (conversationId.isEmpty) {
        final status = booking['status']?.toString() ?? 'pending';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bookingStatusGroup(status) == BookingStatusGroup.pending
                  ? 'Finalize this booking first to open its group conversation.'
                  : 'The booking conversation could not be created. Please try again.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }

      setState(() {
        _selectedIndex = 2;
        _selectedConversationId = conversationId;
      });
      await _loadConversationMessages(conversationId);
    } catch (error) {
      debugPrint(
        '[Messages] Could not open conversation for $bookingId: $error',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to open the booking conversation right now.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _openTrackingForBooking(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty || !_canTrackBooking(booking)) return;

    setState(() {
      _selectedIndex = 6;
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
              operator_id,
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
                plate_number,
                owner_id,
                owner_role,
                operator_id,
                location,
                latitude,
                longitude,
                vehicle_name,
                price_per_day,
                transmission,
                vehicle_type,
                category,
                seats,
                owner:owner_id (
                  id,
                  full_name,
                  email,
                  phone,
                  location,
                  latitude,
                  longitude
                ),
                vehicle_images(id, image_url, display_order)
              ),
              renter:users!bookings_renter_id_fkey (
                id,
                full_name,
                email,
                phone,
                location,
                latitude,
                longitude,
                avatar_url,
                profile_picture_url
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

  Future<void> _loadOperatorRevenueBookings() async {
    final operatorId = _supabase.auth.currentUser?.id;
    if (operatorId == null || operatorId.isEmpty) {
      _operatorRevenueBookings = [];
      return;
    }

    try {
      final response = await _supabase
          .from('bookings')
          .select('''
            id,
            operator_id,
            status,
            total_price,
            total_cost,
            created_at,
            completed_at
          ''')
          .eq('operator_id', operatorId)
          .order('created_at', ascending: false);
      _operatorRevenueBookings = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading operator revenue analytics: $e');
      _operatorRevenueBookings = [];
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
                      '*, partners:partner_id(id,user_id,business_name,business_address,business_phone,users:user_id(full_name,email,phone))',
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
              ..['partner_email'] = partnerUser['email']
              ..['partner_phone'] =
                  partner['business_phone'] ?? partnerUser['phone']
              ..['partner_address'] = partner['business_address']
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
    if (directImageUrl.isNotEmpty) {
      return _normalizeVehicleImageUrl(directImageUrl);
    }

    final images = vehicle['vehicle_images'];
    if (images is! List) return '';

    for (final image in images) {
      if (image is! Map) continue;
      final imageMap = Map<String, dynamic>.from(image);
      final imageUrl = imageMap['image_url']?.toString().trim() ?? '';
      if (imageUrl.isNotEmpty) return _normalizeVehicleImageUrl(imageUrl);
    }

    return '';
  }

  String _normalizeVehicleImageUrl(String value) {
    var imageUrl = value.trim();
    if (imageUrl.isEmpty ||
        imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://') ||
        imageUrl.startsWith('data:')) {
      return imageUrl;
    }

    imageUrl = imageUrl.replaceFirst(RegExp(r'^/+'), '');
    if (imageUrl.startsWith('$_vehicleImagesBucket/')) {
      imageUrl = imageUrl.substring(_vehicleImagesBucket.length + 1);
    }
    return _supabase.storage.from(_vehicleImagesBucket).getPublicUrl(imageUrl);
  }

  String _notificationVehicleImageUrl(Map<String, dynamic> notification) {
    final target = resolveNotificationTarget(notification);
    final directImage =
        target.data['vehicle_image_url']?.toString().trim() ??
        target.data['image_url']?.toString().trim() ??
        '';
    if (directImage.isNotEmpty) return _normalizeVehicleImageUrl(directImage);

    final bookingId = target.bookingId;
    if (bookingId == null || bookingId.isEmpty) return '';
    for (final booking in _recentBookings) {
      if (booking['id']?.toString() != bookingId) continue;
      final vehicle = booking['vehicles'];
      if (vehicle is Map) {
        return _primaryVehicleImageUrl(Map<String, dynamic>.from(vehicle));
      }
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
      await Future.wait([
        _loadDashboardData(showLoading: false),
        _loadConversations(),
      ]);
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

  double? _coordinateValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '');
  }

  bool _isPartnerBookingVehicle(Map<String, dynamic> vehicle) =>
      vehicle['owner_role']?.toString().trim().toLowerCase() == 'partner';

  List<Map<String, double>> _driverProximityTargets(
    Map<String, dynamic> vehicle,
    Map<String, dynamic> renter,
  ) {
    final targets = <Map<String, double>>[];

    void addTarget(dynamic latitudeValue, dynamic longitudeValue) {
      final latitude = _coordinateValue(latitudeValue);
      final longitude = _coordinateValue(longitudeValue);
      if (latitude == null || longitude == null) return;
      final duplicate = targets.any(
        (target) =>
            (target['latitude']! - latitude).abs() < 0.000001 &&
            (target['longitude']! - longitude).abs() < 0.000001,
      );
      if (!duplicate) {
        targets.add({'latitude': latitude, 'longitude': longitude});
      }
    }

    addTarget(vehicle['latitude'], vehicle['longitude']);
    final owner = vehicle['owner'] as Map<String, dynamic>? ?? {};
    addTarget(owner['latitude'], owner['longitude']);
    addTarget(renter['latitude'], renter['longitude']);
    return targets;
  }

  void _showApproveDialog(Map<String, dynamic> booking) {
    final withDriver = _bookingNeedsDriver(booking['with_driver']);
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final partnerVehicle = _isPartnerBookingVehicle(vehicle);
    final bookingDate = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );
    final proximityTargets = partnerVehicle
        ? _driverProximityTargets(vehicle, renter)
        : const <Map<String, double>>[];
    final mapTargets = _driverProximityTargets(vehicle, renter);
    final driversFuture = BookingService().getAvailableVerifiedDrivers(
      bookingDate: bookingDate,
      proximityTargets: proximityTargets,
      prioritizeProximity: partnerVehicle,
    );

    showDialog(
      context: context,
      builder: (context) {
        String? selectedDriverId;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 940,
                  maxHeight: 700,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: _operatorNavyDeep,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 40,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 18, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _operatorGold,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      partnerVehicle
                                          ? 'PSDC PARTNER VEHICLE'
                                          : 'PSDC VEHICLE',
                                      style: const TextStyle(
                                        color: _operatorNavyDeep,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    withDriver
                                        ? 'Assign Professional Driver'
                                        : 'Finalize Booking',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    withDriver
                                        ? partnerVehicle
                                              ? 'Certified drivers ranked near the partner vehicle and renter for ${_vehicleTitle(vehicle)}.'
                                              : 'Available Mobilis by PSDC certified drivers for ${_vehicleTitle(vehicle)}.'
                                        : 'Confirm the reservation and create its booking conversation.',
                                    style: const TextStyle(
                                      color: Color(0xFF87A0B7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                      Expanded(
                        child: withDriver
                            ? FutureBuilder<List<Map<String, dynamic>>>(
                                future: driversFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: _operatorGold,
                                      ),
                                    );
                                  }
                                  final drivers = snapshot.data ?? [];
                                  if (drivers.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'No available certified drivers found',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    );
                                  }
                                  return ListView.separated(
                                    padding: const EdgeInsets.all(24),
                                    itemCount: drivers.length + 1,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        return _buildDriverCoverageSummary(
                                          booking: booking,
                                          vehicle: vehicle,
                                          partnerVehicle: partnerVehicle,
                                          drivers: drivers,
                                          mapTargets: mapTargets,
                                        );
                                      }
                                      final driver = drivers[index - 1];
                                      final driverId = driver['id'].toString();
                                      final user =
                                          driver['users']
                                              as Map<String, dynamic>? ??
                                          {};
                                      final name =
                                          user['full_name']?.toString() ??
                                          'Unknown driver';
                                      final selected =
                                          selectedDriverId == driverId;
                                      final rating =
                                          (driver['rating'] as num?)
                                              ?.toDouble() ??
                                          0;
                                      final trips =
                                          (driver['total_trips'] as num?)
                                              ?.toInt() ??
                                          0;
                                      final distance =
                                          (driver['distance_km'] as num?)
                                              ?.toDouble();
                                      return InkWell(
                                        onTap: () => setDialogState(
                                          () => selectedDriverId = driverId,
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? _operatorGold
                                                : Colors.white.withOpacity(
                                                    0.06,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                            border: Border.all(
                                              color: selected
                                                  ? _operatorGold
                                                  : Colors.white.withOpacity(
                                                      0.09,
                                                    ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 48,
                                                height: 48,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? _operatorNavy
                                                      : const Color(0xFF173D5B),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Text(
                                                  name.isEmpty
                                                      ? '?'
                                                      : name[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        color: selected
                                                            ? _operatorNavyDeep
                                                            : Colors.white,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Text(
                                                      [
                                                        '$trips completed trips',
                                                        '${rating.toStringAsFixed(1)} rating',
                                                        if (distance != null)
                                                          '${distance.toStringAsFixed(1)} km away',
                                                      ].join('  |  '),
                                                      style: TextStyle(
                                                        color: selected
                                                            ? _operatorNavy
                                                            : const Color(
                                                                0xFF8CA5BB,
                                                              ),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                selected
                                                    ? Icons.check_circle
                                                    : Icons.circle_outlined,
                                                color: selected
                                                    ? _operatorNavy
                                                    : Colors.white38,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(
                                  Icons.verified_outlined,
                                  color: _operatorGold,
                                  size: 72,
                                ),
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(22),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text('Discard'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (withDriver && selectedDriverId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select an available driver',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(context);
                                _approveBooking(
                                  booking,
                                  driverId: selectedDriverId,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _operatorGold,
                                foregroundColor: _operatorNavyDeep,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 26,
                                  vertical: 16,
                                ),
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                withDriver
                                    ? 'Finalize Assignment'
                                    : 'Finalize Booking',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDriverCoverageSummary({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> vehicle,
    required bool partnerVehicle,
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, double>> mapTargets,
  }) {
    final pickup = booking['pickup_location']?.toString().trim();
    final vehicleLocation = vehicle['location']?.toString().trim();
    final referenceLocation = pickup?.isNotEmpty == true
        ? pickup!
        : vehicleLocation?.isNotEmpty == true
        ? vehicleLocation!
        : 'Location coordinates are not yet available';
    final mapMarkers = <MobilisMapMarker>[
      ...mapTargets.map(
        (target) => MobilisMapMarker(
          latitude: target['latitude']!,
          longitude: target['longitude']!,
          icon: Icons.directions_car_filled_rounded,
          color: _operatorGold,
          size: 40,
        ),
      ),
      ...drivers.take(8).expand((driver) {
        final user = driver['users'] as Map<String, dynamic>? ?? {};
        final latitude = _coordinateValue(user['latitude']);
        final longitude = _coordinateValue(user['longitude']);
        if (latitude == null || longitude == null) {
          return const <MobilisMapMarker>[];
        }
        return [
          MobilisMapMarker(
            latitude: latitude,
            longitude: longitude,
            icon: Icons.person_pin_circle_rounded,
            color: AppColors.success,
            size: 34,
          ),
        ];
      }),
    ];
    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF082944),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: mapMarkers.isEmpty
                ? Container(
                    color: const Color(0xFF06233A),
                    child: const Center(
                      child: Icon(
                        Icons.map_outlined,
                        color: Color(0xFF46677F),
                        size: 50,
                      ),
                    ),
                  )
                : MobilisLeafletMap(
                    markers: mapMarkers,
                    initialZoom: mapMarkers.length > 1 ? 10 : 14,
                  ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _operatorGold.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_searching_rounded,
                      color: _operatorGold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    partnerVehicle
                        ? 'Partner and renter proximity'
                        : 'PSDC certified driver pool',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    referenceLocation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF91A9BE),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${drivers.length} eligible  |  '
                    '${partnerVehicle && mapTargets.isNotEmpty ? 'Nearest first' : 'Availability verified'}',
                    style: const TextStyle(
                      color: _operatorGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

  void _showRejectDialog(String bookingId) {
    final reasonController = TextEditingController();
    const reasons = [
      'Vehicle unavailable',
      'Incomplete renter documents',
      'Safety policy violation',
      'Maintenance schedule conflict',
      'Other',
    ];

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String selectedReason = reasons.first;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final surface = isDark
                ? const Color(0xFF263247)
                : const Color(0xFFF5F6F8);
            final border = isDark
                ? const Color(0xFF46536A)
                : const Color(0xFFD6DAE1);
            final secondary = isDark
                ? Colors.blueGrey.shade200
                : Colors.blueGrey.shade700;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 540,
                  maxHeight: 760,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 12, 18),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Decline Reservation',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Select a clear reason for the renter.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: border.withOpacity(0.65)),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reason for decline',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...reasons.map((reason) {
                              final selected = selectedReason == reason;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: selected
                                      ? _operatorGold.withOpacity(0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: () => setDialogState(
                                      () => selectedReason = reason,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: selected
                                              ? _operatorGold
                                              : border,
                                          width: selected ? 1.5 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 160,
                                            ),
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: selected
                                                    ? _operatorGold
                                                    : secondary,
                                                width: 2,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: selected
                                                ? Container(
                                                    width: 9,
                                                    height: 9,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: _operatorGold,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              reason,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            const Text(
                              'Additional comments for renter',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: reasonController,
                              minLines: 3,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText:
                                    'Provide details to help the renter understand the decision...',
                                hintStyle: TextStyle(color: secondary),
                                filled: true,
                                fillColor: surface,
                                contentPadding: const EdgeInsets.all(16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: _operatorGold,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'The selected reason and comments will be included in the renter notification.',
                              style: TextStyle(
                                color: secondary,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: border.withOpacity(0.65)),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                ),
                                child: const Text('Go Back'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final comments = reasonController.text.trim();
                                  final reason = comments.isEmpty
                                      ? selectedReason
                                      : '$selectedReason: $comments';
                                  Navigator.pop(dialogContext);
                                  _rejectBooking(bookingId, reason);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.block_outlined,
                                  size: 17,
                                ),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Confirm Decline',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
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
          },
        );
      },
    ).whenComplete(reasonController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 980;

    return Theme(
      data: WebPortalTheme.resolve(context, isDark: isDark),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF101827) : _operatorPage,
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
      ),
    );
  }

  Widget _buildSidebar(bool isDark, bool isCompact) {
    final expanded = _sidebarExpanded && !isCompact;
    final sidebarWidth = expanded ? 252.0 : 76.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: _operatorNavyDeep,
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 92,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 20 : 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _operatorGold,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Image.asset(
                    'assets/icon/logo-black.png',
                    fit: BoxFit.contain,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PSDC Operator',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'VEHICLE MANAGEMENT',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w600,
                            color: _operatorGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                _buildNavItem(0, Icons.grid_view_rounded, 'Home', isDark),
                _buildNavItem(
                  1,
                  Icons.calendar_month_outlined,
                  'Bookings',
                  isDark,
                ),
                _buildNavItem(
                  2,
                  Icons.chat_bubble_outline_rounded,
                  'Messages',
                  isDark,
                ),
                _buildNavItem(
                  3,
                  Icons.notifications_none_rounded,
                  'Notifications',
                  isDark,
                  badge:
                      _notifications.where((n) => n['is_read'] == false).isEmpty
                      ? null
                      : _notifications
                            .where((n) => n['is_read'] == false)
                            .length,
                ),
                _buildNavItem(
                  4,
                  Icons.directions_car_outlined,
                  'Vehicles',
                  isDark,
                ),
                _buildNavItem(
                  6,
                  Icons.location_on_outlined,
                  'Live Tracking',
                  isDark,
                  badge: _trackingLocations.isEmpty
                      ? null
                      : _trackingLocations.length,
                ),
                _buildNavItem(
                  7,
                  Icons.account_balance_wallet_outlined,
                  'Revenue',
                  isDark,
                ),
                const SizedBox(height: 20),
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Text(
                      'SETTINGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7991A5),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                _buildNavItem(5, Icons.settings_outlined, 'Settings', isDark),
              ],
            ),
          ),
          InkWell(
            onTap: isCompact
                ? null
                : () => setState(() => _sidebarExpanded = !_sidebarExpanded),
            child: Container(
              height: isCompact ? 12 : 44,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.center,
                children: [
                  if (!isCompact)
                    Icon(
                      expanded ? Icons.chevron_left : Icons.chevron_right,
                      color: const Color(0xFF8CA0B2),
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
    final expanded =
        _sidebarExpanded && MediaQuery.of(context).size.width >= 980;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _selectNavigationIndex(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0),
          decoration: BoxDecoration(
            color: isSelected ? _operatorGold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? _operatorNavyDeep : const Color(0xFF9CB0C2),
                size: 21,
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? _operatorNavyDeep
                          : const Color(0xFFC4D0DB),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 14,
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

  void _selectNavigationIndex(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
    if (index == 2) {
      _loadConversations();
    }
  }

  Future<void> _refreshCurrentSection() async {
    if (_selectedIndex == 2) {
      await _loadConversations();
      return;
    }
    await _loadDashboardData(showLoading: false);
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172235) : Colors.white,
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
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : _operatorInk,
            ),
          ),
          const SizedBox(width: 34),
          if (MediaQuery.of(context).size.width >= 1250)
            SizedBox(
              width: 350,
              height: 42,
              child: TextField(
                onChanged: (value) {
                  if (_selectedIndex == 1) {
                    setState(() => _bookingSearchQuery = value.trim());
                  } else if (_selectedIndex == 4) {
                    setState(() => _vehicleSearchQuery = value.trim());
                  }
                },
                decoration: InputDecoration(
                  hintText: switch (_selectedIndex) {
                    1 => 'Search booking ID, renter, or vehicle...',
                    4 => 'Search vehicle, plate, or owner...',
                    _ => 'Search operations...',
                  },
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFF0F2F4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: isDark ? 'Use light theme' : 'Use dark theme',
            onPressed: () => widget.onThemeToggle?.call(!isDark),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _refreshCurrentSection,
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 1,
            height: 30,
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          const SizedBox(width: 18),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _handleLogout();
            },
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _operatorGold,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operator',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : _operatorInk,
                      ),
                    ),
                    Text(
                      'Operations Desk',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_drop_down,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ],
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(
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
      case 7:
        return 'Revenue & Analytics';
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
      case 7:
        return _buildRevenueContent(isDark);
      default:
        return _buildDashboardContent(isDark);
    }
  }

  Widget _buildDashboardContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Operations Summary',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : _operatorInk,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7D6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: _operatorGold),
                    SizedBox(width: 7),
                    Text(
                      'LIVE SYSTEM STATUS',
                      style: TextStyle(
                        color: _operatorInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 18)) / columns;
              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  SizedBox(
                    width: width,
                    child: _buildStatCard(
                      'Active Trips',
                      _activeBookings.toString(),
                      Icons.route_outlined,
                      _operatorNavy,
                      isDark,
                      onTap: () => _openDashboardSection(
                        selectedIndex: 1,
                        bookingFilter: 'ongoing',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildStatCard(
                      'Pending Assignments',
                      _recentBookings
                          .where(
                            (booking) =>
                                bookingStatusGroup(booking['status']) ==
                                BookingStatusGroup.pending,
                          )
                          .length
                          .toString(),
                      Icons.assignment_late_outlined,
                      const Color(0xFFC62828),
                      isDark,
                      onTap: () => _openDashboardSection(
                        selectedIndex: 1,
                        bookingFilter: 'pending',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildStatCard(
                      'Vehicles',
                      _totalVehicles.toString(),
                      Icons.directions_car_outlined,
                      const Color(0xFF2E7D32),
                      isDark,
                      onTap: () => _openDashboardSection(selectedIndex: 4),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildStatCard(
                      'Total Bookings',
                      _totalBookings.toString(),
                      Icons.fact_check_outlined,
                      const Color(0xFF886A00),
                      isDark,
                      onTap: () => _openDashboardSection(
                        selectedIndex: 1,
                        bookingFilter: 'all',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          _buildCard(
            'Live Booking Queue',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incoming and recent requests awaiting operator action',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                Scrollbar(
                  controller: _dashboardQueueScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _dashboardQueueScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildBookingsTable(isDark),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedIndex = 1),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                    label: const Text('View all bookings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : _operatorInk,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            isDark,
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
    bool isDark, {
    VoidCallback? onTap,
  }) {
    final borderRadius = BorderRadius.circular(18);
    return Semantics(
      button: onTap != null,
      label: onTap == null ? null : 'Open $title',
      child: Material(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          mouseCursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          borderRadius: borderRadius,
          hoverColor: _operatorGold.withOpacity(0.08),
          child: Container(
            constraints: const BoxConstraints(minHeight: 132),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
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
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : _operatorInk,
                        ),
                      ),
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDashboardSection({
    required int selectedIndex,
    String? bookingFilter,
  }) {
    setState(() {
      _selectedIndex = selectedIndex;
      if (bookingFilter != null) {
        _bookingFilter = bookingFilter;
        _bookingPage = 0;
        _bookingSearchQuery = '';
        _bookingSearchController.clear();
      }
    });
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

  List<Map<String, dynamic>> _operatorManagedBookings() {
    final operatorId = _supabase.auth.currentUser?.id;
    if (operatorId == null || operatorId.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    return _operatorRevenueBookings;
  }

  double _bookingAmount(Map<String, dynamic> booking) {
    return (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0;
  }

  Widget _buildRevenueContent(bool isDark) {
    final managed = _operatorManagedBookings();
    final completed = managed
        .where(
          (booking) =>
              bookingStatusGroup(booking['status']) ==
              BookingStatusGroup.completed,
        )
        .toList();
    final active = managed.where((booking) {
      final group = bookingStatusGroup(booking['status']);
      return group == BookingStatusGroup.approved ||
          group == BookingStatusGroup.ongoing;
    }).length;
    final processedRevenue = completed.fold<double>(
      0,
      (total, booking) => total + _bookingAmount(booking),
    );
    final averageValue = completed.isEmpty
        ? 0.0
        : processedRevenue / completed.length;
    final now = DateTime.now();
    final monthly = List.generate(6, (index) {
      final monthDate = DateTime(now.year, now.month - (5 - index));
      final monthBookings = managed.where((booking) {
        final date = DateTime.tryParse(
          (booking['completed_at'] ?? booking['created_at'])?.toString() ?? '',
        )?.toLocal();
        return date != null &&
            date.year == monthDate.year &&
            date.month == monthDate.month;
      }).toList();
      return <String, dynamic>{
        'label': _getMonthName(monthDate.month),
        'count': monthBookings.length,
        'amount': monthBookings.fold<double>(
          0,
          (total, booking) => total + _bookingAmount(booking),
        ),
      };
    });
    final maxMonthly = monthly.fold<double>(
      1,
      (maximum, item) => (item['amount'] as double) > maximum
          ? item['amount'] as double
          : maximum,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operator Revenue & Analytics',
            style: TextStyle(
              color: isDark ? Colors.white : _operatorInk,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Only bookings assigned to and managed by this operator are included.',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050
                  ? 4
                  : constraints.maxWidth >= 580
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 16)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _buildRevenueMetricCard(
                      'Managed Bookings',
                      managed.length.toString(),
                      'Bookings assisted by you',
                      Icons.assignment_turned_in_outlined,
                      _operatorNavy,
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildRevenueMetricCard(
                      'Active Trips',
                      active.toString(),
                      'Approved or ongoing',
                      Icons.route_outlined,
                      const Color(0xFF1976D2),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildRevenueMetricCard(
                      'Processed Value',
                      'PHP ${processedRevenue.toStringAsFixed(2)}',
                      '${completed.length} completed transactions',
                      Icons.account_balance_wallet_outlined,
                      const Color(0xFF2E7D32),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildRevenueMetricCard(
                      'Average Booking',
                      'PHP ${averageValue.toStringAsFixed(2)}',
                      'Completed bookings only',
                      Icons.insights_outlined,
                      const Color(0xFF886A00),
                      isDark,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final chart = Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderColor
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Managed Booking Value',
                      style: TextStyle(
                        color: isDark ? Colors.white : _operatorInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last six months based on your managed bookings',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: monthly.map((item) {
                          final amount = item['amount'] as double;
                          final ratio = amount / maxMonthly;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item['count']}',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : _operatorInk,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    height: 24 + (140 * ratio),
                                    decoration: BoxDecoration(
                                      color: _operatorGold,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item['label'].toString(),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
              final breakdown = _buildOperatorRevenueBreakdown(
                managed,
                completed,
                isDark,
              );
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [chart, const SizedBox(height: 16), breakdown],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: chart),
                  const SizedBox(width: 16),
                  Expanded(child: breakdown),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueMetricCard(
    String label,
    String value,
    String caption,
    IconData icon,
    Color accent,
    bool isDark,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontSize: 9,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            caption,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorRevenueBreakdown(
    List<Map<String, dynamic>> managed,
    List<Map<String, dynamic>> completed,
    bool isDark,
  ) {
    final pending = managed
        .where(
          (booking) =>
              bookingStatusGroup(booking['status']) ==
              BookingStatusGroup.pending,
        )
        .length;
    final cancelled = managed
        .where(
          (booking) =>
              bookingStatusGroup(booking['status']) ==
              BookingStatusGroup.cancelled,
        )
        .length;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _operatorNavy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _buildRevenueBreakdownLine('Completed', completed.length),
          _buildRevenueBreakdownLine('Pending review', pending),
          _buildRevenueBreakdownLine('Cancelled', cancelled),
          _buildRevenueBreakdownLine('All managed', managed.length),
          const SizedBox(height: 14),
          const Text(
            'Analytics are operational records, not operator commission or payout.',
            style: TextStyle(
              color: Color(0xFF9CB1C3),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdownLine(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFB8C6D2), fontSize: 12),
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: _operatorGold,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingContent(bool isDark) {
    final visibleLocations = _visibleTrackingLocations();
    final mapMarkers = visibleLocations
        .where(
          (location) =>
              location['latitude'] is num && location['longitude'] is num,
        )
        .take(50)
        .map(
          (location) => MobilisMapMarker(
            latitude: (location['latitude'] as num).toDouble(),
            longitude: (location['longitude'] as num).toDouble(),
            icon: Icons.directions_car_filled_rounded,
            color: AppColors.primary,
            size: 40,
          ),
        )
        .toList();

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
                child: mapMarkers.isEmpty
                    ? Center(
                        child: Text(
                          'No active company tracking locations yet',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                      )
                    : MobilisLeafletMap(
                        markers: mapMarkers,
                        initialZoom: mapMarkers.length > 1 ? 10 : 14,
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

  Widget _buildBookingsTable(bool isDark) {
    final queueBookings = _recentBookings.where((booking) {
      final group = bookingStatusGroup(booking['status']);
      return group == BookingStatusGroup.pending ||
          group == BookingStatusGroup.approved ||
          group == BookingStatusGroup.ongoing;
    }).toList();
    queueBookings.sort((a, b) {
      int priority(Map<String, dynamic> booking) {
        return switch (bookingStatusGroup(booking['status'])) {
          BookingStatusGroup.pending => 0,
          BookingStatusGroup.approved => 1,
          BookingStatusGroup.ongoing => 2,
          _ => 3,
        };
      }

      final statusOrder = priority(a).compareTo(priority(b));
      if (statusOrder != 0) return statusOrder;
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
    });

    if (queueBookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 44,
                color: isDark ? Colors.grey[600] : Colors.grey.shade300,
              ),
              const SizedBox(height: 10),
              Text(
                'The live queue is clear',
                style: TextStyle(
                  color: isDark ? Colors.white : _operatorInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'New, approved, and ongoing bookings will appear here.',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalPages = (queueBookings.length / _dashboardQueuePageSize).ceil();
    final safePage = _dashboardQueuePage.clamp(0, totalPages - 1);
    final firstRecord = safePage * _dashboardQueuePageSize;
    final visible = queueBookings
        .skip(firstRecord)
        .take(_dashboardQueuePageSize)
        .toList();
    return SizedBox(
      width: 1430,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : const Color(0xFFF5F7F9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildQueueHeader('Booking', 2, isDark),
                _buildQueueHeader('Vehicle', 3, isDark),
                _buildQueueHeader('Renter', 3, isDark),
                _buildQueueHeader('Schedule', 4, isDark),
                _buildQueueHeader('Service', 3, isDark),
                _buildQueueHeader('Driver', 3, isDark),
                _buildQueueHeader('Amount', 2, isDark),
                _buildQueueHeader('Status', 2, isDark),
                _buildQueueHeader('Actions', 5, isDark),
              ],
            ),
          ),
          ...visible.map((booking) => _buildDetailedQueueRow(booking, isDark)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : const Color(0xFFFAFBFC),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Showing ${firstRecord + 1}-${firstRecord + visible.length} of ${queueBookings.length} bookings',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildDashboardQueuePagination(
                  currentPage: safePage,
                  totalPages: totalPages,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueHeader(String label, int flex, bool isDark) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
          fontSize: 9,
          letterSpacing: 0.65,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildDetailedQueueRow(Map<String, dynamic> booking, bool isDark) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final driver = booking['driver'] as Map<String, dynamic>?;
    final driverUser = driver?['user'] as Map<String, dynamic>?;
    final bookingId = booking['id']?.toString() ?? '';
    final shortId = bookingId.length > 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();
    final start = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );
    final end = DateTime.tryParse(
      (booking['end_at'] ?? booking['end_date'])?.toString() ?? '',
    );
    final needsDriver = _bookingNeedsDriver(booking['with_driver']);
    final deliveryFee = (booking['delivery_fee'] as num?)?.toDouble() ?? 0;
    final plateNumber = vehicle['plate_number']?.toString().trim() ?? '';
    final service = needsDriver
        ? 'Professional driver'
        : deliveryFee > 0
        ? 'Vehicle delivery'
        : 'Self-pickup';
    final assignmentStatus = _latestDriverAssignment(
      booking,
    )?['status']?.toString().trim().toLowerCase();
    final driverName = driverUser?['full_name']?.toString().trim();
    final driverLabel = !needsDriver
        ? 'Not required'
        : driverName?.isNotEmpty == true
        ? driverName!
        : assignmentStatus == 'pending_offer' || assignmentStatus == 'assigned'
        ? 'Awaiting response'
        : assignmentStatus == 'rejected'
        ? 'Reselection needed'
        : 'Unassigned';
    final foreground = isDark ? Colors.white : _operatorInk;
    final muted = isDark ? Colors.grey[400] : Colors.grey.shade600;
    Widget cell(Widget child, int flex) => Expanded(flex: flex, child: child);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          cell(
            Text(
              '#$shortId',
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            2,
          ),
          cell(
            Row(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  color: _operatorGold,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _vehicleTitle(vehicle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        plateNumber.isEmpty ? 'No plate' : plateNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            3,
          ),
          cell(
            _buildOperatorPersonCell(
              renter['full_name']?.toString() ?? 'Unknown renter',
              renter['email']?.toString() ?? 'Renter',
              foreground,
              muted ?? Colors.grey,
              avatarUrl: _operatorUserAvatarUrl(renter),
            ),
            3,
          ),
          cell(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatBookingDateTime(start),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Return: ${_formatBookingDateTime(end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 9),
                ),
              ],
            ),
            4,
          ),
          cell(
            Text(
              service,
              style: TextStyle(
                color: foreground,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            3,
          ),
          cell(
            Text(
              driverLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: needsDriver && driverName?.isNotEmpty != true
                    ? Colors.orange.shade400
                    : foreground,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            3,
          ),
          cell(
            Text(
              'PHP ${_bookingAmount(booking).toStringAsFixed(2)}',
              style: TextStyle(
                color: foreground,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            2,
          ),
          cell(
            Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusBadge(
                booking['status']?.toString() ?? 'pending',
              ),
            ),
            2,
          ),
          cell(_buildOperatorBookingActions(booking, isDark, compact: true), 5),
        ],
      ),
    );
  }

  Widget _buildDashboardQueuePagination({
    required int currentPage,
    required int totalPages,
    required bool isDark,
  }) {
    final pageItems = _dashboardQueuePageItems(currentPage, totalPages);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dashboardQueuePageButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous page',
          enabled: currentPage > 0,
          isDark: isDark,
          onTap: () => setState(() => _dashboardQueuePage = currentPage - 1),
        ),
        const SizedBox(width: 5),
        for (final page in pageItems) ...[
          if (page == -1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Text(
                '...',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            _dashboardQueuePageButton(
              label: '${page + 1}',
              selected: page == currentPage,
              enabled: true,
              isDark: isDark,
              onTap: () => setState(() => _dashboardQueuePage = page),
            ),
          const SizedBox(width: 5),
        ],
        _dashboardQueuePageButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next page',
          enabled: currentPage < totalPages - 1,
          isDark: isDark,
          onTap: () => setState(() => _dashboardQueuePage = currentPage + 1),
        ),
      ],
    );
  }

  List<int> _dashboardQueuePageItems(int currentPage, int totalPages) {
    if (totalPages <= 7)
      return List<int>.generate(totalPages, (index) => index);

    final pages = <int>{0, totalPages - 1};
    for (var page = currentPage - 1; page <= currentPage + 1; page++) {
      if (page > 0 && page < totalPages - 1) pages.add(page);
    }
    final sorted = pages.toList()..sort();
    final items = <int>[];
    for (var index = 0; index < sorted.length; index++) {
      if (index > 0 && sorted[index] - sorted[index - 1] > 1) items.add(-1);
      items.add(sorted[index]);
    }
    return items;
  }

  Widget _dashboardQueuePageButton({
    String? label,
    IconData? icon,
    String? tooltip,
    required bool enabled,
    required bool isDark,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final foreground = selected
        ? _operatorNavyDeep
        : isDark
        ? Colors.grey.shade300
        : _operatorInk;
    final button = InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _operatorGold
              : isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? _operatorGold
                : isDark
                ? Colors.white12
                : Colors.grey.shade300,
          ),
        ),
        child: icon != null
            ? Icon(
                icon,
                size: 18,
                color: enabled ? foreground : foreground.withOpacity(0.3),
              )
            : Text(
                label ?? '',
                style: TextStyle(
                  color: enabled ? foreground : foreground.withOpacity(0.3),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _buildStatusBadge(String status) {
    final group = bookingStatusGroup(status);
    final color = bookingStatusColor(group);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        bookingStatusLabel(group).toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w800,
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
    final filteredBookings = _recentBookings.where((booking) {
      final matchesStatus = _bookingFilterMatches(booking, _bookingFilter);
      if (!matchesStatus) return false;
      if (!_bookingDateFilterMatches(booking, _bookingDateFilter)) return false;
      if (!_bookingVehicleTypeFilterMatches(
        booking,
        _bookingVehicleTypeFilter,
      )) {
        return false;
      }
      final query = _bookingSearchQuery.toLowerCase();
      if (query.isEmpty) return true;
      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final renter = booking['renter'] as Map<String, dynamic>? ?? {};
      final haystack = [
        booking['id'],
        renter['full_name'],
        renter['email'],
        _vehicleTitle(vehicle),
        vehicle['plate_number'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    final totalPages = filteredBookings.isEmpty
        ? 1
        : ((filteredBookings.length - 1) ~/ _bookingPageSize) + 1;
    final safePage = _bookingPage.clamp(0, totalPages - 1);
    final pagedBookings = filteredBookings
        .skip(safePage * _bookingPageSize)
        .take(_bookingPageSize)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bookings Management',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : _operatorInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review reservations, assign drivers, and monitor trips.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : _operatorInk,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildBookingFilterTab('all', 'All Bookings', isDark),
                  _buildBookingFilterTab('pending', 'Pending', isDark),
                  _buildBookingFilterTab('approved', 'Approved', isDark),
                  _buildBookingFilterTab('ongoing', 'Ongoing', isDark),
                  _buildBookingFilterTab('completed', 'Completed', isDark),
                  _buildBookingFilterTab('cancelled', 'Cancelled', isDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildBookingReportFilters(filteredBookings, isDark),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bookingSearchController,
                    onChanged: (value) => setState(() {
                      _bookingSearchQuery = value.trim();
                      _bookingPage = 0;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search booking ID, renter, or vehicle',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : const Color(0xFFF2F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${filteredBookings.length} result${filteredBookings.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildOperatorBookingsResult(
            pagedBookings,
            isDark,
            totalFiltered: filteredBookings.length,
            currentPage: safePage,
            totalPages: totalPages,
          ),
        ],
      ),
    );
  }

  bool _bookingFilterMatches(Map<String, dynamic> booking, String filter) {
    if (filter == 'all') return true;
    final group = bookingStatusGroup(booking['status']);
    return switch (filter) {
      'pending' => group == BookingStatusGroup.pending,
      'approved' => group == BookingStatusGroup.approved,
      'ongoing' => group == BookingStatusGroup.ongoing,
      'completed' => group == BookingStatusGroup.completed,
      'cancelled' => group == BookingStatusGroup.cancelled,
      _ => true,
    };
  }

  bool _bookingDateFilterMatches(Map<String, dynamic> booking, String filter) {
    if (filter == 'all') return true;
    final start = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    )?.toLocal();
    if (start == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDay = DateTime(start.year, start.month, start.day);
    return switch (filter) {
      'today' => bookingDay == today,
      'next7' =>
        !bookingDay.isBefore(today) &&
            bookingDay.isBefore(today.add(const Duration(days: 8))),
      'next30' =>
        !bookingDay.isBefore(today) &&
            bookingDay.isBefore(today.add(const Duration(days: 31))),
      'past30' =>
        !bookingDay.isAfter(today) &&
            bookingDay.isAfter(today.subtract(const Duration(days: 31))),
      _ => true,
    };
  }

  bool _bookingVehicleTypeFilterMatches(
    Map<String, dynamic> booking,
    String filter,
  ) {
    if (filter == 'all') return true;
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final type = (vehicle['vehicle_type'] ?? vehicle['category'])
        ?.toString()
        .trim()
        .toLowerCase();
    return type == filter;
  }

  List<String> get _bookingVehicleTypeOptions {
    final types =
        _recentBookings
            .map((booking) {
              final vehicle =
                  booking['vehicles'] as Map<String, dynamic>? ?? {};
              return (vehicle['vehicle_type'] ?? vehicle['category'])
                  ?.toString()
                  .trim()
                  .toLowerCase();
            })
            .whereType<String>()
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['all', ...types];
  }

  String _bookingFilterDisplayName(String value) {
    if (value == 'all') return 'All Types';
    return value
        .split(RegExp(r'[\s_-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Widget _buildBookingReportFilters(
    List<Map<String, dynamic>> filteredBookings,
    bool isDark,
  ) {
    final foreground = isDark ? Colors.grey[300] : Colors.grey.shade700;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list_rounded, size: 17, color: foreground),
              const SizedBox(width: 7),
              Text(
                'Filter by:',
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          _buildBookingDropdownFilter(
            value: _bookingDateFilter,
            items: const {
              'all': 'Date Range: All Dates',
              'today': 'Date Range: Today',
              'next7': 'Date Range: Next 7 Days',
              'next30': 'Date Range: Next 30 Days',
              'past30': 'Date Range: Past 30 Days',
            },
            isDark: isDark,
            onChanged: (value) => setState(() {
              _bookingDateFilter = value;
              _bookingPage = 0;
            }),
          ),
          _buildBookingDropdownFilter(
            value: _bookingVehicleTypeFilter,
            items: {
              for (final type in _bookingVehicleTypeOptions)
                type: 'Vehicle: ${_bookingFilterDisplayName(type)}',
            },
            isDark: isDark,
            onChanged: (value) => setState(() {
              _bookingVehicleTypeFilter = value;
              _bookingPage = 0;
            }),
          ),
          ElevatedButton.icon(
            onPressed: filteredBookings.isEmpty
                ? null
                : () => _exportBookingsReport(filteredBookings),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? _operatorGold : _operatorNavy,
              foregroundColor: isDark ? _operatorNavyDeep : Colors.white,
              disabledBackgroundColor: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade200,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(Icons.download_rounded, size: 17),
            label: const Text(
              'Export Report',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDropdownFilter({
    required String value,
    required Map<String, String> items,
    required bool isDark,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = items.containsKey(value) ? value : items.keys.first;
    return Container(
      height: 42,
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: isDark ? AppColors.darkCard : Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: TextStyle(
            color: isDark ? Colors.white : _operatorInk,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          items: items.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (nextValue) {
            if (nextValue != null) onChanged(nextValue);
          },
        ),
      ),
    );
  }

  Future<void> _exportBookingsReport(
    List<Map<String, dynamic>> bookings,
  ) async {
    String csvCell(Object? value) {
      final text = value?.toString() ?? '';
      return '"${text.replaceAll('"', '""')}"';
    }

    final rows = <String>[
      [
        'Booking ID',
        'Renter',
        'Vehicle',
        'Vehicle Type',
        'Plate Number',
        'Schedule',
        'Status',
        'Total',
      ].map(csvCell).join(','),
      ...bookings.map((booking) {
        final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
        final renter = booking['renter'] as Map<String, dynamic>? ?? {};
        final start = DateTime.tryParse(
          (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
        );
        return [
          booking['id'],
          renter['full_name'],
          _vehicleTitle(vehicle),
          vehicle['vehicle_type'] ?? vehicle['category'],
          vehicle['plate_number'],
          _formatBookingDateTime(start),
          bookingStatusLabel(bookingStatusGroup(booking['status'])),
          booking['total_price'] ?? booking['total_cost'] ?? 0,
        ].map(csvCell).join(',');
      }),
    ];
    final bytes = Uint8List.fromList(utf8.encode(rows.join('\r\n')));
    final date = DateTime.now().toIso8601String().split('T').first;

    try {
      if (kIsWeb) {
        await FilePicker.platform.saveFile(
          dialogTitle: 'Export booking report',
          fileName: 'mobilis-bookings-$date.csv',
          bytes: bytes,
        );
      } else {
        await Clipboard.setData(ClipboardData(text: rows.join('\r\n')));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Booking report exported successfully.'
                  : 'Booking report copied to the clipboard.',
            ),
          ),
        );
      }
    } catch (error) {
      _showErrorSnackBar('Could not export booking report: $error');
    }
  }

  int _bookingFilterCount(String filter) {
    return _recentBookings
        .where((booking) => _bookingFilterMatches(booking, filter))
        .length;
  }

  Widget _buildBookingFilterTab(String value, String label, bool isDark) {
    final selected = _bookingFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: () => setState(() {
          _bookingFilter = value;
          _bookingPage = 0;
        }),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? _operatorGold : _operatorNavy)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$label (${_bookingFilterCount(value)})',
            style: TextStyle(
              color: selected
                  ? (isDark ? _operatorNavyDeep : Colors.white)
                  : (isDark ? Colors.grey[300] : Colors.grey.shade700),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorBookingsResult(
    List<Map<String, dynamic>> bookings,
    bool isDark, {
    required int totalFiltered,
    required int currentPage,
    required int totalPages,
  }) {
    if (bookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _operatorGold.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.event_busy_outlined,
                color: _operatorNavy,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No matching bookings',
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Try another status or clear the search field.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              ...bookings.map(
                (booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOperatorBookingCard(booking, isDark),
                ),
              ),
              _buildOperatorBookingPaginationFooter(
                visibleCount: bookings.length,
                totalFiltered: totalFiltered,
                currentPage: currentPage,
                totalPages: totalPages,
                isDark: isDark,
              ),
            ],
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade200,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildOperatorBookingTableHeader(isDark),
              ...bookings.map(
                (booking) => _buildOperatorBookingTableRow(booking, isDark),
              ),
              _buildOperatorBookingPaginationFooter(
                visibleCount: bookings.length,
                totalFiltered: totalFiltered,
                currentPage: currentPage,
                totalPages: totalPages,
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOperatorBookingPaginationFooter({
    required int visibleCount,
    required int totalFiltered,
    required int currentPage,
    required int totalPages,
    required bool isDark,
  }) {
    final firstItem = totalFiltered == 0
        ? 0
        : (currentPage * _bookingPageSize) + 1;
    final lastItem = totalFiltered == 0 ? 0 : firstItem + visibleCount - 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.025)
            : const Color(0xFFFAFBFC),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Text(
            'Showing $firstItem-$lastItem of $totalFiltered bookings',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (totalPages > 1)
            _buildOperatorBookingPagination(
              currentPage: currentPage,
              totalPages: totalPages,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildOperatorBookingPagination({
    required int currentPage,
    required int totalPages,
    required bool isDark,
  }) {
    final pageItems = _dashboardQueuePageItems(currentPage, totalPages);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dashboardQueuePageButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous page',
          enabled: currentPage > 0,
          isDark: isDark,
          onTap: () => setState(() => _bookingPage = currentPage - 1),
        ),
        const SizedBox(width: 5),
        for (final page in pageItems) ...[
          if (page == -1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Text(
                '...',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            _dashboardQueuePageButton(
              label: '${page + 1}',
              selected: page == currentPage,
              enabled: true,
              isDark: isDark,
              onTap: () => setState(() => _bookingPage = page),
            ),
          const SizedBox(width: 5),
        ],
        _dashboardQueuePageButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next page',
          enabled: currentPage < totalPages - 1,
          isDark: isDark,
          onTap: () => setState(() => _bookingPage = currentPage + 1),
        ),
      ],
    );
  }

  Widget _buildOperatorBookingTableHeader(bool isDark) {
    Widget label(String text, int flex) => Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
          fontSize: 10,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF7F8FA),
      child: Row(
        children: [
          label('Booking ID', 2),
          label('Customer', 3),
          label('Vehicle', 3),
          label('Driver', 3),
          label('Date & Time', 3),
          label('Status', 2),
          label('Actions', 4),
        ],
      ),
    );
  }

  Widget _buildOperatorBookingTableRow(
    Map<String, dynamic> booking,
    bool isDark,
  ) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final driver = booking['driver'] as Map<String, dynamic>?;
    final driverUser = driver?['user'] as Map<String, dynamic>?;
    final bookingId = booking['id']?.toString() ?? '';
    final displayId = bookingId.length > 8
        ? '#${bookingId.substring(0, 8).toUpperCase()}'
        : '#${bookingId.toUpperCase()}';
    final start = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );
    final needsDriver = _bookingNeedsDriver(booking['with_driver']);
    final driverName = driverUser?['full_name']?.toString().trim();

    Widget cell(Widget child, int flex) => Expanded(
      flex: flex,
      child: Align(alignment: Alignment.center, child: child),
    );
    final primaryColor = isDark ? Colors.white : _operatorInk;
    final Color mutedColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          cell(
            Text(
              displayId,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            2,
          ),
          cell(
            _buildOperatorPersonCell(
              renter['full_name']?.toString() ?? 'Unknown renter',
              renter['email']?.toString() ?? 'Renter',
              primaryColor,
              mutedColor,
              avatarUrl: _operatorUserAvatarUrl(renter),
              centered: true,
            ),
            3,
          ),
          cell(
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 17,
                  color: isDark ? _operatorGold : _operatorNavy,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _vehicleTitle(vehicle),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            3,
          ),
          cell(
            Text(
              needsDriver
                  ? (driverName == null || driverName.isEmpty
                        ? 'Unassigned'
                        : driverName)
                  : 'Self-drive',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: needsDriver && (driverName == null || driverName.isEmpty)
                    ? Colors.red.shade400
                    : primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            3,
          ),
          cell(
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatBookingDateTime(start),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: primaryColor, fontSize: 11),
                ),
                if (_canTrackBooking(booking)) ...[
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: BookingReturnCountdown(
                      booking: booking,
                      compact: true,
                      lightBackground: !isDark,
                    ),
                  ),
                ],
              ],
            ),
            3,
          ),
          cell(
            Align(
              alignment: Alignment.center,
              child: _buildStatusBadge(
                booking['status']?.toString() ?? 'pending',
              ),
            ),
            2,
          ),
          cell(_buildOperatorBookingActions(booking, isDark, compact: true), 4),
        ],
      ),
    );
  }

  Widget _buildOperatorPersonCell(
    String name,
    String detail,
    Color primaryColor,
    Color mutedColor, {
    String? avatarUrl,
    bool centered = false,
  }) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final avatarFallback = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE9FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: _operatorNavy,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (avatarUrl != null && avatarUrl.isNotEmpty)
          OptimizedNetworkImage(
            imageUrl: avatarUrl,
            width: 34,
            height: 34,
            borderRadius: BorderRadius.circular(10),
            placeholder: avatarFallback,
            errorWidget: avatarFallback,
          )
        else
          avatarFallback,
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: centered
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                name,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                detail,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: mutedColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _operatorUserAvatarUrl(Map<String, dynamic> user) {
    for (final key in const ['avatar_url', 'profile_picture_url']) {
      final value = user[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Widget _buildOperatorBookingCard(Map<String, dynamic> booking, bool isDark) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final start = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );
    return Container(
      padding: const EdgeInsets.all(18),
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
              Expanded(
                child: Text(
                  _vehicleTitle(vehicle),
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildStatusBadge(booking['status']?.toString() ?? 'pending'),
            ],
          ),
          const SizedBox(height: 12),
          _buildOperatorPersonCell(
            renter['full_name']?.toString() ?? 'Unknown renter',
            renter['email']?.toString() ?? 'Renter',
            isDark ? Colors.grey.shade200 : _operatorInk,
            isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            avatarUrl: _operatorUserAvatarUrl(renter),
          ),
          const SizedBox(height: 5),
          Text(
            _formatBookingDateTime(start),
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          _buildOperatorBookingActions(booking, isDark),
        ],
      ),
    );
  }

  Widget _buildOperatorBookingActions(
    Map<String, dynamic> booking,
    bool isDark, {
    bool compact = false,
  }) {
    final group = bookingStatusGroup(booking['status']);
    final needsDriver = _bookingNeedsDriver(booking['with_driver']);
    final assignmentStatus = _latestDriverAssignment(
      booking,
    )?['status']?.toString().trim().toLowerCase();
    final waitingForDriver =
        assignmentStatus == 'pending_offer' || assignmentStatus == 'assigned';
    final driverAccepted = assignmentStatus == 'accepted';

    final buttons = <Widget>[
      _buildOperatorBookingActionButton(
        onPressed: () => _showOperatorBookingDetailsDialog(booking),
        icon: Icons.visibility_rounded,
        label: compact ? 'Details' : 'View Details',
        foregroundColor: isDark ? Colors.white : _operatorInk,
        borderColor: isDark ? Colors.white24 : Colors.grey.shade400,
        compact: compact,
      ),
    ];

    if (group == BookingStatusGroup.pending) {
      buttons.add(
        _buildOperatorBookingActionButton(
          onPressed: waitingForDriver
              ? null
              : () => _handleQuickApproveBooking(
                  booking,
                  needsDriver: needsDriver,
                  driverAccepted: driverAccepted,
                ),
          icon: waitingForDriver
              ? Icons.hourglass_top_rounded
              : needsDriver && !driverAccepted
              ? Icons.person_search_rounded
              : Icons.check_circle_outline_rounded,
          label: waitingForDriver ? 'Awaiting' : 'Approve',
          foregroundColor: Colors.white,
          backgroundColor: Colors.green.shade600,
          compact: compact,
        ),
      );
      buttons.add(
        _buildOperatorBookingActionButton(
          onPressed: () => _showRejectDialog(booking['id'].toString()),
          icon: Icons.cancel_outlined,
          label: 'Reject',
          foregroundColor: Colors.red.shade400,
          borderColor: Colors.red.shade400,
          compact: compact,
        ),
      );
    } else if (group == BookingStatusGroup.approved) {
      buttons.add(
        _buildOperatorBookingActionButton(
          onPressed: () => _openBookingConversation(booking),
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Message',
          foregroundColor: _operatorNavyDeep,
          backgroundColor: _operatorGold,
          compact: compact,
        ),
      );
    } else if (_canTrackBooking(booking)) {
      buttons.add(
        _buildOperatorBookingActionButton(
          onPressed: () => _openTrackingForBooking(booking),
          icon: Icons.near_me_outlined,
          label: 'Track',
          foregroundColor: _operatorNavyDeep,
          backgroundColor: _operatorGold,
          compact: compact,
        ),
      );
    }

    if (compact) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < buttons.length; index++) ...[
              if (index > 0) const SizedBox(width: 7),
              buttons[index],
            ],
          ],
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }

  Widget _buildOperatorBookingActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color foregroundColor,
    Color? backgroundColor,
    Color? borderColor,
    required bool compact,
  }) {
    final enabled = onPressed != null;
    final effectiveForeground = enabled
        ? foregroundColor
        : Colors.grey.shade400;
    final effectiveBackground = enabled
        ? (backgroundColor ?? Colors.transparent)
        : Colors.grey.shade700.withOpacity(0.45);
    return Tooltip(
      message: label,
      child: Material(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: compact ? 34 : 40,
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: enabled
                    ? (borderColor ?? backgroundColor ?? Colors.transparent)
                    : Colors.grey.shade600,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: compact ? 14 : 16, color: effectiveForeground),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: effectiveForeground,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleQuickApproveBooking(
    Map<String, dynamic> booking, {
    required bool needsDriver,
    required bool driverAccepted,
  }) async {
    if (needsDriver && !driverAccepted) {
      _showApproveDialog(booking);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve booking?'),
        content: const Text(
          'This will finalize the booking and create its conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _approveBooking(booking);
    }
  }

  Future<void> _showOperatorBookingDetailsDialog(
    Map<String, dynamic> booking,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final driver = booking['driver'] as Map<String, dynamic>?;
    final driverUser = driver?['user'] as Map<String, dynamic>?;
    final status = booking['status']?.toString() ?? 'pending';
    final statusLower = status.toLowerCase();
    final group = bookingStatusGroup(status);
    final needsDriver = _bookingNeedsDriver(booking['with_driver']);
    final assignmentStatus = _latestDriverAssignment(
      booking,
    )?['status']?.toString().trim().toLowerCase();
    final waitingForDriver =
        assignmentStatus == 'pending_offer' || assignmentStatus == 'assigned';
    final driverAccepted = assignmentStatus == 'accepted';
    final driverDeclined = assignmentStatus == 'rejected';
    final completionState = BookingService().getTripCompletionState(booking);
    final completionStage = completionState['completionStage']?.toString();
    final start = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );
    final end = DateTime.tryParse(
      (booking['end_at'] ?? booking['end_date'])?.toString() ?? '',
    );
    final total =
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final imageUrl = _primaryVehicleImageUrl(vehicle);
    final bookingId = booking['id']?.toString() ?? '';
    final shortId = bookingId.length > 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 780),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172235) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      final vehiclePanel = _buildOperatorVehicleDetailPanel(
                        vehicle: vehicle,
                        renter: renter,
                        imageUrl: imageUrl,
                        isDark: isDark,
                      );
                      final detailPanel = _buildOperatorBookingDetailPanel(
                        booking: booking,
                        bookingShortId: shortId,
                        driverName:
                            driverUser?['full_name']?.toString() ??
                            (needsDriver ? 'Unassigned' : 'Self-drive'),
                        start: start,
                        end: end,
                        total: total,
                        status: status,
                        isDark: isDark,
                        onClose: () => Navigator.pop(dialogContext),
                      );
                      if (compact) {
                        return SingleChildScrollView(
                          child: Column(children: [vehiclePanel, detailPanel]),
                        );
                      }
                      return Row(
                        children: [
                          SizedBox(width: 310, child: vehiclePanel),
                          Expanded(child: detailPanel),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.12)
                        : const Color(0xFFF8F9FA),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (group == BookingStatusGroup.pending)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showRejectDialog(bookingId);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const Text('Decline'),
                        ),
                      if (group == BookingStatusGroup.pending &&
                          (!needsDriver || driverAccepted))
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _approveBooking(booking);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorGold,
                            foregroundColor: _operatorNavyDeep,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 17),
                          label: const Text('Finalize Booking'),
                        ),
                      if (group == BookingStatusGroup.pending &&
                          needsDriver &&
                          !driverAccepted &&
                          !waitingForDriver)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showApproveDialog(booking);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorNavy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: const Icon(Icons.person_search, size: 17),
                          label: Text(
                            driverDeclined
                                ? 'Select Another Driver'
                                : 'Assign Driver',
                          ),
                        ),
                      if ((statusLower == 'confirmed' ||
                              statusLower == 'approved' ||
                              statusLower == 'active') &&
                          !_isPartnerOwnedBooking(booking))
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showInspectionDialog(
                              booking,
                              inspectionType: 'before',
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(Icons.fact_check_outlined, size: 17),
                          label: const Text(
                            'Before Checklist',
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      if ((statusLower == 'active' ||
                              statusLower == 'ongoing' ||
                              statusLower == 'return_pending_inspection') &&
                          !_isPartnerOwnedBooking(booking))
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showInspectionDialog(
                              booking,
                              inspectionType: 'after',
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 17,
                          ),
                          label: const Text('After Checklist'),
                        ),
                      if (_canTrackBooking(booking))
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _openTrackingForBooking(booking);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorGold,
                            foregroundColor: _operatorNavyDeep,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: const Icon(Icons.explore_outlined, size: 17),
                          label: const Text('Track Trip'),
                        ),
                      if (completionStage == 'awaiting_payment' &&
                          !_isPartnerOwnedBooking(booking))
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _confirmOperatorFinalPayment(booking);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorNavy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: const Icon(Icons.payments_outlined, size: 17),
                          label: const Text('Confirm Full Payment'),
                        ),
                      if (completionStage == 'operator_rating' &&
                          !_isPartnerOwnedBooking(booking))
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _openOperatorRenterRating(booking);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorNavy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: const Icon(Icons.star_rate_rounded, size: 17),
                          label: const Text('Rate Renter'),
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

  Widget _buildOperatorVehicleDetailPanel({
    required Map<String, dynamic> vehicle,
    required Map<String, dynamic> renter,
    required String imageUrl,
    required bool isDark,
  }) {
    final foreground = isDark ? Colors.white : _operatorInk;
    final muted = isDark ? Colors.grey[400] : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.all(24),
      color: isDark ? Colors.black.withOpacity(0.14) : const Color(0xFFF2F4F6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 178,
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              child: imageUrl.isEmpty
                  ? Icon(Icons.directions_car_outlined, color: muted, size: 52)
                  : OptimizedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: Icon(
                        Icons.directions_car_outlined,
                        color: muted,
                        size: 52,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _vehicleTitle(vehicle),
            style: TextStyle(
              color: foreground,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            [
                  vehicle['transmission'],
                  vehicle['vehicle_type'] ?? vehicle['category'],
                  vehicle['plate_number'],
                ]
                .where((value) => value?.toString().trim().isNotEmpty == true)
                .join(' - '),
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 22),
          Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            'RENTER',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _operatorGold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child:
                    (renter['avatar_url'] ?? renter['profile_picture_url'])
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true
                    ? OptimizedNetworkImage(
                        imageUrl:
                            (renter['avatar_url'] ??
                                    renter['profile_picture_url'])
                                .toString(),
                        fit: BoxFit.cover,
                        errorWidget: const Icon(
                          Icons.person_outline_rounded,
                          color: _operatorGold,
                        ),
                      )
                    : const Icon(
                        Icons.person_outline_rounded,
                        color: _operatorGold,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      renter['full_name']?.toString() ?? 'Unknown renter',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      renter['email']?.toString() ?? 'No email provided',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                    if (renter['phone']?.toString().trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 4),
                      Text(
                        renter['phone'].toString(),
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorBookingDetailPanel({
    required Map<String, dynamic> booking,
    required String bookingShortId,
    required String driverName,
    required DateTime? start,
    required DateTime? end,
    required double total,
    required String status,
    required bool isDark,
    required VoidCallback onClose,
  }) {
    final foreground = isDark ? Colors.white : _operatorInk;
    final muted = isDark ? Colors.grey[400] : Colors.grey.shade600;
    final pickup = booking['pickup_location']?.toString().trim() ?? '';
    final destination = booking['dropoff_location']?.toString().trim() ?? '';
    final route = pickup.isNotEmpty && destination.isNotEmpty
        ? '$pickup to $destination'
        : destination.isNotEmpty
        ? destination
        : pickup.isNotEmpty
        ? pickup
        : 'PSDC Urdaneta';
    final needsDriver = _bookingNeedsDriver(booking['with_driver']);
    final service = needsDriver
        ? driverName == 'Unassigned'
              ? 'Professional driver required'
              : 'Professional driver - $driverName'
        : 'Self-drive';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOOKING ID  #$bookingShortId',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Booking Details',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusBadge(status),
                  const SizedBox(height: 7),
                  Text(
                    'PHP ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _operatorGold,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Close booking details',
                onPressed: onClose,
                style: IconButton.styleFrom(
                  foregroundColor: foreground,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.grey.shade100,
                  minimumSize: const Size(42, 42),
                ),
                icon: const Icon(Icons.close_rounded, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildOperatorDetailTile(
                Icons.map_outlined,
                'ROUTE',
                route,
                isDark,
              ),
              _buildOperatorDetailTile(
                Icons.calendar_month_outlined,
                'SCHEDULE',
                '${_formatBookingDateTime(start)} - ${_formatBookingDateTime(end)}',
                isDark,
              ),
              _buildOperatorDetailTile(
                Icons.airport_shuttle_outlined,
                'SERVICE',
                service,
                isDark,
              ),
            ],
          ),
          if (_canTrackBooking(booking)) ...[
            const SizedBox(height: 14),
            BookingReturnCountdown(booking: booking, lightBackground: !isDark),
          ],
          const SizedBox(height: 18),
          _buildBookingPaymentDetails(booking, isDark),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _operatorNavy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: _operatorGold, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'Renter Safety Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildOperatorSafetyLine(
                  'Digital signature',
                  booking['renter_signature_url']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? 'Captured'
                      : 'Not provided',
                ),
                _buildOperatorSafetyLine(
                  'Emergency contact',
                  booking['emergency_contact_name']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? booking['emergency_contact_name'].toString()
                      : 'Not provided',
                ),
                _buildOperatorSafetyLine(
                  'Contact phone',
                  booking['emergency_contact_phone']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? booking['emergency_contact_phone'].toString()
                      : 'Not provided',
                ),
                _buildOperatorSafetyLine(
                  'Co-traveler',
                  booking['co_traveler_name']?.toString().trim().isNotEmpty ==
                          true
                      ? booking['co_traveler_name'].toString()
                      : 'Not provided',
                ),
                _buildOperatorSafetyLine(
                  'Co-traveler license',
                  booking['co_traveler_license']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? booking['co_traveler_license'].toString()
                      : 'Not provided',
                ),
                _buildOperatorSafetyLine(
                  'Co-traveler signature',
                  booking['co_traveler_signature_url']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? 'Captured'
                      : 'Not provided',
                ),
                Divider(color: Colors.white.withOpacity(0.12), height: 22),
                const Text(
                  'VERIFICATION EVIDENCE',
                  style: TextStyle(
                    color: Color(0xFF91A9BE),
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildOperatorEvidenceChip(
                      Icons.draw_outlined,
                      'Signature',
                      booking['renter_signature_url'],
                    ),
                    _buildOperatorEvidenceChip(
                      Icons.badge_outlined,
                      'Valid ID',
                      booking['renter_valid_id_url'],
                    ),
                    _buildOperatorEvidenceChip(
                      Icons.camera_alt_outlined,
                      'Selfie',
                      booking['renter_selfie_url'],
                    ),
                    _buildOperatorEvidenceChip(
                      Icons.draw_outlined,
                      'Co-traveler Signature',
                      booking['co_traveler_signature_url'],
                    ),
                    _buildOperatorEvidenceChip(
                      Icons.badge_outlined,
                      'Co-traveler ID',
                      booking['co_traveler_valid_id_url'],
                    ),
                    _buildOperatorEvidenceChip(
                      Icons.camera_alt_outlined,
                      'Co-traveler Selfie',
                      booking['co_traveler_selfie_url'],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorDetailTile(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Container(
      width: 205,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? _operatorGold : _operatorNavy, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 9,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorSafetyLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF91A9BE),
                fontSize: 9,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorEvidenceChip(IconData icon, String label, dynamic url) {
    final available = url?.toString().trim().isNotEmpty == true;
    return Tooltip(
      message: available ? 'Preview $label' : '$label was not uploaded',
      child: InkWell(
        onTap: available
            ? () => _showOperatorEvidencePreview(label, url.toString().trim())
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 132),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: available
                  ? _operatorGold.withOpacity(0.45)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                available ? icon : Icons.warning_amber_rounded,
                size: 15,
                color: available ? _operatorGold : Colors.orangeAccent,
              ),
              const SizedBox(width: 7),
              Text(
                available ? label : '$label missing',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (available) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.visibility_outlined,
                  color: Color(0xFF91A9BE),
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOperatorEvidencePreview(String title, String url) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (previewContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172235) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 34,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _operatorGold.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: _operatorGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isDark ? Colors.white : _operatorInk,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Booking verification evidence',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.pop(previewContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: isDark
                          ? Colors.black.withOpacity(0.18)
                          : const Color(0xFFF1F3F5),
                      child: SizedBox.expand(
                        child: OptimizedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          isThumbnail: false,
                          errorWidget: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.broken_image_outlined,
                                    size: 54,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'This uploaded file cannot be previewed as an image.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                final completionStage = completionState['completionStage']
                    ?.toString();
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
                                if ((statusLower == 'confirmed' ||
                                        statusLower == 'approved' ||
                                        statusLower == 'active') &&
                                    !_isPartnerOwnedBooking(booking))
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
                                if ((statusLower == 'active' ||
                                        statusLower == 'ongoing' ||
                                        statusLower ==
                                            'return_pending_inspection') &&
                                    !_isPartnerOwnedBooking(booking))
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
                                if (completionStage == 'awaiting_payment' &&
                                    !_isPartnerOwnedBooking(booking))
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _confirmOperatorFinalPayment(booking),
                                    icon: const Icon(
                                      Icons.payments_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Confirm Full Payment'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if (completionStage == 'operator_rating' &&
                                    !_isPartnerOwnedBooking(booking))
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _openOperatorRenterRating(booking),
                                    icon: const Icon(
                                      Icons.star_rate_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Rate Renter'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if (completionStage == 'completed')
                                  Text(
                                    'Trip completed after all required ratings',
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
    final releasedByController = TextEditingController();
    final receivedByController = TextEditingController();
    final checklistItems = <String, bool>{
      for (final key in BookingInspectionService.requiredChecklistKeys)
        key: false,
    };
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
                  VehicleInspectionChecklistFields(
                    values: checklistItems,
                    isDark: isDark,
                    onChanged: (entry) => setDialogState(
                      () => checklistItems[entry.key] = entry.value,
                    ),
                  ),
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
                  _buildInspectionTextField(
                    releasedByController,
                    'Released by',
                  ),
                  _buildInspectionTextField(
                    receivedByController,
                    'Received by (client)',
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
              onPressed: () {
                final allChecked = BookingInspectionService
                    .requiredChecklistKeys
                    .every((key) => checklistItems[key] == true);
                final requiredFieldsReady =
                    fuelController.text.trim().isNotEmpty &&
                    mileageController.text.trim().isNotEmpty &&
                    cleanlinessController.text.trim().isNotEmpty &&
                    releasedByController.text.trim().isNotEmpty &&
                    receivedByController.text.trim().isNotEmpty;
                if (!allChecked ||
                    !requiredFieldsReady ||
                    selectedEvidence.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Complete all checklist items, handover names, and attach at least one photo or video.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                inspectionType == 'before'
                    ? 'Submit and Start Trip'
                    : 'Submit Return Checklist',
              ),
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
      releasedByController.dispose();
      receivedByController.dispose();
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
        checklistItems: checklistItems,
        releasedBy: releasedByController.text,
        receivedBy: receivedByController.text,
      );

      if (inspectionType == 'before') {
        await BookingService().startBookingAfterInspection(
          bookingId: bookingId,
          inspectorId: currentUserId,
        );
      } else {
        await BookingService().completeBookingAfterInspection(
          bookingId: bookingId,
          inspectorId: currentUserId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            inspectionType == 'before'
                ? 'Checklist submitted. The booking is now ongoing.'
                : 'Return checklist submitted. Confirm payment and complete the required ratings next.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadDashboardData(showLoading: false);
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
      releasedByController.dispose();
      receivedByController.dispose();
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
                final visual = notificationVisualFor(notification);
                final vehicleImageUrl = _notificationVehicleImageUrl(
                  notification,
                );

                return InkWell(
                  onTap: () => _handleOperatorNotificationTap(notification),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isRead
                          ? (isDark ? AppColors.darkCard : Colors.white)
                          : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
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
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: visual.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isRead
                                      ? Colors.transparent
                                      : visual.color.withOpacity(0.45),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: vehicleImageUrl.isNotEmpty
                                  ? OptimizedNetworkImage(
                                      imageUrl: vehicleImageUrl,
                                      width: 58,
                                      height: 58,
                                      fit: BoxFit.cover,
                                      placeholder: Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: visual.color,
                                          ),
                                        ),
                                      ),
                                      errorWidget: Icon(
                                        visual.icon,
                                        color: visual.color,
                                      ),
                                    )
                                  : Icon(
                                      visual.icon,
                                      color: isRead
                                          ? (isDark
                                                ? Colors.grey
                                                : Colors.grey.shade600)
                                          : visual.color,
                                    ),
                            ),
                            if (!isRead)
                              Positioned(
                                right: -3,
                                top: -3,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF101827)
                                          : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isRead
                                      ? FontWeight.w700
                                      : FontWeight.w800,
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
                              const SizedBox(height: 10),
                              RelativeTimeText(
                                value: notification['created_at'],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade500,
                                ),
                              ),
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

  Future<void> _handleOperatorNotificationTap(
    Map<String, dynamic> notification,
  ) async {
    final notificationId = notification['id']?.toString();
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        notification['is_read'] != true) {
      await NotificationService().markAsRead(notificationId);
      notification['is_read'] = true;
      if (mounted) setState(() {});
    }
    if (!mounted) return;

    final target = resolveNotificationTarget(notification);
    switch (target.destination) {
      case NotificationDestination.messages:
        setState(() {
          _selectedIndex = 2;
          if (target.conversationId != null) {
            _selectedConversationId = target.conversationId!;
          }
        });
        if (target.conversationId != null) {
          await _loadConversationMessages(target.conversationId!);
        }
        return;
      case NotificationDestination.tracking:
        setState(() {
          _selectedIndex = 6;
          _focusedTrackingBookingId = target.bookingId;
        });
        return;
      case NotificationDestination.booking:
        setState(() {
          _selectedIndex = 1;
          _bookingFilter = 'all';
        });
        final bookingId = target.bookingId;
        if (bookingId != null) {
          final booking = _recentBookings.firstWhere(
            (item) => item['id']?.toString() == bookingId,
            orElse: () => <String, dynamic>{},
          );
          if (booking.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showOperatorBookingDetailsDialog(booking);
            });
          }
        }
        return;
      case NotificationDestination.payment:
        setState(() => _selectedIndex = 7);
        return;
      case NotificationDestination.application:
      case NotificationDestination.verification:
      case NotificationDestination.vehicles:
        setState(() => _selectedIndex = 4);
        return;
      case NotificationDestination.ratings:
        setState(() => _selectedIndex = 7);
        return;
      case NotificationDestination.announcement:
      case NotificationDestination.general:
        _showOperatorNotificationDetails(notification);
        return;
    }
  }

  void _showOperatorNotificationDetails(Map<String, dynamic> notification) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(notification['title']?.toString() ?? 'Notification'),
        content: Text(
          notification['message']?.toString().trim().isNotEmpty == true
              ? notification['message'].toString()
              : 'No additional details are available.',
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
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      if (mounted) {
        setState(() {
          _isLoadingConversations = false;
          _conversationLoadError = 'Your operator session is not ready yet.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingConversations = true;
        _conversationLoadError = null;
      });
    }

    try {
      debugPrint(
        '[Messages] Loading conversations for operator: $currentUserId',
      );

      const activeStatuses = ['approved', 'confirmed', 'active', 'ongoing'];
      final participantConversationIds = <String>{};
      try {
        final participations = await _supabase
            .from('conversation_participants')
            .select('conversation_id')
            .eq('user_id', currentUserId);
        participantConversationIds.addAll(
          List<Map<String, dynamic>>.from(participations)
              .map((row) => row['conversation_id']?.toString().trim())
              .whereType<String>()
              .where((id) => id.isNotEmpty),
        );
      } on PostgrestException catch (error) {
        debugPrint('[Messages] Participant lookup skipped: ${error.message}');
      }
      final participantBookingIds = <String>{};
      if (participantConversationIds.isNotEmpty) {
        final participantConversationRows = await _supabase
            .from('conversations')
            .select('booking_id')
            .inFilter('id', participantConversationIds.toList());
        for (final row in List<Map<String, dynamic>>.from(
          participantConversationRows,
        )) {
          final bookingId = row['booking_id']?.toString().trim() ?? '';
          if (bookingId.isNotEmpty) participantBookingIds.add(bookingId);
        }
      }

      final bookingRows = await _supabase
          .from('bookings')
          .select('id, status, operator_id')
          .inFilter('status', activeStatuses)
          .order('updated_at', ascending: false);
      final eligibleBookings = List<Map<String, dynamic>>.from(bookingRows)
          .where((booking) {
            final bookingId = booking['id']?.toString().trim() ?? '';
            final operatorId = booking['operator_id']?.toString().trim() ?? '';
            return operatorId.isEmpty ||
                operatorId == currentUserId ||
                participantBookingIds.contains(bookingId);
          })
          .toList();
      final bookingIds = eligibleBookings
          .map((booking) => booking['id']?.toString().trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (bookingIds.isEmpty) {
        _conversations = [];
        if (mounted) {
          setState(() {
            _isLoadingConversations = false;
            _conversationLoadError = null;
          });
        }
        return;
      }

      final existingRows = await _supabase
          .from('conversations')
          .select('id, booking_id, status')
          .inFilter('booking_id', bookingIds);
      final existingByBooking = <String, Map<String, dynamic>>{};
      for (final conversation in List<Map<String, dynamic>>.from(
        existingRows,
      )) {
        final bookingId = conversation['booking_id']?.toString();
        if (bookingId != null && bookingId.isNotEmpty) {
          existingByBooking[bookingId] = conversation;
        }
      }

      for (final booking in eligibleBookings) {
        final bookingId = booking['id']?.toString() ?? '';
        final conversation = existingByBooking[bookingId];
        final conversationId = conversation?['id']?.toString() ?? '';
        final conversationStatus =
            conversation?['status']?.toString().trim().toLowerCase() ?? '';
        final needsRepair =
            conversation == null ||
            conversationStatus != 'active' ||
            !participantConversationIds.contains(conversationId);
        if (!needsRepair) continue;

        try {
          await BookingService().ensureBookingConversationForActiveBooking(
            bookingId: bookingId,
            operatorId: currentUserId,
          );
        } catch (error) {
          debugPrint(
            '[Messages] Could not repair conversation for $bookingId: $error',
          );
        }
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
              updated_at,
              bookings!conversations_booking_id_fkey (
                id,
                vehicle_id,
                start_at,
                end_at,
                start_date,
                end_date,
                status,
                vehicles!bookings_vehicle_id_fkey (
                  brand,
                  model,
                  year,
                  vehicle_images(image_url, display_order)
                ),
                renter:users!bookings_renter_id_fkey (id, full_name, email)
              ),
              users!conversations_user_id_fkey (id, full_name, email),
              other_users:users!conversations_other_user_id_fkey (id, full_name, email)
            ''')
          .inFilter('booking_id', bookingIds)
          .order('updated_at', ascending: false);

      final conversationsByBooking = <String, Map<String, dynamic>>{};
      for (final item in List<Map<String, dynamic>>.from(response)) {
        final conversationStatus =
            item['status']?.toString().trim().toLowerCase() ?? 'active';
        final booking = item['bookings'];
        final bookingStatus = booking is Map
            ? booking['status']?.toString().trim().toLowerCase() ?? ''
            : '';
        if (conversationStatus != 'active' ||
            !activeStatuses.contains(bookingStatus)) {
          continue;
        }
        final bookingId = item['booking_id']?.toString().trim() ?? '';
        if (bookingId.isNotEmpty) {
          conversationsByBooking.putIfAbsent(bookingId, () => item);
        }
      }
      _conversations = conversationsByBooking.values.toList();
      if (_conversations.isEmpty) {
        _conversations = await _loadOperatorConversationFallback(
          currentUserId,
          activeStatuses,
        );
      }
      debugPrint('[Messages] Loaded ${_conversations.length} conversations');

      if (mounted) {
        setState(() {
          _isLoadingConversations = false;
          _conversationLoadError = null;
        });
      }
    } catch (e) {
      debugPrint('[Messages] Error loading conversations: $e');
      try {
        _conversations = await _loadOperatorConversationFallback(
          currentUserId,
          const ['approved', 'confirmed', 'active', 'ongoing'],
        );
        if (mounted) {
          setState(() {
            _isLoadingConversations = false;
            _conversationLoadError = _conversations.isEmpty
                ? 'No active booking conversations were found.'
                : null;
          });
        }
      } catch (fallbackError) {
        debugPrint(
          '[Messages] Fallback conversation loading failed: $fallbackError',
        );
        if (mounted) {
          setState(() {
            _isLoadingConversations = false;
            _conversationLoadError =
                'Unable to load booking conversations. Please retry.';
          });
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadOperatorConversationFallback(
    String currentUserId,
    List<String> activeStatuses,
  ) async {
    final rows = await ChatService().getConversations(currentUserId);
    final conversationsByBooking = <String, Map<String, dynamic>>{};
    for (final conversation in rows) {
      final conversationStatus =
          conversation['status']?.toString().trim().toLowerCase() ?? 'active';
      final booking = conversation['bookings'];
      final bookingStatus = booking is Map
          ? booking['status']?.toString().trim().toLowerCase() ?? ''
          : '';
      final bookingId = conversation['booking_id']?.toString().trim() ?? '';
      if (bookingId.isEmpty ||
          conversationStatus != 'active' ||
          !activeStatuses.contains(bookingStatus)) {
        continue;
      }
      conversationsByBooking.putIfAbsent(bookingId, () => conversation);
    }
    return conversationsByBooking.values.toList();
  }

  Future<void> _loadConversationMessages(String conversationId) async {
    try {
      debugPrint(
        '[Messages] Loading messages for conversation: $conversationId',
      );

      await _loadConversationParticipants(conversationId);
      _watchConversationMessages(conversationId);

      final response = await _supabase
          .from('messages')
          .select('''
              id,
              conversation_id,
              sender_id,
              message,
              content,
              is_auto_generated,
              is_deleted,
              deleted_at,
              created_at,
              sender:users!messages_new_sender_id_fkey (id, full_name)
            ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final loadedMessages = List<Map<String, dynamic>>.from(response);
      loadedMessages.sort((first, second) {
        final firstTime =
            parseMessageTimestamp(first['created_at']) ?? DateTime(1970);
        final secondTime =
            parseMessageTimestamp(second['created_at']) ?? DateTime(1970);
        return firstTime.compareTo(secondTime);
      });
      _messages[conversationId] = loadedMessages;
      debugPrint(
        '[Messages] Loaded ${_messages[conversationId]?.length ?? 0} messages',
      );

      setState(() {});
      _scrollMessagesToBottom();
    } catch (e) {
      debugPrint('[Messages] Error loading messages: $e');
    }
  }

  void _watchConversationMessages(String conversationId) {
    _conversationMessagesChannel?.unsubscribe();
    _conversationMessagesChannel = _supabase
        .channel('operator-conversation-$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final raw = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            if (raw.isEmpty || !mounted) return;
            final message = Map<String, dynamic>.from(raw);
            setState(() => _mergeOperatorMessage(conversationId, message));
            if (_selectedConversationId == conversationId) {
              _scrollMessagesToBottom();
            }
          },
        )
        .subscribe();
  }

  void _mergeOperatorMessage(
    String conversationId,
    Map<String, dynamic> message,
  ) {
    final messages = _messages.putIfAbsent(conversationId, () => []);
    final messageId = message['id']?.toString();
    if (messageId == null || messageId.isEmpty) return;
    var enrichedMessage = message;
    if (message['sender'] == null) {
      final senderId = message['sender_id']?.toString();
      final participants =
          _conversationParticipants[conversationId] ?? const [];
      final participant = participants.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['user_id']?.toString() == senderId,
        orElse: () => null,
      );
      final senderName = participant?['display_name']?.toString();
      if (senderName != null && senderName.trim().isNotEmpty) {
        enrichedMessage = {
          ...message,
          'sender': {'id': senderId, 'full_name': senderName.trim()},
        };
      }
    }
    final existingIndex = messages.indexWhere(
      (item) => item['id']?.toString() == messageId,
    );
    if (existingIndex >= 0) {
      final existing = messages[existingIndex];
      messages[existingIndex] = {...existing, ...enrichedMessage};
    } else {
      messages.add(enrichedMessage);
    }
    messages.sort((first, second) {
      final firstTime =
          parseMessageTimestamp(first['created_at']) ?? DateTime(1970);
      final secondTime =
          parseMessageTimestamp(second['created_at']) ?? DateTime(1970);
      return firstTime.compareTo(secondTime);
    });
  }

  void _scrollMessagesToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) return;
      final target = _messageScrollController.position.maxScrollExtent;
      if (animate) {
        _messageScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _messageScrollController.jumpTo(target);
      }
    });
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

      final sentMessage = await ChatService().sendMessage(
        conversationId: conversationId,
        senderId: currentUserId,
        content: content,
      );

      _messageController.clear();
      if (mounted) {
        setState(() => _mergeOperatorMessage(conversationId, sentMessage));
      }
      _scrollMessagesToBottom(animate: true);
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

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        backgroundColor: isDark
            ? AppColors.darkBgSecondary
            : Colors.grey.shade50,
        collapsedBackgroundColor: isDark
            ? AppColors.darkBgSecondary
            : Colors.grey.shade50,
        iconColor: AppColors.primary,
        collapsedIconColor: isDark
            ? Colors.grey.shade400
            : Colors.grey.shade600,
        title: Text(
          'Conversation profiles',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : _operatorInk,
          ),
        ),
        subtitle: Text(
          '${participants.length} participant${participants.length == 1 ? '' : 's'} - tap to view contact details',
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[400] : Colors.grey.shade600,
          ),
        ),
        children: [
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: participants.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _buildParticipantProfileCard(participants[index], isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantProfileCard(
    Map<String, dynamic> participant,
    bool isDark,
  ) {
    final name =
        participant['display_name']?.toString().trim().isNotEmpty == true
        ? participant['display_name'].toString().trim()
        : 'Unknown User';
    final role =
        participant['display_role']?.toString().trim().isNotEmpty == true
        ? participant['display_role'].toString().trim()
        : 'Participant';
    final phone =
        participant['display_phone']?.toString().trim().isNotEmpty == true
        ? participant['display_phone'].toString().trim()
        : '';
    final email = participant['email']?.toString().trim() ?? '';
    final avatar = participant['display_avatar']?.toString().trim() ?? '';
    final detail = phone.isNotEmpty
        ? phone
        : email.isNotEmpty
        ? email
        : 'No contact saved';

    return Container(
      width: 250,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              color: AppColors.primary.withOpacity(0.18),
              child: avatar.isNotEmpty
                  ? OptimizedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                  : Text(
                      _initials(name),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 11),
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
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesContent(bool isDark) {
    if (_isLoadingConversations && _conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(42),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade200,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _operatorGold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: _operatorNavy,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _conversationLoadError ?? 'No booking conversations yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : _operatorInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _conversationLoadError == null
                    ? 'A group conversation appears after a booking is finalized.'
                    : 'The conversations already in the database were not removed. Try loading them again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _isLoadingConversations ? null : _loadConversations,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Map<String, dynamic>? selectedConversation;
    for (final conversation in _conversations) {
      if (conversation['id']?.toString() == _selectedConversationId) {
        selectedConversation = conversation;
        break;
      }
    }
    final selectedBooking =
        selectedConversation?['bookings'] as Map<String, dynamic>?;
    final selectedRenter =
        selectedBooking?['renter'] as Map<String, dynamic>? ?? {};
    final selectedVehicle =
        selectedBooking?['vehicles'] as Map<String, dynamic>? ?? {};
    final selectedStatus =
        selectedBooking?['status']?.toString().toLowerCase() ?? 'active';
    final conversationStatus =
        selectedConversation?['status']?.toString().toLowerCase() ?? 'active';
    final isClosed =
        conversationStatus == 'closed' || selectedStatus == 'completed';
    final messages = _messages[_selectedConversationId] ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final showThreads = !compact || _selectedConversationId.isEmpty;
            final showConversation =
                !compact || _selectedConversationId.isNotEmpty;
            return Row(
              children: [
                if (showThreads)
                  SizedBox(
                    width: compact ? constraints.maxWidth : 360,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(22, 22, 18, 18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.12)
                                : const Color(0xFFFAFBFC),
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Active Threads',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : _operatorInk,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${_conversations.length} booking conversations',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey.shade600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh conversations',
                                onPressed: _loadConversations,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _conversations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 9),
                            itemBuilder: (context, index) =>
                                _buildOperatorConversationTile(
                                  _conversations[index],
                                  isDark,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!compact)
                  VerticalDivider(
                    width: 1,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                if (showConversation)
                  Expanded(
                    child: _selectedConversationId.isEmpty
                        ? _buildOperatorEmptyConversation(isDark)
                        : Column(
                            children: [
                              _buildOperatorConversationHeader(
                                selectedConversation,
                                selectedRenter,
                                selectedVehicle,
                                selectedStatus,
                                compact,
                                isDark,
                              ),
                              _buildOperatorParticipantReference(
                                _conversationParticipants[_selectedConversationId] ??
                                    [],
                                isDark,
                              ),
                              Expanded(
                                child: messages.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No messages yet',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        controller: _messageScrollController,
                                        padding: const EdgeInsets.fromLTRB(
                                          28,
                                          22,
                                          28,
                                          12,
                                        ),
                                        itemCount: messages.length,
                                        itemBuilder: (context, index) =>
                                            _buildOperatorMessageBubble(
                                              messages[index],
                                              isDark,
                                            ),
                                      ),
                              ),
                              _buildOperatorMessageComposer(isClosed, isDark),
                            ],
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOperatorConversationTile(
    Map<String, dynamic> conversation,
    bool isDark,
  ) {
    final conversationId = conversation['id']?.toString() ?? '';
    final booking = conversation['bookings'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renterName = renter['full_name']?.toString() ?? 'Unknown renter';
    final vehicleName = [
      vehicle['brand'],
      vehicle['model'],
    ].where((value) => value?.toString().trim().isNotEmpty == true).join(' ');
    final status = booking['status']?.toString() ?? 'pending';
    final imageUrl = _operatorVehicleImageUrl(vehicle);
    final selected = conversationId == _selectedConversationId;
    final shortId = conversation['booking_id']?.toString() ?? conversationId;
    final displayId = shortId.length > 8
        ? shortId.substring(0, 8).toUpperCase()
        : shortId.toUpperCase();

    return InkWell(
      onTap: () {
        setState(() => _selectedConversationId = conversationId);
        _loadConversationMessages(conversationId);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                    ? _operatorGold.withOpacity(0.16)
                    : const Color(0xFFFFF8DC))
              : (isDark
                    ? Colors.white.withOpacity(0.035)
                    : const Color(0xFFF6F7F8)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _operatorGold
                : (isDark ? Colors.white10 : Colors.transparent),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(right: 10),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: imageUrl.isNotEmpty
                      ? OptimizedNetworkImage(
                          imageUrl: imageUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(12),
                          errorWidget: const Icon(
                            Icons.directions_car_outlined,
                          ),
                        )
                      : const Icon(Icons.directions_car_outlined),
                ),
                Text(
                  '#$displayId',
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              renterName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              vehicleName.isEmpty ? 'Booking conversation' : vehicleName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _operatorVehicleImageUrl(Map<String, dynamic> vehicle) {
    final direct = vehicle['image_url']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final images =
        List<Map<String, dynamic>>.from(
          vehicle['vehicle_images'] as List? ?? const [],
        )..sort((a, b) {
          final aOrder = (a['display_order'] as num?)?.toInt() ?? 999;
          final bOrder = (b['display_order'] as num?)?.toInt() ?? 999;
          return aOrder.compareTo(bOrder);
        });
    for (final image in images) {
      final url = image['image_url']?.toString().trim() ?? '';
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  Widget _buildOperatorEmptyConversation(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 58,
            color: isDark ? Colors.grey[600] : Colors.grey.shade300,
          ),
          const SizedBox(height: 14),
          Text(
            'Select a booking conversation',
            style: TextStyle(
              color: isDark ? Colors.white : _operatorInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Messages from the renter, driver, and vehicle owner appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorConversationHeader(
    Map<String, dynamic>? conversation,
    Map<String, dynamic> renter,
    Map<String, dynamic> vehicle,
    String status,
    bool compact,
    bool isDark,
  ) {
    final bookingId = conversation?['booking_id']?.toString() ?? '';
    final shortId = bookingId.length > 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.12) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          if (compact) ...[
            IconButton(
              onPressed: () => setState(() => _selectedConversationId = ''),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _operatorNavy,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: _operatorGold,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortId.isEmpty
                      ? 'Booking Conversation'
                      : 'Booking #$shortId',
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${renter['full_name'] ?? 'Renter'} - ${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBadge(status),
        ],
      ),
    );
  }

  Widget _buildOperatorMessageBubble(
    Map<String, dynamic> message,
    bool isDark,
  ) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final isOwn = message['sender_id']?.toString() == currentUserId;
    final sender = message['sender'] as Map<String, dynamic>? ?? {};
    final senderName = sender['full_name']?.toString() ?? 'System';
    final content =
        message['content']?.toString() ?? message['message']?.toString() ?? '';
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Column(
            crossAxisAlignment: isOwn
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  isOwn ? 'You (Operator)' : senderName,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: isOwn
                      ? _operatorNavy
                      : (isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isOwn ? 16 : 4),
                    bottomRight: Radius.circular(isOwn ? 4 : 16),
                  ),
                  border: isOwn
                      ? null
                      : Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                ),
                child: Text(
                  content,
                  style:
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ).copyWith(
                        color: isOwn
                            ? Colors.white
                            : (isDark ? Colors.white : _operatorInk),
                      ),
                ),
              ),
              const SizedBox(height: 4),
              RelativeTimeText(
                value: message['created_at'],
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey.shade500,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorMessageComposer(bool isClosed, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.12)
            : const Color(0xFFFAFBFC),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: isClosed
          ? Text(
              'This completed booking conversation is read-only.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _sendMessage(
                      _selectedConversationId,
                      _messageController.text,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message to the booking team...',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: () => _sendMessage(
                    _selectedConversationId,
                    _messageController.text,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: _operatorGold,
                    foregroundColor: _operatorNavyDeep,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
    );
  }

  Widget _buildLegacyMessagesContent(bool isDark) {
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
                                          ? const Color(0xFF101820)
                                          : (isDark
                                                ? Colors.white
                                                : Colors.black),
                                      fontWeight: isOwn
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  RelativeTimeText(
                                    value: message['created_at'],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isOwn
                                          ? const Color(0xA6101820)
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
    final source = _vehicleView == 'partner' ? _partnerVehicles : _vehicles;
    final query = _vehicleSearchQuery.toLowerCase();
    final visible = source.where((vehicle) {
      if (query.isEmpty) return true;
      final haystack = [
        vehicle['brand'],
        vehicle['model'],
        vehicle['vehicle_name'],
        vehicle['plate_number'],
        vehicle['partner_name'],
        vehicle['owner_name'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    final allVehicles = [..._vehicles, ..._partnerVehicles];
    final available = allVehicles.where(_operatorVehicleIsAvailable).length;
    final posted = allVehicles
        .where((vehicle) => vehicle['is_posted'] == true)
        .length;
    final unavailable = allVehicles.length - available;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Management',
                      style: TextStyle(
                        color: isDark ? Colors.white : _operatorInk,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Manage PSDC vehicles and review partner vehicle inventory.',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddVehicleDialog(isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _operatorNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add New Vehicle'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1040
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 16)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _buildVehicleMetricCard(
                      'Total Vehicles',
                      allVehicles.length,
                      Icons.directions_car_outlined,
                      _operatorNavy,
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildVehicleMetricCard(
                      'Available',
                      available,
                      Icons.route_outlined,
                      const Color(0xFF2E7D32),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildVehicleMetricCard(
                      'Unavailable',
                      unavailable,
                      Icons.build_outlined,
                      const Color(0xFFC62828),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildVehicleMetricCard(
                      'Posted',
                      posted,
                      Icons.verified_outlined,
                      const Color(0xFF886A00),
                      isDark,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 720;
                      final tabs = Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildVehicleViewTab(
                              'company',
                              'Managed Vehicles',
                              isDark,
                            ),
                            _buildVehicleViewTab(
                              'partner',
                              'Partner Vehicles',
                              isDark,
                            ),
                          ],
                        ),
                      );
                      final search = SizedBox(
                        width: compact ? constraints.maxWidth : 340,
                        child: TextField(
                          controller: _vehicleSearchController,
                          onChanged: (value) => setState(
                            () => _vehicleSearchQuery = value.trim(),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search vehicle, plate, or owner',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : const Color(0xFFF4F5F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: tabs,
                            ),
                            const SizedBox(height: 12),
                            search,
                          ],
                        );
                      }
                      return Row(children: [tabs, const Spacer(), search]);
                    },
                  ),
                ),
                _buildOperatorVehicleInventory(visible, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _operatorVehicleIsAvailable(Map<String, dynamic> vehicle) {
    if (vehicle['is_available'] is bool) {
      return vehicle['is_available'] == true;
    }
    final status = vehicle['status']?.toString().trim().toLowerCase() ?? '';
    return status == 'active' || status == 'available' || status == 'approved';
  }

  Widget _buildVehicleMetricCard(
    String label,
    int value,
    IconData icon,
    Color accent,
    bool isDark,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 125),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 9,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleViewTab(String value, String label, bool isDark) {
    final selected = _vehicleView == value;
    return InkWell(
      onTap: () => setState(() => _vehicleView = value),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? _operatorGold : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected && !isDark
              ? const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? _operatorNavyDeep
                : (isDark ? Colors.grey[300] : Colors.grey.shade700),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorVehicleInventory(
    List<Map<String, dynamic>> vehicles,
    bool isDark,
  ) {
    if (vehicles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.directions_car_outlined,
              color: isDark ? Colors.grey[600] : Colors.grey.shade300,
              size: 54,
            ),
            const SizedBox(height: 12),
            Text(
              'No matching vehicles',
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: vehicles
                  .map(
                    (vehicle) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildOperatorVehicleRowCard(vehicle, isDark),
                    ),
                  )
                  .toList(),
            ),
          );
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : const Color(0xFFF7F8FA),
              child: Row(
                children: [
                  _vehicleHeaderLabel('Vehicle', 4, isDark),
                  _vehicleHeaderLabel('Owner', 3, isDark),
                  _vehicleHeaderLabel('Status', 2, isDark),
                  _vehicleHeaderLabel('Pricing', 3, isDark),
                  _vehicleHeaderLabel('Listing', 2, isDark),
                  _vehicleHeaderLabel('Actions', 2, isDark),
                ],
              ),
            ),
            ...vehicles.map(
              (vehicle) => _buildOperatorVehicleTableRow(vehicle, isDark),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : const Color(0xFFFAFBFC),
              child: Text(
                'Showing ${vehicles.length} ${_vehicleView == 'partner' ? 'partner' : 'managed'} vehicles',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _vehicleHeaderLabel(String label, int flex, bool isDark) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
          fontSize: 9,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildOperatorVehicleTableRow(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final foreground = isDark ? Colors.white : _operatorInk;
    final owner = vehicle['_source'] == 'partner'
        ? vehicle['partner_name']?.toString() ?? 'Mobilis Partner'
        : 'PSDC';
    final available = _operatorVehicleIsAvailable(vehicle);
    final posted = vehicle['is_posted'] == true;
    Widget cell(Widget child, int flex) => Expanded(flex: flex, child: child);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          cell(_buildOperatorVehicleIdentity(vehicle, isDark), 4),
          cell(
            Text(
              owner,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            3,
          ),
          cell(_buildOperatorVehicleStatus(available, isDark), 2),
          cell(
            Text(
              'PHP ${((vehicle['price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}/day\nPHP ${((vehicle['price_per_hour'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}/hour',
              style: TextStyle(color: foreground, fontSize: 10, height: 1.45),
            ),
            3,
          ),
          cell(
            Row(
              children: [
                Transform.scale(
                  scale: 0.72,
                  child: Switch(
                    value: posted,
                    onChanged: (value) => _togglePostingStatus(vehicle, value),
                    activeTrackColor: _operatorGold,
                    activeThumbColor: _operatorNavyDeep,
                  ),
                ),
                Text(
                  posted ? 'POSTED' : 'HIDDEN',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            2,
          ),
          cell(_buildOperatorVehicleMenu(vehicle, isDark), 2),
        ],
      ),
    );
  }

  Widget _buildOperatorVehicleIdentity(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final imageUrl = _primaryVehicleImageUrl(vehicle);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 62,
            height: 46,
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            child: imageUrl.isEmpty
                ? const Icon(Icons.directions_car_outlined)
                : OptimizedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: const Icon(Icons.directions_car_outlined),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _vehicleTitle(vehicle),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : _operatorInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                vehicle['plate_number']?.toString() ?? 'No plate number',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorVehicleStatus(bool available, bool isDark) {
    final color = available ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            available ? 'Available' : 'Unavailable',
            style: TextStyle(
              color: isDark ? Colors.white : _operatorInk,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  void _showOperatorVehicleDetailsDialog(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final isPartner = vehicle['_source'] == 'partner';
    final owner = isPartner
        ? vehicle['partner_name']?.toString() ?? 'Mobilis Partner'
        : 'PSDC';
    final available = _operatorVehicleIsAvailable(vehicle);
    final posted = vehicle['is_posted'] == true;
    final imageUrls = <String>{};
    final primaryImageUrl = _primaryVehicleImageUrl(vehicle);
    if (primaryImageUrl.isNotEmpty) imageUrls.add(primaryImageUrl);
    for (final image in vehicle['vehicle_images'] as List? ?? const []) {
      if (image is! Map) continue;
      final value = image['image_url']?.toString().trim() ?? '';
      if (value.isNotEmpty) imageUrls.add(_normalizeVehicleImageUrl(value));
    }
    final images = imageUrls.toList();
    var selectedImage = 0;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final surface = isDark ? const Color(0xFF172235) : Colors.white;
          final mutedSurface = isDark
              ? const Color(0xFF101B2D)
              : const Color(0xFFF5F6F7);
          final foreground = isDark ? Colors.white : _operatorInk;
          final secondary = isDark
              ? Colors.grey.shade400
              : Colors.grey.shade600;

          Widget imagePanel() => Container(
            height: 300,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: mutedSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (images.isEmpty)
                  Center(
                    child: Icon(
                      Icons.directions_car_outlined,
                      size: 72,
                      color: secondary,
                    ),
                  )
                else
                  OptimizedNetworkImage(
                    imageUrl: images[selectedImage],
                    fit: BoxFit.cover,
                    errorWidget: Icon(
                      Icons.directions_car_outlined,
                      size: 72,
                      color: secondary,
                    ),
                  ),
                if (images.length > 1) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _operatorGalleryButton(
                      Icons.chevron_left_rounded,
                      () => setDialogState(
                        () => selectedImage =
                            (selectedImage - 1 + images.length) % images.length,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _operatorGalleryButton(
                      Icons.chevron_right_rounded,
                      () => setDialogState(
                        () =>
                            selectedImage = (selectedImage + 1) % images.length,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: index == selectedImage ? 22 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == selectedImage
                                ? _operatorGold
                                : Colors.white70,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );

          Widget specs() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _operatorDetailSectionTitle(
                'Technical Specifications',
                secondary,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = constraints.maxWidth < 430
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: _operatorVehicleSpecTile(
                          'Transmission',
                          vehicle['transmission']?.toString() ?? 'Not provided',
                          Icons.settings_outlined,
                          isDark,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _operatorVehicleSpecTile(
                          'Fuel Type',
                          vehicle['fuel_type']?.toString() ?? 'Not provided',
                          Icons.local_gas_station_outlined,
                          isDark,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _operatorVehicleSpecTile(
                          'Vehicle Type',
                          (vehicle['vehicle_type'] ??
                                  vehicle['category'] ??
                                  'Not provided')
                              .toString(),
                          Icons.category_outlined,
                          isDark,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _operatorVehicleSpecTile(
                          'Seats / Color',
                          '${vehicle['seats'] ?? 'N/A'} seats - ${vehicle['color'] ?? 'Not provided'}',
                          Icons.event_seat_outlined,
                          isDark,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );

          Widget statusAndOwner() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _operatorDetailSectionTitle(
                'Asset Status & Live Data',
                secondary,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: mutedSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    _operatorVehicleHealthRow(
                      'Availability',
                      available ? 'Available' : 'Unavailable',
                      Icons.route_outlined,
                      available ? const Color(0xFF2EAD78) : Colors.redAccent,
                      foreground,
                    ),
                    const SizedBox(height: 15),
                    _operatorVehicleHealthRow(
                      'Listing',
                      posted ? 'Posted' : 'Hidden',
                      Icons.campaign_outlined,
                      posted ? _operatorGold : secondary,
                      foreground,
                    ),
                    const SizedBox(height: 15),
                    _operatorVehicleHealthRow(
                      'Location',
                      vehicle['location']?.toString().trim().isNotEmpty == true
                          ? vehicle['location'].toString()
                          : 'Not provided',
                      Icons.location_on_outlined,
                      _operatorGold,
                      foreground,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _operatorDetailSectionTitle(
                isPartner ? 'Partnership Information' : 'Ownership Information',
                secondary,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _operatorNavy,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE29A),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            isPartner
                                ? Icons.workspace_premium_outlined
                                : Icons.business_outlined,
                            color: _operatorNavy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                owner,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                isPartner
                                    ? 'PSDC CERTIFIED PARTNER'
                                    : 'PSDC DIRECT VEHICLE',
                                style: const TextStyle(
                                  color: _operatorGold,
                                  fontSize: 9,
                                  letterSpacing: 0.7,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28, color: Colors.white24),
                    _operatorPartnerContactRow(
                      Icons.email_outlined,
                      vehicle['partner_email']?.toString() ??
                          (isPartner
                              ? 'Email not provided'
                              : 'PSDC Operations'),
                    ),
                    const SizedBox(height: 10),
                    _operatorPartnerContactRow(
                      Icons.phone_outlined,
                      vehicle['partner_phone']?.toString() ??
                          (isPartner
                              ? 'Phone not provided'
                              : 'Operations Desk'),
                    ),
                    if (vehicle['partner_address']
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 10),
                      _operatorPartnerContactRow(
                        Icons.location_on_outlined,
                        vehicle['partner_address'].toString(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 790),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 16, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _operatorVehicleBadge(
                                      vehicle['plate_number']?.toString() ??
                                          'NO PLATE',
                                      _operatorNavy,
                                      _operatorGold,
                                    ),
                                    const SizedBox(width: 9),
                                    _operatorVehicleBadge(
                                      available
                                          ? 'Active & Ready'
                                          : 'Unavailable',
                                      available
                                          ? const Color(0xFFFFF4D0)
                                          : const Color(0xFFFFE1E1),
                                      available
                                          ? const Color(0xFF755B00)
                                          : const Color(0xFFC62828),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  _vehicleTitle(vehicle),
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(Icons.close_rounded, color: foreground),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 760;
                            final left = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                imagePanel(),
                                const SizedBox(height: 24),
                                specs(),
                              ],
                            );
                            if (compact) {
                              return Column(
                                children: [
                                  left,
                                  const SizedBox(height: 28),
                                  statusAndOwner(),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: left),
                                const SizedBox(width: 28),
                                Expanded(flex: 4, child: statusAndOwner()),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      color: mutedSurface,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compactFooter = constraints.maxWidth < 620;
                          final details = Row(
                            children: [
                              Expanded(
                                child: _operatorFooterValue(
                                  'PLATE NUMBER',
                                  vehicle['plate_number']?.toString() ??
                                      'Not set',
                                  foreground,
                                  secondary,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 38,
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                              const SizedBox(width: 22),
                              Expanded(
                                child: _operatorFooterValue(
                                  'CATEGORY',
                                  vehicle['category']?.toString() ?? 'Not set',
                                  foreground,
                                  secondary,
                                ),
                              ),
                            ],
                          );
                          final manageButton = ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _showEditVehicleDialog(vehicle, isDark);
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(
                                compactFooter ? double.infinity : 0,
                                50,
                              ),
                              backgroundColor: _operatorNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: Text(
                              isPartner ? 'Manage Price' : 'Manage Vehicle',
                            ),
                          );
                          if (compactFooter) {
                            return Column(
                              children: [
                                details,
                                const SizedBox(height: 16),
                                manageButton,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: details),
                              const SizedBox(width: 30),
                              manageButton,
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _operatorGalleryButton(IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xCC021F35),
          foregroundColor: Colors.white,
        ),
        icon: Icon(icon),
      ),
    );
  }

  Widget _operatorVehicleBadge(String label, Color background, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _operatorDetailSectionTitle(String title, Color color) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 9,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _operatorVehicleSpecTile(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF5F6F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: _operatorNavy, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _operatorVehicleHealthRow(
    String label,
    String value,
    IconData icon,
    Color accent,
    Color foreground,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: accent),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _operatorPartnerContactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _operatorFooterValue(
    String label,
    String value,
    Color foreground,
    Color secondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: secondary,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorVehicleMenu(Map<String, dynamic> vehicle, bool isDark) {
    final posted = vehicle['is_posted'] == true;
    final isPartner = vehicle['_source'] == 'partner';
    return PopupMenuButton<String>(
      tooltip: 'Vehicle actions',
      onSelected: (action) {
        if (action == 'view') {
          _showOperatorVehicleDetailsDialog(vehicle, isDark);
        } else if (action == 'edit') {
          _showEditVehicleDialog(vehicle, isDark);
        } else if (action == 'toggle') {
          _togglePostingStatus(vehicle, !posted);
        } else if (action == 'delete') {
          _deleteVehicle(vehicle['id']);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18),
              SizedBox(width: 9),
              Text('View Details'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 9),
              Text(isPartner ? 'Manage Price' : 'Edit Vehicle'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                posted
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              const SizedBox(width: 9),
              Text(posted ? 'Hide Listing' : 'Post Vehicle'),
            ],
          ),
        ),
        if (!isPartner)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                SizedBox(width: 9),
                Text('Delete Vehicle', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFFF2F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.more_vert_rounded, size: 19),
      ),
    );
  }

  Widget _buildOperatorVehicleRowCard(
    Map<String, dynamic> vehicle,
    bool isDark,
  ) {
    final available = _operatorVehicleIsAvailable(vehicle);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.035)
            : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildOperatorVehicleIdentity(vehicle, isDark)),
              _buildOperatorVehicleMenu(vehicle, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildOperatorVehicleStatus(available, isDark)),
              Text(
                vehicle['is_posted'] == true ? 'POSTED' : 'HIDDEN',
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : _operatorInk,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyVehiclesContent(bool isDark) {
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

  InputDecoration _registerVehicleDecoration(
    String hint,
    bool isDark, {
    Widget? suffixIcon,
  }) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFD9E0E6);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.blueGrey.shade400,
        fontSize: 13,
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.045)
          : const Color(0xFFF7F9FA),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _operatorGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
      ),
    );
  }

  Widget _registerVehicleField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDark,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.blueGrey.shade600,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          cursorColor: _operatorGold,
          style: TextStyle(
            color: isDark ? Colors.white : _operatorInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: _registerVehicleDecoration(
            hint,
            isDark,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Widget _registerVehicleDropdown({
    required String label,
    required String value,
    required List<String> options,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.blueGrey.shade600,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white54 : Colors.blueGrey,
          ),
          dropdownColor: isDark ? const Color(0xFF102C43) : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : _operatorInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: _registerVehicleDecoration('Select $label', isDark),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _resetNewVehicleForm() {
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
    _seatsController.text = '5';
    _locationController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _selectedImages = [];
    _selectedStatus = 'active';
  }

  String? _requiredVehicleField(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  String? _positiveNumberVehicleField(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) return 'Enter a value greater than 0';
    return null;
  }

  Future<bool> _saveOperatorVehicle({
    required String category,
    required String vehicleType,
    required String fuelType,
    required String transmission,
    required String status,
    required void Function(VoidCallback callback) setDialogState,
  }) async {
    setDialogState(() => _isSubmittingVehicle = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw 'Operator account is required to add vehicles';
      }

      final normalizedPlate = _plateController.text.trim().toUpperCase();
      final existing = await _supabase
          .from('vehicles')
          .select('id')
          .eq('plate_number', normalizedPlate)
          .limit(1);
      if ((existing as List).isNotEmpty) {
        throw 'A vehicle with plate number $normalizedPlate already exists';
      }

      final vehicleResponse = await _supabase
          .from('vehicles')
          .insert({
            'brand': _brandController.text.trim(),
            'model': _modelController.text.trim(),
            'category': category,
            'vehicle_type': vehicleType,
            'vehicle_name': _vehicleNameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'color': _colorController.text.trim(),
            'fuel_type': fuelType,
            'transmission': transmission,
            'plate_number': normalizedPlate,
            'year': int.parse(_yearController.text.trim()),
            'seats': int.parse(_seatsController.text.trim()),
            'price_per_day': double.parse(_priceController.text.trim()),
            'price_per_hour': double.parse(_pricePerHourController.text.trim()),
            'location': _locationController.text.trim(),
            'latitude': double.tryParse(_latitudeController.text.trim()),
            'longitude': double.tryParse(_longitudeController.text.trim()),
            'status': status,
            'is_available': status == 'active',
            'is_posted': false,
            'owner_id': currentUserId,
          })
          .select('id')
          .single();
      final vehicleId = vehicleResponse['id'].toString();

      var uploadedImageCount = 0;
      for (var index = 0; index < _selectedImages.length; index++) {
        final fileName =
            'vehicle_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
        final filePath = 'vehicles/$currentUserId/$fileName';
        try {
          final originalBytes = await _selectedImages[index].readAsBytes();
          final imageBytes = await ImageOptimizationService.optimizeForUpload(
            originalBytes,
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
          await _supabase.from('vehicle_images').insert({
            'vehicle_id': vehicleId,
            'image_url': imageUrl,
            'display_order': index,
          });
          uploadedImageCount++;
        } catch (error) {
          debugPrint('Error uploading vehicle image $index: $error');
        }
      }

      _resetNewVehicleForm();
      await _loadVehicles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uploadedImageCount == 1
                  ? 'Vehicle added with 1 image.'
                  : 'Vehicle added with $uploadedImageCount images.',
            ),
            backgroundColor: const Color(0xFF178A5B),
          ),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to add vehicle: $error'),
            backgroundColor: const Color(0xFFC93C47),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setDialogState(() => _isSubmittingVehicle = false);
      }
    }
  }

  void _showAddVehicleDialog(bool isDark) {
    _resetNewVehicleForm();
    final formKey = GlobalKey<FormState>();
    var category = 'Sedan';
    var vehicleType = 'Sedan';
    var fuelType = 'Unleaded';
    var transmission = 'Automatic';
    var status = 'active';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final foreground = isDark ? Colors.white : _operatorInk;
          final panelColor = isDark ? _operatorNavyDeep : Colors.white;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 36,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(38, 28, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Register New Vehicle',
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Configure vehicle details, pricing, and deployment status.',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.blueGrey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: _isSubmittingVehicle
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.all(12),
                            ),
                            icon: Icon(Icons.close_rounded, color: foreground),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 850;
                          final imagePanel = _buildRegisterVehicleImagePanel(
                            isDark: isDark,
                            setDialogState: setDialogState,
                          );
                          final formPanel = Form(
                            key: formKey,
                            child: _buildRegisterVehicleFields(
                              isDark: isDark,
                              category: category,
                              vehicleType: vehicleType,
                              fuelType: fuelType,
                              transmission: transmission,
                              status: status,
                              onCategoryChanged: (value) => setDialogState(
                                () => category = value ?? category,
                              ),
                              onVehicleTypeChanged: (value) => setDialogState(
                                () => vehicleType = value ?? vehicleType,
                              ),
                              onFuelTypeChanged: (value) => setDialogState(
                                () => fuelType = value ?? fuelType,
                              ),
                              onTransmissionChanged: (value) => setDialogState(
                                () => transmission = value ?? transmission,
                              ),
                              onStatusChanged: (value) => setDialogState(
                                () => status = value ?? status,
                              ),
                              setDialogState: setDialogState,
                            ),
                          );
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(38),
                            child: compact
                                ? Column(
                                    children: [
                                      imagePanel,
                                      const SizedBox(height: 28),
                                      formPanel,
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(width: 285, child: imagePanel),
                                      const SizedBox(width: 38),
                                      Expanded(child: formPanel),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 18, 30, 22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isSubmittingVehicle
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white70
                                  : Colors.blueGrey.shade700,
                              minimumSize: const Size(110, 52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isSubmittingVehicle
                                ? null
                                : () async {
                                    if (!(formKey.currentState?.validate() ??
                                        false)) {
                                      return;
                                    }
                                    final saved = await _saveOperatorVehicle(
                                      category: category,
                                      vehicleType: vehicleType,
                                      fuelType: fuelType,
                                      transmission: transmission,
                                      status: status,
                                      setDialogState: setDialogState,
                                    );
                                    if (saved && dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _operatorGold,
                              foregroundColor: _operatorNavyDeep,
                              elevation: 0,
                              minimumSize: const Size(190, 54),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 17,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isSubmittingVehicle
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _operatorNavyDeep,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 20,
                                  ),
                            label: Text(
                              _isSubmittingVehicle
                                  ? 'Adding Vehicle...'
                                  : 'Add Vehicle',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
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
          );
        },
      ),
    );
  }

  Widget _buildRegisterVehicleImagePanel({
    required bool isDark,
    required void Function(VoidCallback callback) setDialogState,
  }) {
    final borderColor = isDark ? Colors.white24 : Colors.blueGrey.shade200;
    Future<void> pickImages() async {
      final images = await _imagePicker.pickMultiImage(imageQuality: 88);
      if (images.isEmpty) return;
      setDialogState(() {
        final remaining = 5 - _selectedImages.length;
        if (remaining > 0) _selectedImages.addAll(images.take(remaining));
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VEHICLE IMAGES',
          style: TextStyle(
            color: _operatorGold,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: pickImages,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 220,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.025)
                  : const Color(0xFFF7F9FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: _selectedImages.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageWidget(
                        _selectedImages.first,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _operatorNavyDeep.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_selectedImages.length}/5 images',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: _operatorNavy.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          color: _operatorGold,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Upload vehicle images',
                        style: TextStyle(
                          color: isDark ? Colors.white : _operatorInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'JPG or PNG - up to 5 images',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.blueGrey,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 13),
                      const Text(
                        'Browse files',
                        style: TextStyle(
                          color: _operatorGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Stack(
                children: [
                  SizedBox(
                    width: 70,
                    child: _buildImageWidget(
                      _selectedImages[index],
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  Positioned(
                    top: 3,
                    right: 3,
                    child: InkWell(
                      onTap: () =>
                          setDialogState(() => _selectedImages.removeAt(index)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _selectedImages.length >= 5 ? null : pickImages,
            style: OutlinedButton.styleFrom(
              foregroundColor: _operatorGold,
              side: BorderSide(color: borderColor),
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
            label: const Text(
              'Add More Images',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRegisterVehicleFields({
    required bool isDark,
    required String category,
    required String vehicleType,
    required String fuelType,
    required String transmission,
    required String status,
    required ValueChanged<String?> onCategoryChanged,
    required ValueChanged<String?> onVehicleTypeChanged,
    required ValueChanged<String?> onFuelTypeChanged,
    required ValueChanged<String?> onTransmissionChanged,
    required ValueChanged<String?> onStatusChanged,
    required void Function(VoidCallback callback) setDialogState,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 1;
        const gap = 18.0;
        final fieldWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;
        Widget field(Widget child, {bool fullWidth = false}) => SizedBox(
          width: fullWidth ? constraints.maxWidth : fieldWidth,
          child: child,
        );
        final currentYear = DateTime.now().year;

        return Wrap(
          spacing: gap,
          runSpacing: 18,
          children: [
            field(
              _registerVehicleField(
                label: 'Brand',
                hint: 'e.g. Toyota',
                controller: _brandController,
                isDark: isDark,
                validator: _requiredVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Model',
                hint: 'e.g. Innova',
                controller: _modelController,
                isDark: isDark,
                validator: _requiredVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Year',
                hint: '$currentYear',
                controller: _yearController,
                isDark: isDark,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final year = int.tryParse(value?.trim() ?? '');
                  if (year == null || year < 1900 || year > currentYear + 1) {
                    return 'Enter a valid vehicle year';
                  }
                  return null;
                },
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Plate Number',
                hint: 'ABC 1234',
                controller: _plateController,
                isDark: isDark,
                validator: _requiredVehicleField,
              ),
            ),
            field(
              _registerVehicleDropdown(
                label: 'Transmission',
                value: transmission,
                options: const ['Automatic', 'Manual', 'CVT'],
                isDark: isDark,
                onChanged: onTransmissionChanged,
              ),
            ),
            field(
              _registerVehicleDropdown(
                label: 'Category',
                value: category,
                options: const ['Sedan', 'SUV', 'Van', 'Pickup', 'Hatchback'],
                isDark: isDark,
                onChanged: onCategoryChanged,
              ),
            ),
            field(
              _registerVehicleDropdown(
                label: 'Vehicle Type',
                value: vehicleType,
                options: const ['Sedan', 'SUV', 'Van', 'Pickup', 'Hatchback'],
                isDark: isDark,
                onChanged: onVehicleTypeChanged,
              ),
            ),
            field(
              _registerVehicleDropdown(
                label: 'Fuel Type',
                value: fuelType,
                options: const [
                  'Diesel',
                  'Premium',
                  'Unleaded',
                  'Gasoline',
                  'Electric',
                  'Hybrid',
                ],
                isDark: isDark,
                onChanged: onFuelTypeChanged,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Color',
                hint: 'e.g. Pearl White',
                controller: _colorController,
                isDark: isDark,
                validator: _requiredVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Vehicle Name',
                hint: 'Display name',
                controller: _vehicleNameController,
                isDark: isDark,
                validator: _requiredVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Seats',
                hint: '5',
                controller: _seatsController,
                isDark: isDark,
                keyboardType: TextInputType.number,
                validator: _positiveNumberVehicleField,
              ),
            ),
            field(
              _registerVehicleDropdown(
                label: 'Active Status',
                value: status,
                options: const ['active', 'inactive', 'maintenance'],
                isDark: isDark,
                onChanged: onStatusChanged,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Price / Day (PHP)',
                hint: '0.00',
                controller: _priceController,
                isDark: isDark,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _positiveNumberVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Price / Hour (PHP)',
                hint: '0.00',
                controller: _pricePerHourController,
                isDark: isDark,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _positiveNumberVehicleField,
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Location',
                hint: 'Vehicle location',
                controller: _locationController,
                isDark: isDark,
                validator: _requiredVehicleField,
                suffixIcon: IconButton(
                  tooltip: 'Use current location',
                  onPressed: () => _getCurrentVehicleLocation(
                    onLocationFound: (location, latitude, longitude) {
                      setDialogState(() {
                        _locationController.text = location;
                        _latitudeController.text = latitude;
                        _longitudeController.text = longitude;
                      });
                    },
                  ),
                  icon: const Icon(
                    Icons.my_location_rounded,
                    color: _operatorGold,
                    size: 20,
                  ),
                ),
              ),
            ),
            field(
              _registerVehicleField(
                label: 'Vehicle Description',
                hint: 'Add features, condition, and other important details...',
                controller: _descriptionController,
                isDark: isDark,
                maxLines: 3,
                validator: _requiredVehicleField,
              ),
              fullWidth: true,
            ),
          ],
        );
      },
    );
  }

  void _showLegacyAddVehicleDialog(bool isDark) {
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
    final plateController = TextEditingController(
      text: vehicle['plate_number']?.toString() ?? '',
    );
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
                            controller: plateController,
                            readOnly: isPartnerVehicle,
                            cursorColor: AppColors.primary,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _fieldDecoration(
                              'Plate Number',
                              isDark,
                            ),
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
                                  final normalizedPlate = plateController.text
                                      .trim()
                                      .toUpperCase();
                                  if (!isPartnerVehicle &&
                                      normalizedPlate.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Plate number is required.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
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
                                            'plate_number': normalizedPlate,
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
      await _loadVehicles();

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
    return SettingsScreen(
      isDarkMode: isDark,
      showHeader: false,
      showAppearance: true,
      showSignOut: true,
      onThemeToggle: widget.onThemeToggle,
      onBack: () {},
      onOpenSupport: () => setState(() => _selectedIndex = 2),
      onSignOut: _handleLogout,
      onProfileUpdated: () {
        _loadDashboardData();
      },
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
