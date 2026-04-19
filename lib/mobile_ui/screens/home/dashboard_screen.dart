import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/app_bar_with_logo.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/conversation_tile.dart';
import '../../widgets/notification_item.dart';
import '../../widgets/cost_breakdown_row.dart';
import '../../widgets/trip_timeline_step.dart';
import '../profile/settings_screen.dart';
import '../profile/payment_methods_screen.dart';
import '../profile/verification_documents_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const DashboardScreen({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedNavIndex = 0;
  String selectedCategory = 'Economy';
  String? selectedProfilePage; // null = main profile, else = specific page

  // User data
  String userName = 'Loading...';
  String userLocation = 'Loading...';
  bool emailConfirmed = true;
  bool userVerified = true; // Default to true, check against DB

  // Real data from services
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoadingVehicles = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadUserData();
    _initializeConnectivity();
    // Delay verification check until dashboard is fully visible (3 seconds)
    // This prevents the modal from appearing during login/navigation transitions
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _checkAndShowVerificationModal();
      }
    });
    _loadAllData();
  }

  // Load all data from services
  Future<void> _loadAllData() async {
    _loadVehicles();
    _loadBookings();
    _loadConversations();
    _loadNotifications();
  }

  // Refresh function for pull-to-refresh
  Future<void> _refreshDashboard() async {
    await _loadAllData();
  }

  Future<void> _loadVehicles() async {
    try {
      final vehicleService = VehicleService();
      final vehicles = await vehicleService.getAvailableVehicles();
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _isLoadingVehicles = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      if (mounted) {
        setState(() {
          _isLoadingVehicles = false;
        });
      }
    }
  }

  Future<void> _loadBookings() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user != null) {
        final bookingService = BookingService();
        final bookings = await bookingService.getRenterBookings(user.id);
        if (mounted) {
          setState(() {
            _bookings = bookings;
          });
        }
      } else {
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error loading bookings: $e');
    }
  }

  Future<void> _loadConversations() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user != null) {
        final chatService = ChatService();
        final conversations = await chatService.getConversations(user.id);
        if (mounted) {
          setState(() {
            _conversations = conversations;
          });
        }
      } else {
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user != null) {
        final notificationService = NotificationService();
        final notifications = await notificationService.getNotifications(
          user.id,
        );
        if (mounted) {
          setState(() {
            _notifications = notifications;
          });
        }
      } else {
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _checkAndShowVerificationModal() async {
    final authService = AuthService();

    // Only show verification modal if the dashboard is actually the current active route
    if (ModalRoute.of(context)?.isCurrent != true) {
      debugPrint('Dashboard not current route, skipping verification modal');
      return;
    }

    // Check if user needs ID verification
    final needsVerification = await authService.needsIdVerification();

    if (needsVerification &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      _showVerificationModal();
    }
  }

  void _showVerificationModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      color: AppColors.warning,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Identity Verification Required',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please verify your identity to start\nrenting cars on Mobilis',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed('/id-verification');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Verify Now',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Maybe Later',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
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

  void _initializeConnectivity() async {
    final connectivityService = ConnectivityService();

    // Check initial connectivity
    await connectivityService.checkConnectivity();

    // Listen to connectivity changes
    connectivityService.listenConnectivity((isOnline) {
      // Show warning if offline
      if (!isOnline && mounted) {
        _showOfflineWarning();
      }
    });
  }

  void _showRentalVerificationModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.warning,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Verification Required',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Complete your identity verification\nto book and rent cars',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed('/id-verification');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Verify Identity',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
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

  bool _checkRentalVerification() {
    if (!userVerified) {
      _showRentalVerificationModal();
      return false;
    }
    return true;
  }

  void _showOfflineWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 12),
            Text('No Internet Connection'),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _checkAuth() {
    // Allow temporary access during email confirmation phase
    // Once email is confirmed and user logs in, full session will be active
    // For now, allow access without full authentication to enable testing
  }

  void _loadUserData() async {
    final authService = AuthService();
    final user = authService.currentUser;

    if (user != null) {
      // Get user metadata
      final fullName = user.userMetadata?['full_name'] ?? 'User';
      final location = user.userMetadata?['location'] ?? 'Not specified';

      // Check if email is confirmed
      final emailConfirmedValue = user.emailConfirmedAt != null;

      // Check if user is verified
      final isVerified = await authService.isUserVerified();

      setState(() {
        userName = fullName;
        userLocation = location;
        emailConfirmed = emailConfirmedValue;
        userVerified = isVerified;
      });

      // Show warning if email not confirmed
      if (!emailConfirmedValue && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.mail_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Check your email to confirm your account'),
                    ),
                  ],
                ),
                backgroundColor: Color(0xFFF59E0B),
                duration: Duration(seconds: 5),
              ),
            );
          }
        });
      }
    } else {
      setState(() {
        userName = 'Guest';
        userLocation = 'Not specified';
        emailConfirmed = true;
        userVerified = true;
      });
    }
  }

  final List<Map<String, dynamic>> categories = [
    {'name': 'Economy', 'icon': Icons.directions_car},
    {'name': 'SUV', 'icon': Icons.directions_car},
    {'name': 'Luxury', 'icon': Icons.diamond},
    {'name': 'Van', 'icon': Icons.directions_car},
  ];

  List<Map<String, dynamic>> _uiBookings() {
    return _bookings.map((booking) {
      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final totalCost =
          (booking['total_price'] as num?)?.toDouble() ??
          (booking['total_cost'] as num?)?.toDouble() ??
          0.0;

      final startDateRaw = booking['start_date']?.toString();
      final endDateRaw = booking['end_date']?.toString();
      final startDate = _formatDateShort(startDateRaw);
      final endDate = _formatDateShort(endDateRaw);

      int days = 1;
      try {
        if (startDateRaw != null && endDateRaw != null) {
          final start = DateTime.parse(startDateRaw);
          final end = DateTime.parse(endDateRaw);
          days = end.difference(start).inDays.abs();
          if (days == 0) days = 1;
        }
      } catch (_) {
        days = 1;
      }

      final rawStatus = (booking['status'] ?? '').toString().toLowerCase();
      String uiStatus;
      if (rawStatus == 'active') {
        uiStatus = 'Active';
      } else if (rawStatus == 'completed') {
        uiStatus = 'Past';
      } else if (rawStatus == 'cancelled' || rawStatus == 'rejected') {
        uiStatus = 'Cancelled';
      } else {
        uiStatus = 'Upcoming';
      }

      return {
        'id': booking['id']?.toString() ?? '',
        'carName':
            '${vehicle?['brand'] ?? 'Unknown'} ${vehicle?['model'] ?? ''}'
                .trim(),
        'carImage': Icons.directions_car,
        'status': uiStatus,
        'startDate': startDate,
        'endDate': endDate,
        'pickupLocation':
            booking['pickup_location']?.toString() ?? 'Pickup not specified',
        'dropoffLocation':
            booking['dropoff_location']?.toString() ?? 'Drop-off not specified',
        'totalCost': totalCost,
        'days': days,
        'rentalPartner':
            vehicle?['owner_name']?.toString() ?? 'Mobilis Partner',
        'rating': (vehicle?['rating'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _uiNotifications() {
    return _notifications.map((n) {
      final type = (n['type'] ?? 'general').toString().toLowerCase();
      IconData icon;
      Color iconColor;
      if (type.contains('booking')) {
        icon = Icons.calendar_today;
        iconColor = AppColors.warning;
      } else if (type.contains('message')) {
        icon = Icons.message;
        iconColor = AppColors.primary;
      } else if (type.contains('payment') || type.contains('success')) {
        icon = Icons.check_circle;
        iconColor = AppColors.success;
      } else {
        icon = Icons.notifications;
        iconColor = AppColors.textSecondary;
      }

      return {
        'title': n['title']?.toString() ?? 'Notification',
        'message': n['message']?.toString() ?? '',
        'timestamp': _formatTimeAgo(n['created_at']?.toString()),
        'icon': icon,
        'iconColor': iconColor,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _uiConversations() {
    final currentUserId = AuthService().currentUser?.id;

    return _conversations.map((c) {
      final messages = List<Map<String, dynamic>>.from(
        (c['messages'] as List<dynamic>? ?? []).map(
          (m) => Map<String, dynamic>.from(m as Map),
        ),
      );

      messages.sort((a, b) {
        final aTime = a['created_at']?.toString();
        final bTime = b['created_at']?.toString();
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });

      final mappedMessages = messages.map((m) {
        return {
          'sender': currentUserId != null && m['sender_id'] == currentUserId,
          'message': m['content']?.toString() ?? '',
          'time': _formatTimeShort(m['created_at']?.toString()),
        };
      }).toList();

      final unreadCount = messages
          .where(
            (m) => m['sender_id'] != currentUserId && m['is_read'] == false,
          )
          .length;

      final lastMessage = mappedMessages.isNotEmpty
          ? mappedMessages.last['message']?.toString() ?? ''
          : 'No messages';

      return {
        'id': c['id']?.toString() ?? '',
        'senderName': 'Conversation',
        'lastMessage': lastMessage,
        'timestamp': _formatTimeAgo(c['updated_at']?.toString()),
        'unreadCount': unreadCount,
        'messages': mappedMessages,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _topRentalPartners() {
    final partnerMap = <String, Map<String, dynamic>>{};

    for (final vehicle in _vehicles) {
      final ownerName =
          vehicle['owner_name']?.toString() ??
          vehicle['partner_name']?.toString() ??
          'Mobilis Partner';
      final rating = (vehicle['rating'] as num?)?.toDouble() ?? 0.0;

      final current = partnerMap[ownerName];
      if (current == null) {
        partnerMap[ownerName] = {
          'name': ownerName,
          'ratingTotal': rating,
          'ratingCount': rating > 0 ? 1 : 0,
          'trips': 1,
          'image': Icons.person,
          'verified': true,
        };
      } else {
        current['ratingTotal'] = (current['ratingTotal'] as double) + rating;
        current['ratingCount'] =
            (current['ratingCount'] as int) + (rating > 0 ? 1 : 0);
        current['trips'] = (current['trips'] as int) + 1;
      }
    }

    final result = partnerMap.values.map((p) {
      final count = p['ratingCount'] as int;
      final avg = count > 0 ? (p['ratingTotal'] as double) / count : 0.0;
      return {
        'name': p['name'],
        'rating': avg,
        'reviews': '${p['trips']} vehicles',
        'image': p['image'],
        'verified': p['verified'],
      };
    }).toList();

    result.sort(
      (a, b) => ((b['rating'] as double)).compareTo(a['rating'] as double),
    );
    return result.take(10).toList();
  }

  String _formatDateShort(String? date) {
    if (date == null || date.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(date).toLocal();
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
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return date;
    }
  }

  String _formatTimeShort(String? date) {
    if (date == null || date.isEmpty) return '--:--';
    try {
      final d = DateTime.parse(date).toLocal();
      final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final minute = d.minute.toString().padLeft(2, '0');
      final suffix = d.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    } catch (_) {
      return date;
    }
  }

  String _formatTimeAgo(String? date) {
    if (date == null || date.isEmpty) return 'just now';
    try {
      final d = DateTime.parse(date).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return _formatDateShort(date);
    } catch (_) {
      return date;
    }
  }

  // Track selected chat and booking
  int? selectedConversationIndex;
  int? selectedBookingIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBarWithLogo(title: 'Mobilis by PSDC', showLogo: true),
      body: _buildTabContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedNavIndex,
        backgroundColor: AppColors.darkBgSecondary,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          setState(() {
            selectedNavIndex = index;
            selectedConversationIndex = null;
            selectedBookingIndex = null;
          });
        },
      ),
    );
  }

  Widget _buildTabContent() {
    switch (selectedNavIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildBookingsTab();
      case 2:
        return _buildNotificationsTab();
      case 3:
        return _buildMessagesTab();
      case 4:
        return _buildProfileTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    final uiBookings = _uiBookings();
    final homeTrips = uiBookings
        .where((b) => b['status'] == 'Active' || b['status'] == 'Upcoming')
        .take(10)
        .toList();
    final partnerItems = _topRentalPartners();

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with profile and location
            Container(
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.of(context).padding.top + 24,
                24,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile section
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome,',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.favorite_border,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'CURRENT LOCATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {},
                        child: const Icon(
                          Icons.expand_more,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userLocation,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: TextField(
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Find a car near you...',
                        hintStyle: const TextStyle(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textTertiary,
                        ),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.tune,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Categories section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = selectedCategory == category['name'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCategory = category['name'];
                              });
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.darkBgSecondary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.borderColor,
                                    ),
                                  ),
                                  child: Icon(
                                    category['icon'],
                                    color: isSelected
                                        ? Colors.black
                                        : AppColors.textSecondary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  category['name'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Active Bookings section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Trips',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: homeTrips.isEmpty
                        ? Container(
                            decoration: BoxDecoration(
                              color: AppColors.darkBgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderColor),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_taxi,
                                    size: 40,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No bookings yet',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: homeTrips.length,
                            itemBuilder: (context, index) {
                              final booking = homeTrips[index];
                              final isActive = booking['status'] == 'Active';
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () {},
                                  child: Container(
                                    width: 280,
                                    decoration: BoxDecoration(
                                      color: AppColors.darkBgSecondary,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isActive
                                            ? AppColors.primary
                                            : AppColors.borderColor,
                                        width: isActive ? 2 : 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: AppColors.darkBgTertiary,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                booking['carImage'],
                                                color: AppColors.textSecondary,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    booking['carName'],
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  Text(
                                                    booking['rentalPartner'],
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors
                                                          .textTertiary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? AppColors.success
                                                    : AppColors.warning,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                booking['status'],
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today,
                                              size: 12,
                                              color: AppColors.textTertiary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${booking['days']} days',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(
                                              Icons.location_on,
                                              size: 12,
                                              color: AppColors.textTertiary,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                booking['pickupLocation'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.arrow_forward,
                                              size: 12,
                                              color: AppColors.textTertiary,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                booking['dropoffLocation'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Total',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        AppColors.textTertiary,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${booking['totalCost']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  size: 12,
                                                  color: AppColors.ratingGold,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${booking['rating']}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
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
            const SizedBox(height: 24),

            // Top Rental Partners section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Top Rental Partners',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: partnerItems.length,
                      itemBuilder: (context, index) {
                        final partner = partnerItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              width: 120,
                              decoration: BoxDecoration(
                                color: AppColors.darkBgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          partner['image'],
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (partner['verified'])
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: AppColors.success,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              border: Border.all(
                                                color:
                                                    AppColors.darkBgSecondary,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 10,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    partner['name'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: AppColors.ratingGold,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${partner['rating']}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    partner['reviews'],
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
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
            const SizedBox(height: 24),

            // Featured Cars section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Featured Cars',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Row(
                      children: const [
                        Text(
                          'Sort by: Popular',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _isLoadingVehicles
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : _vehicles.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.asset(
                              'assets/icon/logo1.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No vehicles available',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _vehicles.length,
                    itemBuilder: (context, index) {
                      final car = _vehicles[index];
                      final carName =
                          '${car['brand'] ?? 'Unknown'} ${car['model'] ?? 'Model'}';
                      final category = (car['category'] ?? 'Standard')
                          .toString()
                          .toUpperCase();
                      final price =
                          (car['price_per_day'] as num?)?.toDouble() ?? 0.0;
                      final rating = (car['rating'] as num?)?.toDouble() ?? 4.5;
                      final transmission = car['transmission'] ?? 'Auto';
                      final fuel = car['fuel_type'] ?? 'Petrol';
                      final seats = car['seats'] ?? 5;
                      final imageUrl = car['image_url'] as String?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/vehicle-detail',
                              arguments: {
                                'vehicleId': car['id']?.toString() ?? '',
                                'vehicleData': car,
                              },
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.darkBgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Car image placeholder
                                  Stack(
                                    children: [
                                      Container(
                                        height: 200,
                                        color: AppColors.darkBgTertiary,
                                        child: imageUrl != null
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (_, __, ___) =>
                                                    const Center(
                                                      child: Icon(
                                                        Icons.directions_car,
                                                        size: 60,
                                                        color: AppColors
                                                            .textTertiary,
                                                      ),
                                                    ),
                                              )
                                            : const Center(
                                                child: Icon(
                                                  Icons.directions_car,
                                                  size: 60,
                                                  color: AppColors.textTertiary,
                                                ),
                                              ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.darkBgSecondary,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: AppColors.borderColor,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: AppColors.ratingGold,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: AppColors.darkBgSecondary,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppColors.borderColor,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.favorite_border,
                                            color: AppColors.textSecondary,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Car details
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          carName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          category,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                _buildFeatureIcon(
                                                  Icons.settings_outlined,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  transmission.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                _buildFeatureIcon(
                                                  Icons.local_gas_station,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  fuel.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                _buildFeatureIcon(Icons.person),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '$seats Seats',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '\$${price.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                const Text(
                                                  '/day',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: 44,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  if (_checkRentalVerification()) {
                                                    Navigator.of(
                                                      context,
                                                    ).pushNamed(
                                                      '/vehicle-detail',
                                                      arguments: {
                                                        'vehicleId':
                                                            car['id']
                                                                ?.toString() ??
                                                            '',
                                                        'vehicleData': car,
                                                      },
                                                    );
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.primary,
                                                  foregroundColor: Colors.black,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Book Now',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
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
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // Bookings Tab
  Widget _buildBookingsTab() {
    final uiBookings = _uiBookings();

    return Column(
      children: [
        // Yellow banner with back button
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            12,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedNavIndex = 0;
                  });
                },
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'My Bookings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBgSecondary
                      : Colors.white,
                  child: TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondary
                        : const Color(0xFF666666),
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Active'),
                      Tab(text: 'Past'),
                      Tab(text: 'Cancelled'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBookingsList(
                        uiBookings
                            .where((b) => b['status'] == 'Upcoming')
                            .toList(),
                      ),
                      _buildBookingsList(
                        uiBookings
                            .where((b) => b['status'] == 'Active')
                            .toList(),
                      ),
                      _buildBookingsList(
                        uiBookings.where((b) => b['status'] == 'Past').toList(),
                      ),
                      _buildBookingsList(
                        uiBookings
                            .where((b) => b['status'] == 'Cancelled')
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text(
              'No bookings found',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          bookings.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedBookingIndex = index;
                });
                _showBookingDetails(bookings[index]);
              },
              child: BookingCard(
                carName: bookings[index]['carName'],
                rentalPartner: bookings[index]['rentalPartner'],
                status: bookings[index]['status'],
                days: bookings[index]['days'],
                pickupLocation: bookings[index]['pickupLocation'],
                dropoffLocation: bookings[index]['dropoffLocation'],
                totalCost: bookings[index]['totalCost'],
                rating: bookings[index]['rating'],
                isActive: bookings[index]['status'] == 'Active',
                onTap: () {
                  _showBookingDetails(bookings[index]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Notifications Tab
  Widget _buildNotificationsTab() {
    final notificationItems = _uiNotifications();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 16,
        16,
        16,
      ),
      child: Column(
        children: List.generate(
          notificationItems.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NotificationItem(
              icon: notificationItems[index]['icon'],
              title: notificationItems[index]['title'],
              message: notificationItems[index]['message'],
              timestamp: notificationItems[index]['timestamp'],
              iconColor: notificationItems[index]['iconColor'],
            ),
          ),
        ),
      ),
    );
  }

  // Messages Tab (Chat Conversation)
  Widget _buildMessagesTab() {
    final conversationItems = _uiConversations();

    if (selectedConversationIndex == null) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 16,
          16,
          16,
        ),
        child: Column(
          children: List.generate(
            conversationItems.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ConversationTile(
                senderName: conversationItems[index]['senderName'],
                lastMessage: conversationItems[index]['lastMessage'],
                timestamp: conversationItems[index]['timestamp'],
                unreadCount: conversationItems[index]['unreadCount'],
                onTap: () {
                  final conversationId = conversationItems[index]['id'];
                  final recipientName = conversationItems[index]['senderName'];
                  Navigator.of(context).pushNamed(
                    '/chat-detail',
                    arguments: {
                      'conversationId': conversationId,
                      'recipientName': recipientName,
                      'recipientAvatar': '',
                      'isDarkMode': widget.isDarkMode,
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    final conversation = conversationItems[selectedConversationIndex!];
    final messages = conversation['messages'] as List;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            12,
          ),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            border: Border(bottom: BorderSide(color: AppColors.borderColor)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedConversationIndex = null;
                  });
                },
                child: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  conversation['senderName'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.call, color: AppColors.textSecondary),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            reverse: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                messages.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MessageBubble(
                    message: messages[index]['message'],
                    timestamp: messages[index]['time'],
                    isSender: messages[index]['sender'],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            border: Border(top: BorderSide(color: AppColors.borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: const TextField(
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type message...',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.black),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Profile Tab
  Widget _buildProfileTab() {
    // If a profile page is selected, show that instead
    if (selectedProfilePage != null) {
      if (selectedProfilePage == 'settings') {
        return SettingsScreen(
          onThemeToggle: widget.onThemeToggle,
          isDarkMode: widget.isDarkMode,
          onBack: () {
            setState(() {
              selectedProfilePage = null;
            });
          },
        );
      } else if (selectedProfilePage == 'payment') {
        return PaymentMethodsScreen(
          isDarkMode: widget.isDarkMode,
          onBack: () {
            setState(() {
              selectedProfilePage = null;
            });
          },
        );
      } else if (selectedProfilePage == 'verification') {
        return VerificationDocumentsScreen(
          isDarkMode: widget.isDarkMode,
          onBack: () {
            setState(() {
              selectedProfilePage = null;
            });
          },
        );
      }
    }

    // Main profile view
    return Column(
      children: [
        // Yellow banner with back button
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            12,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedNavIndex = 0;
                  });
                },
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Icon(
                  Icons.notifications_none,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile header with image and info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.black,
                              size: 50,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.darkBg,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Verified Renter',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Member since 2023',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkBgSecondary
                                : AppColors.lightBgSecondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.borderColor
                                  : AppColors.lightBorderColor,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '42',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total Trips',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Menu items
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildProfileMenuOption(
                        Icons.calendar_today,
                        'My Bookings',
                        onTap: () {
                          setState(() {
                            selectedNavIndex = 1;
                          });
                        },
                      ),
                      _buildProfileMenuOption(
                        Icons.chat,
                        'Messages',
                        badgeCount: 3,
                        onTap: () {
                          setState(() {
                            selectedNavIndex = 3;
                          });
                        },
                      ),
                      _buildProfileMenuOption(
                        Icons.payment,
                        'Payment Methods',
                        onTap: () {
                          setState(() {
                            selectedProfilePage = 'payment';
                          });
                        },
                      ),
                      _buildProfileMenuOption(
                        Icons.verified_user,
                        'Verification Documents',
                        onTap: () {
                          setState(() {
                            selectedProfilePage = 'verification';
                          });
                        },
                      ),
                      _buildProfileMenuOption(
                        Icons.settings,
                        'Settings',
                        onTap: () {
                          setState(() {
                            selectedProfilePage = 'settings';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Appearance section (Light/Dark mode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBgSecondary
                          : AppColors.lightBgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.borderColor
                            : AppColors.lightBorderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appearance',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.isDarkMode ? 'Dark Mode' : 'Light Mode',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: widget.isDarkMode,
                          onChanged: (value) {
                            widget.onThemeToggle?.call(value);
                          },
                          activeThumbColor: AppColors.primary,
                          inactiveThumbColor: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Log Out'),
                            content: const Text(
                              'Are you sure you want to log out?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Log Out',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          final authService = AuthService();
                          await authService.signOut();
                          if (mounted) {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/login');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMenuOption(
    IconData icon,
    String label, {
    int badgeCount = 0,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBgSecondary
              : AppColors.lightBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.borderColor
                : AppColors.lightBorderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textTertiary
                  : AppColors.lightTextTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Detail modals
  void _showBookingDetails(Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trip Details',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Car info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.darkBgTertiary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['carName'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          booking['rentalPartner'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: booking['status']),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Trip timeline
            const Text(
              'Trip Timeline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TripTimelineStep(
              label: 'Pickup',
              date: booking['startDate'],
              time: '2:00 PM',
              icon: Icons.location_on,
              isActive: true,
            ),
            const SizedBox(height: 16),
            TripTimelineStep(
              label: 'Dropoff',
              date: booking['endDate'],
              time: '2:00 PM',
              icon: Icons.location_on,
              isCompleted: booking['status'] == 'Completed',
            ),
            const SizedBox(height: 16),

            // Trip breakdown
            const Text(
              'Cost Breakdown',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            CostBreakdownRow(
              label:
                  '${booking['days']} days × \$${booking['totalCost'] ~/ booking['days']}/day',
              amount: '\$${booking['totalCost']}',
            ),
            CostBreakdownRow(label: 'Insurance', amount: '\$50'),
            CostBreakdownRow(
              label: 'Tax (10%)',
              amount:
                  '\$${((booking['totalCost'] + 50) * 0.1).toStringAsFixed(0)}',
            ),
            const Divider(color: AppColors.borderColor),
            CostBreakdownRow(
              label: 'Total',
              amount:
                  '\$${(booking['totalCost'] + 50 + ((booking['totalCost'] + 50) * 0.1)).toStringAsFixed(0)}',
              isBold: true,
              amountColor: AppColors.primary,
            ),
            const SizedBox(height: 20),

            // Action buttons
            if (booking['status'] == 'Active')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Extend Trip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel Trip'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon) {
    return Icon(icon, size: 14, color: AppColors.textTertiary);
  }
}
