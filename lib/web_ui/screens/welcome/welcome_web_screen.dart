import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../mobile_ui/theme/app_colors.dart';
import '../../../utils/pricing_policy.dart';

class WelcomeWebScreen extends StatefulWidget {
  const WelcomeWebScreen({super.key});

  @override
  State<WelcomeWebScreen> createState() => _WelcomeWebScreenState();
}

class _WelcomeWebScreenState extends State<WelcomeWebScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  
  // Navigation Keys for Smooth Scrolling
  final GlobalKey _vehiclesKey = GlobalKey();
  final GlobalKey _modesKey = GlobalKey();
  final GlobalKey _estimatorKey = GlobalKey();
  final GlobalKey _hubKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  // Filter & State
  String _selectedCategory = 'all';
  int _activeRoleTab = 0; // 0: Renter, 1: Driver, 2: Partner
  int? _expandedFaqIndex = 0;

  // Estimator State
  String _estimatorMode = 'daily'; // 'hourly' or 'daily'
  int _estimatorDays = 1;
  int _estimatorHours = 12;
  String _estimatorVehicleType = 'Sedan';
  bool _estimatorWithDriver = false;
  bool _estimatorDoorstepDelivery = false;
  final double _estimatorDeliveryKm = 10.0;

  // Real Database Vehicles + Rich Fallbacks
  List<Map<String, dynamic>> _liveVehicles = [];
  bool _isLoadingVehicles = true;

  // Contacts, Downloads & Brand Data
  static const String hotline1 = '0962-269-9862';
  static const String hotline2 = '0955-281-1306';
  static const String facebookUrl = 'https://www.facebook.com/psdc.dagupan';
  static const String mainOfficeLocation = 'Urdaneta City, Pangasinan, Philippines';
  static const String mainOfficePlusCode = 'XGFW+JQ Urdaneta City, Pangasinan';
  static const String googleMapsLocationUrl =
      'https://www.google.com/maps/search/?api=1&query=XGFW%2BJQ+Urdaneta+City%2C+Pangasinan';
  static const String apkDownloadUrl =
      'https://github.com/robinjay1123/mobilis_project/releases/download/APK/mobilis-app.apk';
  static const String githubReleasesUrl =
      'https://github.com/robinjay1123/mobilis_project/releases';

  @override
  void initState() {
    super.initState();
    _fetchLiveVehicles();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveVehicles() async {
    try {
      final supabase = Supabase.instance.client;
      final List<Map<String, dynamic>> combined = [];

      // 1. Fetch PSDC Company Fleet Vehicles Only (excludes partner cars to save space)
      try {
        final companyRes = await supabase
            .from('vehicles')
            .select('id, brand, model, year, plate_number, price_per_day, price_per_hour, seats, transmission, fuel_type, category, vehicle_type, vehicle_name, description, status, is_available, is_posted, rating, rating_count, vehicle_images(image_url, display_order)')
            .neq('status', 'deleted')
            .order('created_at', ascending: false);

        for (final item in List<Map<String, dynamic>>.from(companyRes)) {
          combined.add(_normalizeVehicle(item, isPartner: false));
        }
      } catch (e) {
        debugPrint('Error fetching company vehicles: $e');
      }

      if (combined.isNotEmpty && mounted) {
        setState(() {
          _liveVehicles = combined;
          _isLoadingVehicles = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error in _fetchLiveVehicles: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingVehicles = false;
      });
    }
  }

  Map<String, dynamic> _normalizeVehicle(Map<String, dynamic> raw, {required bool isPartner}) {
    String brand = _capitalize(raw['brand']?.toString() ?? 'Toyota');
    String model = _capitalize(raw['model']?.toString() ?? 'Model');
    if (brand.toUpperCase() == 'BYD') brand = 'BYD';
    if (brand.toUpperCase() == 'BMW') brand = 'BMW';

    final year = raw['year']?.toString() ?? '2024';
    final seats = (raw['seats'] as num?)?.toInt() ?? 5;
    final transmission = _cleanText(raw['transmission']) ?? 'Manual';
    final fuelType = _cleanText(raw['fuel_type']) ?? 'Gasoline';
    final priceDay = (raw['price_per_day'] as num?)?.toDouble() ?? 1800.0;
    final priceHour = (raw['price_per_hour'] as num?)?.toDouble() ?? (priceDay / 10).roundToDouble();
    final plate = raw['plate_number']?.toString().trim() ?? '';
    final category = raw['category']?.toString() ?? (isPartner ? 'Partner Vehicle' : 'Sedan');
    final vehicleType = raw['vehicle_type']?.toString() ?? category;

    // Extract best image from vehicle_images relation
    String? imageUrl;
    final images = raw['vehicle_images'];
    if (images is List && images.isNotEmpty) {
      final imgList = List<Map<String, dynamic>>.from(images.whereType<Map<String, dynamic>>());
      imgList.sort((a, b) => ((a['display_order'] as num?) ?? 0).compareTo((b['display_order'] as num?) ?? 0));
      for (final img in imgList) {
        final url = img['image_url']?.toString();
        if (url != null && url.isNotEmpty) {
          imageUrl = url;
          break;
        }
      }
    }
    imageUrl ??= raw['image_url']?.toString();

    final tag = isPartner
        ? (raw['owner_name'] != null && raw['owner_name'].toString().trim().isNotEmpty
            ? 'Partner: ${raw['owner_name']}'
            : 'Partner Vehicle')
        : 'PSDC Fleet • Urdaneta';

    return {
      'id': raw['id'],
      'brand': brand,
      'model': model,
      'year': year,
      'seats': seats,
      'transmission': transmission,
      'fuel_type': fuelType,
      'price_per_day': priceDay,
      'price_per_hour': priceHour,
      'plate_number': plate,
      'category': category,
      'vehicle_type': vehicleType,
      'image_url': imageUrl,
      'tag': tag,
      'is_partner': isPartner,
      'rating': (raw['rating'] as num?)?.toDouble() ?? 5.0,
      'rating_count': (raw['rating_count'] as num?)?.toInt() ?? 1,
    };
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.toUpperCase() == 'BYD') return 'BYD';
      if (word.toUpperCase() == 'BMW') return 'BMW';
      if (word.toUpperCase() == 'SUV') return 'SUV';
      if (word.toUpperCase() == 'MPV') return 'MPV';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String? _cleanText(dynamic text) {
    final t = text?.toString().trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  void _goToSignup() {
    _showDownloadApkDialog();
  }

  void _showDownloadApkDialog({Map<String, dynamic>? selectedVehicle}) {
    showDialog(
      context: context,
      builder: (context) {
        final vehicleName = selectedVehicle != null
            ? '${selectedVehicle['brand'] ?? ''} ${selectedVehicle['model'] ?? ''}'.trim()
            : null;
        final priceDay = (selectedVehicle?['price_per_day'] as num?)?.toDouble();

        return Dialog(
          backgroundColor: const Color(0xFF07142E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0x33FFD740)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vehicleName != null && vehicleName.isNotEmpty) ...[
                    // Selected Vehicle Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F2656), Color(0xFF081836)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 24),
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
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  priceDay != null ? '₱${priceDay.toStringAsFixed(0)} / day  •  PSDC Verified' : 'PSDC Pangasinan Fleet',
                                  style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: const Icon(Icons.android_rounded, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(height: 14),
                  ],

                  Text(
                    vehicleName != null ? 'Book in the Mobilis App' : 'Download Mobilis for Android',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vehicleName != null
                        ? 'Download the official Mobilis app to complete real-time reservation, license verification, and digital payment.'
                        : 'Official release for Renters, Drivers, and Vehicle Partners in Pangasinan.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.45),
                  ),
                  const SizedBox(height: 20),

                  // Direct Download Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openUrl(apkDownloadUrl);
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        'Direct Download (.apk)',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF030A18),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // GitHub Releases Link
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openUrl(githubReleasesUrl);
                      },
                      icon: const Icon(Icons.code_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'View on GitHub Releases',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x33FFFFFF)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Installation Tips
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF030A18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 15),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'If prompted "File might be harmful", tap "Download anyway" -> Open file -> Tap "Install".',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Curated Fallback Vehicles (4 Strict Categories: Sedan, SUV, Pickup, Van)
  final List<Map<String, dynamic>> _curatedVehicles = [
    {
      'brand': 'Toyota',
      'model': 'Vios 1.3 Dual VVT-i',
      'year': 2024,
      'category': 'Sedan',
      'seats': 5,
      'transmission': 'Automatic',
      'fuel_type': 'Gasoline',
      'price_per_day': 1800.0,
      'price_per_hour': 180.0,
      'image_url': 'https://images.unsplash.com/photo-1590362891991-f776e747a588?auto=format&fit=crop&w=800&q=80',
      'tag': 'PSDC Fleet • Urdaneta',
    },
    {
      'brand': 'Toyota',
      'model': 'Fortuner 2.4G Diesel 4x2',
      'year': 2024,
      'category': 'SUV',
      'seats': 7,
      'transmission': 'Automatic',
      'fuel_type': 'Diesel',
      'price_per_day': 3500.0,
      'price_per_hour': 380.0,
      'image_url': 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=800&q=80',
      'tag': 'PSDC Fleet • Urdaneta',
    },
    {
      'brand': 'Toyota',
      'model': 'Hilux Conquest 2.8 4x4',
      'year': 2024,
      'category': 'Pickup',
      'seats': 5,
      'transmission': 'Automatic',
      'fuel_type': 'Diesel',
      'price_per_day': 3200.0,
      'price_per_hour': 340.0,
      'image_url': 'https://images.unsplash.com/photo-1559416523-140ddc3d238c?auto=format&fit=crop&w=800&q=80',
      'tag': 'PSDC Fleet • Urdaneta',
    },
    {
      'brand': 'Toyota',
      'model': 'Hiace Commuter Deluxe 15-Seat',
      'year': 2024,
      'category': 'Van',
      'seats': 15,
      'transmission': 'Manual',
      'fuel_type': 'Diesel',
      'price_per_day': 3800.0,
      'price_per_hour': 420.0,
      'image_url': 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=800&q=80',
      'tag': 'PSDC Fleet • Urdaneta',
    },
    {
      'brand': 'Toyota',
      'model': 'Wigo 1.0G VVT-i',
      'year': 2024,
      'category': 'Sedan',
      'seats': 5,
      'transmission': 'Automatic',
      'fuel_type': 'Gasoline',
      'price_per_day': 1500.0,
      'price_per_hour': 160.0,
      'image_url': 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&w=800&q=80',
      'tag': 'PSDC Fleet • Urdaneta',
    },
    {
      'brand': 'Mitsubishi',
      'model': 'Xpander Cross 1.5 AT',
      'year': 2024,
      'category': 'SUV',
      'seats': 7,
      'transmission': 'Automatic',
      'fuel_type': 'Gasoline',
      'price_per_day': 2600.0,
      'price_per_hour': 280.0,
      'image_url': 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=800&q=80',
      'tag': 'PSDC Fleet • Urdaneta',
    },
  ];

  List<Map<String, dynamic>> get _displayVehicles {
    final source = _liveVehicles.isNotEmpty ? _liveVehicles : _curatedVehicles;
    if (_selectedCategory == 'all') return source;
    return source.where((v) {
      final cat = (v['category'] ?? '').toString().toLowerCase();
      final vType = (v['vehicle_type'] ?? '').toString().toLowerCase();
      final model = (v['model'] ?? '').toString().toLowerCase();
      final brand = (v['brand'] ?? '').toString().toLowerCase();
      final combined = '$cat $vType $model $brand';

      switch (_selectedCategory) {
        case 'sedan':
          return combined.contains('sedan') ||
              combined.contains('vios') ||
              combined.contains('wigo') ||
              combined.contains('camry') ||
              combined.contains('altis') ||
              combined.contains('city') ||
              combined.contains('hatchback') ||
              ((v['seats'] == null || (v['seats'] as int) <= 5) &&
                  !combined.contains('pickup') &&
                  !combined.contains('hilux') &&
                  !combined.contains('suv') &&
                  !combined.contains('van'));
        case 'suv':
          return combined.contains('suv') ||
              combined.contains('fortuner') ||
              combined.contains('montero') ||
              combined.contains('innova') ||
              combined.contains('xpander') ||
              combined.contains('rush') ||
              combined.contains('everest') ||
              combined.contains('cr-v') ||
              combined.contains('mpv');
        case 'pickup':
          return combined.contains('pickup') ||
              combined.contains('hilux') ||
              combined.contains('ranger') ||
              combined.contains('navara') ||
              combined.contains('d-max') ||
              combined.contains('strada') ||
              combined.contains('triton');
        case 'van':
          return combined.contains('van') ||
              combined.contains('hiace') ||
              combined.contains('commuter') ||
              combined.contains('urvan') ||
              combined.contains('grandia') ||
              (v['seats'] != null && (v['seats'] as int) >= 10);
        default:
          return combined.contains(_selectedCategory.toLowerCase());
      }
    }).toList();
  }

  // Estimator Math
  double get _calculatedEstimate {
    double baseRate = 0;
    switch (_estimatorVehicleType) {
      case 'Compact':
        baseRate = _estimatorMode == 'hourly' ? 160.0 * _estimatorHours : 1500.0 * _estimatorDays;
        break;
      case 'Sedan':
        baseRate = _estimatorMode == 'hourly' ? 180.0 * _estimatorHours : 1800.0 * _estimatorDays;
        break;
      case 'MPV':
        baseRate = _estimatorMode == 'hourly' ? 280.0 * _estimatorHours : 2600.0 * _estimatorDays;
        break;
      case 'SUV':
        baseRate = _estimatorMode == 'hourly' ? 380.0 * _estimatorHours : 3500.0 * _estimatorDays;
        break;
      case 'Van':
        baseRate = _estimatorMode == 'hourly' ? 420.0 * _estimatorHours : 3800.0 * _estimatorDays;
        break;
      default:
        baseRate = 1800.0 * _estimatorDays;
    }

    double driverCost = 0.0;
    if (_estimatorWithDriver) {
      final days = _estimatorMode == 'hourly' ? 1 : _estimatorDays;
      driverCost = days * PricingPolicy.driverDailyRate;
    }

    double deliveryCost = 0.0;
    if (_estimatorDoorstepDelivery && !_estimatorWithDriver) {
      deliveryCost = _estimatorDeliveryKm * PricingPolicy.deliveryRatePerKm;
    }

    return baseRate + driverCost + deliveryCost;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final isTablet = width >= 768 && width < 1024;

    return Scaffold(
      backgroundColor: const Color(0xFF030A18),
      body: Stack(
        children: [
          // Background Gradient Mesh
          Positioned.fill(
            child: CustomPaint(
              painter: _GridMeshPainter(),
            ),
          ),

          // Main Scrollable Body
          SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildTopAnnouncementBar(isDesktop, width),
                _buildStickyHeader(isDesktop, width),
                _buildHeroSection(isDesktop, isTablet, width),
                _buildQuickPangasinanPicker(isDesktop, width),
                _buildVehicleShowroomSection(isDesktop, isTablet, width),
                _buildThreeInOnePlatformSection(isDesktop, isTablet, width),
                _buildPangasinanHubSection(isDesktop, isTablet, width),
                _buildRateEstimatorSection(isDesktop, isTablet, width),
                _buildWhyMobilisSafetySection(isDesktop, isTablet, width),
                _buildFaqSection(isDesktop, width),
                _buildPreFooterCta(isDesktop, width),
                _buildFooterSection(isDesktop, width),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. TOP ANNOUNCEMENT BAR
  // ==========================================
  Widget _buildTopAnnouncementBar(bool isDesktop, double width) {
    final isMobile = width < 640;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF06142E),
        border: Border(bottom: BorderSide(color: Color(0x20FFD740))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            isMobile ? 'PANGASINAN SERVICE' : 'PANGASINAN & NEARBY PROVINCES ONLY',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => _openUrl(googleMapsLocationUrl),
                        child: const Text(
                          '•   Main Office: Urdaneta City ($mainOfficePlusCode)   •   PSDC Fleet',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              InkWell(
                onTap: () => _callPhone(hotline1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      hotline1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
  }

  // ==========================================
  // 2. STICKY HEADER WITH AUTH BUTTONS
  // ==========================================
  Widget _buildStickyHeader(bool isDesktop, double width) {
    final isMobile = width < 768;

    return Container(
      width: double.infinity,
      height: isMobile ? 68 : 84,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: const Color(0xE6030A18),
        border: const Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand Logo
              InkWell(
                onTap: () => _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                ),
                child: Row(
                  children: [
                    Container(
                      width: isMobile ? 38 : 44,
                      height: isMobile ? 38 : 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD740), Color(0xFFFFB300)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(5),
                      child: Image.asset('assets/icon/logo-black.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'MOBILIS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PSDC',
                                style: TextStyle(
                                  color: Color(0xFF030A18),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isMobile)
                          const Text(
                            'PANGASINAN CAR RENTAL HUB',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Navigation links (Desktop)
              if (isDesktop)
                Row(
                  children: [
                    _buildHeaderNavLink('Vehicles', () => _scrollToSection(_vehiclesKey)),
                    _buildHeaderNavLink('3-in-1 Platform', () => _scrollToSection(_modesKey)),
                    _buildHeaderNavLink('Pangasinan Hub', () => _scrollToSection(_hubKey)),
                    _buildHeaderNavLink('Rate Estimator', () => _scrollToSection(_estimatorKey)),
                    _buildHeaderNavLink('FAQ', () => _scrollToSection(_faqKey)),
                    _buildHeaderNavLink('Contact', () => _scrollToSection(_contactKey)),
                  ],
                ),

              // Desktop Header Actions
              if (isDesktop)
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showDownloadApkDialog,
                      icon: const Icon(Icons.android_rounded, size: 16, color: AppColors.primary),
                      label: const Text('Download APK', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x44FFD740)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _goToLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x33FFFFFF)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _goToSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF030A18),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        children: [
                          Text('Register', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                )
              else
                // Mobile & Tablet Header Actions
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _goToLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x44FFFFFF)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showMobileNavSheet,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1F42),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
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

  void _showMobileNavSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF07142E),
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                _buildMobileNavItem('🚗  Vehicles', () {
                  Navigator.of(context).pop();
                  _scrollToSection(_vehiclesKey);
                }),
                _buildMobileNavItem('🔄  3-in-1 Platform (Renter, Driver, Partner)', () {
                  Navigator.of(context).pop();
                  _scrollToSection(_modesKey);
                }),
                _buildMobileNavItem('📍  Pangasinan Hub & Coverage', () {
                  Navigator.of(context).pop();
                  _scrollToSection(_hubKey);
                }),
                _buildMobileNavItem('💰  Rate Estimator', () {
                  Navigator.of(context).pop();
                  _scrollToSection(_estimatorKey);
                }),
                _buildMobileNavItem('❓  FAQ', () {
                  Navigator.of(context).pop();
                  _scrollToSection(_faqKey);
                }),
                _buildMobileNavItem('📞  Contact & Support', () {
                  Navigator.of(context).pop();
                  _scrollToSection(_contactKey);
                }),
                const Divider(color: Color(0x1AFFFFFF), height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showDownloadApkDialog();
                    },
                    icon: const Icon(Icons.android_rounded, size: 18),
                    label: const Text('Download Android APK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF030A18),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _goToLogin();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Admin & Operator Portal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileNavItem(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderNavLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. HERO SECTION
  // ==========================================
  Widget _buildHeroSection(bool isDesktop, bool isTablet, double width) {
    final isMobile = width < 768;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 24,
        vertical: isDesktop ? 70 : (isTablet ? 48 : 36),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 7),
                    Text(
                      isMobile ? 'PANGASINAN PREMIER CAR RENTAL' : 'PANGASINAN’S PREMIER 100% CAR RENTAL SERVICE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: isMobile ? 10.5 : 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Big Catchy Title
              Text(
                'Rent a Car & Enjoy the Journey\nExclusively in Pangasinan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 52 : (isTablet ? 38 : 28),
                  fontWeight: FontWeight.w900,
                  height: 1.18,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Description
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Text(
                  'Explore Pangasinan with ease. Flexible Hourly (12 hrs minimum) & Daily rentals for Sedans, SUVs, MPVs, and 15-Seat Tour Vans. Choose self-drive or hire a professional driver with 24/7 active GPS tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF94A3B8),
                    fontSize: isDesktop ? 16 : 14,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _scrollToSection(_vehiclesKey),
                    icon: const Icon(Icons.directions_car_rounded, size: 18),
                    label: const Text('Browse Vehicles', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF030A18),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                      shadowColor: AppColors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showDownloadApkDialog,
                    icon: const Icon(Icons.android_rounded, size: 18, color: Colors.white),
                    label: const Text('Download Android APK', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2B5C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0x55FFD740)),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _scrollToSection(_hubKey),
                    icon: const Icon(Icons.location_city_rounded, size: 18, color: AppColors.primary),
                    label: const Text('Urdaneta Hub', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Key Trust Metric Cards
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : 16,
                    vertical: isDesktop ? 20 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1733),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: isDesktop
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildHeroStat('Urdaneta HQ', 'Central Pangasinan Office'),
                            _buildHeroStatDivider(),
                            _buildHeroStat('100% GPS', 'Active Satellite Tracking'),
                            _buildHeroStatDivider(),
                            _buildHeroStat('Self-Drive / Driver', 'Flexible Rental Options'),
                            _buildHeroStatDivider(),
                            _buildHeroStat('12h to Multi-Day', 'Half-day & Daily Rates'),
                          ],
                        )
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.spaceAround,
                          children: [
                            SizedBox(
                              width: width < 400 ? (width - 70) / 2 : 140,
                              child: _buildHeroStat('Urdaneta HQ', 'Central Hub'),
                            ),
                            SizedBox(
                              width: width < 400 ? (width - 70) / 2 : 140,
                              child: _buildHeroStat('100% GPS', 'Satellite Tracking'),
                            ),
                            SizedBox(
                              width: width < 400 ? (width - 70) / 2 : 140,
                              child: _buildHeroStat('Self-Drive/Driver', 'Flexible Options'),
                            ),
                            SizedBox(
                              width: width < 400 ? (width - 70) / 2 : 140,
                              child: _buildHeroStat('12h to Daily', 'Transparent Rates'),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStat(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStatDivider() {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0x22FFFFFF),
    );
  }

  // ==========================================
  // 4. QUICK PANGASINAN PICKER BAR
  // ==========================================
  Widget _buildQuickPangasinanPicker(bool isDesktop, double width) {
    final isMobile = width < 768;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0C1D40), Color(0xFF07142D)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _buildQuickPickerItem(
                  icon: Icons.location_on_rounded,
                  label: 'Pick-up Location',
                  value: 'Urdaneta City / Pangasinan Hub',
                ),
                _buildQuickPickerItem(
                  icon: Icons.schedule_rounded,
                  label: 'Rental Duration',
                  value: 'Hourly (12h Min) or Daily',
                ),
                _buildQuickPickerItem(
                  icon: Icons.person_pin_circle_rounded,
                  label: 'Driver Option',
                  value: 'Self-Drive or with Driver',
                ),
                SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: ElevatedButton.icon(
                    onPressed: _showDownloadApkDialog,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Check Availability', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF030A18),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildQuickPickerItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 5. VEHICLE SHOWROOM SECTION
  // ==========================================
  Widget _buildVehicleShowroomSection(bool isDesktop, bool isTablet, double width) {
    final vehicles = _displayVehicles;
    final isMobile = width < 768;

    return Container(
      key: _vehiclesKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Section Header
              const Text(
                'EXPLORE OUR PANGASINAN FLEET',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Available Vehicles Ready For Your Journey',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'All vehicles undergo 100% digital safety inspections and include real-time satellite GPS tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 28),

              // 4 Category Filter Tabs + All
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCategoryFilterTab('all', 'All Vehicles', Icons.directions_car_filled_rounded),
                    _buildCategoryFilterTab('sedan', 'Sedans', Icons.directions_car_rounded),
                    _buildCategoryFilterTab('suv', 'SUVs', Icons.car_rental_rounded),
                    _buildCategoryFilterTab('pickup', 'Pickups', Icons.local_shipping_rounded),
                    _buildCategoryFilterTab('van', 'Vans', Icons.airport_shuttle_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Vehicle Grid
              if (_isLoadingVehicles)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 3;
                    double childAspectRatio = 1.18;
                    if (constraints.maxWidth < 680) {
                      crossAxisCount = 1;
                      childAspectRatio = 1.12;
                    } else if (constraints.maxWidth < 1050) {
                      crossAxisCount = 2;
                      childAspectRatio = 1.16;
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: vehicles.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final v = vehicles[index];
                        return _HoverVehicleCard(
                          vehicle: v,
                          onBook: () => _showDownloadApkDialog(selectedVehicle: v),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterTab(String key, String label, IconData icon) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = key),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFF0A1733),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0x22FFFFFF),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF030A18) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF030A18) : const Color(0xFFCBD5E1),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 6. 3-IN-1 PLATFORM SECTION (RENTER, DRIVER, PARTNER)
  // ==========================================
  Widget _buildThreeInOnePlatformSection(bool isDesktop, bool isTablet, double width) {
    final isMobile = width < 768;

    return Container(
      key: _modesKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF061229),
        border: Border.symmetric(horizontal: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              const Text(
                'A UNIFIED ECOSYSTEM',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'One Platform For Renters, Drivers & Partners',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Whether you want to rent a car, drive professionally, or earn passive income with your vehicle—Mobilis PSDC connects everything seamlessly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Role Tabs Switcher (Scrollable horizontally on mobile)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF030A18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRoleTabButton(0, '🔑 Rent a Car (Renter)'),
                      _buildRoleTabButton(1, '🧑‍✈️ Drive as Driver'),
                      _buildRoleTabButton(2, '🤝 List Your Vehicle (Partner)'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Active Role Tab Details Card
              _buildActiveRoleContent(isDesktop, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTabButton(int index, String label) {
    final isSelected = _activeRoleTab == index;
    return InkWell(
      onTap: () => setState(() => _activeRoleTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF030A18) : const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRoleContent(bool isDesktop, bool isMobile) {
    if (_activeRoleTab == 0) {
      // Renter
      return _buildRoleCardLayout(
        badge: 'FOR RENTERS',
        title: 'Seamless Car Rental with Zero Headaches',
        description:
            'Book verified cars in Pangasinan for business, family outings, tourism, or emergencies. Choose between flexible 12-hour minimum hourly rentals or full daily rentals. Opt for self-drive or relax with a certified professional driver.',
        features: [
          'Hourly (12h min) & Daily rental flexibility',
          'Doorstep delivery anywhere in Pangasinan',
          'Self-drive or with professional driver options',
          '100% digital contract, MPIN & electronic signatures',
        ],
        ctaText: 'Sign Up as Renter',
        onCta: _goToSignup,
        icon: Icons.key_rounded,
        isMobile: isMobile,
      );
    } else if (_activeRoleTab == 1) {
      // Driver
      return _buildRoleCardLayout(
        badge: 'FOR PROFESSIONAL DRIVERS',
        title: 'Earn Transparent Daily Driver Fees in Pangasinan',
        description:
            'Join our elite pool of accredited drivers. Receive assigned rental trips across Pangasinan and neighboring regions with clear route waypoints, guaranteed daily driver rates, and transparent payout settlements.',
        features: [
          'Fixed PHP 1,500.00 / day driver fee guaranteed',
          'Digital itinerary & GPS route guidance in-app',
          'Protected by Mobilis verification & safety guidelines',
          'Instant driver settlement & trip rating records',
        ],
        ctaText: 'Apply as Driver',
        onCta: _goToSignup,
        icon: Icons.airline_seat_recline_extra_rounded,
        isMobile: isMobile,
      );
    } else {
      // Partner
      return _buildRoleCardLayout(
        badge: 'FOR VEHICLE OWNERS (PARTNERS)',
        title: 'Turn Your Vehicle Into a High-Earning Asset',
        description:
            'List your car with Mobilis PSDC. We handle verified renter screenings, digital contracts, and vehicle tracking. Monitor your vehicle’s live GPS location 24/7 with our integrated AIKA / Traccar GPS system.',
        features: [
          'Earn high monthly passive income per vehicle',
          'Real-time GPS tracker connection & monitoring',
          'Full digital pre-trip and post-trip condition logs',
          'Operator-backed fleet management and security',
        ],
        ctaText: 'List Your Vehicle',
        onCta: _goToSignup,
        icon: Icons.handshake_rounded,
        isMobile: isMobile,
      );
    }
  }

  Widget _buildRoleCardLayout({
    required String badge,
    required String title,
    required String description,
    required List<String> features,
    required String ctaText,
    required VoidCallback onCta,
    required IconData icon,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 36),
      decoration: BoxDecoration(
        color: const Color(0xFF091636),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: features.map((f) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Text(f, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            )).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: isMobile ? double.infinity : null,
            child: ElevatedButton.icon(
              onPressed: onCta,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(ctaText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: const Color(0xFF030A18),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. PANGASINAN HUB & COVERAGE SECTION
  // ==========================================
  Widget _buildPangasinanHubSection(bool isDesktop, bool isTablet, double width) {
    final isMobile = width < 768;

    return Container(
      key: _hubKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              const Text(
                'LOCAL COVERAGE & HEADQUARTERS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Exclusively Serving Pangasinan & Nearby Places',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Headquartered in Urdaneta City with coverage spanning all major towns and cities across Pangasinan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 36),

              // Hub Info Cards
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _buildHubDetailCard(
                    icon: Icons.location_on_rounded,
                    title: 'Main Office (Tap for Maps 📍)',
                    value: '$mainOfficeLocation\n($mainOfficePlusCode)',
                    subtext: 'Tap to view exact GPS location & directions on Google Maps',
                    onTap: () => _openUrl(googleMapsLocationUrl),
                    isDesktop: isDesktop,
                    width: width,
                  ),
                  _buildHubDetailCard(
                    icon: Icons.phone_in_talk_rounded,
                    title: 'Available Hotlines',
                    value: '$hotline1\n$hotline2',
                    subtext: 'Call or SMS for reservations & roadside assistance',
                    onTap: () => _callPhone(hotline1),
                    isDesktop: isDesktop,
                    width: width,
                  ),
                  _buildHubDetailCard(
                    icon: Icons.facebook_rounded,
                    title: 'Official Facebook',
                    value: 'fb.com/psdc.dagupan',
                    subtext: 'Follow us for promos, announcements & updates',
                    onTap: () => _openUrl(facebookUrl),
                    isDesktop: isDesktop,
                    width: width,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Pangasinan Towns Badges
              Container(
                padding: EdgeInsets.all(isMobile ? 18 : 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF071533),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ACTIVE SERVICE COVERAGE TOWNS',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        'Urdaneta City (HQ)',
                        'Dagupan City',
                        'San Carlos City',
                        'Lingayen',
                        'Manaoag',
                        'Rosales',
                        'Alaminos City (Hundred Islands)',
                        'Calasiao',
                        'Malasiqui',
                        'Villasis',
                        'Binalonan',
                        'Tayug',
                        'Mangaldan',
                        'Nearby Provinces (La Union / Tarlac / Baguio transit)',
                      ].map((town) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D224E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: Text(
                          town,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
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

  Widget _buildHubDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtext,
    required bool isDesktop,
    required double width,
    VoidCallback? onTap,
  }) {
    final cardWidth = isDesktop ? 360.0 : (width < 420 ? double.infinity : 340.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1838),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtext, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 8. INTERACTIVE RENTAL RATE ESTIMATOR
  // ==========================================
  Widget _buildRateEstimatorSection(bool isDesktop, bool isTablet, double width) {
    final isMobile = width < 768;

    return Container(
      key: _estimatorKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF061229),
        border: Border.symmetric(horizontal: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              const Text(
                'TRANSPARENT PRICING ESTIMATOR',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Instant Cost Breakdown Calculator',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Calculate transparent estimated rental fees according to PSDC Pangasinan pricing rules.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Interactive Estimator Card
              Container(
                padding: EdgeInsets.all(isMobile ? 18 : 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1838),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 24,
                  children: [
                    // Left Column: Controls
                    SizedBox(
                      width: isDesktop ? 540 : double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rental Mode
                          const Text('Rental Type', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildEstimatorPill(
                                selected: _estimatorMode == 'daily',
                                label: '📅 Daily Rental',
                                onTap: () => setState(() => _estimatorMode = 'daily'),
                              ),
                              const SizedBox(width: 10),
                              _buildEstimatorPill(
                                selected: _estimatorMode == 'hourly',
                                label: '⏱️ Hourly (12h Min)',
                                onTap: () => setState(() => _estimatorMode = 'hourly'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Vehicle Type
                          const Text('Vehicle Class', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['Sedan', 'SUV', 'Pickup', 'Van'].map((type) {
                              final isSel = _estimatorVehicleType == type;
                              return InkWell(
                                onTap: () => setState(() => _estimatorVehicleType = type),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSel ? AppColors.primary : const Color(0xFF06142E),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isSel ? AppColors.primary : const Color(0x22FFFFFF)),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      color: isSel ? const Color(0xFF030A18) : Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Duration Slider
                          Text(
                            _estimatorMode == 'daily'
                                ? 'Duration: $_estimatorDays Day${_estimatorDays == 1 ? '' : 's'}'
                                : 'Duration: $_estimatorHours Hours (Half-day+)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Slider(
                            value: _estimatorMode == 'daily' ? _estimatorDays.toDouble() : _estimatorHours.toDouble(),
                            min: _estimatorMode == 'daily' ? 1 : 12,
                            max: _estimatorMode == 'daily' ? 14 : 24,
                            divisions: _estimatorMode == 'daily' ? 13 : 12,
                            activeColor: AppColors.primary,
                            inactiveColor: const Color(0x22FFFFFF),
                            onChanged: (val) {
                              setState(() {
                                if (_estimatorMode == 'daily') {
                                  _estimatorDays = val.toInt();
                                } else {
                                  _estimatorHours = val.toInt();
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          // Driver Toggle
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Hire a Professional Driver', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                            subtitle: const Text('PHP 1,500.00 / day. (Doorstep delivery included free with driver)', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            value: _estimatorWithDriver,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) => setState(() => _estimatorWithDriver = val),
                          ),

                          // Doorstep Delivery Toggle (Self-Drive only)
                          if (!_estimatorWithDriver) ...[
                            const SizedBox(height: 6),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Doorstep Delivery (Self-Drive)', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                              subtitle: const Text('PHP 75.00 / km anywhere in Pangasinan', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              value: _estimatorDoorstepDelivery,
                              activeThumbColor: AppColors.primary,
                              onChanged: (val) => setState(() => _estimatorDoorstepDelivery = val),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Right Column: Live Price Breakdown
                    SizedBox(
                      width: isDesktop ? 380 : double.infinity,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06142E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ESTIMATED SUMMARY', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const SizedBox(height: 16),
                            _buildBreakdownRow('Rental Class', _estimatorVehicleType),
                            _buildBreakdownRow('Mode', _estimatorMode == 'daily' ? '$_estimatorDays Day(s)' : '$_estimatorHours Hours'),
                            if (_estimatorWithDriver)
                              _buildBreakdownRow('Driver Fee', '₱${(PricingPolicy.driverDailyRate * (_estimatorMode == 'daily' ? _estimatorDays : 1)).toStringAsFixed(2)}'),
                            if (_estimatorDoorstepDelivery && !_estimatorWithDriver)
                              _buildBreakdownRow('Delivery Fee (~10km)', '₱${(10 * PricingPolicy.deliveryRatePerKm).toStringAsFixed(2)}'),
                            const Divider(color: Color(0x22FFFFFF), height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Estimated Rate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  '₱${_calculatedEstimate.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _showDownloadApkDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: const Color(0xFF030A18),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Proceed to Book in Mobile App', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                              ),
                            ),
                          ],
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
  }

  Widget _buildEstimatorPill({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFF06142E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : const Color(0x22FFFFFF)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF030A18) : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }

  // ==========================================
  // 9. WHY MOBILIS & SAFETY SECTION
  // ==========================================
  Widget _buildWhyMobilisSafetySection(bool isDesktop, bool isTablet, double width) {
    final isMobile = width < 768;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              const Text(
                'SAFE & RELIABLE JOURNEYS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Why Renters in Pangasinan Choose Mobilis',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 36),

              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _buildFeatureHighlightCard(
                    icon: Icons.gps_fixed_rounded,
                    title: '24/7 Satellite GPS Safety',
                    description: 'Every vehicle is paired with live real-time GPS tracking for passenger and fleet security.',
                    isDesktop: isDesktop,
                    width: width,
                  ),
                  _buildFeatureHighlightCard(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Digital Pre/Post Inspection',
                    description: 'Full damage checklist and timestamped photo verification protects you against disputed charges.',
                    isDesktop: isDesktop,
                    width: width,
                  ),
                  _buildFeatureHighlightCard(
                    icon: Icons.price_check_rounded,
                    title: 'Fixed Transparent Rates',
                    description: 'No hidden surge pricing. Clear hourly half-day and daily rates across all vehicle categories.',
                    isDesktop: isDesktop,
                    width: width,
                  ),
                  _buildFeatureHighlightCard(
                    icon: Icons.shield_rounded,
                    title: 'Verified Drivers & Renters',
                    description: 'Strict identity, valid government ID & driver license screenings ensure safe travels.',
                    isDesktop: isDesktop,
                    width: width,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureHighlightCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isDesktop,
    required double width,
  }) {
    final cardWidth = isDesktop ? 280.0 : (width < 640 ? double.infinity : 300.0);

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1838),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.5)),
        ],
      ),
    );
  }

  // ==========================================
  // 10. FAQ SECTION
  // ==========================================
  Widget _buildFaqSection(bool isDesktop, double width) {
    final isMobile = width < 768;
    final faqs = [
      {
        'q': 'Where is Mobilis exclusively available?',
        'a': 'Mobilis is exclusively available throughout the province of Pangasinan (including Urdaneta City, Dagupan City, San Carlos, Lingayen, Manaoag, Alaminos, Rosales, etc.) and neighboring transit corridors. Our central headquarters is in Urdaneta City.',
      },
      {
        'q': 'What are the requirements to rent a vehicle?',
        'a': 'Renters need 1 valid Government-issued ID, a valid Driver’s License (for self-drive), emergency contact details, and co-traveler information. All verification is handled conveniently inside the Mobilis app.',
      },
      {
        'q': 'Can I hire a professional driver?',
        'a': 'Yes! You can hire an accredited professional driver for PHP 1,500.00 / day. When hiring a driver, doorstep pick-up is already included in your booking.',
      },
      {
        'q': 'What is the minimum hourly rental duration?',
        'a': 'Hourly rentals have a minimum duration of 12 hours (Half-day) to guarantee vehicle reservation and turnaround readiness.',
      },
      {
        'q': 'How does vehicle doorstep delivery work?',
        'a': 'For self-drive bookings, you can request doorstep delivery anywhere in Pangasinan at PHP 75.00 per kilometer from the PSDC garage.',
      },
      {
        'q': 'How can vehicle owners join as Partners?',
        'a': 'Vehicle owners can register as Partners in the app, upload vehicle OR/CR documentation, connect their GPS tracker, and start earning passive rental income.',
      },
    ];

    return Container(
      key: _faqKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF061229),
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              const Text(
                'FREQUENTLY ASKED QUESTIONS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Got Questions? We Have Answers',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 36 : (isMobile ? 24 : 28),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 32),

              Column(
                children: List.generate(faqs.length, (index) {
                  final faq = faqs[index];
                  final isExpanded = _expandedFaqIndex == index;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1838),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isExpanded ? AppColors.primary.withValues(alpha: 0.4) : const Color(0x1AFFFFFF)),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _expandedFaqIndex = isExpanded ? null : index;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 16 : 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    faq['q']!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 13.5 : 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isExpanded ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
                                  color: isExpanded ? AppColors.primary : const Color(0xFF64748B),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded)
                          Padding(
                            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 20, 0, isMobile ? 16 : 20, isMobile ? 16 : 20),
                            child: Text(
                              faq['a']!,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 11. PRE-FOOTER CALL TO ACTION
  // ==========================================
  Widget _buildPreFooterCta(bool isDesktop, double width) {
    final isMobile = width < 768;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 36 : 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 36, vertical: isMobile ? 32 : 48),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF132854), Color(0xFF0A1733)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 40,
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'READY TO HIT THE ROAD?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create Your Mobilis Account Today',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 36 : (isMobile ? 22 : 26),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Instant bookings, GPS protection, and flexible hourly or daily rates throughout Pangasinan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _goToSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF030A18),
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Create Free Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showDownloadApkDialog,
                      icon: const Icon(Icons.android_rounded, size: 18, color: Colors.white),
                      label: const Text('Download Android APK', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F2B5C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0x55FFD740)),
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _goToLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Admin & Operator Portal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 12. FOOTER SECTION
  // ==========================================
  Widget _buildFooterSection(bool isDesktop, double width) {
    final isMobile = width < 768;

    return Container(
      key: _contactKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 40),
      decoration: const BoxDecoration(
        color: Color(0xFF020712),
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand & Address
                    Expanded(
                      flex: 2,
                      child: _buildFooterBrandColumn(),
                    ),
                    const SizedBox(width: 48),
                    // Contacts
                    Expanded(
                      child: _buildFooterContactsColumn(),
                    ),
                    // Quick Links
                    Expanded(
                      child: _buildFooterQuickLinksColumn(),
                    ),
                  ],
                )
              else
                // Mobile & Tablet Stacked Footer
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFooterBrandColumn(),
                    const SizedBox(height: 24),
                    _buildFooterContactsColumn(),
                    const SizedBox(height: 24),
                    _buildFooterQuickLinksColumn(),
                  ],
                ),
              const Divider(color: Color(0x1AFFFFFF), height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      '© 2026 Mobilis PSDC. All rights reserved.',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 11),
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Pangasinan, PH',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
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
  }

  Widget _buildFooterBrandColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/icon/logo-black.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            const Text(
              'MOBILIS PSDC',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Pangasinan’s premier car rental solutions platform. Verified fleet, accredited drivers, and registered vehicle partners.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _openUrl(googleMapsLocationUrl),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$mainOfficeLocation ($mainOfficePlusCode)',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0x55FFD740),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterContactsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CONTACTS & SUPPORT', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => _callPhone(hotline1),
          child: const Text('📞 $hotline1', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _callPhone(hotline2),
          child: const Text('📞 $hotline2', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _openUrl(facebookUrl),
          child: const Text('🌐 fb.com/psdc.dagupan', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildFooterQuickLinksColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK ACCESS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        InkWell(onTap: _showDownloadApkDialog, child: const Text('📲 Download Android App (.apk)', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(height: 6),
        InkWell(onTap: _goToLogin, child: const Text('Admin & Operator Portal', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
        const SizedBox(height: 6),
        InkWell(onTap: _showDownloadApkDialog, child: const Text('Register via Mobile App', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => Navigator.of(context).pushNamed('/terms-and-privacy'),
          child: const Text('Legal Terms & Privacy Policy', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
      ],
    );
  }
}

class _GridMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 1;

    const step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HoverVehicleCard extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final VoidCallback onBook;

  const _HoverVehicleCard({
    required this.vehicle,
    required this.onBook,
  });

  @override
  State<_HoverVehicleCard> createState() => _HoverVehicleCardState();
}

class _HoverVehicleCardState extends State<_HoverVehicleCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final brand = vehicle['brand']?.toString() ?? 'Toyota';
    final model = vehicle['model']?.toString() ?? 'Model';
    final year = vehicle['year']?.toString() ?? '2024';
    final seats = vehicle['seats']?.toString() ?? '5';
    final transmission = vehicle['transmission']?.toString() ?? 'Automatic';
    final fuel = vehicle['fuel_type']?.toString() ?? 'Gasoline';
    final priceDay = (vehicle['price_per_day'] as num?)?.toDouble() ?? 1800.0;
    final priceHour = (vehicle['price_per_hour'] as num?)?.toDouble() ?? (priceDay / 10).roundToDouble();
    final tag = vehicle['tag']?.toString() ?? 'PSDC Fleet • Urdaneta';
    final plate = vehicle['plate_number']?.toString().trim() ?? '';
    
    String? imageUrl = vehicle['image_url']?.toString();
    if (imageUrl == null && vehicle['vehicle_images'] is List && (vehicle['vehicle_images'] as List).isNotEmpty) {
      imageUrl = vehicle['vehicle_images'][0]['image_url']?.toString();
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF0D2048) : const Color(0xFF091636),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered ? AppColors.primary : const Color(0x22FFFFFF),
            width: _isHovered ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.35),
              blurRadius: _isHovered ? 24 : 14,
              offset: Offset(0, _isHovered ? 10 : 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Image Container with Zoom Effect on Hover
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                  child: Container(
                    height: 165,
                    width: double.infinity,
                    color: const Color(0xFF061026),
                    child: AnimatedScale(
                      scale: _isHovered ? 1.06 : 1.0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildFallbackCarGraphic(brand, model),
                            )
                          : _buildFallbackCarGraphic(brand, model),
                    ),
                  ),
                ),
                // Gradient overlay at bottom of image for sleek transition
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ),
                // PSDC Fleet Tag
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFD740), Color(0xFFFFB300)]),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Color(0xFF030A18),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                // GPS Monitored Indicator Badge
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xDD000000),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isHovered ? AppColors.primary : const Color(0x33FFFFFF),
                        width: 1,
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
                            color: _isHovered ? AppColors.primary : const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 4.5),
                        const Text(
                          'GPS LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Compact Details Section (Snug fit, no giant empty space)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$brand $model',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (plate.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x22FFFFFF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            plate,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$year Model  •  Exclusively in Pangasinan',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Specs Chips
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _buildSpecBadge(Icons.people_alt_outlined, '$seats Seats'),
                      _buildSpecBadge(Icons.settings_outlined, transmission),
                      _buildSpecBadge(Icons.local_gas_station_outlined, fuel),
                    ],
                  ),

                  const SizedBox(height: 10),
                  const Divider(color: Color(0x1AFFFFFF), height: 1),
                  const SizedBox(height: 10),

                  // Pricing & Action Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₱${priceDay.toStringAsFixed(0)} / day',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '₱${priceHour.toStringAsFixed(0)}/hr (12h min)',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: widget.onBook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isHovered ? AppColors.primary : const Color(0xFFFFD740),
                          foregroundColor: const Color(0xFF030A18),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                          elevation: _isHovered ? 5 : 2,
                          shadowColor: AppColors.primary.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Book Now', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
                            if (_isHovered) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 13),
                            ],
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
    );
  }

  Widget _buildFallbackCarGraphic(String brand, String model) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_rounded, size: 48, color: AppColors.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          Text(
            '$brand $model',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          const Text('Mobilis Verified Vehicle', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSpecBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF061229),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: AppColors.primary),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
